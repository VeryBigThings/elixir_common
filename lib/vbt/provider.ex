defmodule VBT.Provider do
  alias Ecto.Changeset

  @type adapter :: module
  @type params :: %{param_name => param_spec}
  @type param_name :: atom
  @type param_spec :: %{type: type, default: value}
  @type type :: :string | :integer | :float | :boolean
  @type value :: String.t() | number | boolean | nil
  @type data :: %{param_name => value}

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @spec fetch_all(adapter, params) :: {:ok, data} | {:error, [String.t()]}
  def fetch_all(adapter, params) do
    types = Enum.into(params, %{}, fn {name, spec} -> {name, spec.type} end)

    data =
      params
      |> Stream.zip(adapter.values(Map.keys(types)))
      |> Enum.into(%{}, fn {{param, opts}, provided_value} ->
        value = if is_nil(provided_value), do: opts.default, else: provided_value
        {param, value}
      end)

    {%{}, types}
    |> Changeset.cast(data, Map.keys(types))
    |> Changeset.validate_required(Map.keys(types), message: "is missing")
    |> case do
      %Changeset{valid?: true} = changeset -> {:ok, Changeset.apply_changes(changeset)}
      %Changeset{valid?: false} = changeset -> {:error, changeset_error(adapter, changeset)}
    end
  end

  @spec fetch_one(adapter, param_name, param_spec) :: {:ok, value} | {:error, [String.t()]}
  def fetch_one(adapter, param_name, param_spec) do
    with {:ok, map} <- fetch_all(adapter, %{param_name => param_spec}),
         do: {:ok, Map.fetch!(map, param_name)}
  end

  @spec fetch_one!(adapter, param_name, param_spec) :: value
  def fetch_one!(adapter, param, param_spec) do
    case fetch_one(adapter, param, param_spec) do
      {:ok, value} -> value
      {:error, errors} -> raise Enum.join(errors, ", ")
    end
  end

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp changeset_error(adapter, changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(
        opts,
        msg,
        fn {key, value}, acc -> String.replace(acc, "%{#{key}}", to_string(value)) end
      )
    end)
    |> Enum.flat_map(fn {key, errors} ->
      Enum.map(errors, &"#{adapter.display_name(key)} #{&1}")
    end)
    |> Enum.sort()
  end

  defmodule Adapter do
    @callback values([VBT.Provider.param_name()]) :: [VBT.Provider.value()]
    @callback display_name(VBT.Provider.param_name()) :: String.t()
  end
end
