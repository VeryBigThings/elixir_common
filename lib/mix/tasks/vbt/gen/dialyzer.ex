defmodule Mix.Tasks.Vbt.Gen.Dialyzer do
  @moduledoc "Generate dialyzer files"
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @shortdoc "Generate dialyzer files"
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.dialyzer can only be run inside an application directory")
    end

    Mix.Generator.create_file("dialyzer.ignore-warnings", "")
  end
end
