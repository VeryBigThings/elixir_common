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
      {:credo, "~> 1.1", runtime: false},
      {:dialyxir, "~> 0.5", runtime: false},
      {:stream_data, "~> 0.4", only: [:test, :dev]},
      {:ecto, "~> 3.0", optional: true},
      {:absinthe, "~> 1.4", optional: true}
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
      plt_add_apps: [:mix, :eex, :ecto, :absinthe, :credo]
    ]
  end
end
