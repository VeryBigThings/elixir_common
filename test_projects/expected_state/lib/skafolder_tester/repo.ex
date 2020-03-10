defmodule SkafolderTester.Repo do
  use Ecto.Repo,
    otp_app: :skafolder_tester,
    adapter: Ecto.Adapters.Postgres

  @impl Ecto.Repo
  def init(_type, config) do
    config =
      Keyword.merge(
        config,
        url: SkafolderTester.Config.db_url(),
        pool_size: SkafolderTester.Config.db_pool_size(),
        ssl: SkafolderTester.Config.db_ssl()
      )

    {:ok, config}
  end
end
