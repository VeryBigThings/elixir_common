defmodule SkafolderTesterTest.Web.TestPlug do
  @behaviour Plug
  import Phoenix.ConnTest

  @spec dispatch((Plug.Conn.t() -> Plug.Conn.t())) :: Plug.Conn.t()
  def dispatch(fun) do
    code =
      fun
      |> :erlang.term_to_binary()
      |> Base.url_encode64(padding: false)

    build_conn()
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> dispatch(SkafolderTesterWeb.Endpoint, :get, "/test_execute/#{code}")
  end

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with %Plug.Conn{method: "GET", path_info: ["test_execute", code]} <- conn do
      fun =
        code
        |> Base.url_decode64!(padding: false)
        |> :erlang.binary_to_term()

      fun.(conn)
    end
  end
end
