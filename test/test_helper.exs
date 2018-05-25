ExUnit.start(exclude: [:integration])

defmodule ExqScheduler.Time do
  @base DateTime.to_unix(Timex.now(), :microsecond)
  @scale 60 * 60

  def now do
    elapsed = DateTime.to_unix(Timex.now(), :microsecond) - @base
    Timex.from_unix(@base + elapsed * @scale, :microsecond)
  end

  def scale_duration(duration) do
    div(duration, @scale)
  end
end

defmodule TestUtils do
  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.TimeRange
  alias ExqScheduler.Storage
  alias ExqScheduler.Time
  alias ExqScheduler.Schedule.Job
  import ExUnit.Assertions

  def build_schedule(cron) do
    {:ok, job} = %{class: "TestJob"} |> Poison.encode()
    Schedule.new("test_schedule", "test description", cron, job, %{"include_metadata" => true})
  end

  def build_time_range(now, offset) do
    t_start = now |> Timex.shift(seconds: -offset)
    t_end = now
    %TimeRange{t_start: t_start, t_end: t_end}
  end

  def build_scheduled_jobs(opts, cron, offset, now \\ Time.now()) do
    schedule = build_schedule(cron)
    time_range = build_time_range(now, offset)
    {schedule, Schedule.get_jobs(opts, schedule, time_range, now)}
  end

  def build_and_enqueue(cron, offset, now, redis) do
    opts = Storage.build_opts(add_redis_name(env(), redis))
    {schedule, jobs} = build_scheduled_jobs(opts, cron, offset, now)
    Storage.enqueue_jobs(schedule, jobs, opts)
    jobs
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

  def configure_env(env, threshold_duration, schedules) do
    env
    |> put_in([:server_opts, :missed_jobs_threshold_duration], threshold_duration)
    |> put_in([:schedules], schedules)
  end

  def redis_lib(e \\ env()) do
    ExqScheduler.redis_lib(e)
  end

  def flush_redis do
    "OK" = redis_lib().command!(:redix, ["FLUSHDB"])
  end

  def assert_job_uniqueness(jobs \\ get_jobs()) do
    assert length(jobs) > 0
    grouped = Enum.group_by(jobs, fn job -> [job.class, List.first(job.args)["scheduled_at"]] end)

    Enum.each(grouped, fn {key, val} ->
      assert(length(val) == 1, "Duplicate job scheduled for #{inspect(key)} #{inspect(val)}")
    end)
  end

  def redis_pid(idx \\ "test") do
    pid = "redis_#{idx}" |> String.to_atom()
    opts =
      add_redis_name(env(), pid)
      |> ExqScheduler.redix_spec()
      |> get_opts()

    lib = redis_lib(env())
    {:ok, _} = apply(lib, :start_link, opts)
    pid
  end

  def get_opts(spec) do
    spec.start |> elem(2)
  end

  def set_opts(spec, opts) do
    {lib, :start_link, _} = spec.start
    put_in(spec[:start], {lib, :start_link, opts})
  end

  def update_opts(opts, name) do
    [redix_opts | rest_args] = opts |> Enum.reverse()
    redix_opts = put_in(redix_opts[:name], name)
    [redix_opts | rest_args] |> Enum.reverse()
  end

  def add_redis_name(env, name) do
    spec =
      ExqScheduler.redix_spec(env)
      |> put_in([:id], name)
    
    opts = update_opts(get_opts(spec), name)
    spec = set_opts(spec, opts)

    put_in(env[:redis][:spec], spec)
  end

  def pmap(collection, func) do
    collection
    |> Enum.map(&Task.async(fn -> func.(&1) end))
    |> Enum.map(&Task.await/1)
  end

  def get_jobs(class_name \\ nil, queue_name \\ "default") do
    opts = storage_opts()
    get_jobs_from_storage(Storage.queue_key(queue_name, opts))
    |> Enum.filter(fn job -> (class_name == nil) || (job.class == class_name) end)
  end

  defp get_jobs_from_storage(queue_name) do
    redis_lib().command!(:redix, ["LRANGE", queue_name, "0", "-1"])
    |> Enum.map(&Job.decode/1)
  end

  def iso_to_unixtime(date) do
    Timex.parse!(date, "{ISO:Extended:Z}")
    |> Timex.to_unix()
  end

  def schedule_time_from_job(job) do
    List.last(job.args)["scheduled_at"]
  end

  def assert_continuity(jobs, diff) do
    assert length(jobs) > 0, "Jobs list is empty"
    jobs
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map( fn [job1, job2] ->
      t1 = schedule_time_from_job(job1)
      t2 = schedule_time_from_job(job2)
      assert(diff == iso_to_unixtime(t1)-iso_to_unixtime(t2),
        "Failed. job1: #{inspect(job1)} job2: #{inspect(job2)} ")
    end)
  end

  def assert_properties(class, interval, queue_name \\ "default") do
    jobs = get_jobs(class, queue_name)
    assert_job_uniqueness(jobs)
    assert_continuity(jobs, interval)
  end

  def set_scheduler_state(schedule_name, state) do
    schedule_state = %{"enabled" => state}
    redis_lib().command!(
      :redix,
      ["HSET",
       "exq:sidekiq-scheduler:states",
       schedule_name,
       Poison.encode!(schedule_state)
      ]
    )
  end

  def down(service) do
    {:ok, _} = Toxiproxy.update(%{name: service, enabled: false})
  end

  def up(service) do
    {:ok, _} = Toxiproxy.update(%{name: service, enabled: true})
  end
end

defmodule ExqScheduler.Case do
  use ExUnit.CaseTemplate

  setup do
    TestUtils.flush_redis()

    on_exit(fn ->
      TestUtils.flush_redis()
    end)

    :ok
  end
end

test_env = Application.get_all_env(:exq_scheduler)
opts =
  TestUtils.add_redis_name(test_env, :redix)
  |> ExqScheduler.redix_spec()
  |> TestUtils.get_opts()

lib = ExqScheduler.redis_lib(test_env)
{:ok, _} = apply(lib, :start_link, opts)
