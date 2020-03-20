defmodule Mix.Tasks.Vbt.Gen.FormatterConfig do
  @shortdoc "Generate .formatter.exs"
  @moduledoc "Generate .formatter.exs"
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.formatter_config can only be run inside an application directory")
    end

    Mix.Vbt.generate_file(
      """
      [
        import_deps: [:absinthe, :ecto, :ecto_enum, :ecto_sql, :phoenix],
        inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
        subdirectories: ["priv/*/migrations"]
      ]
      """,
      ".formatter.exs",
      args
    )
  end
end
