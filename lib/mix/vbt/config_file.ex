defmodule Mix.Vbt.ConfigFile do
  @moduledoc false
  alias Mix.Vbt.SourceFile

  @type updater_fun :: (Keyword.t() -> Keyword.t())

  @spec update_endpoint_config(SourceFile.t(), updater_fun) :: SourceFile.t()
  def update_endpoint_config(file, updater), do: update_config(file, endpoint_module, updater)

  defp update_config(file, app \\ app(), key, updater) do
    config_regex =
      ~r/(\n\s*config\s+#{inspect(app)},\s+#{inspect(key)},\s*?)(?<opts>[^\s].*?)(?=\n\n)/s

    %{"opts" => opts} = Regex.named_captures(config_regex, file.content)
    {opts, _} = Code.eval_string("[#{opts}]")

    opts =
      updater.(opts)
      |> inspect(limit: :infinity)
      |> String.replace(~r/^\[/, "")
      |> String.replace(~r/\]$/, "")

    %{file | content: String.replace(file.content, config_regex, "\\1 #{opts}")}
  end

  defp endpoint_module, do: Module.concat(Macro.camelize("#{app()}_web"), Endpoint)
  defp app, do: Keyword.fetch!(Mix.Project.config(), :app)
end
