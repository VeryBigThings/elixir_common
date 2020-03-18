defmodule Mix.Tasks.Vbt.Gen.Docker do
  @shortdoc "Generate docker files"
  @moduledoc "Generate docker files"

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @templates [
    Path.join(["skf.gen.docker", "Dockerfile"]),
    Path.join(["skf.gen.docker", ".dockerignore"]),
    Path.join(["skf.gen.docker", ".env.development"]),
    Path.join(["skf.gen.docker", "entrypoint.sh"]),
    Path.join(["skf.gen.docker", "docker-compose.yml"])
  ]

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.docker can only be run inside an application directory")
    end

    app = Mix.Project.config()[:app]

    bindings = Keyword.merge([app: app], [])

    Enum.each(@templates, fn tpl ->
      tpl
      |> Mix.Vbt.eval_from_templates(bindings)
      |> Mix.Vbt.generate_file(Path.join([File.cwd!(), Path.basename(tpl)]), args)
    end)
  end
end
