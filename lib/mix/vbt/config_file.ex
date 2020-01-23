defmodule Mix.Vbt.ConfigFile do
  @moduledoc false
  alias Mix.Vbt
  alias Mix.Vbt.SourceFile

  @type updater_fun :: (Keyword.t() -> Keyword.t())

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
    do: update_kw_config(file, Vbt.endpoint_module(), updater)

  @spec update_repo_config(SourceFile.t(), updater_fun) :: SourceFile.t()
  def update_repo_config(file, updater),
    do: update_kw_config(file, Vbt.repo_module(), updater)

  @spec update_config(SourceFile.t(), atom, updater_fun) :: SourceFile.t()
  def update_config(file, app \\ Vbt.otp_app(), updater) do
    do_update_config(
      file,
      updater,
      ~r/(\n\s*config\s+#{inspect(app)},\n)(?<opts>.*?)(?=\n\n)/s
    )
  end

  defp update_kw_config(file, key, updater) do
    # match `config :my_app, SomeKey,` (i.e. the part up until and including the comma character
    # and the remaining whitespaces)
    config_start_regex = ~r/(\n\s*config\s+#{inspect(Vbt.otp_app())},\s+#{inspect(key)},\s*?)/

    # config opts are all characters up until (but excluding) two newline characters
    config_opts_regex = ~r/(?<opts>[^\s].*?)(?=\n\n)/

    do_update_config(
      file,
      updater,
      ~r/#{Regex.source(config_start_regex)}#{Regex.source(config_opts_regex)}/s
    )
  end

  defp do_update_config(file, updater, regex),
    do: update_in(file.content, &replace(&1, updater, regex))

  defp replace(content, updater, regex) do
    # Recursive replacing of the content according to the regex.
    # Normally we could use String.replace for this, but this won't work in the cases where
    # there are multiple config entries for the same key. This code performs iterative
    # replaces of all matched occurences in the given content.
    case Regex.named_captures(regex, content, return: :index) do
      nil ->
        content

      %{"opts" => {from, len}} ->
        {prefix, suffix} = String.split_at(content, from + len)
        {prefix, opts} = String.split_at(prefix, from)

        {opts, _} = Code.eval_string("[#{opts}]")

        updated_opts = updater.(opts)
        updated_suffix = replace(suffix, updater, regex)

        if opts == updated_opts and suffix == updated_suffix do
          # Small optimization to avoid changing the content if nothing has changed.
          # Without this, we might end up making some minor changes which are semantically
          # equivalent, but visually different (e.g. replacing ~w// with [...]).
          content
        else
          updated_opts =
            updated_opts
            |> inspect(limit: :infinity)
            |> String.replace(~r/^\[/, "")
            |> String.replace(~r/\]$/, "")

          prefix <> updated_opts <> updated_suffix
        end
    end
  end
end
