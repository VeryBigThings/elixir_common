defmodule Mix.Vbt.SourceFile do
  @moduledoc false

  @type t :: %{name: String.t(), content: String.t()}

  @spec load!(String.t()) :: t
  def load!(name), do: %{name: name, content: File.read!(name)}

  @spec store!(t) :: :ok
  def store!(file), do: File.write!(file.name, format(file.content))

  @spec add_to_module(t(), String.t()) :: t()
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

  defp format(code) do
    code = to_string(Code.format_string!(code, locals_without_parens: [plug: :*, socket: :*]))
    if String.ends_with?(code, "\n"), do: code, else: code <> "\n"
  end
end
