defmodule ExqScheduler.Storage do
  # TODO: Sync with Exq config
  @exq_namespace "exq"
  @namespace "exq_scheduler"
  @enqued_jobs_key "#{@namespace}:enqueued_jobs"
  @schedule_key "schedules"
  @default_queue "default"

  alias ExqScheduler.Schedule
  alias ExqScheduler.Storage.Redis
  alias ExqScheduler.Schedule.Parser
  alias Exq.Support.Job

  def add_schedule(name, cron, job, opts) do
    val =
      Schedule.new(name, cron, job, opts)
      |> Schedule.encode()

    Redis.hset(@schedule_key, name, val)
  end

  def get_schedules do
    {:ok, keys} = Redis.hkeys(@schedule_key)

    Enum.map(keys, fn name ->
      # TODO: opts are being ignored as of now, include them
      {cron, job, _} =
        Redis.hget(@schedule_key, name)
        |> Parser.parse_schedule()

      Schedule.new(name, cron, job)
    end)
  end

  def filter_active_jobs(schedules, time_range) do
    Enum.flat_map(schedules, &Schedule.get_jobs(&1, time_range))
  end

  def enqueue_jobs(jobs) do
    Enum.each(jobs, &enqueue_job(&1))
  end

  defp enqueue_job(job_data) do
    {time, job} = {elem(job_data, 0), elem(job_data, 1)}
    queue_name = job.queue || @default_queue

    commands = [
      ["SADD", queues_key(), queue_name],
      ["LPUSH", queue_key(queue_name), Job.encode(job)]
    ]

    Redis.cas(build_compare_key(job, time), commands)
  end

  defp build_compare_key(job, time) do
    serialized_job = Job.encode(job)
    time_string = NaiveDateTime.to_string(time)
    "#{@enqued_jobs_key}:#{serialized_job}:#{time_string}"
  end

  defp queues_key do
    "#{@exq_namespace}:queues"
  end

  defp queue_key(queue_name) do
    "#{@exq_namespace}:queues:#{queue_name}"
  end
end
