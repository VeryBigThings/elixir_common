defmodule VBT.Application do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Application
  alias VBT.{Absinthe, Telemetry}

  test_children =
    if Mix.env() == :test do
      [
        VBT.TestRepo,
        {Oban, repo: VBT.TestRepo, crontab: false, queues: false, plugins: false},
        {Phoenix.PubSub, [name: VBT.GraphqlServer.PubSub, adapter: Phoenix.PubSub.PG2]},
        VBT.GraphqlServer
      ]
    else
      []
    end

  def start(_type, _args) do
    VBT.FixedJob.init_time_provider()
    Telemetry.Oban.install_handler()

    Absinthe.Instrumentation.configure()
    Supervisor.start_link(unquote(test_children), strategy: :one_for_one, name: VBT.Supervisor)
  end
end
