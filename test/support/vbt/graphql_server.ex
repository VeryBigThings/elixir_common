defmodule VBT.GraphqlServer do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Phoenix.Endpoint, otp_app: :vbt
  import Phoenix.Controller, only: [accepts: 2]
  import VBT.Absinthe.ResolverHelper

  socket "/socket", __MODULE__.Socket,
    websocket: true,
    longpoll: false

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  plug :accepts, ["json"]
  plug VBT.Auth
  plug Absinthe.Plug, schema: __MODULE__.Schema

  defmodule Schema do
    @moduledoc false
    use Absinthe.Schema

    query do
      field :order, :order do
        arg :id, non_null(:integer)

        resolve fn arg, _ ->
          order = %{id: arg.id, order_items: [order_item(1), order_item(2)]}
          {:ok, order}
        end
      end

      field :auth_token, :string do
        arg :login, non_null(:string)
        resolve fn arg, _ -> {:ok, VBT.Auth.sign(VBT.GraphqlServer, "some_salt", arg.login)} end
      end

      field :current_user, :string do
        arg :max_age, :integer

        resolve fn arg, resolution ->
          VBT.Auth.verify(resolution, "some_salt", arg.max_age || 100)
        end
      end
    end

    mutation do
      field :register_user, :string do
        resolve fn _, _ ->
          types = %{login: :string, password: :string}

          changeset_errors =
            {%{}, types}
            |> Ecto.Changeset.cast(%{}, Map.keys(types))
            |> Ecto.Changeset.validate_required([:login])
            |> changeset_errors()

          {:error, ["invalid login data" | changeset_errors]}
        end
      end
    end

    object :order do
      field :id, non_null(:integer)
      field :order_items, non_null(list_of(:order_item))
    end

    object :order_item do
      field :product_name, non_null(:string)
      field :quantity, non_null(:integer)
    end

    defp order_item(id), do: %{product_name: "product #{id}", quantity: id}
  end

  defmodule Socket do
    @moduledoc false
    use Phoenix.Socket

    def connect(args, socket) do
      case VBT.Auth.verify(socket, "some_salt", Map.get(args, "max_age", 100), args) do
        {:ok, login} -> {:ok, assign(socket, %{login: login})}
        {:error, _reason} -> :error
      end
    end

    def id(socket), do: "user:#{socket.assigns.login}"
  end
end
