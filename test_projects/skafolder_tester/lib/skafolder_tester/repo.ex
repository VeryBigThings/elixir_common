defmodule SkafolderTester.Repo do
  use Ecto.Repo,
    otp_app: :skafolder_tester,
    adapter: Ecto.Adapters.Postgres
end
