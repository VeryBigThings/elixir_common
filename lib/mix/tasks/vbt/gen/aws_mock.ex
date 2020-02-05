defmodule Mix.Tasks.Vbt.Gen.AwsMock do
  @shortdoc "Generate ex_aws mocking code."
  @moduledoc "Generate ex_aws mocking code."

  # credo:disable-for-this-file Credo.Check.Readability.Specs
  use Mix.Task

  alias Mix.Vbt.{ConfigFile, MixFile, SourceFile}

  def run(_args) do
    SourceFile.load!("mix.exs")
    |> MixFile.append_config(:deps, ~s/{:mox, "~> 0.5", only: :test}/)
    |> SourceFile.store!()

    SourceFile.load!("config/test.exs")
    |> ConfigFile.add_new_config("config :vbt, :ex_aws_client, VBT.TestAwsClient\n")
    |> SourceFile.store!()

    SourceFile.load!("test/test_helper.exs")
    |> SourceFile.append("Mox.defmock(VBT.TestAwsClient, for: ExAws.Behaviour)")
    |> SourceFile.store!()
  end
end
