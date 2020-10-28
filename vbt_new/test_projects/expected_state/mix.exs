defmodule SkafolderTester.MixProject do
  use Mix.Project

  def project do
    [
      app: :skafolder_tester,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:boundary, :phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      preferred_cli_env: preferred_cli_env(),
      dialyzer: dialyzer(),
      releases: releases(),
      boundary: boundary(),
      build_path: System.get_env("BUILD_PATH", "_build")
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SkafolderTesterApp, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:boundary, "~> 0.6"},
      {:ecto_sql, "~> 3.4"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:mox, "~> 0.5", only: :test},
      {:phoenix, "~> 1.5.6"},
      {:phoenix_ecto, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.3 or ~> 0.2.9"},
      {:plug_cowboy, "~> 2.0"},
      {:postgrex, ">= 0.0.0"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:vbt, path: "../../.."}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      credo: ["compile", "credo"],
      operator_template: ["compile", &operator_template/1],
      release: release_steps()
    ]
  end

  defp preferred_cli_env,
    do: [credo: :test, dialyzer: :test, release: :prod, operator_template: :prod]

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix],
      ignore_warnings: "dialyzer.ignore-warnings"
    ]
  end

  defp operator_template(_),
    do: IO.puts(SkafolderTesterConfig.template())

  defp releases() do
    [
      skafolder_tester: [
        include_executables_for: [:unix],
        steps: [:assemble, &copy_bin_files/1]
      ]
    ]
  end

  # solution from https://elixirforum.com/t/equivalent-to-distillerys-boot-hooks-in-mix-release-elixir-1-9/23431/2
  defp copy_bin_files(release) do
    File.cp_r("rel/bin", Path.join(release.path, "bin"))
    release
  end

  defp release_steps do
    if Mix.env() != :prod or System.get_env("SKIP_ASSETS") == "true" or not File.dir?("assets") do
      []
    else
      [
        "cmd 'cd assets && npm install && npm run deploy'",
        "phx.digest"
      ]
    end
    |> Enum.concat(["release"])
  end

  defp boundary do
    [
      default: [
        check: [
          apps: [{:mix, :runtime}]
        ]
      ]
    ]
  end
end
