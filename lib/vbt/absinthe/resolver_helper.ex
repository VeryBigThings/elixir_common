defmodule VBT.Absinthe.ResolverHelper do
  @moduledoc "Helper functions for absinthe resolvers."
  alias Absinthe.Adapter.LanguageConventions

  @type changeset_errors_opts :: [format_value: value_formatter]
  @type value_formatter :: (key :: String.t(), value :: any -> String.t())
  @type changeset_error :: %{message: String.t(), extensions: %{field: String.t()}}

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc "Converts changeset error into GraphQL compatible output."
  @spec changeset_errors(Ecto.Changeset.t(), changeset_errors_opts) :: [changeset_error]
  def changeset_errors(changeset, opts \\ []) do
    changeset
    |> Ecto.Changeset.traverse_errors(& &1)
    |> format_errors(Keyword.merge(default_opts(), opts))
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp default_opts, do: [format_value: &format_value/2]

  defp format_errors(errors, opts) do
    errors
    |> Enum.map(fn {field_name, errors_per_field} ->
      external_field_name = to_external_name(field_name)
      Enum.map(errors_per_field, &handle_error(external_field_name, &1, opts))
    end)
    |> List.flatten()
  end

  defp to_external_name(field) do
    field
    |> Atom.to_string()
    |> LanguageConventions.to_external_name(:field)
  end

  defp handle_error(field, {msg, values}, opts) when is_binary(msg) do
    %{message: error_message(msg, values, opts), extensions: %{field: field}}
  end

  defp handle_error(_field, {field_name, nested}, opts) do
    Enum.map(nested, &handle_error(field_name, &1, opts))
  end

  defp handle_error(_field, errors, opts) do
    format_errors(errors, opts)
  end

  defp error_message("is invalid" = template, _values, _opts), do: template

  defp error_message(template, values, opts) do
    Enum.reduce(values, template, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", value_formatter(opts).(key, value))
    end)
  end

  defp value_formatter(opts), do: Keyword.fetch!(opts, :format_value)

  defp format_value(_, value), do: to_string(value)
end
