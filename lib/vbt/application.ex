defmodule VBT.Application do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Application
  alias VBT.Telemetry

  children =
    if Mix.env() == :test do
      [
        VBT.TestRepo,
        {Oban, repo: VBT.TestRepo, crontab: false, queues: false, prune: :disabled},
        VBT.GraphqlServer
      ]
    end

  def start(_type, _args) do
    VBT.FixedJob.init_time_provider()
    Telemetry.Oban.install_handler()

    Supervisor.start_link(
      unquote(children || []),
      strategy: :one_for_one,
      name: VBT.Supervisor
    )
  end
end
