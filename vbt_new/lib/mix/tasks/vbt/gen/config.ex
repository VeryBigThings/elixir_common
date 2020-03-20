defmodule Mix.Tasks.Vbt.Gen.Config do
  @shortdoc "Generate operator config"
  @moduledoc "Generate operator config"

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @template Path.join(["skf.gen.config", "config.eex"])

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.config can only be run inside an application directory")
    end

    app = Mix.Project.config()[:app]

    bindings = Keyword.merge([app: app], [])

    @template
    |> Mix.Vbt.eval_from_templates(bindings)
    |> Mix.Vbt.generate_file(
      Path.join([File.cwd!(), "lib", to_string(app), "config.ex"]),
      args
    )
  end
end
