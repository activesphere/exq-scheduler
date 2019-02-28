use Mix.Config

config :exq,
  name: Exq,
  host: "127.0.0.1",
  port: 6379,
  namespace: "exq",
  concurrency: 500,
  queues: ["default"]

config :exq_scheduler,
  missed_jobs_window: 100_000
  max_timeout: 60_000

config :exq_scheduler, :storage,
  exq_namespace: "exq"

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
  best_scheduler: %{
    description: "Best scheduler ever!",
    cron: "* * * * *",
    class: "BestWorker",
    args: []
  }
