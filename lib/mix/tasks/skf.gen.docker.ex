defmodule Mix.Tasks.Skf.Gen.Docker do
  use Mix.Task

  @templates [
    Path.join(["skf.gen.docker", "Dockerfile"]),
    Path.join(["skf.gen.docker", ".dockerignore"]),
    Path.join(["skf.gen.docker", "entrypoint.sh"]),
    Path.join(["skf.gen.docker", "docker-compose.yml"])
  ]

  @switches []

  @shortdoc "Generate docker files"
  def run(args) do
    if Mix.Project.umbrella? do
      Mix.raise "mix phx.gen.json can only be run inside an application directory"
    end

    app = Mix.Project.config[:app]

    bindings = Keyword.merge([app: app], [])

    Enum.each(@templates, fn(tpl) ->
      tpl
      |> Skafolder.eval_from_templates(bindings)
      |> Skafolder.generate_file(Path.join([File.cwd!, Path.basename(tpl)]))
    end)
  end
end
