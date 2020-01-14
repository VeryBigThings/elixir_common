defmodule VBT.Accounts.Token do
  import Ecto.Query
  alias Ecto.Multi

  @type encoded :: String.t()
  @type raw :: %{id: binary, data: data}
  @type max_age :: pos_integer | :infinity
  @type data :: any

  @spec create!(Ecto.Schema.t() | nil, data, max_age, VBT.Accounts.config()) :: encoded
  def create!(account, data, max_age, config) do
    token = %{id: Ecto.UUID.bingenerate(), data: data}
    store!(token.id, account, max_age, config)
    Phoenix.Token.sign(config.secret_key_base, salt(account), token)
  end

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

  @spec use(raw, Ecto.Schema.t(), (() -> result), VBT.Accounts.config()) ::
          result | {:error, :invalid}
        when result: var
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

  defp store!(_id, nil, _max_age, _config), do: :ok

  defp store!(id, account, max_age, config) do
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, max_age, :second)

    {1, [%{id: ^id}]} =
      config.repo.insert_all(
        config.tokens_table,
        [
          %{
            id: id,
            account_id: dump!(account.id),
            expires_at: expires_at,
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    :ok
  end

  defp dump!(uuid) when is_binary(uuid) do
    {:ok, dumped} = Ecto.UUID.dump(uuid)
    dumped
  end

  defp dump!(id) when is_integer(id), do: id

  defp salt(nil),
    do: Base.url_encode64(:crypto.hash(:sha256, ""), padding: false)

  defp salt(account),
    do: Base.url_encode64(:crypto.hash(:sha256, to_string(account.id)), padding: false)

  defp mark_used(repo, token, account, config) do
    now = DateTime.utc_now()

    case repo.update_all(
           from(
             token in config.tokens_table,
             where: token.id == ^token.id,
             where: token.account_id == ^dump!(account.id),
             where: is_nil(token.used_at),
             where: token.expires_at >= ^now
           ),
           set: [used_at: now, updated_at: now]
         ) do
      {1, _} -> {:ok, nil}
      _ -> {:error, :invalid}
    end
  end
end
