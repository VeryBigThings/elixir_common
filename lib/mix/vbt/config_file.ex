defmodule Mix.Vbt.ConfigFile do
  @moduledoc false
  alias Mix.Vbt.SourceFile

  @type updater_fun :: (Keyword.t() -> Keyword.t())

  @spec endpoint_module :: module
  def endpoint_module, do: Module.concat(Macro.camelize("#{app()}_web"), Endpoint)

  @spec repo_module :: module
  def repo_module, do: Module.concat(Macro.camelize("#{app()}"), Repo)

  @spec app :: atom
  def app, do: Keyword.fetch!(Mix.Project.config(), :app)

  @spec add_new_config(SourceFile.t(), String.t()) :: SourceFile.t()
  def add_new_config(file, code) do
    update_in(
      file.content,
      &String.replace(&1, ~r/\n(?=# Configures Elixir's Logger)/s, "\n#{code}\n")
    )
  end

  @spec update_endpoint_config(SourceFile.t(), updater_fun) :: SourceFile.t()
  def update_endpoint_config(file, updater),
    do: update_kw_config(file, endpoint_module(), updater)

  @spec update_repo_config(SourceFile.t(), updater_fun) :: SourceFile.t()
  def update_repo_config(file, updater), do: update_kw_config(file, repo_module(), updater)

  @spec update_config(SourceFile.t(), atom, updater_fun) :: SourceFile.t()
  def update_config(file, app \\ app(), updater) do
    do_update_config(
      file,
      updater,
      ~r/(\n\s*config\s+#{inspect(app)},\n)(?<opts>.*?)(?=\n\n)/s
    )
  end

  defp update_kw_config(file, key, updater) do
    do_update_config(
      file,
      updater,
      ~r/(\n\s*config\s+#{inspect(app())},\s+#{inspect(key)},\s*?)(?<opts>[^\s].*?)(?=\n\n)/s
    )
  end

  defp do_update_config(file, updater, regex) do
    %{"opts" => opts} = Regex.named_captures(regex, file.content)
    {opts, _} = Code.eval_string("[#{opts}]")

    opts =
      updater.(opts)
      |> inspect(limit: :infinity)
      |> String.replace(~r/^\[/, "")
      |> String.replace(~r/\]$/, "")

    %{file | content: String.replace(file.content, regex, "\\1 #{opts}")}
  end
end
