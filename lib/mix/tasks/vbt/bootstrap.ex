defmodule Mix.Tasks.Vbt.Bootstrap do
  use Mix.Task

  @shortdoc "Boostrap project (generate everything!!!)"
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.bootstrap can only be run inside an application directory")
    end

    Enum.each(
      ~w/makefile docker circleci heroku github_pr_template credo dialyzer/,
      &Mix.Task.run("vbt.gen.#{&1}", args)
    )
  end
end
