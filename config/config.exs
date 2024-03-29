use Mix.Config

config :phoenix, :json_library, Jason
config :ex_aws, json_codec: Jason

if Mix.env() == :test do
  config :logger, level: :warn
  config :phoenix, :json_library, Jason
  config :stream_data, max_runs: if(System.get_env("CI"), do: 100, else: 10)

  config :vbt, VBT.GraphqlServer,
    server: false,
    secret_key_base: String.duplicate("0", 64),
    pubsub_server: VBT.GraphqlServer.PubSub

  config :vbt, ecto_repos: [VBT.TestRepo]

  config :bcrypt_elixir, :log_rounds, 4
end
