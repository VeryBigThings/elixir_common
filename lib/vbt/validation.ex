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

  @type field_specs :: [field_spec, ...]
  @type field_spec :: {field_name, field_type} | {field_name, {field_type, field_opts}}
  @type field_name :: atom
  @type field_type :: atom | {:enum, [atom]} | {module, any} | nested | {:array, field_type}
  @type field_opts :: [required: boolean]

  @type nested :: {:map, field_specs | {field_specs, normalize_opts}}

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


  ## Nested data structures

  This function can be used to normalize the nested data (maps inside maps, and list of maps).

  However, due to limitations in Ecto changesets, this function doesn't return errors which can
  work with Phoenix HTML forms. Therefore it is not recommended to use this feature
  in such situations. Instead consider using embedded schemas.

  On the other hand, you can use this feature to normalize the data from 3rd party APIs. In case
  of validation errors, the resulting changeset will contain detailed information (see the
  "Nested errors" section for details).

  ### Direct nesting

  A nested map can be described as `{:map, nested_type_spec}`. For example:

      order_item_spec = {:map, product_id: :integer, quantity: :integer}
      order_spec = [user_id: :integer, order_item: order_item_spec]

      data = %{
        "user_id" => "1",
        "order_item" => %{"product_id" => "2", "quantity" => "3"}
      }

      Validation.normalize(data, order_spec)

  If you want to provide additional normalization options you can use a tuple form:

      order_item_spec =
        {
          :map,
          {
            # nested type specification
            [product_id: :integer, quantity: :integer],

            # normalization options for this nested type
            validate: &custom_order_item_validation/1
          }
        }

      order_spec = [user_id: :integer, order_item: order_item_spec]
      Validation.normalize(data, order_spec)


  ### Nesting inside lists

  A list of nested maps can be described as follows:

      order_item_spec = {:map, product_id: :integer, quantity: :integer}
      order_spec = [user_id: :integer, order_items: {:array, order_item_spec}]

      data = %{
        "user_id" => "1",
        "order_items" => [
          %{"product_id" => "2", "quantity" => "3"},
          %{"product_id" => "4", "quantity" => "5"}
        ]
      }

      Validation.normalize(data, order_spec)

  ### Nested errors

  The resulting changeset will contain expanded errors for all nested structures. For example,
  suppose we're trying to cast two order items, where 1st one has two errors, and the 2nd one
  has three errors. The final changeset will contain 5 errors, all of them residing under the
  `:order_items` field.

  Each error will contain the `:path` meta that points to the problematic field. For example
  the `:path` of an error in the `:product_id` field of the 2nd item will be `[1, :product_id]`,
  where `1` represents an index in the list, and `:product_id` the field name inside the nested
  data structure.
  """
  @spec normalize(map, field_specs, normalize_opts) :: {:ok, map} | {:error, Changeset.t()}
  def normalize(data, specs, opts \\ []) do
    data
    |> changeset(specs)
    |> Keyword.get(opts, :validate, & &1).()
    |> Changeset.apply_action(Keyword.get(opts, :action, :insert))
  end

  defp changeset(data, specs) do
    specs = Enum.map(specs, &field_spec/1)
    types = Enum.into(specs, %{}, &{&1.name, ecto_type(&1.type)})
    required = specs |> Enum.filter(& &1.required) |> Enum.map(& &1.name)
    trimable = specs |> Enum.filter(& &1.trim) |> Enum.map(& &1.name)

    {assocs, fields} = Enum.split_with(specs, &assoc?(&1.type))

    {%{}, types}
    |> Changeset.cast(data, Enum.map(fields, & &1.name))
    |> cast_assocs(data, assocs)
    |> Changeset.validate_required(required)
    |> trim_params(trimable)
  end

  defp field_spec({name, {:enum, _values} = type}), do: field_spec({name, {type, []}})
  defp field_spec({name, {:array, _type} = type}), do: field_spec({name, {type, []}})
  defp field_spec({name, {:map, _type} = type}), do: field_spec({name, {type, []}})

  defp field_spec({name, {type, opts}}) do
    %{required: false, trim: false}
    |> Map.merge(Map.new(opts))
    |> Map.merge(%{type: type_spec(type), name: name})
  end

  defp field_spec({name, type}), do: field_spec({name, {type, []}})

  defp type_spec(name) when is_atom(name), do: name
  defp type_spec({:map, [_ | _] = nested}), do: {:map, {nested, []}}
  defp type_spec({:map, {[_ | _], _opts}} = nested), do: nested
  defp type_spec({:array, type}), do: {:array, type_spec(type)}
  defp type_spec({:enum, values}), do: type_spec({Ecto.Enum, values: values})
  defp type_spec({module, arg}), do: {:parameterized, module, module.init(arg)}

  # has_one-like assoc is represented with a map
  defp ecto_type({:map, {[_ | _], _opts}}), do: :map
  # has_many-like assoc is represented as an array of maps
  defp ecto_type({:array, type}), do: {:array, ecto_type(type)}
  defp ecto_type(other), do: other

  defp assoc?({:map, {[_ | _], _opts}}), do: true
  defp assoc?({:array, type}), do: assoc?(type)
  defp assoc?(_other), do: false

  # ------------------------------------------------------------------------
  # Nested data structures
  # ------------------------------------------------------------------------

  # In Ecto nested data structures are typically handled with associations (e.g. has_one & has_many).
  # Unfortunately, Ecto associations only work with dedicated modules (i.e. schemas), so they can't
  # be used in this case.
  #
  # Another option that was explored is a custom parameterized type (https://hexdocs.pm/ecto/Ecto.ParameterizedType.html).
  # This approach works, and requires less amount of code, but the problem is that error reporting
  # is very poor. An error deep inside a nested structure is going to be completely useless.
  #
  # The selected approach manually casts nested data strucure, and produces errors with details.

  defp cast_assocs(changeset, data, assocs) do
    Enum.reduce(
      assocs,
      changeset,
      fn assoc, changeset ->
        case fetch_assoc_data(data, assoc.name) do
          :error -> changeset
          {:ok, nil} -> changeset
          {:ok, data} -> cast_assoc(changeset, data, assoc)
        end
      end
    )
  end

  defp fetch_assoc_data(data, name),
    do: with(:error <- Map.fetch(data, name), do: Map.fetch(data, to_string(name)))

  # list of nested maps
  defp cast_assoc(changeset, data, %{type: {:array, type}} = assoc) do
    if is_list(data) do
      casted = Enum.map(data, &cast_nested(&1, type))

      if Enum.any?(casted, &match?({:error, _}, &1)) do
        for {{:error, errors}, index} <- Enum.with_index(casted),
            {error, path} <- errors,
            reduce: changeset do
          changeset -> Changeset.add_error(changeset, assoc.name, error, path: [index | path])
        end
      else
        values = Enum.map(casted, fn {:ok, value} -> value end)
        Changeset.put_change(changeset, assoc.name, values)
      end
    else
      Changeset.add_error(changeset, assoc.name, "is invalid")
    end
  end

  # nested map
  defp cast_assoc(changeset, data, assoc) do
    if is_map(data) do
      case cast_nested(data, assoc.type) do
        {:ok, normalized} ->
          Changeset.put_change(changeset, assoc.name, normalized)

        {:error, errors} ->
          Enum.reduce(
            errors,
            changeset,
            fn {error, path}, changeset ->
              Changeset.add_error(changeset, assoc.name, error, path: path)
            end
          )
      end
    else
      Changeset.add_error(changeset, assoc.name, "is invalid")
    end
  end

  defp cast_nested(data, {:map, {specs, opts}}) do
    with {:error, changeset} <- normalize(data, specs, opts) do
      errors =
        for {field, errors} <- field_errors(changeset),
            {error, path} <- errors,
            do: {error, [field | path]}

      {:error, errors}
    end
  end

  defp field_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      error =
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)

      {error, Keyword.get(opts, :path, [])}
    end)
  end

  defp trim_params(changeset, keys) do
    Enum.reduce(keys, changeset, fn key, changeset ->
      Changeset.update_change(changeset, key, &String.trim/1)
    end)
  end
end
