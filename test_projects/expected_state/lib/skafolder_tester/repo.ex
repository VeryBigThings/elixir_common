defmodule SkafolderTester.Repo do
  use Ecto.Repo,
    otp_app: :skafolder_tester,
    adapter: Ecto.Adapters.Postgres

  @impl Ecto.Repo
  def init(_type, config) do
    config =
      Keyword.merge(
        config,
        url: SkafolderTester.OperatorConfig.db_url(),
        pool_size: SkafolderTester.OperatorConfig.db_pool_size(),
        ssl: SkafolderTester.OperatorConfig.db_ssl()
      )

    {:ok, config}
  end
end
