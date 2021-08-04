defmodule TestUtils do
  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.TimeRange
  alias ExqScheduler.Storage
  alias ExqScheduler.Time
  alias ExqScheduler.Schedule.Job
  alias ExqScheduler.Schedule.Parser
  import ExUnit.Assertions

  def build_schedule(cron) do
    sch = %{cron: cron, class: "TestJob", name: "test_schedule", description: "test description"}

    {description, cron, job, _} =
      Map.merge(Parser.scheduler_defaults(), sch)
      |> Parser.get_schedule()

    Schedule.new("test_schedule", description, cron, job, %{:include_metadata => true})
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
    # 1hour
    Storage.enqueue_jobs(schedule, jobs, opts, Time.scale_duration(offset + 3600))
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
    |> put_in([:missed_jobs_window], threshold_duration)
    |> put_in([:schedules], schedules)
  end

  def redis_module(e \\ env()) do
    ExqScheduler.redis_module(e)
  end

  def flush_redis do
    "OK" = redis_module().command!(:redix, ["FLUSHDB"])
  end

  def assert_job_uniqueness(jobs \\ get_jobs()) do
    assert length(jobs) > 0
    grouped = Enum.group_by(jobs, fn job -> [job.class, scheduled_at(job)] end)

    Enum.each(grouped, fn {[class, time], jobs} ->
      assert(
        length(jobs) == 1,
        "Duplicate jobs scheduled for #{class} at #{time} \n jobs: #{inspect(jobs)}"
      )
    end)
  end

  def redis_pid(idx \\ "test") do
    pid = "redis_#{idx}" |> String.to_atom()

    opts =
      add_redis_name(env(), pid)
      |> ExqScheduler.redix_spec()
      |> get_opts()

    module = redis_module(env())
    {:ok, _} = apply(module, :start_link, opts)
    pid
  end

  def get_opts(spec) do
    spec.start |> elem(2)
  end

  def set_opts(spec, opts) do
    {module, :start_link, _} = spec.start
    put_in(spec[:start], {module, :start_link, opts})
  end

  def update_opts(opts, name) do
    [redix_opts | rest_args] = opts |> Enum.reverse()
    redix_opts = put_in(redix_opts[:name], name)
    [redix_opts | rest_args] |> Enum.reverse()
  end

  def add_redis_name(env, name) do
    env = env |> put_in([:redis, :name], name)
    spec = ExqScheduler.redix_spec(env)

    opts = update_opts(get_opts(spec), name)
    spec = set_opts(spec, opts)

    put_in(env[:redis][:child_spec], spec)
  end

  def add_redis_port(env, port) do
    spec = ExqScheduler.redix_spec(env)

    [opts | rest] = get_opts(spec)
    opts = Keyword.put(opts, :port, port)
    spec = set_opts(spec, [opts | rest])

    put_in(env[:redis][:child_spec], spec)
  end

  def pmap(collection, func) do
    collection
    |> Enum.map(&Task.async(fn -> func.(&1) end))
    |> Enum.map(&Task.await/1)
  end

  def get_jobs(class_name \\ nil, queue_name \\ "default") do
    opts = storage_opts()

    get_jobs_from_storage(Storage.queue_key(queue_name, opts))
    |> Enum.filter(fn job -> class_name == nil || job.class == class_name end)
  end

  defp get_jobs_from_storage(queue_name) do
    redis_module().command!(:redix, ["LRANGE", queue_name, "0", "-1"])
    |> Enum.map(&Job.decode/1)
  end

  def scheduled_at(job) do
    List.last(job.args)["scheduled_at"]
  end

  def job_unixtime(job) do
    trunc(scheduled_at(job))
  end

  def scheduled_at_local(job, timezone) do
    scheduled_at(job)
    |> trunc
    |> Timex.from_unix(:second)
    |> Schedule.utc_to_localtime(timezone)
  end

  def last_scheduled_time(class_name) do
    get_jobs(class_name)
    |> Enum.map(&job_unixtime/1)
    |> Enum.max()
  end

  def assert_continuity(jobs, diff, timezone) do
    assert length(jobs) > 0, "Jobs list is empty"

    jobs
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [job1, job2] ->
      t1 = scheduled_at_local(job1, timezone)
      t2 = scheduled_at_local(job2, timezone)

      assert(
        Timex.diff(t1, t2, :seconds) == diff,
        "Failed. t1: #{inspect(t1)} t2: #{inspect(t2)} expected_diff: #{diff} diff: #{Timex.diff(t1, t2, :seconds)}"
      )
    end)
  end

  def assert_properties(class, interval, queue_name \\ "default") do
    jobs = get_jobs(class, queue_name)
    assert_job_uniqueness(jobs)
    assert_continuity(jobs, interval, Timex.local().time_zone)
  end

  def assert_jobs_properties(jobs, interval, timezone \\ Timex.local().time_zone) do
    assert_job_uniqueness(jobs)
    assert_continuity(jobs, interval, timezone)
  end

  def set_scheduler_state(env, schedule_name, state) do
    schedule_state = %{:enabled => state}
    exq_namespace = get_in(env, [:storage, :exq_namespace])

    redis_module().command!(
      :redix,
      [
        "HSET",
        "#{exq_namespace}:sidekiq-scheduler:states",
        schedule_name,
        Poison.encode!(schedule_state)
      ]
    )
  end

  def schedule_keys(env) do
    exq_namespace = get_in(env, [:storage, :exq_namespace])
    redis_module().command!(:redix, ["KEYS", "#{exq_namespace}:enqueued_jobs:*"])
  end

  def down(service) do
    {:ok, _} = Toxiproxy.update(%{name: service, enabled: false})
  end

  def up(service) do
    {:ok, _} = Toxiproxy.update(%{name: service, enabled: true})
  end

  def utc(time, zone) do
    time
    |> Timex.to_datetime(zone)
    |> Timex.Timezone.convert("Etc/UTC")
  end

  def utc(%DateTime{} = time) do
    Timex.Timezone.convert(time, "Etc/UTC")
  end

  def utc(%NaiveDateTime{} = time) do
    Timex.to_datetime(time, "Etc/UTC")
  end

  def utc(%Timex.AmbiguousDateTime{before: before, after: aft}) do
    %Timex.AmbiguousDateTime{before: utc(before), after: utc(aft)}
  end

  def first(time, zone) do
    %Timex.AmbiguousDateTime{before: before_time} = Timex.to_datetime(time, zone)
    before_time
  end

  def second(time, zone) do
    %Timex.AmbiguousDateTime{after: after_time} = Timex.to_datetime(time, zone)
    after_time
  end
end
