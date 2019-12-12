defmodule VBT.Graphql.Case do
  @moduledoc """
  ExUnit case template for writing tests which issue GraphQL requests.

  Example:

      defmodule SomeTest do
        use VBT.Graphql.Case,
          endpoint: MyEndpoint,
          api_path: "/api/graphql",
          repo: MyRepo,
          async: true

        describe "current_user" do
          test "returns current user's login" do
            {:ok, token} = call(auth_query, variables: %{login: login, password: password})
            assert {:ok, data} = call(current_user_query, auth: token)
            assert data.login == "expected login"
          end

          test "returns an error when not authenticated" do
            assert {:ok, response} = call(current_user_query, auth: token)
            assert "unauthenticated" in errors(response)
          end
      end
  """
  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  @type call_opts :: [
          variables: variables,
          auth: String.t() | nil,
          headers: [header],
          endpoint: module,
          api_path: String.t()
        ]

  @type variables :: %{atom => any} | Keyword.t()
  @type header :: {String.t(), String.t()}

  @type response :: %{data: data, errors: [error]}

  @type data :: %{atom => data_value}
  @type data_value :: number | String.t() | data | [data_value]

  @type error :: %{
          required(:message) => String.t(),
          optional(:path) => [String.t()],
          optional(:locations) => [%{column: non_neg_integer, line: non_neg_integer}],
          optional(:extensions) => [%{field: String.t()}]
        }

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc "Makes a GraphQL query call."
  @spec call(String.t(), call_opts) :: {:ok, data} | {:error, response}
  def call(query_string, opts \\ []) do
    opts = normalize_opts(opts)
    query_body = %{query: query_string, variables: variables(opts)}

    response =
      Phoenix.ConnTest.build_conn()
      |> add_headers(opts)
      |> Phoenix.ConnTest.dispatch(endpoint(opts), :post, api_path(opts), query_body)
      |> Phoenix.ConnTest.json_response(200)
      |> normalize_keys()

    if Map.has_key?(response, :errors),
      do: {:error, response},
      else: {:ok, response.data}
  end

  @doc "Makes a GraphQL call, returning data on success, raising an assertion error otherwise."
  @spec call!(String.t(), call_opts) :: data
  def call!(query_string, opts \\ []) do
    case call(query_string, opts) do
      {:error, response} ->
        errors = inspect(response.errors, limit: :infinity, pretty: true)
        raise ExUnit.AssertionError, "GraphQL call failed\n\n#{errors}"

      {:ok, data} ->
        data
    end
  end

  @doc "Returns error messages from the GraphQL response errors."
  @spec errors(response) :: [String.t()]
  def errors(call_result), do: Enum.map(call_result.errors, & &1.message)

  @doc "Returns error messages for the given field from the GraphQL response errors."
  @spec field_errors(response, String.t()) :: [String.t()]
  def field_errors(response, field) do
    response.errors
    |> Stream.filter(&match?(%{extensions: %{field: ^field}}, &1))
    |> Enum.map(& &1.message)
  end

  @doc false
  def set_config(opts) do
    Process.put(__MODULE__, opts)
    :ok
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp config, do: Process.get(__MODULE__, [])

  defp endpoint(opts), do: Keyword.fetch!(opts, :endpoint)
  defp api_path(opts), do: Keyword.fetch!(opts, :api_path)
  defp variables(opts), do: Keyword.get(opts, :variables)
  defp headers(opts), do: Keyword.fetch!(opts, :headers)

  defp normalize_opts(opts) do
    opts = config() |> Keyword.merge(headers: []) |> Keyword.merge(opts)

    case Keyword.pop(opts, :auth) do
      {nil, _} -> opts
      {token, opts} -> Keyword.update!(opts, :headers, &[auth_header(token) | &1])
    end
  end

  defp auth_header(token), do: {"authorization", "Bearer #{token}"}

  defp add_headers(conn, opts), do: Enum.reduce(headers(opts), conn, &add_header(&2, &1))
  defp add_header(conn, {key, value}), do: Plug.Conn.put_req_header(conn, key, value)

  defp normalize_keys(%{} = map),
    do: Enum.into(map, %{}, fn {key, value} -> {normalize_key(key), normalize_keys(value)} end)

  defp normalize_keys(list) when is_list(list), do: Enum.map(list, &normalize_keys/1)
  defp normalize_keys(other), do: other

  defp normalize_key(key), do: key |> Macro.underscore() |> String.to_atom()

  using opts do
    quote bind_quoted: [opts: opts, module: unquote(__MODULE__)] do
      import VBT.Graphql.Case, except: [set_config: 1]

      setup do
        unquote(module).set_config(unquote(opts))
      end
    end
  end
end
