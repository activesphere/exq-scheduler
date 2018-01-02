defmodule ExqScheduler.Storage do
  @schedule_key "schedules"

  alias ExqScheduler.Schedule
  alias ExqScheduler.Storage.Redis
  alias ExqScheduler.Schedule.Parser

  def add_schedule(name, cron, job, opts) do
    val = Schedule.new(name, cron, job, opts)
          |> Schedule.encode
    Redis.hset(@schedule_key, name, val)
  end

  def get_schedules do
    {:ok, keys} = Redis.hkeys(@schedule_key)
    Enum.map(keys, fn(name) ->
      {cron, job, _} = Redis.hget(@schedule_key, name)
      |> Parser.parse_schedule
      Schedule.new(name, cron, job)
    end)
  end

  def filter_active_jobs(schedules, time_range) do
    Enum.flat_map(schedules, &Schedule.get_jobs(&1, time_range))
  end

  def queue_jobs(jobs) do
    IO.puts("QUEUING JOBS: #{inspect(jobs)}")
  end
end
