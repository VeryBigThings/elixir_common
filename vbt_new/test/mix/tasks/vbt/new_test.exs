defmodule Mix.Tasks.Vbt.NewTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Vbt.New

  @tag timeout: :timer.minutes(3)
  test "mix.vbt.new" do
    # hardcoding the generated secret key to ensure reproducible output
    System.put_env("SECRET_KEY_BASE", "test_only_secret_key_base")

    output = bootstrap_project()
    refute output.error =~ "Error fetching latest tool versions"

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

    case System.cmd("mix", ["do", "deps.get,", "compile,", "credo", "--strict"],
           cd: build_path(),
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {output, _error} -> flunk("Error running standard checks. Output:\n\n#{output}")
    end
  end

  defp bootstrap_project do
    instrument_mix_shell(fn ->
      # Response to fetch deps question by phx.new. We won't fetch deps immediately, since this is
      # done automatically by the `vbt.new` task.
      send(self(), {:mix_shell_input, :yes?, false})

      # Naive caching: if the folder already exists, we'll rename it into a temp folder, and
      # once the test project is bootstrapped, we'll copy over the existing _build and deps
      if File.exists?(build_path()) do
        File.rm_rf(tmp_path())
        File.rename!(build_path(), tmp_path())
      end

      # capturing stderr to suppress mix warning when this project's mix module is reloaded
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        New.run(~w/#{build_path()} --no-html --no-webpack/)
      end)

      # Naive caching continued: copy deps & _build from the previous build
      if File.exists?(tmp_path()) do
        Enum.each(
          ~w/deps _build/,
          &File.cp_r(Path.join(tmp_path(), &1), Path.join(build_path(), &1))
        )

        File.rm_rf(tmp_path())
      end
    end)
  end

  defp instrument_mix_shell(fun) do
    current_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    try do
      fun.()

      # collect output messages
      Stream.repeatedly(fn ->
        receive do
          {:mix_shell, :info, msg} -> {:info, msg}
          {:mix_shell, :error, msg} -> {:error, msg}
        after
          0 -> nil
        end
      end)
      |> Stream.take_while(&(not is_nil(&1)))
      |> Enum.group_by(fn {type, _msg} -> type end, fn {_type, msg} -> msg end)
      |> Enum.into(%{info: "", error: ""}, fn {key, messages} -> {key, to_string(messages)} end)
    after
      Mix.shell(current_shell)
    end
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
        output_content = normalize_content(File.read!(output_path))

        expected_path = Path.join(expected_path(), file)
        expected_content = normalize_content(File.read!(expected_path))

        output_content != expected_content or not same_mode?(output_path, expected_path)
      end)
      |> Enum.sort()

    if Enum.all?([missing, unexpected, changed], &Enum.empty?/1),
      do: :ok,
      else: {:error, %{missing: missing, unexpected: unexpected, changed: changed}}
  end

  defp normalize_content(content) do
    # removes `signing_salt: "random stuff"` to avoid false positives
    String.replace(content, ~r/signing_salt: ".*"/, "")
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
    # ignoring files whose content may change unpredictably
    |> Stream.reject(&(&1 == "mix.lock"))
    |> Stream.reject(&(&1 == ".tool_versions"))
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

  defp build_path, do: Path.join(~w/tmp skafolder_tester/)
  defp tmp_path, do: Path.join(~w/tmp skafolder_tester_tmp/)
  defp expected_path, do: Path.join(~w/test_projects expected_state/)
end
