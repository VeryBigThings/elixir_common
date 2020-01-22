defmodule Mix.Tasks.Vbt.Bootstrap do
  @shortdoc "Boostrap project (generate everything!!!)"
  @moduledoc "Boostrap project (generate everything!!!)"

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task
  alias Mix.Vbt.MixFile

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.bootstrap can only be run inside an application directory")
    end

    Enum.each(
      ~w/makefile docker circleci heroku github_pr_template credo dialyzer/,
      &Mix.Task.run("vbt.gen.#{&1}", args)
    )

    adapt_code!()
  end

  defp adapt_code! do
    MixFile.load!()
    |> add_standard_deps()
    |> configure_preferred_cli_env()
    |> configure_dialyzer()
    |> MixFile.store!()
  end

  defp add_standard_deps(mix_file) do
    MixFile.add_deps(
      mix_file,
      """
        {:absinthe, "~> 1.4"},
        {:absinthe_phoenix, "~> 1.4"},
        {:absinthe_plug, "~> 1.4"},
        {:absinthe_relay, "~> 1.4"},
        {:ecto_enum, "~> 1.3"},
        {:dialyxir, "~> 0.5", runtime: false}
      """
    )
  end

  defp configure_preferred_cli_env(mix_file) do
    mix_file
    |> MixFile.append_config(:project, "preferred_cli_env: preferred_cli_env()")
    |> MixFile.add_function("defp preferred_cli_env, do: [credo: :test, dialyzer: :test]")
  end

  defp configure_dialyzer(mix_file) do
    mix_file
    |> MixFile.append_config(:aliases, ~s/credo: ["compile", "credo"]/)
    |> MixFile.append_config(:project, "dialyzer: dialyzer()")
    |> MixFile.add_function("""
        defp dialyzer do
          [
            plt_add_apps: [:ex_unit, :mix],
            ignore_warnings: "dialyzer.ignore-warnings"
          ]
        end
    """)
  end
end
