defmodule ExqScheduler.Storage do
  @schedule_key 'schedules'

  alias ExqScheduler.Schedule
  alias ExqScheduler.Storage.Redis
  alias ExqScheduler.Schedule.Parser

  def add_schedule(name, cron, job, opts) do
    val = Schedule.new(name, {cron, job}, opts)
          |> Schedule.encode
    Redis.hset(@schedule_key, name, val)
  end

  def get_schedules do
    keys = Redis.hkeys(@schedule_key)
    Enum.map(keys, fn(field) ->
      {cron, job} = Redis.hget(@schedule_key, field)
      |> Parser.parse_schedule
      Schedule.new(field, {cron, job})
    end)
  end

  def filter_active_jobs(window, schedules) do
    win_start = elem(window, 0)
    win_end = elem(window, 1)
    IO.puts("Looking for active jobs between: #{inspect(win_start)}, #{inspect(win_end)}")
    Enum.map(schedules, &(&1.job))
  end

  def queue_jobs(jobs) do
    IO.puts("QUEUING JOBS: #{inspect(jobs)}")
  end
end
