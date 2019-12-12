defmodule Mix.Tasks.Vbt.Bootstrap do
  @moduledoc "Boostrap project (generate everything!!!)"

  # credo:disable-for-this-file Credo.Check.Readability.Specs
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

    Mix.shell().info(manual_instructions())
  end

  defp manual_instructions do
    """
    You also need to make the following changes in your mix.exs file:

        def project do
          [
            # ...
            preferred_cli_env: preferred_cli_env(),
            dialyzer: dialyzer()
          ]
        end

        def deps do
          [
            # ...
            {:dialyxir, "~> 0.5", runtime: false}
          ]
        end

        defp aliases do
          [
            # ...
            test: ["ecto.create --quiet", "ecto.migrate", "test"],
            credo: ~w/compile credo/
          ]
        end

        defp preferred_cli_env() do
          [credo: :test, dialyzer: :test]
        end

        defp dialyzer() do
          [
            plt_add_apps: [:ex_unit, :mix],
            ignore_warnings: "dialyzer.ignore-warnings"
          ]
        end
    """
  end
end
