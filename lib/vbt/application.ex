defmodule VBT.Application do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Application

  children =
    if Mix.env() == :test do
      [
        VBT.TestRepo,
        {Oban, repo: VBT.TestRepo, crontab: false, queues: false, prune: :disabled},
        VBT.GraphqlServer
      ]
    end

  def start(_type, _args) do
    Supervisor.start_link(
      unquote(children || []),
      strategy: :one_for_one,
      name: VBT.Supervisor
    )
  end
end
