defmodule ExqScheduler.Storage do
  @moduledoc false
  @schedules_key "schedules"
  @schedule_states_key "states"
  @schedule_prev_times_key "last_times"
  @schedule_next_times_key "next_times"
  @schedule_first_runs_key "first_runs"
  @schedule_last_runs_key "last_runs"

  alias ExqScheduler.Serializer

  defmodule Opts do
    @moduledoc false
    @enforce_keys [:namespace, :exq_namespace, :name, :module]
    defstruct @enforce_keys

    def new(opts) do
      %__MODULE__{
        namespace: "#{opts[:exq_namespace]}:sidekiq-scheduler",
        exq_namespace: opts[:exq_namespace],
        name: opts[:name],
        module: opts[:module]
      }
    end
  end

  alias ExqScheduler.Schedule.Parser
  alias ExqScheduler.Storage.Redis
  alias ExqScheduler.{Storage, Schedule, Time}
  alias ExqScheduler.Schedule.{Job, ScheduledJob, Utils}
  require Logger

  def persist_schedule(schedule, storage_opts) do
    val = Schedule.encode(schedule)
    _ = Redis.hset(storage_opts, build_schedules_key(storage_opts), schedule.name, val)

    schedule_state =
      %{enabled: schedule.schedule_opts.enabled}
      |> Serializer.encode!()

    Redis.hset(
      storage_opts,
      build_schedule_states_key(storage_opts),
      schedule.name,
      schedule_state
    )
  end

  def build_opts(env) do
    Keyword.get(env, :storage)
    |> Keyword.put(:name, ExqScheduler.Utils.redis_name(env))
    |> Keyword.put(:module, ExqScheduler.Utils.redis_module(env))
    |> Storage.Opts.new()
  end

  def persist_schedule_times(schedules, storage_opts, ref_time) do
    Enum.each(schedules, fn schedule ->
      prev_time =
        Schedule.get_previous_schedule_date(schedule.cron, schedule.timezone, ref_time)
        |> Serializer.encode!()

      Redis.hset(
        storage_opts,
        build_schedule_times_key(storage_opts, :prev),
        schedule.name,
        prev_time
      )

      next_time =
        Schedule.get_next_schedule_date(schedule.cron, schedule.timezone, ref_time)
        |> Serializer.encode!()

      Redis.hset(
        storage_opts,
        build_schedule_times_key(storage_opts, :next),
        schedule.name,
        next_time
      )

      now = ref_time |> Timex.to_naive_datetime() |> Serializer.encode!()

      schedule_first_run = get_schedule_first_run_time(storage_opts, schedule)

      if schedule_first_run == nil do
        Redis.hset(
          storage_opts,
          build_schedule_runs_key(storage_opts, :first),
          schedule.name,
          now
        )
      end

      Redis.hset(
        storage_opts,
        build_schedule_runs_key(storage_opts, :last),
        schedule.name,
        now
      )
    end)
  end

  def load_schedules_config(env) do
    schedule_conf_list = Keyword.get(env, :schedules)

    if is_nil(schedule_conf_list) or Enum.empty?(schedule_conf_list) do
      []
    else
      Enum.map(schedule_conf_list, fn {name, schedule_conf} ->
        map_to_schedule(name, schedule_conf)
      end)
    end
  end

  def schedule_from_storage(name, storage_opts) do
    storage_sch =
      Redis.hget(storage_opts, build_schedules_key(storage_opts), name)
      |> Parser.convert_keys()
      |> Utils.remove_nils()

    storage_sch_state =
      Redis.hget(storage_opts, build_schedule_states_key(storage_opts), name)
      |> Parser.convert_keys()
      |> Utils.remove_nils()

    Parser.scheduler_defaults()
    |> Map.merge(storage_sch)
    |> Map.merge(storage_sch_state)
  end

  def map_to_schedule(name, schedule) do
    {description, cron, job, opts} = Parser.get_schedule(schedule)
    Schedule.new(name, description, cron, job, opts)
  end

  def get_schedule_last_run_time(storage_opts, schedule) do
    last_run_time =
      Redis.hget(
        storage_opts,
        build_schedule_runs_key(storage_opts, :last),
        schedule.name
      )

    if last_run_time != nil do
      last_run_time
      |> Timex.parse!("{ISO:Extended:Z}")
      |> Timex.to_datetime("Etc/UTC")
    end
  end

  def get_schedule_first_run_time(storage_opts, schedule) do
    Redis.hget(
      storage_opts,
      build_schedule_runs_key(storage_opts, :first),
      schedule.name
    )
  end

  def is_schedule_enabled?(storage_opts, schedule) do
    schedule_state =
      Redis.hget(
        storage_opts,
        build_schedule_states_key(storage_opts),
        schedule.name
      )

    if schedule_state != nil do
      Map.fetch!(schedule_state, "enabled") == true
    else
      # By default the schedule will always be enabled, so we return true
      # if the entry does not exist.
      true
    end
  end

  def enable_schedule(storage_opts, schedule, enable?) do
    schedule_state =
      %{enabled: enable?}
      |> Serializer.encode!()

    Redis.hset(
      storage_opts,
      build_schedule_states_key(storage_opts),
      schedule.name,
      schedule_state
    )
  end

  def storage_connected?(storage_opts) do
    Redis.connected?(storage_opts)
  end

  def get_schedule_names(storage_opts) do
    schedules_key = build_schedules_key(storage_opts)
    Redis.hkeys(storage_opts, schedules_key)
  end

  def filter_active_schedules(storage_opts, schedules, time_range, ref_time) do
    Enum.filter(schedules, &Storage.is_schedule_enabled?(storage_opts, &1))
    |> Enum.map(&{&1, Schedule.get_jobs(storage_opts, &1, time_range, ref_time)})
  end

  def enqueue_jobs(schedule, jobs, storage_opts, key_expire_duration) do
    Enum.each(jobs, &enqueue_job(schedule, &1, storage_opts, key_expire_duration))
  end

  def queue_key(queue_name, storage_opts) do
    [storage_opts.exq_namespace, "queue", queue_name]
    |> build_key
  end

  def enqueue_now(storage_opts, schedule) do
    {commands, _, _} =
      Storage.build_job_commands(
        storage_opts,
        schedule,
        schedule.job,
        DateTime.utc_now() |> Utils.encode_to_epoc()
      )

    Redis.multi(storage_opts, commands)
  end

  # TODO: Update schedule.first_run, schedule.last_run
  defp enqueue_job(schedule, scheduled_job, storage_opts, key_expire_duration) do
    %ScheduledJob{job: job, time: localtime} = scheduled_job

    schedule_unix_time =
      Schedule.local_to_utc(localtime, schedule.timezone)
      |> case do
        %Timex.AmbiguousDateTime{before: time} -> time
        time -> time
      end
      |> Utils.encode_to_epoc()

    {commands, job, job_without_id} =
      build_job_commands(storage_opts, schedule, job, schedule_unix_time)

    enqueue_key = build_enqueued_jobs_key(storage_opts)
    lock = build_lock_key(job_without_id, localtime, enqueue_key)

    response =
      Redis.cas(
        storage_opts,
        lock,
        key_expire_duration,
        commands
      )

    # Log only if job is enqueued
    if length(response) > 1 do
      Logger.info(
        "Enqueued a job  #{log_str(job, :class)} #{log_str(job, :queue)} #{log_str(job, :enqueued_at)} #{log_str(job, :args)}"
      )
    end
  end

  def build_job_commands(storage_opts, schedule, job, schedule_unix_time) do
    job_without_id =
      if schedule.schedule_opts.include_metadata == true do
        metadata = %{scheduled_at: schedule_unix_time}

        args = job.args

        args =
          cond do
            is_list(args) -> List.insert_at(args, -1, metadata)
            is_nil(args) -> [metadata]
            true -> args
          end

        %Job{job | args: args}
      else
        job
      end

    queue_name = job.queue

    job =
      Map.put(job_without_id, :jid, UUID.uuid4())
      |> Map.put(:enqueued_at, Timex.to_unix(Time.now()))

    commands = [
      ["SADD", queues_key(storage_opts), queue_name],
      ["LPUSH", queue_key(queue_name, storage_opts), Job.encode(job)]
    ]

    {commands, job, job_without_id}
  end

  defp log_str(map, key) do
    "#{key}: #{inspect(Map.get(map, key))}"
  end

  defp build_lock_key(job, time, enqueue_key) do
    serialized_job = Job.encode(job)
    md5 = :crypto.hash(:md5, serialized_job) |> Base.encode16()
    time_string = NaiveDateTime.to_string(time)

    [enqueue_key, md5, time_string]
    |> build_key
  end

  defp queues_key(storage_opts) do
    [storage_opts.exq_namespace, "queues"]
    |> build_key
  end

  defp build_enqueued_jobs_key(storage_opts) do
    [storage_opts.exq_namespace, "enqueued_jobs"]
    |> build_key
  end

  defp build_schedules_key(storage_opts) do
    [storage_opts.exq_namespace, @schedules_key]
    |> build_key
  end

  defp build_schedule_states_key(storage_opts) do
    [storage_opts.namespace, @schedule_states_key]
    |> build_key
  end

  defp build_schedule_times_key(storage_opts, :prev) do
    [storage_opts.namespace, @schedule_prev_times_key]
    |> build_key
  end

  defp build_schedule_times_key(storage_opts, :next) do
    [storage_opts.namespace, @schedule_next_times_key]
    |> build_key
  end

  defp build_schedule_runs_key(storage_opts, :first) do
    [storage_opts.namespace, @schedule_first_runs_key]
    |> build_key
  end

  defp build_schedule_runs_key(storage_opts, :last) do
    [storage_opts.namespace, @schedule_last_runs_key]
    |> build_key
  end

  defp build_key(list) do
    list
    |> Enum.filter(&(!!&1))
    |> Enum.join(":")
  end
end
