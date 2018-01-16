use Mix.Config

config :exq_scheduler, :storage_opts,
  namespace: "exq_scheduler_test",
  exq_namespace: "exq_test"

config :exq_scheduler, :server_opts,
  timeout: 10_000,
  prev_offset: 200_000,
  next_offset: 1000,
  time_zone: "Asia/Kolkata"

config :exq_scheduler, :redis,
  host: "127.0.0.1",
  port: 6379,
  database: 1

config :exq_scheduler, :schedules,
  schedule_cron_5m: %{ "cron" => "5 * * * *", "class" => "ExqWorker" },
  schedule_cron_10m: %{ "cron" => "10 * * * *", "class" => "ExqWorker"}
