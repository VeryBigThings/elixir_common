defmodule VBT.Credo.Check.Consistency.FileLocationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias VBT.Credo.Check.Consistency.FileLocation

  property "doesn't report errors for valid file" do
    check all file <- valid_file() do
      assert verify(file) == :ok
    end
  end

  property "reports errors for invalid file" do
    check all file <- invalid_file() do
      assert {:error, top_module, expected_file} = verify(file)
    end
  end

  test "ignores folder namespace" do
    assert verify(
             %{
               name: "lib/app_web/views/my_view.ex",
               expected_module: AppWeb.MyView,
               modules: [AppWeb.MyView]
             },
             ignore_folder_namespace: %{"lib/app_web" => ["views"]}
           ) == :ok
  end

  test "ignores excluded folders" do
    assert verify(
             %{
               name: "lib/app_web/views/my_view.ex",
               expected_module: AppWeb.MyView,
               modules: [AppWeb.MyView]
             },
             exclude: ["lib/app_web"]
           ) == :ok
  end

  defp verify(file, params \\ []), do: FileLocation.verify(file.name, ast(file), params)

  defp ast(file) do
    Enum.map(
      file.modules,
      &{:defmodule, [], [{:__aliases__, [], [&1]}, [do: {:__block__, [], []}]]}
    )
  end

  defp invalid_file do
    gen all file <- valid_file(),
            match?([_, _ | _], file.modules) do
      modules = file.modules -- [file.expected_module]
      name = ensure_valid_root(file.name)
      %{file | modules: modules, name: name}
    end
  end

  defp ensure_valid_root("test/support" <> rest), do: "test/#{rest}"
  defp ensure_valid_root("lib/" <> _ = name), do: name
  defp ensure_valid_root("test/" <> _ = name), do: name
  defp ensure_valid_root(name), do: "lib/#{name}"

  defp valid_file do
    gen all root_folder <- root_folder(),
            folder <- folder(),
            name <- path_element(),
            expected_module <- expected_module(folder, name),
            modules <- modules(expected_module) do
      %{
        name: Path.join(root_folder, "#{folder}/#{name}.#{extension(root_folder)}"),
        expected_module: expected_module,
        modules: modules
      }
    end
  end

  defp extension("test"), do: "exs"
  defp extension(_), do: "ex"

  defp modules(expected_module) do
    gen all additional_modules <- list_of(atom(:alias), max_length: 5),
            do: Enum.uniq([expected_module | additional_modules])
  end

  defp expected_module(folder, name) do
    [folder, name]
    |> Enum.reject(&(&1 == ""))
    |> Path.join()
    |> Path.split()
    |> Enum.map(&module_part(&1))
    |> fixed_list()
    |> map(&Module.concat/1)
  end

  defp module_part(part) do
    gen all capitalize? <- boolean() do
      part
      |> String.split("_")
      |> Stream.with_index()
      |> Enum.map(fn {part, index} -> camelize(part, capitalize? and rem(index, 2) == 0) end)
      |> Enum.join()
      |> String.to_atom()
    end
  end

  defp camelize(part, false), do: Macro.camelize(part)
  defp camelize(part, true), do: Macro.camelize(String.upcase(part))

  defp root_folder do
    one_of([
      filter(folder(), &(&1 != ""))
      | Enum.map(~w[lib test test/support], &constant/1)
    ])
  end

  defp folder do
    gen all elements <- list_of(path_element(), max_length: 5) do
      if elements != [],
        do: Path.join(elements),
        else: ""
    end
  end

  defp path_element do
    gen all part <-
              list_of(string([?a..?z], min_length: 2, max_length: 10),
                min_length: 1,
                max_length: 5
              ),
            do: Enum.join(part, "_")
  end
end
