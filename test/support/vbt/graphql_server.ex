defmodule VBT.GraphqlServer do
  use Phoenix.Endpoint, otp_app: :vbt
  import Phoenix.Controller, only: [accepts: 2]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  plug :accepts, ["json"]
  plug Absinthe.Plug, schema: __MODULE__.Schema

  defmodule Schema do
    use Absinthe.Schema

    query do
      field :health, :string do
        resolve fn _, _ -> {:ok, "ok"} end
      end
    end
  end
end
