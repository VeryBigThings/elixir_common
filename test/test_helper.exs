Ecto.Adapters.SQL.Sandbox.mode(VBT.TestRepo, :manual)
Mox.defmock(VBT.TestAwsClient, for: ExAws.Behaviour)
Application.ensure_all_started(:credo)
ExUnit.start()
