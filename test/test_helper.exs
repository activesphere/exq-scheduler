ExUnit.start()

require Logger

Redix.start_link([database: 1], name: :redix)

defmodule ExqScheduler.Time do
  @base Timex.to_unix(Timex.now())
  @scale 60 * 60

  def now do
    elapsed = Timex.to_unix(Timex.now()) - @base
    Timex.from_unix(@base + elapsed * @scale)
  end
end

defmodule TestUtils do
  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.TimeRange
  alias ExqScheduler.Storage
  alias ExqScheduler.Storage.Redis
  alias ExqScheduler.Time
  alias Exq.Support.Job
  import ExUnit.Assertions

  def build_schedule(cron) do
    {:ok, job} = %{class: "TestJob"} |> Poison.encode()
    Schedule.new("test_schedule", "test description", cron, job, %{include_metadata: true})
  end

  def build_time_range(now, offset) do
    t_start = now |> Timex.shift(seconds: -offset)
    t_end = now
    %TimeRange{t_start: t_start, t_end: t_end}
  end

  def build_scheduled_jobs(opts, cron, offset, now \\ Time.now()) do
    schedule = build_schedule(cron)
    time_range = build_time_range(now, offset)
    {schedule, Schedule.get_jobs(opts, schedule, time_range)}
  end

  def storage_opts do
    Storage.build_opts(env())
  end

  def env() do
    Application.get_all_env(:exq_scheduler)
  end

  def env(path, value) do
    env()
    |> put_in(path, value)
  end

  def flush_redis do
    "OK" = Redix.command!(:redix, ["FLUSHDB"])
  end

  def assert_job_uniqueness do
    opts = storage_opts()
    queue_name = Storage.queue_key("default", opts)
    jobs = Redix.command!(:redix, ["LRANGE", queue_name, "0", "-1"])
    jobs = Enum.map(jobs, &Job.decode/1)
    assert length(jobs) > 0
    grouped = Enum.group_by(jobs, fn job -> List.first(job.args)["scheduled_at"] end)

    Enum.each(grouped, fn {key, val} ->
      assert(length(val) == 1, "Duplicate job scheduled for #{inspect(key)} #{inspect(val)}")
    end)
  end

  def redis_pid(idx \\ "test") do
    pid = "redis_#{idx}" |> String.to_atom()
    {:ok, _} = Redix.start_link(Keyword.get(env(), :redis), name: pid)
    pid
  end

  def pmap(collection, func) do
    collection
    |> Enum.map(&Task.async(fn -> func.(&1) end))
    |> Enum.map(&Task.await/1)
  end
end
