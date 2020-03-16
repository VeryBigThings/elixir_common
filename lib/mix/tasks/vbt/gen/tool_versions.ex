defmodule Mix.Tasks.Vbt.Gen.ToolVersions do
  @shortdoc "Generate .tool-versions"
  @moduledoc "Generate .tool-versions"
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task
  require Logger

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.tool_versions can only be run inside an application directory")
    end

    tool_versions =
      for {tool, version} <- tool_versions(),
          tool != :nodejs or File.dir?("assets"),
          do: "#{tool} #{version}"

    VBT.Skafolder.generate_file([Enum.join(tool_versions, "\n"), ?\n], ".tool-versions", args)
  end

  defp tool_versions do
    versions = Mix.Vbt.tool_versions()

    %{
      elixir: "#{versions.elixir.major}.#{versions.elixir.minor}-otp-#{versions.erlang.major}",
      erlang: "#{versions.erlang.major}.#{versions.erlang.minor}",
      nodejs: to_string(versions.nodejs)
    }
  end
end
