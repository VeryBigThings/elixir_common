defmodule Mix.Tasks.Vbt.Gen.GithubPrTemplate do
  @moduledoc "Generate Github pull request template"
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @template Path.join(["skf.gen.github_pr_template", "pull_request_template.md"])

  @shortdoc "Generate Github pull request template"
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.github_pr_template can only be run inside an application directory")
    end

    bindings = Mix.Vbt.bindings()

    @template
    |> VBT.Skafolder.eval_from_templates(bindings)
    |> VBT.Skafolder.generate_file(
      Path.join([File.cwd!(), ".github", "pull_request_template.md"])
    )
  end
end
