defmodule ScaffolderTest do
  use ExUnit.Case
  doctest Scaffolder

  test "greets the world" do
    assert Scaffolder.hello() == :world
  end
end
