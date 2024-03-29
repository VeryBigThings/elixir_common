defmodule VbtNew.MixProject do
  use Mix.Project

  def project do
    [
      app: :vbt_new,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: preferred_cli_env(),
      dialyzer: dialyzer(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets]
    ]
  end

  defp deps do
    [
      {:vbt, path: "..", only: [:dev, :test], runtime: false}
    ]
  end

  defp preferred_cli_env do
    [
      credo: :test,
      dialyzer: :test,
      "archive.build": :prod
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: ~w/mix eex inets ssl/a
    ]
  end

  defp aliases do
    [
      "archive.build": ["compile", "archive.build --include-dot-files"]
    ]
  end
end
