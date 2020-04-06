# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule VBT.Credo.Check.Consistency.ModuleLayout do
  @moduledoc false

  use Credo.Check,
    category: :warning,
    base_priority: :high,
    explanations: [
      check: """
      Module parts should appear in the following order:

         1. @shortdoc
         2. @moduledoc
         3. @behaviour
         4. use
         5. import
         6. alias
         7. require
         8. custom module attributes
         9. defstruct
        10. @opaque
        11. @type
        12. @typep
        13. @callback
        14. @macrocallback
        15. @optional_callbacks
        16. public guards
        17. public macros
        18. public functions
        19. behaviour callbacks
        20. private functions

      This order has been adapted from https://github.com/christopheradams/elixir_style_guide#module-attribute-ordering.
      """
    ]

  alias Credo.Code
  alias VBT.Credo.ModulePartExtractor

  @expected_order Map.new(Enum.with_index(~w/
    shortdoc
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
    |> store_current_part(part)
  end

  defp store_current_part(state, part) do
    if is_nil(order(part)), do: state, else: Map.put(state, :current_part, part)
  end

  defp validate_order(state, part, file_pos, issue_meta) do
    current_part = state.current_part

    if is_nil(current_part) or is_nil(order(part)) or order(state.current_part) <= order(part),
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
