defmodule VBT.EctoTest do
  use ExUnit.Case, async: true
  doctest VBT.Ecto

  import VBT.Ecto
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Multi
  alias VBT.TestRepo

  setup do
    Sandbox.checkout(VBT.TestRepo)
    :ok
  end

  describe "multi_operation_result" do
    test "raises if invalid field is accessed" do
      result =
        Multi.new()
        |> Multi.run(:foo, fn _, _ -> {:ok, 1} end)
        |> TestRepo.transaction()

      assert_raise(
        KeyError,
        "key :bar not found in: %{foo: 1}",
        fn -> multi_operation_result(result, :bar) end
      )
    end
  end
end
