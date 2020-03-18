defmodule Mix.Tasks.Vbt.Gen.Release do
  @shortdoc "Generate OTP release additional files."
  @moduledoc "Generate OTP release additional files."
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  @template_root "skf.gen.release"

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix vbt.gen.release can only be run inside an application directory")
    end

    bindings = Mix.Vbt.bindings()

    Enum.each(
      ~w/migrate rollback seed check_config/,
      fn bin_file ->
        source = Path.join([@template_root, "bin", "#{bin_file}.sh"])
        destination = Path.join(["rel", "bin", "#{bin_file}.sh"])

        source
        |> Mix.Vbt.eval_from_templates(bindings)
        |> Mix.Vbt.generate_file(destination, args)

        File.chmod!(destination, 0o744)
      end
    )

    Path.join(@template_root, "release.eex")
    |> Mix.Vbt.eval_from_templates(bindings)
    |> Mix.Vbt.generate_file(
      Path.join([File.cwd!(), "lib", Macro.underscore(Mix.Vbt.app_module_name()), "release.ex"]),
      args
    )
  end
end
