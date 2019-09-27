defmodule Mix.Tasks.Skf.Bootstrap do
  use Mix.Task

  @shortdoc "Boostrap project (generate everything!!!)"
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix phx.gen.json can only be run inside an application directory")
    end

    Mix.Tasks.Skf.Gen.Makefile.run(args)
    Mix.Tasks.Skf.Gen.Docker.run(args)
    Mix.Tasks.Skf.Gen.Circleci.run(args)
    Mix.Tasks.Skf.Gen.Heroku.run(args)
  end
end
