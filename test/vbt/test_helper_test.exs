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
end
