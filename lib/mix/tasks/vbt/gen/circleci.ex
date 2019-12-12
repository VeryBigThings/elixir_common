defmodule Mix.Tasks.Vbt.Gen.Circleci do
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @template Path.join(["skf.gen.circleci", "config.yml"])

  @shortdoc "Generate CircleCI config files"
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.circleci can only be run inside an application directory")
    end

    app = Mix.Project.config()[:app]

    bindings = Keyword.merge([app: app], [])

    @template
    |> VBT.Skafolder.eval_from_templates(bindings)
    |> VBT.Skafolder.generate_file(Path.join([File.cwd!(), ".circleci", "config.yml"]))
  end
end
