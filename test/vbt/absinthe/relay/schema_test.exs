defmodule VBT.Absinthe.Relay.SchemaTest do
  use VBT.Graphql.Case, async: true, endpoint: __MODULE__.TestServer, api_path: "/"

  setup do
    Application.put_env(:vbt, __MODULE__.TestServer, [])
    start_supervised(__MODULE__.TestServer)
    :ok
  end

  test "correctly supplies a union result" do
    assert some_field(true) == {:ok, %{response: "some success"}}
    assert some_field(false) == {:ok, %{error_code: "com.vbt.some_field/some_error"}}
  end

  defp some_field(success?) do
    query = """
    mutation {
      some_field(input: {success: #{success?}}) {
        result {
          ... on SomeFieldPayloadSuccess { response }
          ... on BusinessError { error_code }
        }
      }
    }
    """

    with {:ok, response} <- call(query),
         do: {:ok, response.some_field.result}
  end

  defmodule TestServer do
    @moduledoc false
    use Phoenix.Endpoint, otp_app: :vbt
    plug Absinthe.Plug, schema: __MODULE__.Schema

    defmodule Schema do
      @moduledoc false
      use VBT.Absinthe.Relay.Schema

      query do
      end

      mutation do
        payload field :some_field do
          input do
            field :success, non_null(:boolean)
          end

          output do
            field :result, payload_type(:result)

            union payload_type(:result) do
              types [payload_type(:success), :business_error]
              resolve_type fn result, _ -> error_type(result) || payload_type(:success) end
            end

            object payload_type(:success) do
              field :response, non_null(:string)
            end
          end

          resolve payload_resolver(fn input, _ ->
                    if input.success,
                      do: {:ok, %{response: "some success"}},
                      else: {:error, VBT.BusinessError.new("some_field", "some_error")}
                  end)
        end
      end
    end
  end
end
