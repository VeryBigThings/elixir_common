defmodule VBT.Integration.SkafolderTest do
  use ExUnit.Case, async: true
  @moduletag :integration

  setup_all do
    mix!(~w/deps.get/)
    mix!(~w/compile/)
    :ok
  end

  setup do
    Enum.each(expected_files(), &File.rm/1)
    :ok
  end

  test "vbt.bootstrap generates expected files" do
    current_files = all_project_files()
    assert {_output, 0} = mix(~w/vbt.bootstrap/)

    new_files = MapSet.difference(all_project_files(), current_files)
    assert new_files == expected_files()
  end

  defp all_project_files do
    Path.join(project_path(), "**")
    |> Path.wildcard(match_dot: true)
    |> Stream.reject(&File.dir?/1)
    |> MapSet.new()
  end

  defp expected_files do
    Enum.into(
      ~w[
        .dockerignore
        .circleci/config.yml
        .env.development
        Dockerfile
        Makefile
        docker-compose.yml
        entrypoint.sh
        heroku.yml
        rel/bin/migrate.sh
        rel/bin/rollback.sh
        rel/bin/seed.sh
        .credo.exs
        .github/pull_request_template.md
        dialyzer.ignore-warnings
      ],
      MapSet.new(),
      &Path.join(project_path(), &1)
    )
  end

  defp mix!(args) do
    {output, 0} = mix(args)
    output
  end

  defp mix(args), do: System.cmd("mix", args, stderr_to_stdout: true, cd: project_path())

  defp project_path, do: Path.join(~w/test_projects skafolder_tester/)
end
