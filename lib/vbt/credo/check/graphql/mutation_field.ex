# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule VBT.Credo.Check.Graphql.MutationField do
  @moduledoc false

  use Credo.Check,
    category: :warning,
    base_priority: :high,
    explanations: [
      check: """
      Mutation field in a relay schema should be a payload field.

          # preferred

          payload field :some_field, ...


          # NOT preferred

          field :some_field, ...
      """
    ]

  alias alias Credo.Code

  def run(source_file, params \\ []) do
    {_, state} =
      source_file
      |> Code.ast()
      |> Macro.traverse(
        %{module_parts: [], schema?: [], mutation?: false, errors: []},
        &pre_traverse/2,
        &post_traverse/2
      )

    state.errors
    |> Enum.reverse()
    |> Enum.map(&error(IssueMeta.for(source_file, params), &1))
  end

  defp error(issue_meta, error) do
    format_issue(
      issue_meta,
      message: "Mutation field #{error.field_name} is not a payload field.",
      trigger: inspect(error.module),
      line_no: error.location[:line],
      column: error.location[:column]
    )
  end

  defp pre_traverse({:defmodule, _, args} = ast, state) do
    state =
      state
      |> Map.update!(:module_parts, &[module_name(args) | &1])
      |> Map.update!(:schema?, &[false | &1])

    {ast, state}
  end

  defp pre_traverse(
         {:use, _, [{:__aliases__, _, [:VBT, :Absinthe, :Relay, :Schema]} | _]} = ast,
         %{schema?: [_ | _]} = state
       ),
       do: {ast, Map.update!(state, :schema?, &[true | tl(&1)])}

  defp pre_traverse({:mutation, _, _} = ast, %{schema?: [true | _]} = state),
    do: {ast, %{state | mutation?: true}}

  defp pre_traverse({:payload, _, [{:field, _, _}, _]}, state),
    do: {[], state}

  defp pre_traverse({:field, meta, args}, %{mutation?: true} = state) do
    error = %{
      module: Module.concat(Enum.reverse(state.module_parts)),
      field_name: inspect(hd(args)),
      location: Keyword.take(meta, ~w/line column/a)
    }

    {[], Map.update!(state, :errors, &[error | &1])}
  end

  defp pre_traverse(other, state), do: {other, state}

  defp post_traverse({:defmodule, _, _} = ast, state),
    do: {ast, state |> Map.update!(:module_parts, &tl/1) |> Map.update!(:schema?, &tl/1)}

  defp post_traverse({:mutation, _, _} = ast, %{schema?: [true | _]} = state),
    do: {ast, %{state | mutation?: false}}

  defp post_traverse(other, state), do: {other, state}

  defp module_name([{:__aliases__, _, name_parts} | _]) do
    name_parts
    |> Enum.map(fn
      atom when is_atom(atom) -> atom
      _other -> Unknown
    end)
    |> Module.concat()
  end

  defp module_name(_other), do: Unknown
end
