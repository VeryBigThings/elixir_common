defmodule VBT.Validation do
  @moduledoc """
  Helpers for validating and normalizing "free-form" maps, such as maps representing input
  parameters in Phoenix controllers.

  This module can be considered as a lightweight equivalent of GraphQL schemas for REST and
  socket interfaces. It is typically used in Phoenix controllers, sockets, or LiveView modules
  to normalize the input data. The module can also help with normalization of 3rd party API JSON
  responses.
  """

  alias Ecto.Changeset

  @type field_spec :: {field_name, field_type} | {field_name, {field_type, field_opts}}
  @type field_name :: atom
  @type field_type :: atom | {:enum, [atom]} | {module, any}
  @type field_opts :: [required: boolean]

  @type normalize_opts :: [
          action: Changeset.action(),
          validate: (Changeset.t() -> Changeset.t())
        ]

  @doc """
  Normalizes a free-form map according to the given specification.

  Example:

      iex> VBT.Validation.normalize(
      ...>   %{"foo" => "bar", "baz" => "1"},
      ...>   foo: :string,
      ...>   baz: {:integer, required: :true},
      ...>   qux: :string
      ...> )
      {:ok, %{foo: "bar", baz: 1}}

  This function is a wrapper around schemaless changesets. The code above is roughly similar to the
  following manual version:

      data = %{"foo" => "bar", "baz" => "1"}
      types = %{foo: :string, baz: :integer, qux: :string}

      {%{}, types}
      |> Ecto.Changeset.cast(data, Map.keys(types))
      |> Ecto.Changeset.validate_required(~w/baz/a)
      |> Ecto.Changeset.apply_action(:insert)

  Since it is based on Ecto changesets, the function supports the same types
  (see [here](https://hexdocs.pm/ecto/Ecto.Schema.html#module-types-and-casting) for details).

  In addition, custom `{:enum, values}` can be provided for the type. In this case, `Ecto.Enum`
  will be used to validate the value and normalize the result to the atom type.

  Finally, you can provide `{module, arg}` for the type, where `module` implements the
  [Ecto.ParameterizedType](https://hexdocs.pm/ecto/Ecto.ParameterizedType.html) behaviour. Note
  that you can only provide the parameterized type in the fully expanded form, i.e. as
  `field_name: {{module, arg}, field_opts}`.

  If validation fails, an error changeset is returned, with the action set to `:insert`. You can
  set a different action with the `:action` option.

  If you're using this function in Phoenix controllers and rendering the error changeset in
  a form, you need to provide the underlying type name explicitly:

      <%= form_for @changeset, some_path, [as: :user], fn f -> %>
        # ...
      <% end %>

  See `Phoenix.HTML.Form.form_for/4` for details.

  ## Custom validations

  You can perform additional custom validations with the `:validate` option:

      Validation.normalize(
        data,
        [password: :string],
        validate: &Ecto.Changeset.validate_confirmation(&1, :password, required: true)
      )

  The `:validate` option is a function which takes a changeset and returns the changeset with
  extra custom validations performed.
  """
  @spec normalize(map, [field_spec], normalize_opts) :: {:ok, map} | {:error, Changeset.t()}
  def normalize(data, specs, opts \\ []) do
    data
    |> changeset(specs)
    |> Keyword.get(opts, :validate, & &1).()
    |> Changeset.apply_action(Keyword.get(opts, :action, :insert))
  end

  defp changeset(data, specs) do
    specs = Enum.map(specs, &field_spec/1)
    types = Enum.into(specs, %{}, &{&1.name, &1.type})
    required = specs |> Enum.filter(& &1.required) |> Enum.map(& &1.name)

    {%{}, types}
    |> Changeset.cast(data, Map.keys(types))
    |> Changeset.validate_required(required)
  end

  defp field_spec({name, {:enum, _values} = type}), do: field_spec({name, {type, []}})

  defp field_spec({name, {type, opts}}) do
    %{required: false}
    |> Map.merge(Map.new(opts))
    |> Map.merge(%{type: type_spec(type), name: name})
  end

  defp field_spec({name, type}), do: field_spec({name, {type, []}})

  defp type_spec(name) when is_atom(name), do: name
  defp type_spec({:enum, values}), do: type_spec({Ecto.Enum, values: values})
  defp type_spec({module, arg}), do: {:parameterized, module, module.init(arg)}
end
