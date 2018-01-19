use Mix.Config

config :exq_scheduler, :storage_opts,
  namespace: "exq:sidekiq-scheduler",
  exq_namespace: "exq"

config :exq_scheduler, :server_opts,
  timeout: 10_000,
  prev_offset: 200_000,
  next_offset: 1000,
  time_zone: "Asia/Kolkata"

config :exq_scheduler, :redis,
  host: "127.0.0.1",
  port: 6379,
  database: 0

config :exq_scheduler, :schedules,
  schedule_cron_5m: %{ "description" => "It's a 5 minute schedule",
    "cron" => "* * * * *", "class" => "HardWorker" },
  schedule_cron_10m: %{ "description" => "It's a 10 minute schedule",
    "cron" => "*/2 * * * *", "class" => "HardWorker"}
