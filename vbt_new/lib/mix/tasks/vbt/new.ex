defmodule Mix.Tasks.Vbt.New do
  @shortdoc "Generates a new VBT project"

  @moduledoc """
  #{@shortdoc}

  The task internally invokes `phx.new`, and therefore accepts the same options. However, you must
  provide the project folder as the first argument to this task, before other switches.
  """

  use Mix.Task
  alias Mix.Vbt.{MixFile, SourceFile}

  def run(args) do
    Mix.Task.run("archive.install", ["hex", "phx_new", "~> 1.4", "--force"])
    Mix.Task.run("phx.new", args)

    project_folder = project_folder!(args)
    add_vbt_dep(project_folder)
    bootstrap_project(project_folder)
  end

  defp project_folder!(args) do
    {_known_switches, args, _unknown_switches} = OptionParser.parse(args, strict: [])

    case args do
      [project_folder] -> project_folder
      _other -> Mix.raise("usage: mix vbt.new project_folder switches")
    end
  end

  defp add_vbt_dep(project_folder) do
    vbt_dep =
      case Mix.env() do
        :prod -> ~s(git: "git@github.com:VeryBigThings/elixir_common_private")
        :test -> ~s(path: "../../..")
        :dev -> ~s(path: "#{File.cwd!()}")
      end

    Path.join(project_folder, "mix.exs")
    |> SourceFile.load!()
    |> MixFile.append_config("deps", "{:vbt, #{vbt_dep}}")
    |> SourceFile.store!()
  end

  defp bootstrap_project(project_folder) do
    %{name: name, file: file} = Mix.Project.pop()

    try do
      app = project_folder |> Path.basename() |> String.to_atom()

      Mix.Project.in_project(app, project_folder, [], fn _module ->
        with :ok <- Mix.Task.run("deps.get"),
             do: Mix.Task.run("vbt.bootstrap", ~w/--force/)
      end)
    after
      Mix.Project.push(name, file)
    end
  end
end
