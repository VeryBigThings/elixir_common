defmodule Mix.Tasks.Vbt.Gen.Docker do
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @templates [
    Path.join(["skf.gen.docker", "Dockerfile"]),
    Path.join(["skf.gen.docker", ".dockerignore"]),
    Path.join(["skf.gen.docker", ".env.development"]),
    Path.join(["skf.gen.docker", "entrypoint.sh"]),
    Path.join(["skf.gen.docker", "docker-compose.yml"])
  ]

  @shortdoc "Generate docker files"

  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.docker can only be run inside an application directory")
    end

    app = Mix.Project.config()[:app]

    bindings = Keyword.merge([app: app], [])

    Enum.each(@templates, fn tpl ->
      tpl
      |> VBT.Skafolder.eval_from_templates(bindings)
      |> VBT.Skafolder.generate_file(Path.join([File.cwd!(), Path.basename(tpl)]))
    end)
  end
end
