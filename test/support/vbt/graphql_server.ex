defmodule VBT.GraphqlServer do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Phoenix.Endpoint, otp_app: :vbt

  socket "/socket", __MODULE__.Socket,
    websocket: true,
    longpoll: false

  plug VBT.Auth
  plug Absinthe.Plug, schema: __MODULE__.Schema

  defmodule Schema do
    @moduledoc false
    use VBT.Absinthe.Schema

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

      field :datetime_usec, :datetime_usec_result do
        arg :value, :datetime_usec

        resolve fn arg, _ ->
          decoded = arg.value |> :erlang.term_to_binary() |> Base.encode64()

          {:ok,
           %{
             decoded: decoded,
             encoded: arg.value,
             encoded_msec: arg.value && DateTime.truncate(arg.value, :millisecond),
             encoded_sec: arg.value && DateTime.truncate(arg.value, :second)
           }}
        end
      end
    end

    mutation do
      field :register_user, :string do
        resolve fn _, _ ->
          types = %{login: :string, password: :string}

          changeset =
            {%{}, types}
            |> Ecto.Changeset.cast(%{}, Map.keys(types))
            |> Ecto.Changeset.validate_required([:login])
            |> Ecto.Changeset.add_error(:password, "invalid password")

          {:error, changeset}
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

    object :datetime_usec_result do
      field :decoded, :string
      field :encoded, :datetime_usec
      field :encoded_msec, :datetime_usec
      field :encoded_sec, :datetime_usec
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
