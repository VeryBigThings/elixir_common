use Mix.Config

if Mix.env() == :test do
  config :phoenix, :json_library, Jason
  config :stream_data, max_runs: if(System.get_env("CI"), do: 100, else: 10)
  config :vbt, VBT.Mailer, adapter: Bamboo.TestAdapter
  config :vbt, VBT.GraphqlServer, server: false
end
