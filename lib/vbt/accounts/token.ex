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

  @type encoded :: String.t()
  @type max_age :: pos_integer | :infinity
  @type operation_result :: {:ok, any} | {:error, any}
  @type account_id :: any

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc """
  Creates a new token.

  The function returns a token which can be safely sent to remote client. When a client sends the
  token back, it can be verified and used with `use/3`.

  The token will be valid for the `max_age` seconds.

  This function always succeeds. If the account is `nil`, the token will still be generated. This
  approach is chosen to prevent user enumeration attack.
  """
  @spec create!(Ecto.Schema.t() | nil, String.t(), max_age, VBT.Accounts.config()) :: encoded
  def create!(account, type, max_age, config) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    attributes = %{
      # store token hash to db to prevent tokens from being used if the db is compromised
      hash: hash(token),
      type: type,
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(max_age, :second)
        |> DateTime.truncate(:second)
    }

    schema =
      if is_nil(account),
        do: struct!(config.schemas.token, attributes),
        else: Ecto.build_assoc(account, :tokens, attributes)

    config.repo.insert!(schema)

    token
  end

  @doc """
  Performs the desired operation using the given one-time token.

  This function will mark the token as used, and perform the desired operation. This is done
  atomically, inside a transaction.

  The operation function will receive the account id of the corresponding user.

  If the token is not valid, the function will return an error. In this case, the token will
  not be marked as used. The token is valid if the following conditions are satisfied:

  - it hasn't expired
  - it hasn't been used
  - it corresponds to an existing account
  """
  @spec use(encoded, String.t(), (account_id -> result), VBT.Accounts.config()) ::
          result | {:error, :invalid}
        when result: operation_result
  def use(token, expected_type, operation, config) do
    config.repo.transaction(fn repo ->
      with {:ok, account_id} <- mark_used(repo, token, expected_type, config),
           {:ok, result} <- operation.(account_id) do
        result
      else
        {:error, reason} -> repo.rollback(reason)
      end
    end)
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  @doc false
  @spec hash(String.t()) :: binary
  def hash(token), do: :crypto.hash(:sha256, token)

  defp mark_used(repo, token, expected_type, config) do
    case repo.update_all(
           select(valid_token_query(token, expected_type, config), as(:account).id),
           set: [used_at: DateTime.utc_now()]
         ) do
      {1, [account_id]} -> {:ok, account_id}
      _ -> {:error, :invalid}
    end
  end

  defp valid_token_query(token, expected_type, config) do
    from token in config.schemas.token,
      as: :token,
      where: [hash: ^hash(token), type: ^expected_type],
      where: is_nil(token.used_at),
      where: token.expires_at >= ^DateTime.utc_now(),
      inner_join: account in ^config.schemas.account,
      on: account.id == field(token, ^account_id_field_name(config)),
      as: :account
  end

  defp account_id_field_name(config) do
    account_schema = config.schemas.account

    # Using Ecto schema reflection (https://hexdocs.pm/ecto/Ecto.Schema.html#module-reflection)
    # to fetch meta about the `:tokens` association.
    tokens_meta = account_schema.__schema__(:association, :tokens)

    # Since `:tokens` is `has_many`, `tokens_meta` is an instance of `Ecto.Association.Has`
    # (https://hexdocs.pm/ecto/Ecto.Association.Has.html). The field `related_key` in this
    # struct contains the name of the column in the tokens table.
    tokens_meta.related_key
  end

  # ------------------------------------------------------------------------
  # Periodic cleanup
  # ------------------------------------------------------------------------

  defmodule Cleanup do
    @moduledoc """
    Periodical database cleanup of expired and used tokens.

    To run this process, include `{VBT.Accounts.Token.Cleanup, opts}` as a child in your
    supervision tree.

    Options:

      - `:config` - Accounts configuration (`VBT.Accounts.config()`). This parameter is mandatory.
      - `:id` - Supervisor child id of the process. Defaults to `VBT.Accounts.Token.Cleanup`.
      - `:every` - Cleanup interval. Defaults to 10 minutes.
      - `:timeout` - Maximum allowed duration of a single cleanup. Defaults to 1 minute.
      - `:retention` - The period during which expired and used tokens are not deleted.
        Defaults to 7 days.
      - `:name`, `:telemetry_id`, `:mode` - Periodic-specific options. See [Periodic docs]
        (https://hexdocs.pm/parent/Periodic.html#module-options) for details.

    All of the time options should be provided in milliseconds.
    """

    @type opts :: [
            id: any,
            name: GenServer.name(),
            every: pos_integer,
            timeout: pos_integer,
            retention: pos_integer,
            config: VBT.Accounts.config(),
            telemetry_id: any,
            resolve_pid: (() -> pid),
            mode: :auto | :manual
          ]

    @spec child_spec(opts) :: Supervisor.child_spec()
    def child_spec(opts) do
      config = Keyword.fetch!(opts, :config)
      retention = Keyword.get(opts, :retention, 7 * :timer.hours(24))
      now_fun = Keyword.get(opts, :now_fun, &DateTime.utc_now/0)
      resolve_pid = Keyword.get(opts, :resolve_pid)

      [id: __MODULE__, every: :timer.minutes(10), timeout: :timer.minutes(1)]
      |> Keyword.merge(Keyword.take(opts, ~w/id name every timeout telemetry_id mode/a))
      |> Keyword.merge(
        on_overlap: :ignore,
        run: fn -> cleanup(config, now_fun, retention, resolve_pid) end
      )
      |> Periodic.child_spec()
    end

    defp cleanup(config, now_fun, retention, resolve_pid) do
      unless is_nil(resolve_pid), do: config.repo.put_dynamic_repo(resolve_pid.())
      date = DateTime.add(now_fun.(), -retention, :millisecond)

      config.repo.delete_all(
        from(token in config.schemas.token,
          where: token.used_at < ^date or token.expires_at < ^date
        ),
        timeout: :infinity
      )
    end
  end
end
