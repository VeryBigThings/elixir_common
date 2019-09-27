defmodule Mix.Tasks.Skf.Gen.Makefile do
  use Mix.Task

  @template Path.join(["skf.gen.makefile", "Makefile"])
  @switches [cloud: :string, docker: :boolean]
  @defaults [cloud: "heroku", docker: true]

  @shortdoc "Generate Makefile"
  def run(args) do
    if Mix.Project.umbrella? do
      Mix.raise "mix phx.gen.json can only be run inside an application directory"
    end

    {opts, parsed, invalid} = OptionParser.parse(args, switches: @switches)

    app = Mix.Project.config[:app]

    bindings = Keyword.merge([app: app], Enum.into(opts, @defaults))

    @template
    |> Skafolder.eval_from_templates(bindings)
    |> Skafolder.generate_file(Path.join([File.cwd!, "Makefile"]))
  end
end
