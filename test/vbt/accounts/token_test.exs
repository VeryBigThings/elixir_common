defmodule VBT.Accounts.TokenTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import Ecto.Query
  import VBT.TestHelper

  alias Ecto.Adapters.SQL.Sandbox
  alias VBT.Accounts
  alias VBT.Accounts.Token
  alias VBT.Schemas.Serial

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
    min_password_length: 6,
    secret_key_base: String.duplicate("A", 64)
  }

  test "token data is successfully decoded" do
    {:ok, account} = create_account(@config)
    encoded_token = Token.create!(account, %{foo: :bar}, 100, @config)
    assert {:ok, token} = Token.decode(encoded_token, account, @config)
    assert token.data == %{foo: :bar}
  end

  test "if use operation fails, its error is returned, and token is not used" do
    {:ok, account} = create_account(@config)
    encoded_token = Token.create!(account, nil, 100, @config)
    {:ok, token} = Token.decode(encoded_token, account, @config)

    assert Token.use(token, account, fn -> {:error, :some_error} end, @config) ==
             {:error, :some_error}

    assert VBT.TestRepo.exists?(
             from token in @config.schemas.token,
               where: token.id == ^token.id and is_nil(token.used_at)
           )
  end

  describe "VBT.Accounts.Token.Cleanup" do
    test "removes expired token" do
      start_cleanup_process()

      {:ok, account} = create_account(@config)
      encoded_token = Token.create!(account, nil, 1, @config)
      {:ok, token} = Token.decode(encoded_token, account, @config)

      eventually(fn -> refute exists?(token) end, attempts: 100, delay: 100)
    end

    test "removes used token" do
      start_cleanup_process()

      {:ok, account} = create_account(@config)
      encoded_token = Token.create!(account, nil, 100, @config)
      {:ok, token} = Token.decode(encoded_token, account, @config)
      Token.use(token, account, fn -> {:ok, nil} end, @config)

      eventually(fn -> refute exists?(token) end, attempts: 100, delay: 100)
    end

    test "preserves valid token" do
      start_cleanup_process()

      {:ok, account} = create_account(@config)
      encoded_token = Token.create!(account, nil, 100, @config)
      {:ok, token} = Token.decode(encoded_token, account, @config)

      Process.sleep(1000)
      assert exists?(token)
    end

    test "preserves expired and used tokens until the retention period expires" do
      start_cleanup_process(retention: :timer.seconds(2))

      {:ok, account} = create_account(@config)
      encoded_token = Token.create!(account, nil, -1, @config)
      {:ok, expired_token} = Token.decode(encoded_token, account, @config)

      encoded_token = Token.create!(account, nil, 100, @config)
      {:ok, used_token} = Token.decode(encoded_token, account, @config)
      Token.use(used_token, account, fn -> {:ok, nil} end, @config)

      Process.sleep(1000)
      assert exists?(expired_token)
      assert exists?(used_token)

      eventually(
        fn ->
          refute exists?(expired_token)
          refute exists?(used_token)
        end,
        attempts: 100,
        delay: 100
      )
    end

    defp start_cleanup_process(opts \\ []) do
      opts = Keyword.merge([every: 100, retention: 0, config: @config], opts)
      cleanup_pid = start_supervised!({Token.Cleanup, opts})
      Sandbox.allow(VBT.TestRepo, self(), cleanup_pid)
    end

    defp exists?(token),
      do: VBT.TestRepo.exists?(from token in @config.schemas.token, where: token.id == ^token.id)
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
