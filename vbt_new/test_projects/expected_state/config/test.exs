use Mix.Config

config :sentry, client: SkafolderTesterTest.SentryClient

config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :skafolder_tester, SkafolderTester.Repo, pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :skafolder_tester, SkafolderTesterWeb.Endpoint, server: false

# Print only warnings and errors during test
config :logger, level: :warn
