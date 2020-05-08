defmodule VBT.Absinthe.Schema.NormalizeErrors do
  @moduledoc """
  Middleware which converts `Ecto.Changeset` errors into absinthe compatible errors.

  The simplest way to use this middleware is via `VBT.Absinthe.Schema`, which will automatically
  install this middleware to every field. Alternatively, you can install middleware manually, using
  standard absinthe mechanisms.

  Once the middleware is installed, you can safely return `{:error, Ecto.Changeset.t}` from your
  resolvers.
  """

  @behaviour Absinthe.Middleware

  alias Absinthe.Adapter.LanguageConventions

  @impl Absinthe.Middleware
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def call(resolution, _arg) do
    if resolution.state == :resolved do
      errors =
        resolution.errors
        |> Enum.map(&with %Ecto.Changeset{} <- &1, do: changeset_errors(&1))
        |> List.flatten()

      %Absinthe.Resolution{resolution | errors: errors}
    else
      # Field is not yet resolved, so we'll execute this middleware at the very end
      %Absinthe.Resolution{resolution | middleware: resolution.middleware ++ [__MODULE__]}
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def changeset_errors(changeset, opts \\ []) do
    changeset
    |> Ecto.Changeset.traverse_errors(& &1)
    |> format_errors(Keyword.merge(default_opts(), opts))
  end

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
    values
    |> Stream.filter(fn {key, _value} -> String.contains?(template, "%{#{key}}") end)
    |> Enum.reduce(template, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", value_formatter(opts).(key, value))
    end)
  end

  defp value_formatter(opts), do: Keyword.fetch!(opts, :format_value)

  defp format_value(_, value), do: to_string(value)
end
