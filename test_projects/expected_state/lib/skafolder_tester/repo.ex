defmodule SkafolderTester.Repo do
  use Ecto.Repo,
    otp_app: :skafolder_tester,
    adapter: Ecto.Adapters.Postgres

  @db_url_env if Mix.env() == :test,
                do: "TEST_DATABASE_URL",
                else: "DATABASE_URL"

  @impl Ecto.Repo
  def init(_type, config) do
    config =
      Keyword.merge(
        config,
        url: System.fetch_env!(@db_url_env),
        pool_size: String.to_integer(System.fetch_env!("DATABASE_POOL_SIZE")),
        ssl: System.fetch_env!("DATABASE_SSL") == "true"
      )

    {:ok, config}
  end
end
