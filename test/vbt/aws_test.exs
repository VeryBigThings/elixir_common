defmodule VBT.AwsTest do
  use ExUnit.Case, async: false
  alias VBT.Aws

  describe "client" do
    setup do
      Application.delete_env(:vbt, :ex_aws_client)
    end

    test "returns ExAws by default" do
      assert Aws.client() == ExAws
    end

    test "returns configured module" do
      Application.put_env(:vbt, :ex_aws_client, MyExAwsClient)
      assert Aws.client() == MyExAwsClient
    end
  end
end
