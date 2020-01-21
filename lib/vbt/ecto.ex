defmodule VBT.Ecto do
  @moduledoc "Helpers for working with Ecto."

  alias Ecto.Multi

  @type multi_result ::
          {:ok, changes}
          | {:error, failed_operation :: Multi.name(), reason :: any, changes}

  @type changes :: %{Multi.name() => any}

  @doc """
  Returns the result of a multi operation or the operation error.

      iex> result = (
      ...>   Ecto.Multi.new()
      ...>   |> Ecto.Multi.run(:foo, fn _, _ -> {:ok, 1} end)
      ...>   |> Ecto.Multi.run(:bar, fn _, _ -> {:ok, 2} end)
      ...>   |> Ecto.Multi.run(:baz, fn _, _ -> {:ok, 3} end)
      ...>   |> VBT.TestRepo.transaction()
      ...> )
      iex> VBT.Ecto.multi_operation_result(result, :foo)
      {:ok, 1}

      iex> result = (
      ...>   Ecto.Multi.new()
      ...>   |> Ecto.Multi.run(:foo, fn _, _ -> {:ok, 1} end)
      ...>   |> Ecto.Multi.run(:bar, fn _, _ -> {:error, "bar error"} end)
      ...>   |> VBT.TestRepo.transaction()
      ...> )
      iex> VBT.Ecto.multi_operation_result(result, :foo)
      {:error, "bar error"}
  """
  @spec multi_operation_result(multi_result, Multi.name()) :: {:ok, any} | {:error, any}
  def multi_operation_result(multi_result, operation),
    do: map_multi_result(multi_result, &Map.fetch!(&1, operation))

  @doc """
  Maps the result of a multi operation, or returns an error.

      iex> result = (
      ...>   Ecto.Multi.new()
      ...>   |> Ecto.Multi.run(:foo, fn _, _ -> {:ok, 1} end)
      ...>   |> Ecto.Multi.run(:bar, fn _, _ -> {:ok, 2} end)
      ...>   |> Ecto.Multi.run(:baz, fn _, _ -> {:ok, 3} end)
      ...>   |> VBT.TestRepo.transaction()
      ...> )
      iex> VBT.Ecto.map_multi_result(result)
      {:ok, %{foo: 1, bar: 2, baz: 3}}

      iex> result = (
      ...>   Ecto.Multi.new()
      ...>   |> Ecto.Multi.run(:foo, fn _, _ -> {:ok, 1} end)
      ...>   |> Ecto.Multi.run(:bar, fn _, _ -> {:ok, 2} end)
      ...>   |> Ecto.Multi.run(:baz, fn _, _ -> {:ok, 3} end)
      ...>   |> VBT.TestRepo.transaction()
      ...> )
      iex> VBT.Ecto.map_multi_result(result, &Map.take(&1, [:foo, :bar]))
      {:ok, %{foo: 1, bar: 2}}

      iex> result = (
      ...>   Ecto.Multi.new()
      ...>   |> Ecto.Multi.run(:foo, fn _, _ -> {:ok, 1} end)
      ...>   |> Ecto.Multi.run(:bar, fn _, _ -> {:error, "bar error"} end)
      ...>   |> VBT.TestRepo.transaction()
      ...> )
      iex> VBT.Ecto.map_multi_result(result)
      {:error, "bar error"}
  """
  @spec map_multi_result(multi_result, (changes -> result)) :: {:ok, result} | {:error, any}
        when result: var
  def map_multi_result(multi_result, success_mapper \\ & &1)

  def map_multi_result({:ok, result}, success_mapper),
    do: {:ok, success_mapper.(result)}

  def map_multi_result({:error, _operation, error, _changes}, _success_mapper),
    do: {:error, error}
end
