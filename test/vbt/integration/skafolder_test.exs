defmodule VBT.Integration.SkafolderTest do
  use ExUnit.Case, async: true
  require Bitwise

  @moduletag :integration

  @tag timeout: :timer.minutes(3)
  test "vbt.bootstrap" do
    initialize_project()

    # hardcoding the generated secret key to ensure reproducible output
    System.put_env("SECRET_KEY_BASE", "test_only_secret_key_base")
    assert {_output, 0} = mix(~w/vbt.bootstrap --force/)

    # fetch new deps injected by bootstrap
    assert {_output, 0} = mix(~w/deps.get/)

    # make sure that the project can be compiled after the changes have been applied
    assert {_output, 0} = mix(~w/compile --warnings-as-errors/)

    with {:error, differences} <- differences() do
      if System.get_env("SYNC_BOOTSTRAP_TEST", "false") != "true" do
        flunk(error_message(differences))
      else
        sync_differences(differences)

        flunk("""
        Differences have been synchronized.
        Please rerun the test again without the SYNC_BOOTSTRAP_TEST env set.
        """)
      end
    end
  end

  defp initialize_project do
    File.mkdir_p!(build_path())
    File.rm_rf(Path.join([build_path(), "lib"]))
    File.cp_r!(source_path(), build_path())
    mix!(~w/deps.get/)
    mix!(~w/compile/)
  end

  defp differences do
    output_files = MapSet.new(source_files(build_path()))
    expected_files = MapSet.new(source_files(expected_path()))

    missing = Enum.sort(MapSet.difference(expected_files, output_files))
    unexpected = Enum.sort(MapSet.difference(output_files, expected_files))

    changed =
      expected_files
      |> MapSet.intersection(output_files)
      |> Stream.filter(fn file ->
        output_path = Path.join(build_path(), file)
        output_content = File.read!(output_path)

        expected_path = Path.join(expected_path(), file)
        expected_content = File.read!(expected_path)

        output_content != expected_content or not same_mode?(output_path, expected_path)
      end)
      |> Enum.sort()

    if Enum.all?([missing, unexpected, changed], &Enum.empty?/1),
      do: :ok,
      else: {:error, %{missing: missing, unexpected: unexpected, changed: changed}}
  end

  defp same_mode?(file1, file2) do
    # we're testing only `x` bit of the owner since that's the only bit that git tracks
    # (see https://medium.com/@tahteche/how-git-treats-changes-in-file-permissions-f71874ca239d)
    Bitwise.band(File.stat!(file1).mode, 0b1_000_000) ==
      Bitwise.band(File.stat!(file2).mode, 0b1_000_000)
  end

  defp source_files(folder) do
    Path.wildcard("#{folder}/**", match_dot: true)
    |> Stream.reject(&String.starts_with?(&1, "#{folder}/_build"))
    |> Stream.reject(&String.starts_with?(&1, "#{folder}/deps"))
    |> Stream.reject(&File.dir?/1)
    |> Stream.map(&Path.relative_to(&1, folder))
    # ignoring mix.lock, because its shape can change non-deterministically
    |> Stream.reject(&(&1 == "mix.lock"))
    |> Enum.sort()
  end

  defp error_message(differences) do
    error_list =
      Enum.concat([
        Enum.map(differences.missing, &"  - #{&1} is missing"),
        Enum.map(differences.unexpected, &"  - #{&1} is unexpected"),
        Enum.map(differences.changed, &"  - #{&1} is changed")
      ])
      |> Enum.sort()
      |> Enum.join("\n")

    flunk("""
    Bootstrapped project doesn't have the expected shape:

    #{error_list}

    To automatically sync the expected folder, rerun the test as:

        SYNC_BOOTSTRAP_TEST=true mix test ...
    """)
  end

  defp sync_differences(differences) do
    Enum.each(differences.missing, &File.rm!(Path.join(expected_path(), &1)))

    differences.unexpected
    |> Stream.concat(differences.changed)
    |> Enum.each(&copy_to_expected/1)
  end

  defp copy_to_expected(file) do
    source = Path.join(build_path(), file)
    destination = Path.join(expected_path(), file)
    File.mkdir_p!(Path.dirname(destination))
    File.cp!(source, destination)
  end

  defp mix!(args) do
    {output, 0} = mix(args)
    output
  end

  defp mix(args), do: System.cmd("mix", args, stderr_to_stdout: true, cd: build_path())

  defp source_path, do: Path.join(~w/test_projects skafolder_tester/)
  defp build_path, do: Path.join(~w/tmp skafolder_tester/)
  defp expected_path, do: Path.join(~w/test_projects expected_state/)
end
