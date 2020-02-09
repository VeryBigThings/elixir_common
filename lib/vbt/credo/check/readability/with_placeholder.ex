defmodule VBT.Credo.Check.Readability.WithPlaceholder do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  @checkdoc """
  Avoid using with placeholders for error reporting.

  Consider the following code:

      with {:resource, {:ok, resource}} <- {:resource, Resource.fetch(user)},
           {:authz, :ok} <- {:authz, Resource.authorize(resource, user)} do
        do_something_with(resource)
      else
        {:resource, _} -> {:error, :not_found}
        {:authz, _} -> {:error, :unauthorized}
      end

  This code injects placeholders such as `:resource` and `:authz` for the purpose of error
  reporting.

  Instead, extract each validation into a separate helper function which returns error
  information immediately:

      defp find_resource(user) do
        with :error <- Resource.fetch(user), do: {:error, :not_found}
      end

      defp authorize(resource, user) do
        with :error <- Resource.authorize(resource, user), do: {:error, :unauthorized}
      end

  At this point, the validation chain in `with` is more explicit:

      with {:ok, resource} <- find_resource(user),
           :ok <- authorize(resource, user),
           do: do_something(user)
  """
  @explanation [check: @checkdoc]

  # `use Credo.Check` required that module attributes are already defined, so we need to place these attributes
  # before use/alias expressions.
  # credo:disable-for-next-line VBT.Credo.Check.Consistency.ModuleLayout
  use Credo.Check, category: :warning, base_priority: :high

  alias Credo.Code

  def run(source_file, params \\ []) do
    source_file
    |> errors()
    |> Enum.map(&credo_error(&1, IssueMeta.for(source_file, params)))
  end

  defp errors(source_file) do
    {_ast, errors} = Macro.prewalk(Code.ast(source_file), MapSet.new(), &traverse/2)
    Enum.sort_by(errors, &{&1.line, &1.column})
  end

  defp traverse({:with, _meta, args}, errors) do
    errors =
      args
      |> Stream.map(&placeholder/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(errors)

    {args, errors}
  end

  defp traverse(ast, state), do: {ast, state}

  defp placeholder({:<-, meta, [{placeholder, _}, {placeholder, _}]}) when is_atom(placeholder),
    do: %{placeholder: placeholder, line: meta[:line], column: meta[:column]}

  defp placeholder(_), do: nil

  defp credo_error(error, issue_meta) do
    format_issue(
      issue_meta,
      message: "Invalid usage of placeholder `#{inspect(error.placeholder)}` in with",
      line_no: error.line,
      column: error.column
    )
  end
end
