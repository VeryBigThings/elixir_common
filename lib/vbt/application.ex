defmodule VBT.Application do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Application

  def start(_type, _args) do
    Supervisor.start_link([], strategy: :one_for_one, name: VBT.Supervisor)
  end
end
