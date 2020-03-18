defmodule Mix.Tasks.Vbt.Gen.GithubPrTemplate do
  @shortdoc "Generate Github pull request template"
  @moduledoc "Generate Github pull request template"
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @template Path.join(["skf.gen.github_pr_template", "pull_request_template.md"])

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.github_pr_template can only be run inside an application directory")
    end

    bindings = Mix.Vbt.bindings()

    @template
    |> Mix.Vbt.eval_from_templates(bindings)
    |> Mix.Vbt.generate_file(
      Path.join([File.cwd!(), ".github", "pull_request_template.md"]),
      args
    )
  end
end
