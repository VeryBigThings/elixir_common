defmodule VBT.Credo.Check.Consistency.FileLocation do
  @moduledoc false

  @checkdoc """
  File location should follow the namespace hierarchy of the module it defines.

  Examples:

      - `lib/my_system.ex` should define the `MySystem` module
      - `lib/my_system/accounts.ex` should define the `MySystem.Accounts` module
  """
  @explanation [warning: @checkdoc]

  # `use Credo.Check` required that module attributes are already defined, so we need to place these attributes
  # before use/alias expressions.
  # credo:disable-for-next-line VBT.Credo.Check.Consistency.ModuleLayout
  use Credo.Check, category: :warning, base_priority: :high

  alias Credo.Code

  def run(source_file, params \\ []) do
    case verify(source_file, params) do
      :ok ->
        []

      {:error, module, expected_file} ->
        error(IssueMeta.for(source_file, params), module, expected_file)
    end
  end

  defp verify(source_file, params) do
    source_file.filename
    |> Path.relative_to_cwd()
    |> verify(Code.ast(source_file), params)
  end

  @doc false
  def verify(relative_path, ast, params) do
    if verify_path?(relative_path),
      do: ast |> main_module() |> verify_module(relative_path, params),
      else: :ok
  end

  defp verify_path?(relative_path) do
    case Path.split(relative_path) do
      ["lib" | _] -> true
      ["test", "support" | _] -> false
      ["test", "test_helper.exs"] -> false
      ["test" | _] -> true
      _ -> false
    end
  end

  defp main_module(ast) do
    {_ast, modules} = Macro.prewalk(ast, [], &traverse/2)
    Enum.at(modules, -1)
  end

  defp traverse({:defmodule, _meta, args}, modules) do
    [{:__aliases__, _, name_parts}, _module_body] = args
    {args, [Module.concat(name_parts) | modules]}
  end

  defp traverse(ast, state), do: {ast, state}

  # empty file - shouldn't really happen, but we'll let it through
  defp verify_module(nil, _relative_path, _params), do: :ok

  defp verify_module(main_module, relative_path, params) do
    parsed_path = parsed_path(relative_path, params)

    expected_file =
      expected_file_base(parsed_path.root, main_module) <>
        Path.extname(parsed_path.allowed)

    if expected_file == parsed_path.allowed,
      do: :ok,
      else: {:error, main_module, expected_file}
  end

  defp parsed_path(relative_path, params) do
    parts = Path.split(relative_path)

    allowed =
      Keyword.get(params, :ignore_folder_namespace, %{})
      |> Stream.flat_map(fn {root, folders} -> Enum.map(folders, &Path.join([root, &1])) end)
      |> Stream.map(&Path.split/1)
      |> Enum.find(&List.starts_with?(parts, &1))
      |> case do
        nil ->
          relative_path

        ignore_parts ->
          Stream.drop(ignore_parts, -1)
          |> Enum.concat(Stream.drop(parts, length(ignore_parts)))
          |> Path.join()
      end

    %{root: hd(parts), allowed: allowed}
  end

  defp expected_file_base(root_folder, module) do
    {parent_namespace, module_name} = module |> Module.split() |> Enum.split(-1)

    relative_path =
      if parent_namespace == [],
        do: "",
        else: parent_namespace |> Module.concat() |> Macro.underscore()

    file_name = module_name |> Module.concat() |> Macro.underscore()

    Path.join([root_folder, relative_path, file_name])
  end

  defp error(issue_meta, module, expected_file) do
    format_issue(issue_meta,
      message:
        "Mismatch between file name and main module #{inspect(module)}. " <>
          "Expected file path to be #{expected_file}. " <>
          "Either move the file or rename the module.",
      line_no: 1
    )
  end
end
