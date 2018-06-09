use Mix.Config

config :logger, level: :warn

config :exq_scheduler,
  missed_jobs_window: 60 * 60 * 1000,
  time_zone: "Asia/Kolkata"

config :exq_scheduler, :storage, exq_namespace: "exq"

config :exq_scheduler, :redis,
  name: ExqScheduler.Redis.Client,
  child_spec: {
    Redix,
    [
      [host: "127.0.0.1", port: 6379, database: 1],
      [name: ExqScheduler.Redis.Client, backoff_max: 200, backoff_initial: 200]
    ]
  }

config :exq_scheduler, :schedules,
  schedule_cron_1m: %{
    description: "It's a 1 minute schedule",
    cron: "* * * * *",
    class: "HardWorker1",
    include_metadata: true
  },
  schedule_cron_2m: %{
    description: "It's 2 minute schedule",
    cron: "*/2 * * * *",
    class: "HardWorker2",
    include_metadata: true
  }

config :exq_scheduler, start_on_application: false
