defmodule VBT.TestHelper do
  @moduledoc "Various helpers which can be useful in tests."

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

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

  @doc """
  Verifies that the provided assertion is eventually met.

  This function is useful when you want to assert a condition that doesn't necessarily hold
  now, but should be met in a near future. Suppose that we want to verify that a token expires
  after one second. We can do it as:

      iex> VBT.TestHelper.eventually(fn -> assert token_expired?() end, attempts: 100, delay: 100)
      true

  In the call above, we're instructing `eventually` to repeatedly invoke the assertion, sleeping
  100ms between two consecutive attempts. The function returns when the assertion succeeds. If the
  assertion didn't succeed in the given number of attempts, the test will fail.

  Notice that the maximum number of attempts is set to 100. This means that we're waiting for at
  most 10 seconds. Since the timing logic is never completely precise, it's possible that the
  token expires a bit later. If the test machine is very busy, the timing mismatch might even
  be much larger. By choosing a significantly larger maximum waiting time, we're reducing the
  chance of a test randomly failing on a busy CI server. At the same time, the delay is reasonably
  small, so the test will succeed at most 100ms after the token expires. In most cases, the
  test will take about 1 second.

  Options:

    - `:attempts` - The number of attempts before giving up. The default value is 10.
    - `:delay` - Sleep time in ms between two consecutive attempts. The default value is 100.
  """
  @spec eventually((() -> res), attempts: pos_integer, delay: non_neg_integer) :: res
        when res: var
  def eventually(fun, opts \\ []),
    do: eventually(fun, Keyword.get(opts, :attempts, 10), Keyword.get(opts, :delay, 100))

  # ------------------------------------------------------------------------
  # Private
  # ------------------------------------------------------------------------

  defp eventually(fun, attempts, delay) do
    fun.()
  rescue
    e in [ExUnit.AssertionError] ->
      if attempts == 1, do: reraise(e, __STACKTRACE__)
      Process.sleep(delay)
      eventually(fun, attempts - 1, delay)
  end
end
