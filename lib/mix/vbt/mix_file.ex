defmodule Mix.Vbt.MixFile do
  @moduledoc false
  alias Mix.Vbt.SourceFile

  @spec append_config(SourceFile.t(), String.t() | atom, String.t()) :: SourceFile.t()
  def append_config(file, name, element) do
    content =
      String.replace(
        file.content,

        # Match def or defp with the given name, and its inner body, stopping at the
        # last non-whitespace character before the last `]` in the function body which is placed
        # right before the closing `end`. The matched string therefore includes the entire list
        # minus the closing bracket.
        ~r/\s*def(p?)\s*#{name}\s*do.*?[^\s](?=\s*\]\s*end)/s,

        # Inject entire match and append the desired element
        "\\0, #{element} "
      )

    %{file | content: content}
  end
end
