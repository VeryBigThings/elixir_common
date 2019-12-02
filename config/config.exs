use Mix.Config

config :stream_data,
  max_runs: if(System.get_env("CI"), do: 100, else: 10)

config :vbt, VBT.Mailer, adapter: Bamboo.TestAdapter
