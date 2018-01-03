use Mix.Config

config :exq_scheduler, :storage_opts,
  namespace: "exq_scheduler",
  exq_namespace: "exq"

config :exq_scheduler, :server_opts,
  timeout: 10_000

config :exq_scheduler, :redis,
  host: "127.0.0.1",
  port: 6379,
  database: 0

import_config "#{Mix.env}.exs"
