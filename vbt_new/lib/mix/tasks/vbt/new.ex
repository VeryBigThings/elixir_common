defmodule Mix.Tasks.Vbt.New do
  @shortdoc "Generates a new VBT project"

  @moduledoc """
  #{@shortdoc}

  ## Usage

      mix vbt.new organization_name app_name phx_new_switches

  Arguments:

    - `organization_name` - the name or abbreviation of the client company (e.g. banmed)
    - `app_name` - the name of the OTP application
    - `phx_new_switches` - all switches accepted by the `phx.new` mix task

  **Important** - provide `--no-html --no-webpack` switches if you don't need HTML views and JS files

  Example:

      mix vbt.new banmed telecare --no-html --no-webpack

  The project will be generated in the `<organization_name>_<app_name>_backend` folder (in the
  example above `banmed_telecare_backend`). You should use the same name for the GitHub repository,
  because generated GitHub Actions yaml files assume this convention.
  """

  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Mix.Task
  alias Mix.Vbt.{MixFile, SourceFile}

  def run(args) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    opts = parse_opts!(args)

    project_folder = Path.join([opts.parent_folder, "#{opts.organization}_#{opts.app}_backend"])
    if File.exists?(project_folder), do: Mix.raise("folder already exists")

    Mix.Task.run("archive.install", ["hex", "phx_new", "~> 1.5.3", "--force"])

    current_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    try do
      # We'll respond to "fetch deps?" question by phx.new with no.
      # We won't fetch deps now, because after bootstrapper adds its own changes, deps need to
      # be refetched again, and fetching deps before that happens leads to a dep conflict.
      send(self(), {:mix_shell_input, :yes?, false})

      Mix.Task.run(
        "phx.new",
        ~w/#{project_folder} --app #{opts.app}/ ++ Enum.drop(args, 2)
      )
    after
      Mix.shell(current_shell)
    end

    add_vbt_dep(project_folder)
    bootstrap_project(opts, project_folder)

    Mix.shell().info("""

    The project has been bootstrapped 🎉

    Switch to `#{project_folder}`, invoke `asdf install` and `mix deps.get`.
    If you didn't provide the `--no-webpack` option, you also need to install
    npm dependencies with `pushd assets && npm install && popd`.
    """)
  end

  defp parse_opts!(args) do
    {_known_switches, args, _unknown_switches} =
      OptionParser.parse(args, strict: [organization: :string])

    case args do
      [organization, target] ->
        %{
          organization: organization,
          app: Path.basename(target),
          parent_folder: Path.dirname(target)
        }

      _other ->
        Mix.raise("usage: mix vbt.new organization_name app_name switches")
    end
  end

  vbt_dep =
    case Mix.env() do
      :prod -> ~s(git: "git@github.com:VeryBigThings/elixir_common_private")
      :test -> ~s(path: "../../../..")
      :dev -> ~s(path: "#{File.cwd!()}")
    end

  defp add_vbt_dep(project_folder) do
    Path.join(project_folder, "mix.exs")
    |> SourceFile.load!()
    |> MixFile.append_config("deps", "{:vbt, #{unquote(vbt_dep)}}")
    |> SourceFile.store!()
  end

  defp bootstrap_project(opts, project_folder) do
    project = Mix.Project.pop()

    try do
      Mix.Project.in_project(String.to_atom(opts.app), project_folder, [], fn _module ->
        Mix.Task.run("vbt.bootstrap", ~w/#{opts.organization} --force/)
      end)
    after
      with %{name: name, file: file} <- project, do: Mix.Project.push(name, file)
    end
  end
end
