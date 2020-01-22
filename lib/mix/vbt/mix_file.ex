defmodule Mix.Vbt.MixFile do
  @moduledoc false

  @opaque t :: String.t()

  @spec load! :: t
  def load!, do: File.read!("mix.exs")

  @spec store!(t) :: :ok
  def store!(content), do: File.write!("mix.exs", Code.format_string!(content))

  @spec add_deps(t, String.t()) :: t
  def add_deps(content, deps), do: append_config(content, :deps, deps)

  @spec append_config(t, String.t() | atom, String.t()) :: t
  def append_config(content, name, element) do
    String.replace(
      content,

      # Match def or defp with the given name, and its inner body, stopping at the
      # last non-whitespace character before the last `]` in the function body which is placed
      # right before the closing `end`. The matched string therefore includes the entire list
      # minus the closing bracket.
      ~r/\s*def(p?)\s*#{name}\s*do.*?[^\s](?=\s*\]\s*end)/s,

      # Inject entire match and append the desired element
      "\\0, #{element} "
    )
  end

  @spec add_function(t, String.t()) :: t
  def add_function(content, code) do
    String.replace(
      content,

      # Match the final non whitespace character before the last end.
      ~r/(^.*[^\s])(?=\s*end\s*$)/s,

      # Add new line and the desire code
      "\\1\n#{code} "
    )
  end
end
