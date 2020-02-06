defmodule VBTTest do
  use ExUnit.Case, async: true

  describe "aws_client()" do
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
end
