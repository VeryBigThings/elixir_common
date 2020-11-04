# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule SkafolderTesterApp do
  use Boundary, deps: [SkafolderTester, SkafolderTesterConfig, SkafolderTesterWeb]
  use Application

  def start(_type, _args) do
    SkafolderTesterConfig.validate!()

    Supervisor.start_link(
      [
        SkafolderTester,
        SkafolderTesterWeb
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  def config_change(changed, _new, removed) do
    SkafolderTesterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
