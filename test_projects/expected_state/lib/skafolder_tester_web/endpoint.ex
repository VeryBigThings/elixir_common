defmodule SkafolderTesterWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :skafolder_tester

  socket "/socket", SkafolderTesterWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :skafolder_tester,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    store: :cookie,
    key: "_skafolder_tester_key",
    signing_salt: "bwDVzZo/"

  plug SkafolderTesterWeb.Router

  @impl Phoenix.Endpoint
  def init(_type, config) do
    config =
      config
      |> Keyword.put(:secret_key_base, System.fetch_env!("SECRET_KEY_BASE"))
      |> Keyword.update(:url, url_config(), &Keyword.merge(&1, url_config()))
      |> Keyword.update(:http, http_config(), &(http_config() ++ (&1 || [])))

    {:ok, config}
  end

  defp url_config, do: [host: System.fetch_env!("HOST")]
  defp http_config, do: [:inet6, port: System.fetch_env!("PORT")]
end
