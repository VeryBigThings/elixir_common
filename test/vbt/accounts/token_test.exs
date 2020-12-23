defmodule VBT.Accounts.TokenTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import Ecto.Query
  import VBT.TestHelper

  alias Ecto.Adapters.SQL.Sandbox
  alias VBT.Accounts
  alias VBT.Accounts.Token
  alias VBT.Schemas.Serial

  require Periodic.Test

  setup do
    Sandbox.checkout(VBT.TestRepo)
    :ok
  end

  # Note: most of the token behaviour is already verified via `VBT.AccountsTest`. The tests
  # here are checking couple of other properties, and for the sake of simplicity, this behaviour
  # is tested only on a serial id variant. Therefore, keep in mind that this module is not a
  # complete verification of the token behavior.

  @config %{
    repo: VBT.TestRepo,
    schemas: %{account: Serial.Account, token: Serial.Token},
    login_field: :email,
    password_hash_field: :password_hash,
    min_password_length: 6
  }

  describe "use" do
    test "succeeds with a valid token" do
      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", 100, @config)
      assert Token.use(token, "some type", &{:ok, &1}, @config) == {:ok, account.id}
      assert used?(token)
    end

    test "fails for the token of a different type" do
      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", 100, @config)
      assert Token.use(token, "another type", &{:ok, &1}, @config) == {:error, :invalid}
      refute used?(token)
    end

    test "fails for the token created for an unknown user" do
      token = Token.create!(nil, "some type", 100, @config)
      assert Token.use(token, "some type", &{:ok, &1}, @config) == {:error, :invalid}
      refute used?(token)
    end

    test "fails if the operation returns an error" do
      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", 100, @config)

      assert Token.use(token, "some type", fn _ -> {:error, :some_error} end, @config) ==
               {:error, :some_error}

      refute used?(token)
    end

    defp used?(token) do
      [used?] =
        VBT.TestRepo.one!(
          from token in @config.schemas.token,
            where: [hash: ^Token.hash(token)],
            select: [not is_nil(token.used_at)]
        )

      used?
    end
  end

  describe "get_account" do
    test "returns the account if the token is valid" do
      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", 100, @config)
      assert Token.get_account(token, "some type", @config) == account
    end

    test "returns nil if the token type is incorrect" do
      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", 100, @config)
      assert is_nil(Token.get_account(token, "another type", @config))
    end

    test "returns nil if the token expired" do
      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", -1, @config)
      assert is_nil(Token.get_account(token, "some type", @config))
    end

    test "returns nil if the token is invalid" do
      create_account(@config)
      assert is_nil(Token.get_account("invalid token", "some type", @config))
    end
  end

  describe "VBT.Accounts.Token.Cleanup" do
    setup do
      Periodic.Test.observe(__MODULE__)
    end

    test "removes expired token" do
      cleaner_pid = start_cleanup_process!(now_fun: fn -> future_time(5, :second) end)

      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", 1, @config)

      sync_tick(cleaner_pid)
      refute exists?(token)
    end

    test "removes used token" do
      cleaner_pid = start_cleanup_process!(now_fun: fn -> future_time(1, :second) end)

      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", 100, @config)
      Token.use(token, "some type", &{:ok, &1}, @config)

      sync_tick(cleaner_pid)
      refute exists?(token)
    end

    test "preserves valid token" do
      cleaner_pid = start_cleanup_process!()

      {:ok, account} = create_account(@config)
      token = Token.create!(account, "some type", 100, @config)

      sync_tick(cleaner_pid)
      assert exists?(token)
    end

    test "preserves expired and used tokens until the retention period expires" do
      cleaner_pid = start_cleanup_process!(retention: :timer.seconds(1))

      {:ok, account} = create_account(@config)
      expired_token = Token.create!(account, "some type", 0, @config)

      used_token = Token.create!(account, "some type", 100, @config)
      Token.use(used_token, "some type", &{:ok, &1}, @config)

      sync_tick(cleaner_pid)
      assert exists?(expired_token)
      assert exists?(used_token)

      stop_supervised(Token.Cleanup)

      cleaner_pid =
        start_cleanup_process!(
          retention: :timer.seconds(1),
          now_fun: fn -> future_time(2, :second) end
        )

      sync_tick(cleaner_pid)
      refute exists?(expired_token)
      refute exists?(used_token)
    end

    defp future_time(quantity, unit),
      do: DateTime.add(DateTime.utc_now(), quantity, unit)

    defp start_cleanup_process!(opts \\ []) do
      opts =
        Keyword.merge(
          [every: 100, retention: 0, config: @config, telemetry_id: __MODULE__, mode: :manual],
          opts
        )

      cleanup_pid = start_supervised!({Token.Cleanup, opts})
      Sandbox.allow(VBT.TestRepo, self(), cleanup_pid)
      cleanup_pid
    end

    defp sync_tick(cleaner_pid) do
      Periodic.Test.tick(cleaner_pid)
      Periodic.Test.assert_periodic_event(__MODULE__, :finished, %{reason: :normal})
    end

    defp exists?(token),
      do: VBT.TestRepo.exists?(from @config.schemas.token, where: [hash: ^Token.hash(token)])
  end

  defp create_account(config, data \\ []) do
    defaults = %{
      name: "name_#{unique_positive_integer()}",
      email: "email_#{unique_positive_integer()}@x.y.z",
      password: "password_#{unique_positive_integer()}"
    }

    data = Map.merge(defaults, Map.new(data))

    config.schemas.account
    |> struct()
    |> change(Map.take(data, [:name]))
    |> Accounts.create(data.email, data.password, config)
  end
end
