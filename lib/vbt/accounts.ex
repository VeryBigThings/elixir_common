defmodule VBT.Accounts do
  @moduledoc """
  Helper functions for account management.

  This module provides helper functions for typical account management functions, such as
  registration, authentication, and password change.

  To use these functions, you need create required database tables and Ecto schemas, and provide
  accounts configuration.

  ## Database and Ecto

  Two database tables are required: one which holds the accounts, and another for managing
  one-time account tokens.

  The account tables must contain a login field and a password hash field. Both fields should
  be of type strings, and set to `null: false`. A unique constraint should exist on the login
  field.

  There are no rules for the names of the accounts table and these required fields. For example,
  the table can be named `users`, and the login field can be named `email`. Finally, this table
  can contain arbitrary additional data (e.g. first and last name)

  The tokens table can bear arbitrary name, but the list of fields and their names is more
  restrictive. You can create this table with the following migration:

      create table(:tokens, primary_key: false) do
        add :id, :uuid, primary_key: true
        add :hash, :binary, null: false
        add :type, :string, null: false
        add :used_at, :utc_datetime
        add :expires_at, :utc_datetime, null: false
        add :account_id, references(:accounts, type: :uuid), null: true
      end

  Note that `account_id` must be made nullable. The reason is that we're inserting tokens even if
  the account is not existing, which prevents enumeration attacks.

  The Ecto schemas should mirror the database structure of these tables. Most importantly, the
  accounts schema should specify `has_many :tokens`, while the tokens schema should specify
  a corresponding `belong_to` association.

  ## Configuration

  With tables, and schemas in place, you need to define accounts configuration. It is advised to
  do this by defining a private function `accounts_config/0` in the context module where you're
  implementing accounts operations:

      defmodule MyProject.SomeContext do
        # ...

        defp accounts_config() do
          %{
            repo: MyProject.Repo,
            schemas: %{
              account: MyProject.Schemas.Account,
              token: MyProject.Schemas.Token
            },
            login_field: :email,
            password_hash_field: :password_hash,
            min_password_length: 6
          }
        end
      end

  ## Usage

  To implement account operations, define corresponding functions in the same context module. For
  example:

      defmodule MyProject.SomeContext do
        def create_account(params) do
          %Account{}
          # additional client fields
          |> cast(account_params, ~w(first_name last_name)a)
          |> validate_required(~w(first_name last_name)a)
          # invocation of the generic function
          |> Accounts.create(account_params.email, account_params.password, accounts_config())
        end

        # ...
      end

  See documentation of individual functions, as well as `VBT.Accounts.Token` for details.

  ## Tokens cleanup

  By default, token entries are not removed from the database. To periodically remove them,
  you need to start the cleanup process. See `VBT.Accounts.Token.Cleanup` for details.
  """
  import Ecto.Changeset
  import Ecto.Query
  alias VBT.Accounts.Token

  @type config :: %{
          repo: module,
          schemas: %{account: module, token: module},
          login_field: atom,
          password_hash_field: atom,
          min_password_length: pos_integer
        }

  @type data :: Ecto.Schema.t() | Ecto.Changeset.t()

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc """
  Creates a new account.

  Notice that his function accepts either an Ecto schema or a changeset. In case you need
  to populate some additional fields (e.g. first/last name), you can create a changeset with
  corresponding changes, and with desired validations. However, this changeset shouldn't contain
  login/password changes and validations. Those will be included internally by this function.

  If all validations succeed, the account data will be inserted into the database.

  This function validates the uniqueness of the login. To do that, the function expects that a
  corresponding unique constraint is defined in the database.
  """
  @spec create(data, String.t(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def create(data, login, password, config) do
    data
    |> set_password_changeset(password, config)
    |> set_login(login, config)
    |> config.repo.insert()
  end

  @doc "Authenticates the given account, returning the account record from the database."
  @spec authenticate(String.t(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, :invalid}
  def authenticate(login, password, config) do
    # We're always hashing the input password, even if the account doesn't exist, to prevent a possible
    # enumeration attack (https://www.owasp.org/index.php/Testing_for_User_Enumeration_and_Guessable_User_Account_(OWASP-AT-002)#Description_of_the_Issue).
    account = get(login, config)
    if password_ok?(account, password, config), do: {:ok, account}, else: {:error, :invalid}
  end

  @doc """
  Changes the account password in the database.

  The password will be changed only if the correct current password is supplied.
  """
  @spec change_password(Ecto.Schema.t(), String.t(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, :invalid | Ecto.Changeset.t()}
  def change_password(account, current_password, new_password, config) do
    if password_ok?(account, current_password),
      do: set_password(account, new_password, config),
      else: {:error, :invalid}
  end

  @doc """
  Changes the account password in the database without checking the current password.

  ## Warning

  Be careful when using this function because you could end up creating security issues, such as
  allowing attackers to change the password of another user. In almost all cases it's prefered to
  use `change_password/4` or `start_password_reset/3`. Use this function only when the requirements
  explicitly state that the user should be able to change their password without providing the
  current one.
  """
  @spec set_password(Ecto.Schema.t(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def set_password(account, new_password, config),
    do: config.repo.update(set_password_changeset(account, new_password, config))

  @doc """
  Creates a one-time password reset token for the given user.

  The token will be valid for the `max_age` seconds.

  If at some later point you want to verify if a token represents a valid and unused password
  reset token, you can invoke `Token.get_account/3`, passing `"password_reset"` as the expected
  type.

  This function always succeeds. If the account for the given login doesn't exist, the token will
  still be generated. However, this token can't be actually used. This approach is chosen to
  prevent user enumeration attack.
  """
  @spec start_password_reset(String.t(), Token.max_age(), config) :: Token.encoded()
  def start_password_reset(login, max_age, config),
    # We're always creating the token, even if the account doesn't exist, to prevent a possible
    # enumeration attack (https://www.owasp.org/index.php/Testing_for_User_Enumeration_and_Guessable_User_Account_(OWASP-AT-002)#Description_of_the_Issue).
    do: login |> get(config) |> Token.create!("password_reset", max_age, config)

  @doc """
  Resets the password for the given login and token.

  The password is changed only if the token is valid. The token is valid if:

  - it has been created with `start_password_reset/3`
  - it corresponds to an existing user
  - it hasn't expired
  - it is a password reset token
  - it hasn't been used
  """
  @spec reset_password(Token.encoded(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, :invalid | Ecto.Changeset.t()}
  def reset_password(token, new_password, config) do
    Token.use(
      token,
      "password_reset",
      fn account_id ->
        config.schemas.account
        |> config.repo.get!(account_id)
        |> set_password(new_password, config)
      end,
      config
    )
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp get(login, config) do
    case fetch(login, config) do
      {:ok, account} -> account
      {:error, :invalid} -> nil
    end
  end

  defp fetch(login, config) do
    from(config.schemas.account, where: ^[{config.login_field, login}])
    |> config.repo.one()
    |> case do
      nil -> {:error, :invalid}
      account -> {:ok, account}
    end
  end

  defp password_ok?(account, password),
    do: match?({:ok, _}, Bcrypt.check_pass(account, password, hash_key: :password_hash))

  defp password_hash(password), do: Bcrypt.hash_pwd_salt(password)

  defp to_changeset(data), do: change(data)

  defp set_password_changeset(data, password, config) do
    data
    |> to_changeset()
    |> validate_password(password, config.min_password_length)
    |> change(%{config.password_hash_field => password_hash(password)})
  end

  defp validate_password(changeset, password, min_password_length) do
    cond do
      password in [nil, ""] ->
        add_error(changeset, :password, "can't be blank")

      String.length(password) < min_password_length ->
        add_error(changeset, :password, "should be at least #{min_password_length} character(s)")

      true ->
        changeset
    end
  end

  defp set_login(changeset, login, config) do
    changeset
    |> change(%{config.login_field => login})
    |> validate_required(config.login_field)
    |> unique_constraint(config.login_field)
    |> validate_login(config.login_field)
  end

  defp validate_login(changeset, :email) do
    changeset
    |> validate_length(:email, max: 254)
    |> validate_format(:email, ~r/@/)
  end

  defp validate_login(changeset, _field), do: changeset

  defp password_ok?(account, password, config) do
    match?(
      {:ok, _},
      Bcrypt.check_pass(account, password, hash_key: config.password_hash_field)
    )
  end
end
