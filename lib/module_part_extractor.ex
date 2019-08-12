defmodule VbtCredo.ModulePartExtractor do
  @moduledoc "Extraction of module parts from an ast"

  @type module_part :: :moduledoc | :behaviour
  @type location :: [line: pos_integer, column: pos_integer]

  @doc """
  Extracts modules and their parts from the AST obtained from an Elixir source file.

  iex> {:ok, ast} = Code.string_to_quoted(~s(
  ...>   defmodule SomeModule do
  ...>     @moduledoc "Some module doc"
  ...>
  ...>     @behaviour GenServer
  ...>
  ...>     use GenServer
  ...>
  ...>     import GenServer
  ...>
  ...>     alias GenServer
  ...>     alias Mod1.{Mod2, Mod3}
  ...>   end
  ...>
  ...>   defmodule AnotherModule do
  ...>     @moduledoc "Another module doc"
  ...>   end
  ...> ))
  iex> VbtCredo.ModulePartExtractor.analyze(ast)
  [
    {SomeModule, [
      moduledoc: [line: 3],
      behaviour: [line: 5],
      use: [line: 7],
      import: [line: 9],
      alias: [line: 11],
      alias: [line: 12]
    ]},
    {AnotherModule, [moduledoc: [line: 16]]}
  ]
  """
  @spec analyze(Macro.t()) :: [{module, [{module_part, location}]}]
  def analyze(ast) do
    {_ast, state} = Macro.prewalk(ast, initial_state(), &traverse/2)
    module_parts(state)
  end

  defp traverse(ast, state) do
    state = analyze(state, ast)
    {ast, state}
  end

  # Part extractors

  defp analyze(state, {:defmodule, meta, args}) do
    [{:__aliases__, _, name_parts} | _] = args
    start_module(state, Module.concat(name_parts), meta)
  end

  defp analyze(state, {:@, meta, [{:moduledoc, _, _}]}),
    do: add_module_element(state, :moduledoc, meta)

  defp analyze(state, {:@, meta, [{:behaviour, _, _}]}),
    do: add_module_element(state, :behaviour, meta)

  defp analyze(state, {:use, meta, _}),
    do: add_module_element(state, :use, meta)

  defp analyze(state, {:import, meta, _}),
    do: add_module_element(state, :import, meta)

  defp analyze(state, {:alias, meta, _}),
    do: add_module_element(state, :alias, meta)

  defp analyze(state, _ast), do: state

  # Internal state

  defp initial_state(), do: %{modules: %{}, current_module: nil}

  defp module_parts(state) do
    state.modules
    |> Enum.sort_by(fn {_name, module} -> module.location end)
    |> Enum.map(fn {name, module} -> {name, Enum.reverse(module.parts)} end)
  end

  defp start_module(state, module, meta) do
    state = %{state | current_module: module}
    put_in(state.modules[module], %{parts: [], location: Keyword.take(meta, ~w/line column/a)})
  end

  defp add_module_element(state, element, meta) do
    location = Keyword.take(meta, ~w/line column/a)
    update_in(state.modules[state.current_module].parts, &[{element, location} | &1])
  end
end
