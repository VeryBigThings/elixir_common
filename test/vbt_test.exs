defmodule VBTTest do
  use ExUnit.Case, async: true

  doctest VBT

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
