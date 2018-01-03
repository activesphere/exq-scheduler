defmodule ExqScheduler.Storage do
  @schedules_key "schedules"
  @default_queue "default"

  defmodule Opts do
    @enforce_keys [:namespace, :exq_namespace, :redis]
    defstruct @enforce_keys

    def new(opts) do
      %__MODULE__{
        namespace: opts[:namespace],
        exq_namespace: opts[:exq_namespace],
        redis: opts[:redis_pid]
      }
    end
  end

  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.Parser
  alias ExqScheduler.Storage.Redis
  alias Exq.Support.Job

  def add_schedule(name, cron, job, opts, storage_opts) do
    val =
      Schedule.new(name, cron, job, opts)
      |> Schedule.encode()

    Redis.hset(storage_opts.redis, build_schedules_key(storage_opts), name, val)
  end

  def get_schedules(storage_opts) do
    schedules_key = build_schedules_key(storage_opts)
    {:ok, keys} = Redis.hkeys(storage_opts.redis, schedules_key)

    Enum.map(keys, fn name ->
      # TODO: opts are being ignored as of now, include them
      {cron, job, _} =
        Redis.hget(storage_opts.redis, schedules_key, name)
        |> Parser.parse_schedule()

      Schedule.new(name, cron, job)
    end)
  end

  def filter_active_jobs(schedules, time_range) do
    Enum.flat_map(schedules, &Schedule.get_jobs(&1, time_range))
  end

  def enqueue_jobs(jobs, storage_opts) do
    Enum.each(jobs, &enqueue_job(&1, storage_opts))
  end

  # TODO: Update schedule.first_run, schedule.last_run
  defp enqueue_job(scheduled_job, storage_opts) do
    {job, time} = {scheduled_job.job, scheduled_job.time}
    queue_name = job.queue || @default_queue

    commands = [
      ["SADD", queues_key(storage_opts), queue_name],
      ["LPUSH", queue_key(queue_name, storage_opts), Job.encode(job)]
    ]

    enqueue_key = build_enqueued_jobs_key(storage_opts)
    Redis.cas(storage_opts.redis, build_compare_key(job, time, enqueue_key), commands)
  end

  defp build_compare_key(job, time, enqueue_key) do
    serialized_job = Job.encode(job)
    time_string = NaiveDateTime.to_string(time)
    [enqueue_key, serialized_job, time_string]
    |> build_key
  end

  defp queues_key(storage_opts) do
    [storage_opts.exq_namespace, "queues"]
    |> build_key
  end

  defp queue_key(queue_name, storage_opts) do
    [storage_opts.exq_namespace, "queues", queue_name]
    |> build_key
  end

  defp build_enqueued_jobs_key(storage_opts) do
    [storage_opts.namespace, "enqueued_jobs"]
    |> build_key
  end

  defp build_schedules_key(storage_opts) do
    [storage_opts.namespace, @schedules_key]
    |> build_key
  end

  defp build_key(list) do
    list
    |> Enum.filter(&(!!&1))
    |> Enum.join(":")
  end
end
