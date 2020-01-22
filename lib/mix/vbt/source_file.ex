defmodule Mix.Vbt.SourceFile do
  @moduledoc false

  @type t :: %{name: String.t(), content: String.t()}

  @spec load!(String.t()) :: t
  def load!(name), do: %{name: name, content: File.read!(name)}

  @spec store!(t) :: :ok
  def store!(file) do
    code = to_string(Code.format_string!(file.content))
    code = if String.ends_with?(code, "\n"), do: code, else: code <> "\n"
    File.write!(file.name, code)
  end

  @spec add_to_module(SourceFile.t(), String.t()) :: SourceFile.t()
  def add_to_module(file, code) do
    content =
      String.replace(
        file.content,

        # Match the final non whitespace character before the last end.
        ~r/(^.*[^\s])(?=\s*end\s*$)/s,

        # Add new line and the desired code
        "\\1\n#{code} "
      )

    %{file | content: content}
  end
end
