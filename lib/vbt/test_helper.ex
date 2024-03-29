defmodule VBT.TestHelper do
  @moduledoc "Various helpers which can be useful in tests."

  # ------------------------------------------------------------------------
  # API
  # ------------------------------------------------------------------------

  @doc """
  Asserts that an e-mail has been delivered via Bamboo.

  Note that in Bamboo 1.7+ there's a native support for this via
  `Bamboo.Test.assert_email_delivered_with/1`.

  ## Examples

      # pattern matching desired mail parameters
      assert_delivered_email(subject: "some subject")

      # if you want to match the content of an existing variable you need to use `^`
      subject = "some subject"
      assert_delivered_email(subject: ^subject)

      # if you omit the `^` operator, the match will always succeed, and the variable will be
      # bound, and can be used in subsequent expressions
      assert_delivered_email(subject: subject)
      assert subject == "some subject"

      # keep in mind that Bamboo manages sender and recipient addresses as pairs in the shape of
      # `{name::String.t() | nil, address::String.t()}`
      assert_delivered_email(from: {_, "sender@x.y.z"})

      # in addition, the `to`, `cc`, and `bcc` fields are a list of such pairs
      assert_delivered_email(to: [{_, "recipient@x.y.z"}])

      # result of assertion is %Bamboo.Email{} struct
      mail = assert_delivered_email(subject: "some_subject")
      assert mail.text_body == "expected body"

      # matching any mail
      mail = assert_delivered_email()

  ## Details

  This macro behaves similar to [Bamboo.Test.assert_delivered_email]
  (https://hexdocs.pm/bamboo/Bamboo.Test.html#assert_delivered_email/1), but it matches any mail
  which satisfies the given pattern.

  In contrast, the Bamboo assertion macro always takes the first email, and compares it to the
  given pattern.

  Consider the following test scenario:

  ```
  test "something" do
    arrange(...)
    function_under_test(...)
    Bamboo.Test.assert_delivered_email(subject: "expected subject")
  end
  ```

  Suppose that the arrange code sends a couple of e-mails, and then `function_under_test` sends
  the desired e-mail. In this case, Bamboo assertion will fail, because it always compares the
  first sent message. In contrast, this macro will succeed as long as there is at least one e-mail which matches
  the given pattern.
  """
  defmacro assert_delivered_email(mail_params \\ [], opts \\ []) do
    quote do
      {:delivered_email, mail} =
        assert_receive(
          {:delivered_email, %Bamboo.Email{unquote_splicing(mail_params)}},
          Keyword.get(unquote(opts), :timeout, 100)
        )

      mail
    end
  end

  @doc """
  Asserts that an e-mail has not been delivered via Bamboo.

  See `assert_delivered_email/2` for details.
  """
  defmacro refute_delivered_email(mail_params \\ [], opts \\ []) do
    quote do
      refute_receive(
        {:delivered_email, %Bamboo.Email{unquote_splicing(mail_params)}},
        Keyword.get(unquote(opts), :timeout, 100)
      )
    end
  end

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

  @doc """
  Converts map string keys to underscore atoms.

  Example:

      iex> VBT.TestHelper.normalize_keys(%{"fooBar" => 1})
      %{foo_bar: 1}

  Notes:

    - The function can handle deep structure of nested lists and maps.
    - Atom keys are preserved. For example `:FooBar` will not be underscored.
    - Tuples and structs are also preserved.
  """
  @spec normalize_keys(any) :: any
  def normalize_keys(%{} = map) when not is_struct(map),
    do: Enum.into(map, %{}, fn {key, value} -> {normalize_key(key), normalize_keys(value)} end)

  def normalize_keys(list) when is_list(list), do: Enum.map(list, &normalize_keys/1)
  def normalize_keys(other), do: other

  @doc """
  Converts map atom keys to camelized strings.

  Example:

      iex> VBT.TestHelper.camelize_keys(%{foo_bar: 1})
      %{"fooBar" => 1}

  Notes:

    - The function can handle deep structure of nested lists and maps.
    - Structs are converted into plain maps and camelized.
    - String keys are preserved. For example `"foo_bar"` will not be camelized.
  """
  @spec camelize_keys(any) :: any
  def camelize_keys(struct) when is_struct(struct), do: camelize_keys(Map.from_struct(struct))

  def camelize_keys(map) when is_map(map),
    do: Enum.into(map, %{}, fn {key, value} -> {camelize_key(key), camelize_keys(value)} end)

  def camelize_keys(list) when is_list(list), do: Enum.map(list, &camelize_keys/1)
  def camelize_keys(other), do: other

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

  defp normalize_key(key) when is_binary(key), do: key |> Macro.underscore() |> String.to_atom()
  defp normalize_key(key), do: key

  defp camelize_key(key) when is_atom(key) do
    <<first::utf8, rest::binary>> = key |> Atom.to_string() |> Macro.camelize()
    String.downcase(<<first::utf8>>) <> rest
  end

  defp camelize_key(key), do: key
end
