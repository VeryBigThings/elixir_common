defmodule VbtCredo.Check.Consistency.ModuleLayout do
  @moduledoc false

  @checkdoc """
  Module parts should appear in the following order:

    1. @moduledoc
    2. @behaviour
    3. use
  """
  @explanation [check: @checkdoc]

  use Credo.Check, base_priority: :high

  alias Credo.Code
  alias VbtCredo.ModulePartExtractor

  @expected_order Map.new(Enum.with_index(~w/
    moduledoc
    behaviour
    use
    import
    alias
    require
    module_attribute
    defstruct
  /a))

  @doc false
  def run(source_file, params \\ []) do
    source_file
    |> Code.ast()
    |> ModulePartExtractor.analyze()
    |> all_errors(IssueMeta.for(source_file, params))
    |> Enum.sort_by(&{&1.line_no, &1.column})
  end

  defp all_errors(modules_and_parts, issue_meta) do
    Enum.reduce(
      modules_and_parts,
      [],
      fn {module, parts}, errors -> module_errors(module, parts, issue_meta) ++ errors end
    )
  end

  defp module_errors(module, parts, issue_meta) do
    Enum.reduce(
      parts,
      %{module: module, section: -1, errors: []},
      &check_part_location(&2, &1, issue_meta)
    ).errors
  end

  defp check_part_location(state, {part, file_pos}, issue_meta) do
    part_section = section(part)

    if part_section >= state.section,
      do: %{state | section: part_section},
      else: update_in(state.errors, &[error(issue_meta, part, state.module, file_pos) | &1])
  end

  defp section(part), do: Map.fetch!(@expected_order, part)

  defp error(issue_meta, part, module, file_pos) do
    format_issue(
      issue_meta,
      message: "Invalid placement of #{part}.",
      trigger: inspect(module),
      line_no: Keyword.get(file_pos, :line),
      column: Keyword.get(file_pos, :column)
    )
  end
end
