defmodule SkafolderTester.SentryTestClient do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  @doc false
  def send_event(event, _opts) do
    send(self(), {:sentry_report, event})
    :ok
  end
end
