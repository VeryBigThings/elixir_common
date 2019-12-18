defmodule VBT.Auth do
  @moduledoc """
  Helpers for implementing authentication in the UI layer (resolvers, sockets, controllers).

  This module can be used to simplify the implementation of the authentication logic in
  the web layer.

  ## Using from GraphQL resolvers

  Add this module as a plug in your **GraphQL pipeline**:

      defmodule MyRouter do
        pipeline :graphql_api do
          VBT.Auth
        end

        # ...
      end

  At this point, you can invoke `sign/3` and `verify/4` from your resolvers.

  It's highly recommended to introduce a helper module in your project to wrap these invocations.
  For example:

      defmodule MySystemWeb.Authentication do
        alias VBT.Auth

        @user_salt "super secret user salt"
        @max_age :erlang.convert_time_unit(:timer.hours(24), :millisecond, :second)

        def new_token(account),
          do: Auth.sign(MySystemWeb.Endpoint, @user_salt, %{id: account.id})

        def fetch_account(verifier, args \\\\ []) do
          with {:ok, account_data} <- Auth.verify(verifier, @user_salt, @max_age, args),
              do: load_account(account_data.id)
        end

        defp load_account(id) do
          case MySystem.get_account(id) do
            nil -> {:error, :account_not_found}
            account -> {:ok, account}
          end
        end
      end

  ## Using from Phoenix sockets

  Assuming you have the `MySystemWeb.Authentication` helper module in place, and that the input
  is provided as `%{"authorization" => "Bearer some_token"}`:

      defmodule MySystemWeb.UserSocket do
        def connect(args, socket) do
          case MySystemWeb.Authentication.fetch_account(socket, args) do
            {:ok, account} -> {:ok, do_something_with(socket, account)}
            {:error, _reason} -> :error
          end
        end

        # ...
      end
  """

  @behaviour Plug

  @type salt :: String.t()
  @type data :: any
  @type token :: String.t()
  @type verifier :: Plug.Conn.t() | Phoenix.Socket.t() | endpoint | Absinthe.Resolution.t()
  @type endpoint :: module
  @type args :: %{String.t() => arg} | [{String.t(), arg}]
  @type arg :: String.t() | args
  @type verify_error :: :token_missing | :token_invalid | :token_expired

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc "Signs the given data using the secret from the endpoint and the provided salt."
  @spec sign(endpoint, salt, data) :: token
  def sign(endpoint, salt, data), do: Phoenix.Token.sign(endpoint, salt, data)

  @doc "Verifies the signed token, returning decoded data on success."
  @spec verify(verifier, salt, non_neg_integer, args) :: {:ok, data} | {:error, verify_error}
  def verify(verifier, salt, max_age, args \\ []) do
    case Phoenix.Token.verify(endpoint(verifier), salt, token(verifier, args), max_age: max_age) do
      {:ok, _token} = success -> success
      {:error, :missing} -> {:error, :token_missing}
      {:error, :invalid} -> {:error, :token_invalid}
      {:error, :expired} -> {:error, :token_expired}
    end
  end

  # ------------------------------------------------------------------------
  # Plug callbacks
  # ------------------------------------------------------------------------

  @impl Plug
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def init(opts), do: opts

  @impl Plug
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def call(conn, _opts), do: Absinthe.Plug.put_options(conn, context: %{conn: conn})

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp token(verifier, args),
    do: with("Bearer " <> token <- find_token(verifier, args), do: token)

  defp find_token(verifier, args) do
    tokens_from_args(args)
    |> Stream.concat(tokens_from_header(verifier))
    |> Enum.find(&String.starts_with?(&1, "Bearer "))
  end

  defp tokens_from_args(args) do
    args
    |> Stream.filter(&match?({"authorization", _}, &1))
    |> Stream.map(fn {"authorization", value} -> value end)
  end

  defp tokens_from_header(%Phoenix.Socket{} = _socket), do: []

  defp tokens_from_header(verifier),
    do: Plug.Conn.get_req_header(conn(verifier), "authorization")

  defp endpoint(%Phoenix.Socket{} = socket), do: socket.endpoint
  defp endpoint(other), do: Phoenix.Controller.endpoint_module(conn(other))

  defp conn(%Absinthe.Resolution{} = resolution), do: resolution.context.conn
  defp conn(%Plug.Conn{} = conn), do: conn
end
