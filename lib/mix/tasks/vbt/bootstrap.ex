defmodule Mix.Tasks.Vbt.Bootstrap do
  use Mix.Task

  @shortdoc "Boostrap project (generate everything!!!)"
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.bootstrap can only be run inside an application directory")
    end

    Mix.Task.run("vbt.gen.makefile", args)
    Mix.Task.run("vbt.gen.docker", args)
    Mix.Task.run("vbt.gen.circleci", args)
    Mix.Task.run("vbt.gen.heroku", args)
  end
end
