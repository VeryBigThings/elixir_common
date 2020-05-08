defmodule VBT.Absinthe.InstrumentationTest do
  use ExUnit.Case, async: false
  alias VBT.Absinthe.Instrumentation

  test "logs an operation if its duration exceeds the given threshold" do
    set_threshold(0)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        Absinthe.run(
          """
          query {
            object1: object(id: 1) {id children {id children {id}}}
            object2: object(id: 2) {id children {id children {id}}}
          }
          """,
          __MODULE__.Schema
        )
      end)

    assert String.replace(log, ~r/\d+ms/, "0ms") =~
             """
             [warn]  spent 0ms in query { object1: object(id: 1) {id children {id children {id}}} object2: object(id: 2) {id children {id children {id}}} }
               -> 0ms in object1
               -> 0ms in object1.children
               -> 0ms in object1.children.0.children
               -> 0ms in object2
               -> 0ms in object2.children
               -> 0ms in object2.children.0.children
               -> 0ms in object2.children.1.children
             """
  end

  test "doesn't log an operation if its duration is below the given threshold" do
    set_threshold(:timer.hours(24))

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        Absinthe.run(
          """
          query {
            object1: object(id: 1) {id children {id children {id}}}
            object2: object(id: 2) {id children {id children {id}}}
          }
          """,
          __MODULE__.Schema
        )
      end)

    assert log == ""
  end

  test "correctly logs multiple queries made from the same process" do
    set_threshold(0)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        Absinthe.run("query {object(id: 1) {id}}", __MODULE__.Schema)
        Absinthe.run("query {object(id: 2) {id}}", __MODULE__.Schema)
      end)

    assert [_prefix, warning1, warning2] =
             log |> String.replace(~r/\d+ms/, "0ms") |> String.split("[warn]")

    assert warning1 =~ "spent 0ms in query {object(id: 1) {id}}"
    assert warning2 =~ "spent 0ms in query {object(id: 2) {id}}"
  end

  defp set_threshold(duration_ms) do
    Instrumentation.set_long_operation_threshold(duration_ms)
    on_exit(fn -> Instrumentation.set_long_operation_threshold(:infinity) end)
  end

  defmodule Schema do
    @moduledoc false
    use VBT.Absinthe.Schema

    query do
      field :object, :result do
        arg :id, non_null(:integer)
        resolve fn arg, _res -> {:ok, object(arg.id)} end
      end
    end

    object :result do
      field :id, non_null(:integer)

      field :children, list_of(:result),
        resolve: fn parent, _arg, _res -> {:ok, Enum.map(1..parent.id, &object/1)} end
    end

    defp object(id), do: %{id: id, children: nil}
  end
end
