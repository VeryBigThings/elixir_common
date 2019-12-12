defmodule Mix.Tasks.Vbt.Gen.Dialyzer do
  @shortdoc "Generate dialyzer files"
  @moduledoc "Generate dialyzer files"
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.dialyzer can only be run inside an application directory")
    end

    Mix.Generator.create_file("dialyzer.ignore-warnings", "")
  end
end
