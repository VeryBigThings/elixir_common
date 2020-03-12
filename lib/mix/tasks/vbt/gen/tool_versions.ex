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
    # We'll try to figure out the latest supported versions by examining the content of
    # VeryBigThings/dockerfiles and official Elixir/Erlang repositories on GitHub. If that fails,
    # we'll return the latest hard-coded defaults. This is a "best effort" approach which may fail
    # occasionally, but in that case a developer will be warned and they can adjust the
    # `.tool_versions` content manually.
    Application.ensure_all_started(:hackney)
    get_latest_versions!()
  catch
    _, _ ->
      Logger.warn("""

      Error fetching latest tool versions, using default versions instead.

      Check your .tool-versions file and compare it with Dockerfile of the latest
      Elixir version at https://github.com/VeryBigThings/dockerfiles/tree/master/elixir
      """)

      [
        elixir: "1.10-otp-22",
        erlang: "22.2",
        nodejs: "12.14.1"
      ]
  end

  defp get_latest_versions! do
    elixir = elixir_version()
    {erlang_major, erlang_major_minor} = erlang_version(elixir)
    nodejs = nodejs_version(elixir)

    [
      elixir: "#{elixir}-otp-#{erlang_major}",
      erlang: erlang_major_minor,
      nodejs: nodejs
    ]
  end

  defp elixir_version do
    %HTTPoison.Response{status_code: 200, body: body} =
      HTTPoison.get!("https://api.github.com/repos/verybigthings/dockerfiles/contents/elixir")

    body
    |> Jason.decode!()
    |> Enum.map(&Map.fetch!(&1, "name"))
    |> Enum.sort_by(
      &(&1
        |> String.split(".")
        |> Enum.map(fn part -> String.to_integer(part) end)),
      :desc
    )
    |> hd()
  end

  defp erlang_version(elixir_version) do
    %{"major" => major} =
      Regex.named_captures(
        ~r/FROM\s+erlang:(?<major>\d+)/,
        dockerfile("c0b/docker-elixir", elixir_version)
      )

    %{"full" => full} =
      Regex.named_captures(
        ~r/OTP_VERSION="(?<full>\d+\.\d+\.\d+)"/,
        dockerfile("erlang/docker-erlang-otp", major)
      )

    major_minor =
      full
      |> String.split(".")
      |> Stream.take(2)
      |> Enum.join(".")

    {major, major_minor}
  end

  defp nodejs_version(elixir_version) do
    %{"nodejs_version" => nodejs_version} =
      Regex.named_captures(
        ~r/NODE_VERSION\s+(?<nodejs_version>\d+\.\d+\.\d+)/,
        dockerfile("VeryBigThings/dockerfiles", "elixir/#{elixir_version}")
      )

    nodejs_version
  end

  defp dockerfile(repo, path) do
    %HTTPoison.Response{status_code: 200, body: dockerfile} =
      HTTPoison.get!("https://raw.githubusercontent.com/#{repo}/master/#{path}/Dockerfile")

    dockerfile
  end
end
