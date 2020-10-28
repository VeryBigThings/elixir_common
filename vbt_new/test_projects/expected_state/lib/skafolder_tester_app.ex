# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule SkafolderTesterApp do
  use Application

  def start(_type, _args) do
    SkafolderTesterConfig.validate!()

    children = [
      SkafolderTester.Repo,
      SkafolderTesterWeb.Telemetry,
      {Phoenix.PubSub, name: SkafolderTester.PubSub},
      SkafolderTesterWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    SkafolderTesterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
