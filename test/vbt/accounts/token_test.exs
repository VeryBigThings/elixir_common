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

  test "token data is succeffully decoded" do
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
