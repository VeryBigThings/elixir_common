defmodule Mix.Tasks.Vbt.Gen.Circleci do
  @shortdoc "Generate CircleCI config files"
  @moduledoc "Generate CircleCI config files"

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @template Path.join(["skf.gen.circleci", "config.yml"])

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.circleci can only be run inside an application directory")
    end

    app = Mix.Project.config()[:app]

    bindings = Keyword.merge([app: app], [])

    @template
    |> Mix.Vbt.eval_from_templates(bindings)
    |> Mix.Vbt.generate_file(Path.join([File.cwd!(), ".circleci", "config.yml"]), args)
  end
end
