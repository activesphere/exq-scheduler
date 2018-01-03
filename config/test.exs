use Mix.Config

config :exq_scheduler, :storage_opts,
  namespace: "exq_scheduler_test",
  exq_namespace: "exq_test"

config :exq_scheduler, :server_opts,
  timeout: 10_000
