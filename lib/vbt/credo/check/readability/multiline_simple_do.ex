defmodule VBT.Credo.Check.Readability.MultilineSimpleDo do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  # credo:disable-for-this-file VBT.Credo.Check.Readability.MultilineSimpleDo

  @checkdoc """
  Avoid using multiline simple do expression.

      # preferred

      defp some_fun() do
        %{
          a: 1,
          b: 2,
          c: 3
        }
      end

      # NOT preferred

      defp some_fun(),
        do: %{
          a: 1,
          b: 2,
          c: 3
        }
  """
  @explanation [check: @checkdoc]

  # `use Credo.Check` required that module attributes are already defined, so we need to place these attributes
  # before use/alias expressions.
  # credo:disable-for-next-line VBT.Credo.Check.Consistency.ModuleLayout
  use Credo.Check, category: :warning, base_priority: :high

  def run(source_file, params \\ []) do
    source_file
    |> lines()
    |> multiline_simple_dos()
    |> Enum.map(&credo_error(&1, IssueMeta.for(source_file, params)))
  end

  defp lines(source_file) do
    source_file
    |> Credo.SourceFile.lines()
    |> Stream.map(&with_location/1)
    |> Stream.reject(&(&1.content =~ ~r/^#/))
  end

  defp with_location({row, content}) do
    column =
      case Regex.run(~r/^\s*./, content, return: :index) do
        [{0, column}] -> column
        nil -> 0
      end

    %{row: row, column: column, content: String.trim(content)}
  end

  defp multiline_simple_dos(lines) do
    lines
    |> Stream.chunk_every(3, 1, :discard)
    |> Stream.map(fn [previous_line, this_line, next_line] ->
      # Recognition algorithm:
      #   1. Previous line ends with `,`
      #   2. This line starts with `do:`
      #   3. Next line is not empty, `end`, `)`, or `else:`
      if previous_line.content =~ ~r/^.*,$/ and
           String.starts_with?(this_line.content, "do:") and
           not (next_line.content == "" or
                  next_line.content in ~w/end ) end) " """/ or
                  String.starts_with?(next_line.content, "else:")),
         do: this_line
    end)
    |> Stream.reject(&is_nil/1)
  end

  defp credo_error(line, issue_meta) do
    format_issue(
      issue_meta,
      message: "Replace multiline `do:` expression with `do...end`",
      line_no: line.row,
      column: line.column
    )
  end
end
