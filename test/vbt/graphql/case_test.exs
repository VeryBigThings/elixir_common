defmodule VBT.Graphql.CaseTest do
  use VBT.Graphql.Case, async: true, endpoint: VBT.GraphqlServer, api_path: "/"

  describe "call" do
    test "returns data on success" do
      assert {:ok, data} = call(order_query(), variables: %{order_id: 1})

      assert data.order == %{
               id: 1,
               order_items: [
                 %{product_name: "product 1", quantity: 1},
                 %{product_name: "product 2", quantity: 2}
               ]
             }
    end

    test "returns entire response on failure" do
      assert {:error, %{data: data, errors: errors}} = call(failing_query())
      assert data == %{register_user: nil}
      assert [%{message: error1}, %{message: error2}] = errors
      assert error1 == "invalid login data"
      assert error2 == "can't be blank"
    end

    test "propagates authentication header" do
      auth_token = Base.encode64(:crypto.strong_rand_bytes(16), padding: false)
      assert call("query {login}", auth: auth_token) == {:ok, %{login: auth_token}}
    end
  end

  describe "call!" do
    test "returns data on success" do
      data = call!(order_query(), variables: %{order_id: 1})

      assert data.order == %{
               id: 1,
               order_items: [
                 %{product_name: "product 1", quantity: 1},
                 %{product_name: "product 2", quantity: 2}
               ]
             }
    end

    test "raises on failure" do
      error = assert_raise ExUnit.AssertionError, fn -> call!(failing_query()) end
      assert error.message =~ "GraphQL call failed"
      assert error.message =~ "invalid login data"
      assert error.message =~ "can't be blank"
    end
  end

  describe "errors" do
    test "returns all error messages" do
      {:error, response} = call(failing_query())
      assert errors(response) == ["invalid login data", "can't be blank"]
    end
  end

  describe "field_errors" do
    test "returns error messages for the desired field" do
      {:error, response} = call(failing_query())
      assert field_errors(response, "login") == ["can't be blank"]
    end
  end

  defp order_query do
    """
    query ($order_id: Int!) {
      order(id: $order_id) {
        id
        order_items {product_name quantity}
      }
    }
    """
  end

  defp failing_query, do: "mutation {register_user}"
end
