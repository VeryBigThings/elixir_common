defmodule Mix.Tasks.Vbt.Bootstrap do
  @shortdoc "Boostrap project (generate everything!!!)"
  @moduledoc "Boostrap project (generate everything!!!)"

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task
  alias Mix.Vbt.{ConfigFile, MixFile, SourceFile}

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.bootstrap can only be run inside an application directory")
    end

    Enum.each(
      ~w/makefile docker circleci heroku github_pr_template credo dialyzer formatter_config/,
      &Mix.Task.run("vbt.gen.#{&1}", args)
    )

    adapt_code!()
  end

  defp adapt_code! do
    source_files()
    |> add_standard_deps()
    |> configure_preferred_cli_env()
    |> configure_dialyzer()
    |> configure_endpoint()
    |> store_source_files!()
  end

  defp add_standard_deps(source_files) do
    update_in(
      source_files.mix,
      fn mix_file ->
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
    )
  end

  defp configure_preferred_cli_env(source_files) do
    update_in(
      source_files.mix,
      fn mix_file ->
        mix_file
        |> MixFile.append_config(:project, "preferred_cli_env: preferred_cli_env()")
        |> SourceFile.add_to_module("defp preferred_cli_env, do: [credo: :test, dialyzer: :test]")
      end
    )
  end

  defp configure_dialyzer(mix_file) do
    update_in(
      source_files.mix,
      fn mix_file ->
        mix_file
        |> MixFile.append_config(:aliases, ~s/credo: ["compile", "credo"]/)
        |> MixFile.append_config(:project, "dialyzer: dialyzer()")
        |> SourceFile.add_to_module("""
        defp dialyzer do
          [
            plt_add_apps: [:ex_unit, :mix],
            ignore_warnings: "dialyzer.ignore-warnings"
          ]
        end
        """)
      end
    )
  end

  defp configure_endpoint(source_files) do
    source_files
    |> remove_endpoint_configs()
    |> update_in([:endpoint], &setup_runtime_endpoint_config/1)
  end

  defp setup_runtime_endpoint_config(endpoint_file) do
    SourceFile.add_to_module(
      endpoint_file,
      """

      @impl Phoenix.Endpoint
      def init(_type, config) do
        config =
          config
          |> Keyword.put(:secret_key_base, System.fetch_env!("SECRET_KEY_BASE"))
          |> Keyword.update(:url, url_config(), &Keyword.merge(&1, url_config()))
          |> Keyword.update(:http, http_config(), &(http_config() ++ (&1 || [])))

        {:ok, config}
      end

      defp url_config, do: [host: System.fetch_env!("HOST")]
      defp http_config, do: [:inet6, port: System.fetch_env!("PORT")]
      """
    )
  end

  defp remove_endpoint_configs(source_files) do
    Enum.reduce(
      ~w/config dev_config test_config prod_config/a,
      source_files,
      fn config, source_files ->
        update_in(
          source_files[config],
          &ConfigFile.update_endpoint_config(
            &1,
            fn opts -> Keyword.drop(opts, ~w/url http secret_key_base/a) end
          )
        )
      end
    )
  end

  defp source_files do
    %{
      mix: SourceFile.load!("mix.exs"),
      config: SourceFile.load!("config/config.exs"),
      dev_config: SourceFile.load!("config/dev.exs"),
      test_config: SourceFile.load!("config/test.exs"),
      prod_config: SourceFile.load!("config/prod.exs"),
      endpoint: load_web_file("endpoint.ex")
    }
  end

  defp load_web_file(location) do
    app = Keyword.fetch!(Mix.Project.config(), :app)
    SourceFile.load!(Path.join(["lib", "#{app}_web", location]))
  end

  defp store_source_files!(source_files),
    do: source_files |> Map.values() |> Enum.each(&SourceFile.store!/1)
end
