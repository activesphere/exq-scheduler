use Mix.Config

config :exq_scheduler, :storage_opts,
  namespace: "exq_scheduler_test",
  exq_namespace: "exq_test"

config :exq_scheduler, :server_opts,
  timeout: 10_000

config :exq_scheduler, :redis,
  host: "127.0.0.1",
  port: 6379,
  database: 1
