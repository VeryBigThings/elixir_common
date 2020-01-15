defmodule VBT.Accounts do
  import Ecto.Changeset
  import Ecto.Query
  alias VBT.Accounts.Token

  @type config :: %{
          repo: module,
          schemas: %{account: module, token: module},
          login_field: atom,
          password_hash_field: atom,
          min_password_length: pos_integer,
          secret_key_base: String.t()
        }

  @type data :: Ecto.Schema.t() | Ecto.Changeset.t()

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @spec create(data, String.t(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def create(data, login, password, config) do
    data
    |> set_password(password, config)
    |> set_login(login, config)
    |> config.repo.insert()
  end

  @spec authenticate(String.t(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, :invalid}
  def authenticate(login, password, config) do
    # We're always hashing the input password, even if the account doesn't exist, to prevent a possible
    # enumeration attack (https://www.owasp.org/index.php/Testing_for_User_Enumeration_and_Guessable_User_Account_(OWASP-AT-002)#Description_of_the_Issue).
    account = get(login, config)
    if password_ok?(account, password, config), do: {:ok, account}, else: {:error, :invalid}
  end

  @spec change_password(Ecto.Schema.t(), String.t(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, :invalid | Ecto.Changeset.t()}
  def change_password(account, current_password, new_password, config) do
    if password_ok?(account, current_password),
      do: config.repo.update(set_password(account, new_password, config)),
      else: {:error, :invalid}
  end

  @spec start_password_reset(String.t(), Token.max_age(), config) :: Token.encoded()
  def start_password_reset(login, max_age, config),
    # We're always creating the token, even if the account doesn't exist, to prevent a possible
    # enumeration attack (https://www.owasp.org/index.php/Testing_for_User_Enumeration_and_Guessable_User_Account_(OWASP-AT-002)#Description_of_the_Issue).
    do: login |> get(config) |> Token.create!(%{type: :password_reset}, max_age, config)

  @spec reset_password(String.t(), Token.encoded(), String.t(), config) ::
          {:ok, Ecto.Schema.t()} | {:error, :invalid | Ecto.Changeset.t()}
  def reset_password(login, token, new_password, config) do
    with {:ok, account} <- fetch(login, config),
         {:ok, %{data: %{type: :password_reset}} = token} <- Token.decode(token, account, config) do
      Token.use(
        token,
        account,
        fn -> config.repo.update(set_password(account, new_password, config)) end,
        config
      )
    else
      _ -> {:error, :invalid}
    end
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

  defp set_password(data, password, config) do
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
