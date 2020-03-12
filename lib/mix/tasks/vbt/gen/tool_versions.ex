defmodule Mix.Tasks.Vbt.Gen.ToolVersions do
  @shortdoc "Generate .tool-versions"
  @moduledoc "Generate .tool-versions"
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.tool_versions can only be run inside an application directory")
    end

    tools =
      Enum.concat(
        [
          "elixir 1.10-otp-22",
          "erlang 22.2"
        ],
        if(File.dir?("assets"), do: ["nodejs 12.14.1"], else: [])
      )

    VBT.Skafolder.generate_file([Enum.join(tools, "\n"), ?\n], ".tool-versions", args)
  end
end
