use Mix.Config

config :exq_scheduler, :storage_opts,
  namespace: "exq:sidekiq-scheduler",
  exq_namespace: "exq"

config :exq_scheduler, :server_opts,
  missed_jobs_threshold_duration: 60 * 60 * 1000,
  time_zone: "Asia/Kolkata"

config :exq_scheduler, :redis,
  spec: %{
    id: :redis_test,
    start: {
      Redix,
      :start_link,
      [[host: "127.0.0.1",
        port: 6379,
        database: 1],
       [name: :redis_test,
        backoff_max: 200,
        backoff_initial: 200]]
    }
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
