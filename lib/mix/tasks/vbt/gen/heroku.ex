defmodule Mix.Tasks.Vbt.Gen.Heroku do
  @shortdoc "Generate Heroku config"
  @moduledoc "Generate Heroku config"
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @template_root "skf.gen.heroku"

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.heroku can only be run inside an application directory")
    end

    bindings = Mix.Vbt.bindings()

    Enum.each(
      files_for_docker_deployments(@template_root),
      fn {source, destination} ->
        source
        |> VBT.Skafolder.eval_from_templates(bindings)
        |> VBT.Skafolder.generate_file(destination, args)
      end
    )
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
