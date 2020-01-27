defmodule VBT.Skafolder do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  def generate_file(content, file, args) do
    {opts, _args} = OptionParser.parse!(args, switches: [force: :boolean])
    Mix.Generator.create_file(file, content, opts)
  end

  def eval_from_templates(source, bindings) do
    template =
      Enum.find_value(template_paths(), fn tpath ->
        file_path = Path.join(tpath, source)
        File.exists?(file_path) && File.read!(file_path)
      end) || raise "could not find #{source} in any of the sources"

    EEx.eval_string(template, bindings)
  end

  def template_paths do
    base_path = :code.priv_dir(:vbt)
    [Path.join([base_path, "templates"])]
  end

  def random_string(length) when length > 31 do
    :crypto.strong_rand_bytes(length) |> Base.encode64() |> binary_part(0, length)
  end

  def random_string(_), do: Mix.raise("The secret should be at least 32 characters long")
end
