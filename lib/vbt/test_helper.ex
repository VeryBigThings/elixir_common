defmodule VBT.TestHelper do
  @moduledoc "Various helpers which can be useful in tests."

  @doc """
  Returns a unique positive integer.

  The function is globally monotonically strictly increasing. A returned value is guaranteed to
  be greater than previous returned values across all processes.

      iex> a = VBT.TestHelper.unique_positive_integer()
      iex> b = VBT.TestHelper.unique_positive_integer()
      iex> c = VBT.TestHelper.unique_positive_integer()
      iex> a > 0 and b > 0 and c > 0
      true
      iex> a < b and b < c
      true
  """
  @spec unique_positive_integer() :: pos_integer
  def unique_positive_integer, do: :erlang.unique_integer([:positive, :monotonic])
end
