defmodule VBT do
  @moduledoc "Common helper functions"

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc "Converts a boolean into `:ok | {:error, reason}`."
  @spec validate(boolean, error) :: :ok | {:error, error} when error: var
  def validate(condition, error), do: if(condition, do: :ok, else: {:error, error})

  @doc "Converts a boolean into `:ok | {:error, :unauthorized}`."
  @spec authorize(boolean) :: :ok | {:error, :unauthorized}
  def authorize(condition), do: validate(condition, :unauthorized)

  @doc """
  Performs recursive merge of two maps.

  Example:

      iex> map1 = %{a: 1, b: 2, c: %{d: 3}}
      iex> map2 = %{a: 4, c: %{e: 5}, f: 6}
      iex> VBT.deep_merge(map1, map2)
      %{a: 4, b: 2, c: %{d: 3, e: 5}, f: 6}
  """
  @spec deep_merge(map, map) :: map
  def deep_merge(left, right), do: Map.merge(left, right, &deep_resolve/3)

  # Key exists in both maps, and both values are maps as well.
  # These can be merged recursively.
  defp deep_resolve(_key, %{} = left, %{} = right), do: deep_merge(left, right)

  # Key exists in both maps, but at least one of the values is
  # NOT a map. We fall back to standard merge behavior, preferring
  # the value on the right.
  defp deep_resolve(_key, _left, right), do: right
end
