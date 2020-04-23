defmodule Mix.Tasks.Vbt.New do
  @shortdoc "Generates a new VBT project"

  @moduledoc """
  #{@shortdoc}

  The task internally invokes `phx.new`, and therefore accepts the same options. However, you must
  provide the project folder as the first argument to this task, before other switches.
  """

  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Mix.Task
  alias Mix.Vbt.{MixFile, SourceFile}

  def run(args) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    project_folder = project_folder!(args)
    if File.exists?(project_folder), do: Mix.raise("folder already exists")

    Mix.Task.run("archive.install", ["hex", "phx_new", "~> 1.4.0", "--force"])

    current_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    try do
      # We'll respond to "fetch deps?" question by phx.new with no.
      # We won't fetch deps now, because after bootstrapper adds its own changes, deps need to
      # be refetched again, and fetching deps before that happens leads to a dep conflict.
      send(self(), {:mix_shell_input, :yes?, false})

      Mix.Task.run("phx.new", args)
    after
      Mix.shell(current_shell)
    end

    add_vbt_dep(project_folder)
    bootstrap_project(project_folder)

    Mix.shell().info("""

    The project has been bootstrapped 🎉

    Switch to `#{project_folder}`, invoke `asdf install` and `mix deps.get`.
    If you didn't provide the `--no-webpack` option, you also need to install
    npm dependencies with `pushd assets && npm install && popd`.
    """)
  end

  defp project_folder!(args) do
    {_known_switches, args, _unknown_switches} = OptionParser.parse(args, strict: [])

    case args do
      [project_folder] -> project_folder
      _other -> Mix.raise("usage: mix vbt.new project_folder switches")
    end
  end

  vbt_dep =
    case Mix.env() do
      :prod -> ~s(git: "git@github.com:VeryBigThings/elixir_common_private")
      :test -> ~s(path: "../../..")
      :dev -> ~s(path: "#{File.cwd!()}")
    end

  defp add_vbt_dep(project_folder) do
    Path.join(project_folder, "mix.exs")
    |> SourceFile.load!()
    |> MixFile.append_config("deps", "{:vbt, #{unquote(vbt_dep)}}")
    |> SourceFile.store!()
  end

  defp bootstrap_project(project_folder) do
    project = Mix.Project.pop()

    try do
      app = project_folder |> Path.basename() |> String.to_atom()

      Mix.Project.in_project(app, project_folder, [], fn _module ->
        Mix.Task.run("vbt.bootstrap", ~w/--force/)
      end)
    after
      with %{name: name, file: file} <- project, do: Mix.Project.push(name, file)
    end
  end
end
