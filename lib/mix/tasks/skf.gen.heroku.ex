defmodule Mix.Tasks.Skf.Gen.Heroku do
  use Mix.Task

  @template_root "skf.gen.heroku"

  @switches []
  @defaults []

  @shortdoc "Generate Heroku config"
  def run(args) do
    app = Mix.Project.config()[:app]

    if Mix.Project.umbrella?() do
      Mix.raise("mix phx.gen.json can only be run inside an application directory")
    end

    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)
    bindings = Keyword.merge([app: app], Enum.into(opts, @defaults))

    Enum.each(files_for_docker_deployments(@template_root), fn {source, destination} ->
      source
      |> VBT.Skafolder.eval_from_templates(bindings)
      |> VBT.Skafolder.generate_file(destination)
    end)
  end

  def files_for_docker_deployments(template_root) do
    %{
      Path.join([template_root, "heroku.yml"]) => "heroku.yml",
      Path.join([template_root, "db_tasks", "migrate.sh"]) =>
        Path.join(["rel", "bin", "migrate.sh"]),
      Path.join([template_root, "db_tasks", "rollback.sh"]) =>
        Path.join(["rel", "bin", "rollback.sh"]),
      Path.join([template_root, "db_tasks", "seed.sh"]) => Path.join(["rel", "bin", "seed.sh"])
    }
  end
end
