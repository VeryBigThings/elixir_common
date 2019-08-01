defmodule Scaffolder do
  @moduledoc """
  Documentation for Scaffolder.
  """

  def generate_file(content, file) do
    Mix.Generator.create_file(file, content)
  end

  def eval_from_templates(source, bindings) do
    template = Enum.find_value(template_paths(), fn(tpath) ->
      file_path = Path.join(tpath, source)
      File.exists?(file_path) && File.read!(file_path)
    end) || raise "could not find #{source} in any of the sources"

    EEx.eval_string(template, bindings)
  end

  def template_paths do
    base_path = :code.priv_dir(:scaffolder)
    [ Path.join([base_path, "templates"]) ]
  end
end
