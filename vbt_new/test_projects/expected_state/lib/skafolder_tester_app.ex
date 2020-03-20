# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule SkafolderTesterApp do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    SkafolderTester.Config.validate!()

    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      SkafolderTester.Repo,
      # Start the endpoint when the application starts
      SkafolderTesterWeb.Endpoint
      # Starts a worker by calling: SkafolderTester.Worker.start_link(arg)
      # {SkafolderTester.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SkafolderTester.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    SkafolderTesterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
