defmodule SkafolderTester.Repo do
  use VBT.Repo,
    otp_app: :skafolder_tester,
    adapter: Ecto.Adapters.Postgres

  @impl Ecto.Repo
  def init(_type, config) do
    config =
      Keyword.merge(
        config,
        url: SkafolderTesterConfig.database_url(),
        pool_size: SkafolderTesterConfig.database_pool_size(),
        ssl: SkafolderTesterConfig.database_ssl()
      )

    {:ok, config}
  end
end
