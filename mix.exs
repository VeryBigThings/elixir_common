defmodule VBT.MixProject do
  use Mix.Project

  def project do
    [
      app: :vbt,
      version: "0.1.0",
      elixir: "~> 1.18.2",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: preferred_cli_env(),
      dialyzer: dialyzer(),
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      source_url: "https://github.com/VeryBigThings/elixir_common_private/",
      docs: docs()
    ]
  end

  def application do
    additional_apps = if Mix.env() == :test, do: [:postgrex, :ecto], else: []

    [
      extra_applications: [:logger | additional_apps],
      mod: {VBT.Application, []}
    ]
  end

  defp deps do
    [
      {:absinthe_phoenix, "~> 2.0"},
      {:absinthe_relay, "~> 1.5"},
      {:bamboo, "~> 2.4"},
      {:bamboo_phoenix, "~> 1.0.0"},
      {:bcrypt_elixir, "~> 3.2"},
      {:credo, "~> 1.7", runtime: false},
      {:dialyxir, "~> 1.4", runtime: false},
      {:ecto_enum, "~> 1.4"},
      {:ecto_sql, "~> 3.12"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_crypto, "~> 0.10.0"},
      {:ex_doc, "~> 0.37.3", only: :dev, runtime: false},
      {:mox, "~> 1.2", only: :test},
      {:oban, "~> 2.19"},
      {:parent, "~> 0.12.1"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:phoenix, "~> 1.7"},
      {:plug_cowboy, "~> 2.7"},
      {:provider, github: "VeryBigThings/provider"},
      {:sentry, "~> 10.8"},
      {:stream_data, "~> 1.1.3", only: [:test, :dev]}
    ]
  end

  defp aliases do
    [
      credo: ~w/compile credo/,
      "ecto.reset": ~w/ecto.drop ecto.create/,
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp preferred_cli_env do
    [
      credo: :test,
      dialyzer: :test,
      "ecto.reset": :test,
      "ecto.migrate": :test,
      "ecto.rollback": :test,
      "ecto.gen.migration": :test
    ]
  end

  defp dialyzer() do
    [
      plt_add_apps: ~w/mix eex ecto credo bamboo ex_unit phoenix_pubsub phoenix_live_view/a
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: VBT,
      groups_for_modules: [
        "GraphQL & Absinthe": ~r/VBT\.((Absinthe)|(Graphql)).*/,
        Ecto: ~r/VBT\.((Ecto)|(Repo)).*/,
        "Auth & accounts": ~r/VBT\.((Auth)|(Accounts)).*/,
        "External services": ~r/VBT\.((Aws)|(Kubernetes)).*/,
        Credo: ~r/VBT\.Credo.*/,
        "Business errors": ~r/VBT\.[^\.]*Error/
      ]
    ]
  end
end
