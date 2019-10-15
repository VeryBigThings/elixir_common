defmodule VBT.Credo.MixProject do
  use Mix.Project

  def project do
    [
      app: :vbt,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: preferred_cli_env(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.1"},
      {:dialyxir, "~> 0.5", runtime: false, only: [:dev, :test]},
      {:stream_data, "~> 0.4", only: [:test, :dev]}
    ]
  end

  defp aliases do
    [
      credo: ~w/compile credo/
    ]
  end

  defp preferred_cli_env do
    [credo: :test, dialyzer: :test]
  end

  defp dialyzer() do
    [
      plt_add_apps: [:mix, :eex]
    ]
  end
end
