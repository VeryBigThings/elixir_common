use Mix.Config

config :bcrypt_elixir, :log_rounds, 1

config :vbt, :ex_aws_client, VBT.TestAwsClient

# Configure your database
config :skafolder_tester, SkafolderTester.Repo, pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :skafolder_tester, SkafolderTesterWeb.Endpoint, server: false

# Print only warnings and errors during test
config :logger, level: :warn
