defmodule Mix.Tasks.Vbt.Gen.OperatorConfig do
  @shortdoc "Generate operator config"
  @moduledoc "Generate operator config"

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @template Path.join(["skf.gen.operator_config", "operator_config.eex"])

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.operator_config can only be run inside an application directory")
    end

    app = Mix.Project.config()[:app]

    bindings = Keyword.merge([app: app], [])

    @template
    |> VBT.Skafolder.eval_from_templates(bindings)
    |> VBT.Skafolder.generate_file(
      Path.join([File.cwd!(), "lib", to_string(app), "operator_config.ex"]),
      args
    )
  end
end
