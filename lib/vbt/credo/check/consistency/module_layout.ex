defmodule VBT.Credo.Check.Consistency.ModuleLayout do
  @moduledoc false

  @checkdoc """
  Module parts should appear in the following order:

     1. @moduledoc
     2. @behaviour
     3. use
     4. import
     5. alias
     6. require
     7. custom module attributes
     8. defstruct
     9. @opaque
    10. @type
    11. @typep
    12. @callback
    13. @macrocallback
    14. @optional_callbacks
    15. public guards
    16. public macros
    17. public functions
    18. behaviour callbacks
    19. private functions

  This order has been adapted from https://github.com/christopheradams/elixir_style_guide#module-attribute-ordering.
  """
  @explanation [check: @checkdoc]

  # `use Credo.Check` required that module attributes are already defined, so we need to place these attributes
  # before use/alias expressions.
  # credo:disable-for-next-line VBT.Credo.Check.Consistency.ModuleLayout
  use Credo.Check, base_priority: :high

  alias Credo.Code
  alias VBT.Credo.ModulePartExtractor

  @expected_order Map.new(Enum.with_index(~w/
    moduledoc
    behaviour
    use
    import
    alias
    require
    module_attribute
    defstruct
    opaque
    type
    typep
    callback
    macrocallback
    optional_callbacks
    public_guard
    public_macro
    public_fun
    impl
    private_fun
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
      %{module: module, current_part: nil, errors: []},
      &check_part_location(&2, &1, issue_meta)
    ).errors
  end

  defp check_part_location(state, {part, file_pos}, issue_meta) do
    state
    |> validate_order(part, file_pos, issue_meta)
    |> Map.put(:current_part, part)
  end

  defp validate_order(state, part, file_pos, issue_meta) do
    current_part = state.current_part

    if is_nil(current_part) || is_nil(order(part)) || order(state.current_part) <= order(part),
      do: state,
      else: add_error(state, part, file_pos, issue_meta)
  end

  defp order(part), do: Map.get(@expected_order, part)

  defp add_error(state, part, file_pos, issue_meta) do
    update_in(
      state.errors,
      &[error(issue_meta, part, state.current_part, state.module, file_pos) | &1]
    )
  end

  defp error(issue_meta, part, current_part, module, file_pos) do
    format_issue(
      issue_meta,
      message: "#{part_to_string(part)} must appear before #{part_to_string(current_part)}",
      trigger: inspect(module),
      line_no: Keyword.get(file_pos, :line),
      column: Keyword.get(file_pos, :column)
    )
  end

  defp part_to_string(:module_attribute), do: "module attribute"
  defp part_to_string(:public_guard), do: "public guard"
  defp part_to_string(:public_macro), do: "public macro"
  defp part_to_string(:public_fun), do: "public function"
  defp part_to_string(:private_fun), do: "private function"
  defp part_to_string(:impl), do: "callback implementation"
  defp part_to_string(part), do: "#{part}"
end
