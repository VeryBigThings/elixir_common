# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :skafolder_tester, SkafolderTester.Repo,
  adapter: Ecto.Adapters.Postgres,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec],
  otp_app: :skafolder_tester

config :skafolder_tester, ecto_repos: [SkafolderTester.Repo], generators: [binary_id: true]

# Configures the endpoint
config :skafolder_tester, SkafolderTesterWeb.Endpoint,
  render_errors: [view: SkafolderTesterWeb.ErrorView, accepts: ["json"]],
  pubsub: [name: SkafolderTester.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
