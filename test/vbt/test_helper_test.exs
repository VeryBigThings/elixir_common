defmodule VBT.TestHelperTest do
  use ExUnit.Case, async: true
  alias VBT.TestHelper

  doctest TestHelper

  describe "unique_positive_integer" do
    test "returns only positive numbers" do
      Stream.repeatedly(fn -> TestHelper.unique_positive_integer() end)
      |> Stream.take(1000)
      |> Enum.each(&assert(&1 > 0))
    end

    test "returns strictly increasing numbers" do
      Stream.repeatedly(fn -> TestHelper.unique_positive_integer() end)
      |> Stream.take(1000)
      |> Stream.chunk_every(2, 1, :discard)
      |> Enum.each(fn [previous, next] -> assert previous < next end)
    end
  end

  describe "eventually" do
    test "raises an assertion error if the condition is not met after max attempts" do
      e =
        assert_raise(
          ExUnit.AssertionError,
          fn ->
            VBT.TestHelper.eventually(
              fn ->
                current_value = Process.get(:expected_value, 0)
                Process.put(:expected_value, current_value + 1)
                assert current_value == 5
              end,
              attempts: 1,
              delay: 10
            )
          end
        )

      assert e.message == "Assertion with == failed"
    end

    defp token_expired?() do
      current_value = Process.get(:expected_value, 0)
      Process.put(:expected_value, current_value + 1)
      current_value == 5
    end
  end
end
