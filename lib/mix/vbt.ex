defmodule Mix.Vbt do
  @moduledoc false
  require Logger

  @spec otp_app :: atom
  def otp_app, do: Keyword.fetch!(Mix.Project.config(), :app)

  @spec endpoint_module :: module
  def endpoint_module, do: Module.concat(Macro.camelize("#{otp_app()}_web"), Endpoint)

  @spec repo_module :: module
  def repo_module, do: Module.concat(context_module_name(), Repo)

  @spec context_module_name :: String.t()
  def context_module_name, do: Macro.camelize("#{otp_app()}")

  @spec app_module_name :: String.t()
  def app_module_name, do: "#{context_module_name()}App"

  @spec tool_versions :: %{tool => Version.t()} when tool: :elixir | :erlang | :nodejs
  def tool_versions do
    with nil <- :persistent_term.get({__MODULE__, :tool_versions}, nil) do
      tool_versions = compute_latest_tool_versions()
      :persistent_term.put({__MODULE__, :tool_versions}, tool_versions)
      tool_versions
    end
  end

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  def bindings(opts \\ [], defaults \\ []) do
    app = otp_app()
    additional_bindings = Keyword.merge(defaults, opts)
    Keyword.merge([app: app, base_module: base_module(app)], additional_bindings)
  end

  defp base_module(app) do
    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string |> Macro.camelize()
      mod -> inspect(mod)
    end
  end

  defp compute_latest_tool_versions do
    # We'll try to figure out the latest supported versions by examining the content of
    # VeryBigThings/dockerfiles and official Elixir/Erlang repositories on GitHub. If that fails,
    # we'll return the latest hard-coded defaults. This is a "best effort" approach which may fail
    # occasionally, but in that case a developer will be warned and they can adjust the
    # `.tool_versions` content manually.
    Application.ensure_all_started(:hackney)

    Enum.into(get_latest_versions!(), %{}, fn {key, version} -> {key, Version.parse!(version)} end)
  catch
    _, _ ->
      Logger.warn("""

      Error fetching latest tool versions, using default versions instead.

      Check your .tool-versions file and compare it with Dockerfile of the latest
      Elixir version at https://github.com/VeryBigThings/dockerfiles/tree/master/elixir
      """)

      %{
        elixir: Version.parse!("1.10.2"),
        erlang: Version.parse!("22.2.8"),
        nodejs: Version.parse!("12.14.1")
      }
  end

  defp get_latest_versions! do
    elixir_major_minor_version = elixir_major_minor_version()

    %{
      elixir: elixir_version(elixir_major_minor_version),
      erlang: erlang_version(elixir_major_minor_version),
      nodejs: nodejs_version(elixir_major_minor_version)
    }
  end

  defp elixir_major_minor_version do
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

  defp elixir_version(elixir_major_minor_version) do
    ~r/ELIXIR_VERSION=\"v(?<elixir_version>\d+\.\d+\.\d+)\"/
    |> Regex.named_captures(dockerfile("c0b/docker-elixir", elixir_major_minor_version))
    |> Map.fetch!("elixir_version")
  end

  defp erlang_version(elixir_major_minor_version) do
    erlang_major_version =
      ~r/FROM\s+erlang:(?<erlang_major_version>\d+)/
      |> Regex.named_captures(dockerfile("c0b/docker-elixir", elixir_major_minor_version))
      |> Map.fetch!("erlang_major_version")

    ~r/OTP_VERSION="(?<erlang_version>\d+\.\d+\.\d+)"/
    |> Regex.named_captures(dockerfile("erlang/docker-erlang-otp", erlang_major_version))
    |> Map.fetch!("erlang_version")
  end

  defp nodejs_version(elixir_major_minor_version) do
    ~r/NODE_VERSION\s+(?<nodejs_version>\d+\.\d+\.\d+)/
    |> Regex.named_captures(
      dockerfile("VeryBigThings/dockerfiles", "elixir/#{elixir_major_minor_version}")
    )
    |> Map.fetch!("nodejs_version")
  end

  defp dockerfile(repo, path) do
    %HTTPoison.Response{status_code: 200, body: dockerfile} =
      HTTPoison.get!("https://raw.githubusercontent.com/#{repo}/master/#{path}/Dockerfile")

    dockerfile
  end
end
