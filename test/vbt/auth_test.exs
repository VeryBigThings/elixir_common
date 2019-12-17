defmodule VBT.AuthTest do
  use VBT.Graphql.Case, async: true, endpoint: VBT.GraphqlServer, api_path: "/"

  describe "GraphQL authentication" do
    test "correctly decodes valid token" do
      token = authenticate!("some_login")
      assert {:ok, data} = current_user(token)
      assert data.current_user == "some_login"
    end

    test "rejects expired token" do
      token = authenticate!("some_login")
      assert {:error, response} = current_user(token, max_age: 0)
      assert "token_expired" in errors(response)
    end

    test "rejects invalid token" do
      assert {:error, response} = current_user("invalid token")
      assert "token_invalid" in errors(response)
    end

    test "rejects missing token" do
      assert {:error, response} = current_user(nil)
      assert "token_missing" in errors(response)
    end
  end

  defp authenticate!(login),
    do: call!(~s/query {auth_token(login: "#{login}")}/).auth_token

  defp current_user(token, opts \\ []),
    do: call(~s/query {current_user(max_age: #{opts[:max_age] || "null"})}/, auth: token)
end
