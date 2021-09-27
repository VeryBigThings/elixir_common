defmodule Mix.Vbt.SourceFile do
  @moduledoc false

  @type t :: %{name: String.t(), content: String.t(), format?: boolean, output: String.t()}

  @spec load!(String.t(), format?: boolean, output: String.t()) :: t
  def load!(name, opts \\ []) do
    %{
      name: name,
      content: File.read!(name),
      format?: Keyword.get(opts, :format?, true),
      output: Keyword.get(opts, :output, name)
    }
  end

  @spec store!(t) :: :ok
  def store!(file) do
    File.write!(file.output, format(file))
    if file.output != file.name, do: File.rm!(file.name)
    :ok
  end

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

  @spec append(t, String.t()) :: t
  def append(file, extra_content), do: update_in(file.content, &(&1 <> extra_content))

  @spec prepend(t, String.t()) :: t
  def prepend(file, extra_content), do: update_in(file.content, &(extra_content <> &1))

  @spec format_code(String.t()) :: String.t()
  def format_code(content) do
    code =
      content
      |> Code.format_string!(locals_without_parens: [plug: :*, socket: :*])
      |> to_string()

    if String.ends_with?(code, "\n"), do: code, else: code <> "\n"
  end

  defp format(%{format?: false} = file), do: file.content
  defp format(file), do: format_code(file.content)
end
