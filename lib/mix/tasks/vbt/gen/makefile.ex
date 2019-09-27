defmodule Mix.Tasks.Vbt.Gen.Makefile do
  use Mix.Task

  @template Path.join(["skf.gen.makefile", "Makefile"])
  @switches [cloud: :string, docker: :boolean]
  @defaults [cloud: "heroku", docker: true]

  @shortdoc "Generate Makefile"
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.makefile can only be run inside an application directory")
    end

    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)

    app = Mix.Project.config()[:app]

    bindings = Keyword.merge([app: app], Keyword.merge(opts, @defaults))

    @template
    |> VBT.Skafolder.eval_from_templates(bindings)
    |> VBT.Skafolder.generate_file(Path.join([File.cwd!(), "Makefile"]))
  end
end
