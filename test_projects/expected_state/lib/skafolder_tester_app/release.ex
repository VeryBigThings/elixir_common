# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule SkafolderTesterApp.Release do
  @moduledoc false

  @start_apps [
    :crypto,
    :ssl,
    :postgrex,
    :ecto,
    :ecto_sql
  ]

  @app Keyword.fetch!(Mix.Project.config(), :app)

  def migrate(args \\ []) do
    start_services()
    run_migrations(args)
  after
    stop_services()
  end

  def rollback(args \\ []) do
    start_services()
    run_rollbacks(args)
  after
    stop_services()
  end

  def seed(args) do
    {opts, []} = OptionParser.parse!(args, strict: [file: :string])
    start_services()
    run_migrations()
    run_seeds(Keyword.get(opts, :file, "seeds.exs"))
  after
    stop_services()
  end

  defp start_services do
    IO.puts("Starting dependencies..")
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    IO.puts("Starting repos..")
    :ok = Application.load(@app)
    Enum.each(repos(), & &1.start_link(pool_size: 5))
  end

  defp stop_services do
    IO.puts("Stopping...")
    System.stop()
  end

  defp run_migrations(args \\ []) do
    Enum.each(repos(), fn repo ->
      app = Keyword.get(repo.config(), :otp_app)
      IO.puts("Running migrations for #{app}")
      run_migrations_based_on_args(repo, :up, args)
    end)
  end

  defp run_rollbacks(args) do
    Enum.each(repos(), fn repo ->
      app = Keyword.get(repo.config(), :otp_app)
      IO.puts("Running rollback for #{app}")
      run_migrations_based_on_args(repo, :down, args)
    end)
  end

  defp run_migrations_based_on_args(repo, direction, args) do
    case args do
      ["--step", n] -> run_migrations_for(repo, direction, step: String.to_integer(n))
      ["-n", n] -> run_migrations_for(repo, direction, step: String.to_integer(n))
      ["--to", to] -> run_migrations_for(repo, direction, to: String.to_integer(to))
      ["--all"] -> run_migrations_for(repo, direction, all: true)
      [] -> run_migrations_for(repo, direction)
    end
  end

  defp run_migrations_for(repo, :up), do: run_migrations_for(repo, :up, all: true)
  defp run_migrations_for(repo, :down), do: run_migrations_for(repo, :down, step: 1)

  defp run_migrations_for(repo, direction, opts) do
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, direction, opts)
  end

  defp run_seeds(seed_file), do: Enum.each(repos(), &run_seeds_for(&1, seed_file))

  defp run_seeds_for(repo, seed_file) do
    # Run the seed script if it exists
    seed_script = priv_path_for(repo, seed_file)

    if File.exists?(seed_script) do
      IO.puts("Running seed script #{seed_script}..")
      Code.eval_file(seed_script)
    else
      IO.puts("Seed script #{seed_script} does not exist..")
    end
  end

  defp priv_path_for(repo, filename) do
    app_dir = Application.app_dir(Keyword.fetch!(repo.config, :otp_app))

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    Path.join([app_dir, "priv", repo_underscore, filename])
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
end

