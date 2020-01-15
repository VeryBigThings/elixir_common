defmodule VBT.Accounts.Token do
  @moduledoc """
  Helpers for working with account-related one-time tokens.

  This module can be used to generate and work with one-time tokens which are related to
  individual accounts. This can be useful to implement features such as password reset, where
  a confirmation link must be sent via an e-mail.

  The `create!/4` function can be invoked to generate an encoded and signed one-time token.
  This token can then be safely included in an e-mail link, or passed to the user via other
  channels. When the token needs to be used, the client code must invoke `decode/3`, and then
  `use/4`. See the documentation of these functions for details.
  """

  import Ecto.Query
  alias Ecto.Multi

  @type encoded :: String.t()
  @type raw :: %{id: binary, data: data}
  @type max_age :: pos_integer | :infinity
  @type data :: any
  @type operation_result :: {:ok, any} | {:error, any}

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc """
  Creates a new token.

  The function returns encoded and signed token which can be safely sent to remote client.
  When a client sends the token back, it can be decoded and verified with `decode/3`.

  This function always succeeds. If the account is `nil`, the token will still be generated,
  although it won't be stored in the database, and thus it can't be actually used. This approach
  is chosen to prevent user enumeration attack.
  """
  @spec create!(Ecto.Schema.t() | nil, data, max_age, VBT.Accounts.config()) :: encoded
  def create!(account, data, max_age, config) do
    token = %{id: Ecto.UUID.generate(), data: data}
    store!(token.id, account, max_age, config)
    Phoenix.Token.sign(config.secret_key_base, salt(account), token)
  end

  @doc """
  Decodes the encoded token.

  Note that this function requires a valid existing account. It is the responsibility of the
  client to obtain the account.

  This function decodes the given encoded token and verifies that it hasn't been tampered with.
  Other validations (e.g. checking if the token is expired, or if it has been used) are
  performed with `use/1`.
  """
  @spec decode(encoded, Ecto.Schema.t(), VBT.Accounts.config()) :: {:ok, raw} | {:error, :invalid}
  def decode(signed_token, account, config) do
    Phoenix.Token.verify(
      config.secret_key_base,
      salt(account),
      signed_token,
      # Not verifying max_age here, since token validity will be checked by examining the
      # expires_at value in the database table.
      max_age: :infinity
    )
  end

  @doc """
  Performs the desired operation using the given one-time token.

  This function will mark the token as used, and perform the desired operation. This is done
  atomically, inside a transaction.

  If the token is not valid, the function will return an error. In this case, the token will
  not be marked as used. The token is valid if the following conditions are satisfied:

  - it hasn't expired
  - it hasn't been used
  - it corresponds to the correct account
  """
  @spec use(raw, Ecto.Schema.t(), (() -> result), VBT.Accounts.config()) ::
          result | {:error, :invalid}
        when result: operation_result
  def use(token, account, operation, config) do
    Multi.new()
    |> Multi.run(:mark_used, fn repo, _context -> mark_used(repo, token, account, config) end)
    |> Multi.run(:operation, fn _repo, _context -> operation.() end)
    |> config.repo.transaction()
    |> case do
      {:ok, %{operation: result}} -> {:ok, result}
      {:error, _, error, _} -> {:error, error}
    end
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp store!(_id, nil, _max_age, _config), do: :ok

  defp store!(id, account, max_age, config) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(max_age, :second)
      |> DateTime.truncate(:second)

    account
    |> Ecto.build_assoc(:tokens, id: id, expires_at: expires_at)
    |> config.repo.insert!()

    :ok
  end

  defp salt(nil),
    do: Base.url_encode64(:crypto.hash(:sha256, ""), padding: false)

  defp salt(account),
    do: Base.url_encode64(:crypto.hash(:sha256, to_string(account.id)), padding: false)

  defp mark_used(repo, token, account, config) do
    now = DateTime.utc_now()

    case repo.update_all(
           from(
             token in config.schemas.token,
             where: token.id == ^token.id,
             where: token.account_id == ^account.id,
             where: is_nil(token.used_at),
             where: token.expires_at >= ^now
           ),
           set: [used_at: now]
         ) do
      {1, _} -> {:ok, nil}
      _ -> {:error, :invalid}
    end
  end
end
