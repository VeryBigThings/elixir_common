defmodule VBT.GraphqlServer do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :vbt
  import Phoenix.Controller, only: [accepts: 2]
  import VBT.Absinthe.ResolverHelper

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  plug :accepts, ["json"]
  plug :read_auth_token
  plug Absinthe.Plug, schema: __MODULE__.Schema

  defp read_auth_token(conn, _params) do
    auth_token =
      Plug.Conn.get_req_header(conn, "authorization")
      |> Enum.find(&String.starts_with?(&1, "Bearer "))
      |> case do
        "Bearer " <> token -> token
        nil -> nil
      end

    Absinthe.Plug.put_options(conn, context: %{auth_token: auth_token})
  end

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

      field :login, :string do
        resolve fn _, resolution -> {:ok, resolution.context.auth_token} end
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
end
