ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(SkafolderTester.Repo, :manual)
Mox.defmock(VBT.TestAwsClient, for: ExAws.Behaviour)
