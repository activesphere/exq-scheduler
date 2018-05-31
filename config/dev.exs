use Mix.Config

config :exq_scheduler, :storage_opts,
  exq_namespace: "exq"

config :exq_scheduler, :server_opts,
  missed_jobs_threshold_duration: 100_000,
  time_zone: "Asia/Kolkata"

config :exq_scheduler, :redis,
  name: ExqScheduler.Redis.Client,
  child_spec: {
    Redix,
    [
      [host: "127.0.0.1", port: 6379, database: 0],
      [name: ExqScheduler.Redis.Client, backoff_max: 1000, backoff_initial: 1000]
    ]
  }

config :exq_scheduler, :schedules,
  schedule_cron_1m: %{
    :description => "It's a 1 minute schedule",
    :cron => "* * * * *",
    :class => "HardWorker"
  },
  schedule_cron_2m: %{
    :description => "It's 2 minute schedule",
    :cron => "*/2 * * * *",
    :class => "HardWorker"
  }
