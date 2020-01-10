use Mix.Config

if Mix.env() == :test do
  config :logger, level: :warn
  config :phoenix, :json_library, Jason
  config :stream_data, max_runs: if(System.get_env("CI"), do: 100, else: 10)
  config :vbt, VBT.TestMailer, adapter: Bamboo.TestAdapter

  config :vbt, VBT.GraphqlServer,
    server: false,
    secret_key_base: String.duplicate("0", 64),
    pubsub: [name: VBT.PubSub, adapter: Phoenix.PubSub.PG2]
end
