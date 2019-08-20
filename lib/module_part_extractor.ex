defmodule VbtCredo.ModulePartExtractor do
  @moduledoc "Extraction of module parts from an ast"

  @type module_part ::
          :moduledoc
          | :behaviour
          | :use
          | :import
          | :alias
          | :require
          | :module_attribute
          | :defstruct
          | :opaque
          | :type
          | :typep
          | :callback
          | :macrocallback
          | :optional_callbacks
          | :public_fun
          | :private_fun
          | :public_macro
          | :private_macro
          | :public_guard
          | :private_guard
          | :impl
  @type location :: [line: pos_integer, column: pos_integer]

  @doc """
  Extracts modules and their parts from the AST obtained from an Elixir source file.

  iex> {:ok, ast} = Code.string_to_quoted(~s/
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
  ...>
  ...>     require GenServer
  ...>
  ...>     @x 1
  ...>
  ...>     defstruct a: 1, b: 2
  ...>
  ...>     @opaque y :: pos_integer
  ...>     @type x :: pos_integer
  ...>     @typep z :: pos_integer
  ...>
  ...>     @callback callback() :: any
  ...>
  ...>     @macrocallback macrocallback() :: any
  ...>
  ...>     @optional_callbacks [callback: 0]
  ...>
  ...>     def public_fun(), do: :ok
  ...>
  ...>     @impl true
  ...>     def callback_fun(), do: :ok
  ...>
  ...>     @impl GenServer
  ...>     def callback_fun(), do: :ok
  ...>
  ...>     @doc false
  ...>     def private_fun(), do: :ok
  ...>
  ...>     defp another_private_fun(), do: :ok
  ...>
  ...>     defmacro public_macro(), do: :ok
  ...>
  ...>     @impl true
  ...>     defmacro callback_fun(), do: :ok
  ...>
  ...>     @impl GenServer
  ...>     defmacro callback_fun(), do: :ok
  ...>
  ...>     @doc false
  ...>     defmacro private_macro(), do: :ok
  ...>
  ...>     defmacrop another_private_macro(), do: :ok
  ...>
  ...>     defguard public_guard(), do: :ok
  ...>
  ...>     @doc false
  ...>     defguard private_guard(), do: :ok
  ...>
  ...>     defguardp another_private_guard(), do: :ok
  ...>   end
  ...>
  ...>   defmodule AnotherModule do
  ...>     @moduledoc "Another module doc"
  ...>   end
  ...> /)
  iex> VbtCredo.ModulePartExtractor.analyze(ast)
  [
    {SomeModule, [
      moduledoc: [line: 3],
      behaviour: [line: 5],
      use: [line: 7],
      import: [line: 9],
      alias: [line: 11],
      alias: [line: 12],
      require: [line: 14],
      module_attribute: [line: 16],
      defstruct: [line: 18],
      opaque: [line: 20],
      type: [line: 21],
      typep: [line: 22],
      callback: [line: 24],
      macrocallback: [line: 26],
      optional_callbacks: [line: 28],
      public_fun: [line: 30],
      impl: [line: 33],
      impl: [line: 36],
      private_fun: [line: 39],
      private_fun: [line: 41],
      public_macro: [line: 43],
      impl: [line: 46],
      impl: [line: 49],
      private_macro: [line: 52],
      private_macro: [line: 54],
      public_guard: [line: 56],
      private_guard: [line: 59]
    ]},
    {AnotherModule, [moduledoc: [line: 65]]}
  ]
  """
  @spec analyze(Macro.t()) :: [{module, [{module_part, location}]}]
  def analyze(ast) do
    {_ast, state} = Macro.prewalk(ast, initial_state(), &traverse_file/2)
    module_parts(state)
  end

  defp traverse_file({:defmodule, meta, args}, state) do
    [{:__aliases__, _, name_parts} | _] = args
    state = start_module(state, Module.concat(name_parts), meta)
    {_ast, state} = Macro.prewalk(args, state, &traverse_module/2)
    {[], state}
  end

  defp traverse_file(ast, state),
    do: {ast, state}

  defp traverse_module(ast, state) do
    case analyze(state, ast) do
      nil -> traverse_deeper(ast, state)
      state -> traverse_sibling(state)
    end
  end

  defp traverse_deeper(ast, state), do: {ast, state}
  defp traverse_sibling(state), do: {[], state}

  # Part extractors

  defp analyze(state, {:@, _meta, [{:doc, _, [value]}]}),
    do: set_next_fun_modifier(state, if(value == false, do: :private, else: nil))

  defp analyze(state, {:@, _meta, [{:impl, _, [value]}]}),
    do: set_next_fun_modifier(state, if(value == false, do: nil, else: :impl))

  defp analyze(state, {:@, meta, [{attribute, _, _}]})
       when attribute in ~w/moduledoc behaviour type typep opaque callback macrocallback optional_callbacks/a,
       do: add_module_element(state, attribute, meta)

  defp analyze(state, {:@, _meta, [{ignore_attribute, _, _}]})
       when ignore_attribute in ~w/after_compile before_compile compile impl deprecated doc
       typedoc dialyzer external_resource file on_definition on_load vsn spec/a,
       do: state

  defp analyze(state, {:@, meta, _}),
    do: add_module_element(state, :module_attribute, meta)

  defp analyze(state, {clause, meta, _})
       when clause in ~w/use import alias require defstruct/a,
       do: add_module_element(state, clause, meta)

  defp analyze(state, {clause, meta, _})
       when clause in ~w/def defmacro defguard defp defmacrop defguard/a do
    state
    |> add_module_element(code_type(clause, state.next_fun_modifier), meta)
    |> clear_next_fun_modifier()
  end

  defp analyze(_state, _ast), do: nil

  defp code_type(:def, nil), do: :public_fun
  defp code_type(:def, :impl), do: :impl
  defp code_type(:def, :private), do: :private_fun
  defp code_type(:defp, _), do: :private_fun

  defp code_type(:defmacro, nil), do: :public_macro
  defp code_type(:defmacro, :impl), do: :impl
  defp code_type(macro, _) when macro in ~w/defmacro defmacrop/a, do: :private_macro

  defp code_type(:defguard, nil), do: :public_guard
  defp code_type(guard, _) when guard in ~w/defguard defguardp/a, do: :private_guard

  # Internal state

  defp initial_state(), do: %{modules: %{}, current_module: nil, next_fun_modifier: nil}

  defp set_next_fun_modifier(state, value), do: %{state | next_fun_modifier: value}

  defp clear_next_fun_modifier(state), do: set_next_fun_modifier(state, nil)

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
