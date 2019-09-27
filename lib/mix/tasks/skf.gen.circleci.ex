defmodule Mix.Tasks.Skf.Gen.Circleci do
  use Mix.Task

  @template Path.join(["skf.gen.circleci", "config.yml"])

  @shortdoc "Generate CircleCI config files"
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix phx.gen.json can only be run inside an application directory")
    end

    app = Mix.Project.config()[:app]

    bindings = Keyword.merge([app: app], [])

    @template
    |> Skafolder.eval_from_templates(bindings)
    |> Skafolder.generate_file(Path.join([File.cwd!(), ".circleci", "config.yml"]))
  end
end
