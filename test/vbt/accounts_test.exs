defmodule VBT.AccountsTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import VBT.TestHelper

  alias Ecto.Adapters.SQL.Sandbox
  alias VBT.Accounts
  alias VBT.Schemas.{AccountSerialId, AccountUuid}

  setup do
    Sandbox.checkout(VBT.TestRepo)
  end

  for {kind, schema, tokens_table} <- [
        {:serial_id, AccountSerialId, "tokens_serial_id"},
        {:uuid, AccountUuid, "tokens_uuid"}
      ] do
    @config %{
      repo: VBT.TestRepo,
      schema: schema,
      login_field: :email,
      password_hash_field: :password_hash,
      min_password_length: 6,
      secret_key_base: String.duplicate("A", 64),
      tokens_table: tokens_table
    }

    describe "create for table with #{kind} id" do
      test "creates the account" do
        assert {:ok, account} = create_account(@config, name: "some_name", email: "email@x.y.z")
        assert account.name == "some_name"
        assert account.email == "email@x.y.z"
      end

      test "doesn't store password in cleartext" do
        password = "super secret password"
        {:ok, account} = create_account(@config, password: password)
        refute Enum.any?(Map.values(account), &(&1 == password))
      end

      test "rejects empty login" do
        assert {:error, changeset} = create_account(@config, email: "")
        assert "can't be blank" in errors_on(changeset).email
      end

      test "rejects invalid email" do
        assert {:error, changeset} = create_account(@config, email: "invalid email")
        assert "has invalid format" in errors_on(changeset).email
      end

      test "rejects duplicate email" do
        {:ok, account} = create_account(@config)
        assert {:error, changeset} = create_account(@config, email: account.email)
        assert "has already been taken" in errors_on(changeset).email
      end

      test "rejects empty password" do
        assert {:error, changeset} = create_account(@config, password: "")
        assert "can't be blank" in errors_on(changeset).password
      end

      test "rejects too short password" do
        assert {:error, changeset} = create_account(@config, password: "a")
        assert "should be at least 6 character(s)" in errors_on(changeset).password
      end

      test "includes client errors in result" do
        assert {:error, changeset} =
                 @config.schema
                 |> struct()
                 |> change()
                 |> validate_required(:name)
                 |> Accounts.create("mail@x.y.z", "some password", @config)

        assert "can't be blank" in errors_on(changeset).name
      end
    end

    describe "authenticate for table with #{kind} id" do
      test "succeeds with valid credentials" do
        {:ok, account} = create_account(@config, email: "email@x.y.z", password: "some password")
        assert {:ok, ^account} = Accounts.authenticate("email@x.y.z", "some password", @config)
      end

      test "fails with invalid email" do
        {:ok, _account} = create_account(@config, email: "email@x.y.z", password: "some password")
        assert Accounts.authenticate("invalid", "some password", @config) == {:error, :invalid}
      end

      test "fails with invalid password" do
        {:ok, _account} = create_account(@config, email: "email@x.y.z", password: "some password")
        assert Accounts.authenticate("email@x.y.z", "wrong pass", @config) == {:error, :invalid}
      end
    end

    describe "change_password for table with #{kind} id" do
      test "succeeds with valid input" do
        {:ok, account} = create_account(@config, email: "email@x.y.z", password: "some password")
        assert {:ok, changed_account} = change_password(@config, account, "new password")
        assert changed_account.id == account.id
        assert {:ok, _} = Accounts.authenticate("email@x.y.z", "new password", @config)

        assert {:error, :invalid} = Accounts.authenticate("email@x.y.z", "some password", @config)
      end

      test "fails if invalid current password is provided" do
        {:ok, account} = create_account(@config, password: "some password")

        assert change_password(@config, account, "invalid password", "new password") ==
                 {:error, :invalid}

        assert Accounts.authenticate(account.email, "some password", @config) == {:ok, account}
      end

      test "fails if password is empty" do
        {:ok, account} = create_account(@config, password: "some password")
        assert {:error, changeset} = change_password(@config, account, "")
        assert "can't be blank" in errors_on(changeset).password
        assert Accounts.authenticate(account.email, "some password", @config) == {:ok, account}
      end

      test "fails if password is too short" do
        {:ok, account} = create_account(@config, password: "some password")
        assert {:error, changeset} = change_password(@config, account, "A")
        assert "should be at least 6 character(s)" in errors_on(changeset).password
        assert Accounts.authenticate(account.email, "some password", @config) == {:ok, account}
      end
    end

    describe "password reset for table with #{kind} id" do
      test "succeeds with valid input" do
        {:ok, account} = create_account(@config, password: "some password")
        assert {:ok, changed_account} = reset_password(@config, account.email, "new password")
        assert changed_account.id == account.id
        assert {:ok, _} = Accounts.authenticate(account.email, "new password", @config)

        assert {:error, :invalid} = Accounts.authenticate(account.email, "some password", @config)
      end

      test "fails for unknown user" do
        assert reset_password(@config, "invalid email", "new password") == {:error, :invalid}
      end

      test "fails if token is generated for another user" do
        {:ok, account} = create_account(@config, password: "some password")
        {:ok, account2} = create_account(@config)
        token = Accounts.start_password_reset(account2.email, 100, @config)

        assert reset_password(@config, account.email, "new password", token: token) ==
                 {:error, :invalid}

        assert Accounts.authenticate(account.email, "some password", @config) == {:ok, account}
      end

      test "fails if token is generated for a different purpose" do
        {:ok, account} = create_account(@config, password: "some password")
        token = Accounts.Token.create!(account, nil, 100, @config)

        assert reset_password(@config, account.email, "new password", token: token) ==
                 {:error, :invalid}

        assert Accounts.authenticate(account.email, "some password", @config) == {:ok, account}
      end

      test "fails if token expired" do
        {:ok, account} = create_account(@config, password: "some password")

        assert reset_password(@config, account.email, "new password", max_age: -1) ==
                 {:error, :invalid}

        assert Accounts.authenticate(account.email, "some password", @config) == {:ok, account}
      end
    end
  end

  defp create_account(config, data \\ []) do
    defaults = %{
      name: "name_#{unique_positive_integer()}",
      email: "email_#{unique_positive_integer()}@x.y.z",
      password: "password_#{unique_positive_integer()}"
    }

    data = Map.merge(defaults, Map.new(data))

    config.schema
    |> struct()
    |> change(Map.take(data, [:name]))
    |> Accounts.create(data.email, data.password, config)
  end

  defp change_password(config, account, current_password \\ "some password", new_password),
    do: Accounts.change_password(account, current_password, new_password, config)

  defp reset_password(config, email, new_password, opts \\ []) do
    token =
      Keyword.get_lazy(
        opts,
        :token,
        fn ->
          max_age = Keyword.get(opts, :max_age, 100)
          Accounts.start_password_reset(email, max_age, config)
        end
      )

    Accounts.reset_password(email, token, new_password, config)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Map.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
