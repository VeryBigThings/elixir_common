defmodule VBT.Telemetry.Oban do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  require Logger

  def install_handler do
    events = Enum.map([:success, :failure], &[:oban, &1])
    :telemetry.attach_many(__MODULE__, events, &handle_event/4, nil)
  end

  defp handle_event([:oban, :success], _measure, meta, nil) do
    Logger.debug(~s/processed job id=#{meta.id} in queue #{inspect(meta.queue)}/)
  end

  defp handle_event([:oban, :failure], _measure, meta, nil) do
    Logger.error("""
    failed processing job id=#{meta.id} in queue #{inspect(meta.queue)}:

      #{Exception.format(normalize_kind(meta.kind), meta.error, meta.stack)}
    """)
  end

  defp normalize_kind(kind) when kind in ~w/error exit throw/a, do: kind
  defp normalize_kind({:EXIT, pid} = kind) when is_pid(pid), do: kind
  defp normalize_kind(_other), do: :error
end
