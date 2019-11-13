defmodule Mix.Tasks.Vbt.Gen.Credo do
  use Mix.Task

  @template Path.join(["skf.gen.credo", ".credo.exs"])

  @shortdoc "Generate credo config files"
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.credo can only be run inside an application directory")
    end

    bindings = Mix.Vbt.bindings()

    @template
    |> VBT.Skafolder.eval_from_templates(bindings)
    |> VBT.Skafolder.generate_file(Path.join(File.cwd!(), ".credo.exs"))
  end
end