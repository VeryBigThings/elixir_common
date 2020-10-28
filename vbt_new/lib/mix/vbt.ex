defmodule Mix.Vbt do
  @moduledoc false

  @type tool :: :elixir | :erlang | :nodejs | :postgres

  @spec otp_app :: atom
  def otp_app, do: Keyword.fetch!(Mix.Project.config(), :app)

  @spec endpoint_module :: module
  def endpoint_module, do: Module.concat(web_module_name(), Endpoint)

  @spec repo_module :: module
  def repo_module, do: Module.concat(context_module_name(), Repo)

  @spec context_module_name :: String.t()
  def context_module_name, do: Macro.camelize("#{otp_app()}")

  @spec config_module_name :: String.t()
  def config_module_name, do: "#{context_module_name()}Config"

  @spec app_module_name :: String.t()
  def app_module_name, do: "#{context_module_name()}App"

  @spec web_module_name :: String.t()
  def web_module_name, do: "#{context_module_name()}Web"

  @spec test_module_name :: String.t()
  def test_module_name, do: "#{context_module_name()}Test"

  @spec tool_versions :: %{tool => Version.t()}
  def tool_versions do
    with nil <- :persistent_term.get({__MODULE__, :tool_versions}, nil) do
      tool_versions = Map.put(compute_latest_tool_versions(), :postgres, Version.parse!("12.2.0"))
      :persistent_term.put({__MODULE__, :tool_versions}, tool_versions)
      tool_versions
    end
  end

  @spec random_string(non_neg_integer()) :: String.t()
  def random_string(length) when length > 31 do
    :crypto.strong_rand_bytes(length) |> Base.encode64() |> binary_part(0, length)
  end

  def random_string(_), do: Mix.raise("The secret should be at least 32 characters long")

  @spec bindings(Keyword.t(), Keyword.t()) :: Keyword.t()
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
    kind, payload ->
      IO.puts(Exception.format(kind, payload, __STACKTRACE__))

      Mix.shell().error("""

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
    dockerfile = most_recent_dockerfile()

    %{"elixir" => elixir_version, "erlang" => erlang_version} =
      Regex.named_captures(
        ~r/^FROM hexpm\/elixir:(?<elixir>(\d+\.)*(\d+))-erlang-(?<erlang>\d+\.\d+)-*/m,
        dockerfile
      )

    %{"node" => node_version} =
      Regex.named_captures(
        ~r/^ENV NODE_VERSION (?<node>(\d+\.)*(\d+))/m,
        dockerfile
      )

    [elixir_version, erlang_version, node_version]
    |> Stream.map(&String.split(&1, "."))
    |> Stream.map(fn
      [major] -> "#{major}.0.0"
      [major, minor] -> "#{major}.#{minor}.0"
      [major, minor, patch | _] -> "#{major}.#{minor}.#{patch}"
    end)
    |> Stream.zip(~w/elixir erlang nodejs/a)
    |> Enum.into(%{}, fn {version, label} -> {label, version} end)
  end

  defp most_recent_dockerfile do
    dockerfiles_content =
      http_get!("https://api.github.com/repos/verybigthings/dockerfiles/contents/elixir")

    # need to manually parse the json because archive can't depend on 3rd party apps
    latest_version =
      Regex.scan(~r/"name":"(.+?)"/, dockerfiles_content)
      |> Enum.map(fn [_, version] -> version end)
      |> Enum.sort_by(
        &(&1
          |> String.split(".")
          |> Enum.map(fn part -> String.to_integer(part) end)),
        :desc
      )
      |> hd()

    http_get!(
      "https://raw.githubusercontent.com/VeryBigThings/dockerfiles/master/elixir/#{latest_version}/Dockerfile"
    )
  end

  defp http_get!(url) do
    {:ok, {{_, 200, _}, _headers, response}} =
      :httpc.request(:get, {to_charlist(url), [{'User-Agent', 'vbt_new'}]}, [], [])

    to_string(response)
  end
end
