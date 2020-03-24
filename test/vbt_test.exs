defmodule VBTTest do
  use ExUnit.Case, async: true

  describe "aws_client" do
    setup do
      Application.delete_env(:vbt, :ex_aws_client)
    end

    test "returns ExAws by default" do
      assert VBT.aws_client() == ExAws
    end

    test "returns configured module" do
      Application.put_env(:vbt, :ex_aws_client, MyExAwsClient)
      assert VBT.aws_client() == MyExAwsClient
    end
  end

  describe "validate" do
    test "returns :ok if condition is met" do
      assert VBT.validate(1 + 1 == 2, :some_error) == :ok
    end

    test "returns error if condition is not met" do
      assert VBT.validate(1 + 1 == 11, :some_error) == {:error, :some_error}
    end
  end

  describe "authorize" do
    test "returns :ok if condition is met" do
      assert VBT.authorize(1 + 1 == 2) == :ok
    end

    test "returns error if condition is not met" do
      assert VBT.authorize(1 + 1 == 11) == {:error, :unauthorized}
    end
  end
end
