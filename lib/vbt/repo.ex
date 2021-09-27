defmodule VBT.Repo do
  @moduledoc """
  Wrapper around `Ecto.Repo` with a few additional helper functions.
  """

  import Ecto.Query

  @type trans_fun ::
          (() -> {:ok, any} | {:error, any})
          | (module -> {:ok, any} | {:error, any})

  @type fetch_opts :: [{:tag, String.t()} | {:error, String.t()} | {atom, any}]

  @doc """
  Fetches a single struct from the data store where the primary key matches the given id.

  This function accepts the same options as `fetch_one/2`.
  """
  @callback fetch(module, id :: term, fetch_opts) :: {:ok, Ecto.Schema.t()} | {:error, String.t()}

  @doc """
  Fetches a single result from the given schema of query which matches the given filters.

  This function accepts the same options as `fetch_one/2`.
  """
  @callback fetch_by(Ecto.Queryable.t(), Keyword.t() | map, fetch_opts) ::
              {:ok, any} | {:error, String.t()}

  @doc """
  Fetches a single result from the given query.

  The function returns the result in the form of `{:ok, result} | {:error, reason}` You can control
  the error reason with the `:tag` and the `:error` options:

  ```
  iex> Repo.fetch_one(from Account, where: [id: -1])
  {:error, "Record not found"}

  iex> Repo.fetch_one(from Account, where: [id: -1], tag: "Account)
  {:error, "Account not found"}

  iex> Repo.fetch_one(from Account, where: [id: -1], error: "Account missing")
  {:error, "Account missing"}
  ```

  In addition, you can pass all the [Repo shared options](https://hexdocs.pm/ecto/Ecto.Repo.html#module-shared-options),
  as well as the `:prefix` option.
  """
  @callback fetch_one(Ecto.Queryable.t(), fetch_opts) :: {:ok, any} | {:error, String.t()}

  @doc """
  Runs the given function inside a transaction.

  This function is a wrapper around `Ecto.Repo.transaction`, with the following differences:

  - It accepts only a lambda of arity 0 or 1 (i.e. it doesn't work with multi).
  - If the lambda returns `{:ok, result}` the transaction is committed, and `{:ok, result}` is
    returned.
  - If the lambda returns `{:error, reason}` the transaction is rolled back, and
    `{:error, reason}` is returned.
  - If the lambda returns any other kind of result, an exception is raised, and the transaction
    is rolled back.
  """
  @callback transact((() -> result) | (module -> result), Keyword.t()) :: result
            when result: {:ok, any} | {:error, any}

  @doc """
  Deletes a single database row matching the given query.

  This function allows you to delete a single database row, without needing to load it from the
  database first.

  The function can optionally return the deleted row if you provide the `:select` clause in the
  input query. In this case, the function will return `{:ok, selected_term}` on success. If
  the `:select` clause is not present, the function will return `:ok` on success.

  The function succeeds only if exactly one row is matched by the given query. If there are
  multiple rows matching the given query, nothing will be deleted, and an error is returned.
  Likewise, the function returns an error if there are no rows matching the given query.
  """
  @callback delete_one(Ecto.Queryable.t()) ::
              :ok | {:ok, any} | {:error, :not_found | :multiple_rows}

  @doc """
  Wrapper around `use Ecto.Repo`.

  Invoke `use VBT.Repo` instead of `use Ecto.Repo`. This macro will internally invoke
  `use Ecto.Repo`, passing it the given options.

  In addition, the macro will generate the implementation of the `VBT.Repo` behaviour.
  """
  defmacro __using__(opts) do
    quote do
      use Ecto.Repo, unquote(opts)
      @behaviour VBT.Repo

      @impl VBT.Repo
      def fetch(schema, id, opts \\ []), do: VBT.Repo.fetch(__MODULE__, schema, id, opts)

      @impl VBT.Repo
      def fetch_by(queryable, clauses, opts \\ []),
        do: VBT.Repo.fetch_by(__MODULE__, queryable, clauses, opts)

      @impl VBT.Repo
      def fetch_one(queryable, opts \\ []), do: VBT.Repo.fetch_one(__MODULE__, queryable, opts)

      @impl VBT.Repo
      def transact(fun, opts \\ []), do: VBT.Repo.transact(__MODULE__, fun, opts)

      @impl VBT.Repo
      def delete_one(query), do: VBT.Repo.delete_one(__MODULE__, query)
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def fetch(repo, schema, id, opts) do
    unless schema_module?(schema), do: raise(ArgumentError, "expected a schema")

    case schema.__schema__(:primary_key) do
      [primary_key] -> fetch_by(repo, schema, [{primary_key, id}], opts)
      _other -> raise(ArgumentError, "#{inspect(schema)} must have exactly one primary key")
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def fetch_by(repo, queryable, clauses, opts) do
    default_opts =
      if schema_module?(queryable),
        do: [tag: queryable |> Module.split() |> List.last()],
        else: []

    fetch_one(repo, where(queryable, ^Enum.to_list(clauses)), Keyword.merge(default_opts, opts))
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def fetch_one(repo, queryable, opts) do
    {custom_opts, opts} = Keyword.split(opts, ~w/error tag/a)

    error_message =
      case Keyword.fetch(custom_opts, :error) do
        {:ok, message} -> message
        :error -> "#{Keyword.get(custom_opts, :tag, "Record")} not found"
      end

    # This is a modified implementation of `Repo.one`. We can't use `Repo.one` directly because we
    # need to distinguish between these two cases:
    #
    #     1. The row is not present (we should return an error)
    #     2. The row is present but the selected value is NULL (we should return `{:ok, nil}`).
    #
    # For example, consider the following query:
    #
    #     from account in Account, where: account.id == ^id, select: account.phone_number
    #
    # If the given account exists, but its phone number is NULL, `fetch` needs to return
    # `{:ok, nil}`. We can only distinguish between cases 1 and 2 if we invoke `Repo.all` and
    # branch on the number of returned records.
    case repo.all(queryable, opts) do
      [record] -> {:ok, record}
      [] -> {:error, error_message}
      other -> raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def transact(repo, fun, opts \\ []) do
    repo.transaction(
      fn repo ->
        Function.info(fun, :arity)
        |> case do
          {:arity, 0} -> fun.()
          {:arity, 1} -> fun.(repo)
        end
        |> case do
          {:ok, result} -> result
          {:error, reason} -> repo.rollback(reason)
        end
      end,
      opts
    )
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def delete_one(repo, query) do
    # deleting in transaction so we can rollback if multiple rows are deleted
    case transact(repo, fn -> unsafe_delete_one(repo, query) end) do
      {:ok, nil} -> :ok
      {:ok, [record]} -> {:ok, record}
      {:error, _reason} = error -> error
    end
  end

  defp unsafe_delete_one(repo, query) do
    case repo.delete_all(query) do
      {1, result} -> {:ok, result}
      {0, _} -> {:error, :not_found}
      _ -> {:error, :multiple_rows}
    end
  end

  defp schema_module?(queryable),
    do: is_atom(queryable) and function_exported?(queryable, :__schema__, 1)
end
