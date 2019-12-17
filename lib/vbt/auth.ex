defmodule VBT.Auth do
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

  @spec sign(endpoint, salt, data) :: token
  def sign(endpoint, salt, data), do: Phoenix.Token.sign(endpoint, salt, data)

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
