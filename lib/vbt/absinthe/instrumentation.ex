defmodule VBT.Absinthe.Instrumentation do
  @moduledoc """
  Instrumentation of absinthe queries.

  This module is responsible for logging longer running GraphQL operations (queries and mutations).
  By default, each operation that takes longer than 100ms is logged, together with all of the
  resolvers that were invoked:

      [warn]  spent 200ms in query { object1: object(id: 1) {id children {id children {id}}} object2: object(id: 2) {id children {id children {id}}} }
        -> 10ms in object1
        -> 20ms in object1.children
        -> 30ms in object1.children.0.children
        -> 40ms in object2
        -> 50ms in object2.children
        -> 60ms in object2.children.0.children
        -> 70ms in object2.children.1.children

  You can change this threshold via `set_long_operation_threshold/0`. To avoid the noise in tests,
  add the following to your test_helper.exs:

      VBT.Absinthe.Instrumentation.set_long_operation_threshold(:infinity)

  In addition to logging, a telemetry event `[:vbt, :graphql, :operation, :stop]` is emitted for
  each query. You can attach to this event with `:telemetry.attach/4`. The event's measurement will
  contain the field `:total` for the total running time of the operation, and additional entries
  with keys representing field paths, and values representing corresponding times. All times are in
  microseconds. The metadata argument will contain the string representation of the query.
  """

  require Logger

  # telemetry events we're handling
  @field_stop_event [:absinthe, :resolve, :field, :stop]
  @operation_stop_event [:absinthe, :execute, :operation, :stop]
  @vbt_stop_event [:vbt, :graphql, :operation, :stop]

  @doc "Sets the threshold for long running operations."
  @spec set_long_operation_threshold(non_neg_integer | :infinity) :: :ok
  def set_long_operation_threshold(duration_ms), do: :persistent_term.put(__MODULE__, duration_ms)

  @doc false
  @spec configure :: :ok
  def configure do
    set_long_operation_threshold(100)
    events = [@field_stop_event, @operation_stop_event, @vbt_stop_event]
    :telemetry.attach_many(__MODULE__, events, &handle_event/4, %{})
  end

  defp handle_event(@field_stop_event, measurements, metadata, _config) do
    path =
      metadata.resolution
      |> Absinthe.Resolution.path()
      |> Enum.map(fn part -> with index when is_integer(index) <- part, do: "[i]" end)
      |> Enum.join(".")

    state =
      Map.update(
        Process.get(__MODULE__, %{}),
        path,
        {measurements.duration, 1},
        fn {duration, count} -> {duration + measurements.duration, count + 1} end
      )

    Process.put(__MODULE__, state)
  end

  defp handle_event(@operation_stop_event, measurements, metadata, _config) do
    measurements =
      Enum.into(
        Process.delete(__MODULE__) || %{},
        %{total: to_us(measurements.duration)},
        fn {path, {duration, count}} -> {path, %{duration: to_us(duration), count: count}} end
      )

    :telemetry.execute(@vbt_stop_event, measurements, %{query: original_query(metadata)})
  end

  defp handle_event(@vbt_stop_event, measurements, metadata, _config) do
    total_duration = div(measurements.total, 1000)

    if total_duration >= long_operation_threshold() do
      operations =
        Map.delete(measurements, :total)
        |> Enum.sort_by(fn {_operation, data} -> data.duration end, :desc)
        |> Enum.map(fn {operation, data} ->
          "  -> #{div(data.duration, 1000)}ms (#{data.count} calls) in #{operation}\n"
        end)

      Logger.warn([
        "spent #{total_duration}ms in #{Logger.Utils.truncate(metadata.query, 1000)}\n"
        | operations
      ])
    end
  end

  defp long_operation_threshold, do: :persistent_term.get(__MODULE__, 100)

  defp original_query(metadata) do
    metadata.blueprint.source
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp to_us(duration), do: System.convert_time_unit(duration, :native, :microsecond)
end
