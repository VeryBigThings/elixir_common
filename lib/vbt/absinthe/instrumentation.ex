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
  """

  use GenServer
  require Logger

  # telemetry events we're handling
  @operation_start_event [:absinthe, :execute, :operation, :start]
  @field_stop_event [:absinthe, :resolve, :field, :stop]
  @operation_stop_event [:absinthe, :execute, :operation, :stop]

  @doc "Sets the threshold for long running operations."
  @spec set_long_operation_threshold(non_neg_integer | :infinity) :: :ok
  def set_long_operation_threshold(duration_ms), do: :persistent_term.put(__MODULE__, duration_ms)

  @impl GenServer
  def init(_) do
    set_long_operation_threshold(100)

    # This table will hold all relevant telemetry data from all clients.
    # We're using client pid as the key, since telemetry handler are executed in the client process.
    :ets.new(__MODULE__, [
      # Since there will be multiple entries for each client (one per each resolver invoked), the
      # table type has to be bag. The `duplicate_bag` is used because it's faster (no duplicates
      # checks).
      :duplicate_bag,

      # The table will be accessed by many clients, so it needs to be public, named, and configured
      # for concurrent read/write access.
      :public,
      :named_table,
      write_concurrency: true,
      read_concurrency: true
    ])

    events = [@operation_start_event, @field_stop_event, @operation_stop_event]
    :telemetry.attach_many(__MODULE__, events, &handle_event/4, %{})

    {:ok, nil}
  end

  @impl GenServer
  def handle_cast({:register_client, client_pid}, state) do
    Process.monitor(client_pid)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _mref, :process, pid, _reason}, state) do
    # cleanup client entries, in case the process crashed
    :ets.delete(__MODULE__, pid)
    {:noreply, state}
  end

  @doc false
  @spec start_link(any) :: GenServer.on_start()
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  defp handle_event(@operation_start_event, _measurements, _metadata, _config) do
    GenServer.cast(__MODULE__, {:register_client, self()})
  end

  defp handle_event(@field_stop_event, measurements, metadata, _config) do
    path = Absinthe.Resolution.path(metadata.resolution)
    :ets.insert(__MODULE__, {self(), path, measurements.duration})
  end

  defp handle_event(@operation_stop_event, measurements, metadata, _config) do
    total_duration = to_ms(measurements.duration)

    if total_duration >= long_operation_threshold() do
      ["spent #{total_duration}ms in #{original_query(metadata)}" | recorded_fields_entries()]
      |> Enum.join("\n")
      |> Logger.warn()
    end
  end

  defp long_operation_threshold, do: :persistent_term.get(__MODULE__, 100)

  defp recorded_fields_entries do
    :ets.take(__MODULE__, self())
    |> Stream.map(fn {_pid, path, duration} -> {Enum.join(path, "."), to_ms(duration)} end)
    |> Enum.sort_by(fn {path, _duration} -> path end)
    |> Enum.map(fn {path, duration} -> "  -> #{duration}ms in #{path}" end)
  end

  defp original_query(metadata) do
    metadata.blueprint.source
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp to_ms(duration), do: System.convert_time_unit(duration, :native, :millisecond)
end
