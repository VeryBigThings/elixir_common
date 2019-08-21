defmodule VbtCredo.MixProject do
  use Mix.Project

  def project do
    [
      app: :vbt_credo,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:dialyxir, "~> 0.5", runtime: false, only: [:dev, :test]}
    ]
  end
end
