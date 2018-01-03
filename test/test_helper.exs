ExUnit.start()

defmodule TestUtils do
  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.TimeRange
  alias ExqScheduler.Storage
  alias ExqScheduler.Storage.Redis

  def build_schedule(cron) do
    {:ok, job} = %{class: "TestJob"} |> Poison.encode()
    Schedule.new("test_schedule", cron, job)
  end

  def build_time_range(offset) do
    t_start = Timex.now() |> Timex.shift(seconds: -offset)
    t_end = Timex.now() |> Timex.shift(seconds: offset)
    %TimeRange{t_start: t_start, t_end: t_end}
  end

  def build_scheduled_jobs do
    schedule = build_schedule("*/2 * * * *")
    time_range = build_time_range(60)
    Schedule.get_jobs(schedule, time_range)
  end

  def storage_opts do
    ExqScheduler.build_opts()[:storage_opts]
  end

  def flush_redis do
    Redis.flushdb(storage_opts().redis)
  end

  def default_queue_job_count do
    opts = storage_opts()
    queue_name = Storage.queue_key("default", opts)
    Redis.queue_len(opts.redis, queue_name)
  end
end
