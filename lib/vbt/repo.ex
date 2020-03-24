defmodule VBT.Repo do
  @moduledoc """
  Wrapper around `Ecto.Repo` with a few additional helper functions.

  See `__using__/1` for details.
  """

  @doc """
  Wrapper around `use Ecto.Repo`.

  Invoke `use VBT.Repo` instead of `use Ecto.Repo`. This macro will internally invoke
  `use Ecto.Repo`, passing it the given options. In addition, the macro will generate a few extra
  fetch functions:

  - `fetch` - fetch version of `Repo.get`
  - `fetch_by` - fetch version of `Repo.get_by`
  - `fetch_one` - fetch version of `Repo.one`

  These fetch functions return the result in the form of `{:ok, result} | {:error, reason}` You
  can control the error reason with the `:tag` and the `:error` options:

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
  defmacro __using__(opts) do
    quote do
      use Ecto.Repo, unquote(opts)

      @type fetch_opts :: [{:tag, String.t()} | {:error, String.t()} | {atom, any}]

      @doc "Fetches a single struct from the data store where the primary key matches the given id."
      @spec fetch(module, id :: term, fetch_opts) :: {:ok, Ecto.Schema.t()} | {:error, String.t()}
      def fetch(schema, id, opts \\ []) do
        unless VBT.Repo.schema_module?(schema), do: raise(ArgumentError, "expected a schema")

        case schema.__schema__(:primary_key) do
          [primary_key] -> fetch_by(schema, [{primary_key, id}], opts)
          _other -> raise(ArgumentError, "#{inspect(schema)} must have exactly one primary key")
        end
      end

      @doc "Fetches a single result from the given schema of query which matches the given filters."
      @spec fetch_by(Ecto.Queryable.t(), Keyword.t() | map, fetch_opts) ::
              {:ok, any} | {:error, String.t()}
      def fetch_by(queryable, clauses, opts \\ []) do
        import Ecto.Query

        default_opts =
          if VBT.Repo.schema_module?(queryable),
            do: [tag: queryable |> Module.split() |> List.last()],
            else: []

        fetch_one(where(queryable, ^Enum.to_list(clauses)), Keyword.merge(default_opts, opts))
      end

      @doc "Fetches a single result from the given query."
      @spec fetch_one(Ecto.Queryable.t(), fetch_opts) :: {:ok, any} | {:error, String.t()}
      def fetch_one(queryable, opts \\ []) do
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
        case all(queryable, opts) do
          [record] -> {:ok, record}
          [] -> {:error, error_message}
          other -> raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)
        end
      end
    end
  end

  @doc false
  @spec schema_module?(Ecto.Queryable.t()) :: boolean
  def schema_module?(queryable),
    do: is_atom(queryable) and function_exported?(queryable, :__schema__, 1)
end
