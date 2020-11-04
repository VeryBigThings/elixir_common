defmodule SkafolderTester.Repo do
  use VBT.Repo,
    otp_app: :skafolder_tester,
    adapter: Ecto.Adapters.Postgres

  @impl Ecto.Repo
  def init(_type, config) do
    config =
      Keyword.merge(
        config,
        url: SkafolderTesterConfig.db_url(),
        pool_size: SkafolderTesterConfig.db_pool_size(),
        ssl: SkafolderTesterConfig.db_ssl()
      )

    {:ok, config}
  end
end
