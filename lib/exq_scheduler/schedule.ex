defmodule ExqScheduler.Schedule do
  defmodule ScheduleOpts do
    @moduledoc false
    defstruct enabled: nil, include_metadata: nil

    def new(opts) do
      %__MODULE__{
        enabled: Map.get(opts, :enabled, true),
        include_metadata: Map.get(opts, :include_metadata, false)
      }
    end
  end

  defmodule TimeRange do
    @moduledoc false
    @enforce_keys [:t_start, :t_end]
    defstruct @enforce_keys

    def new(time, missed_jobs_window) do
      %__MODULE__{
        t_start: Timex.shift(time, milliseconds: -missed_jobs_window),
        t_end: time
      }
    end
  end

  defmodule ScheduledJob do
    @moduledoc false
    @enforce_keys [:job, :time]
    defstruct @enforce_keys

    def new(job, time) do
      %__MODULE__{
        job: job,
        time: time
      }
    end
  end

  defmodule Job do
    @moduledoc """
    Serializable Job format used by Exq
    """
    alias ExqScheduler.Serializer

    defstruct error_message: nil,
              error_class: nil,
              failed_at: nil,
              retry: true,
              retry_count: 0,
              processor: nil,
              queue: nil,
              class: nil,
              args: [],
              jid: nil,
              finished_at: nil,
              enqueued_at: nil

    def decode(serialized) do
      struct(__MODULE__, Serializer.decode!(serialized))
    end

    def encode(%{__struct__: _} = job) do
      Serializer.encode!(Map.from_struct(job))
    end

    def encode(job) do
      Serializer.encode!(job)
    end
  end

  alias ExqScheduler.Schedule.Utils
  alias ExqScheduler.Serializer
  alias ExqScheduler.Storage
  alias Crontab.Scheduler
  alias Timex.{AmbiguousDateTime, Timezone}

  @enforce_keys [:name, :cron, :job]
  defstruct [:name, :description, :cron, :timezone, :job, :schedule_opts]

  def new(name, description, cron_str, job, schedule_opts) when is_binary(job) do
    {cron_exp, timezone} = Utils.to_cron_exp(cron_str)

    %__MODULE__{
      name: name,
      description: description,
      cron: cron_exp,
      timezone: timezone,
      job: Job.decode(job),
      schedule_opts: ScheduleOpts.new(schedule_opts)
    }
  end

  def encode(schedule) do
    include_keys = [
      :description,
      :queue,
      :class,
      :name,
      :cron,
      :args,
      :include_metadata,
      :enabled,
      :retry
    ]

    Map.merge(schedule, schedule.job)
    |> Map.merge(schedule.schedule_opts)
    |> Map.put(:cron, build_encoded_cron(schedule))
    |> Map.take(include_keys)
    |> Serializer.encode!()
  end

  def get_jobs(storage_opts, schedule, time_range, ref_time) do
    get_missed_run_dates(storage_opts, schedule, time_range.t_start, ref_time)
    |> Enum.reverse()
    |> Enum.map(&ScheduledJob.new(schedule.job, &1))
  end

  def get_missed_run_dates(storage_opts, schedule, lower_bound_time, ref_time) do
    schedule_last_run_time = Storage.get_schedule_last_run_time(storage_opts, schedule)

    local_lower_bound_time =
      if schedule_last_run_time != nil do
        schedule_last_run_time =
          schedule_last_run_time
          |> Timex.parse!("{ISO:Extended:Z}")

        Utils.get_nearer_date(ref_time, lower_bound_time, schedule_last_run_time)
      else
        lower_bound_time
      end
      |> utc_to_localtime(schedule.timezone)

    Scheduler.get_previous_run_dates(schedule.cron, utc_to_localtime(ref_time, schedule.timezone))
    |> Enum.take_while(&gte(&1, local_lower_bound_time))
  end

  def get_previous_schedule_date(cron, timezone, ref_time) do
    Scheduler.get_previous_run_date!(cron, utc_to_localtime(ref_time, timezone))
    |> nearer_lesser_time(timezone, ref_time)
  end

  def get_next_schedule_date(cron, timezone, ref_time) do
    Scheduler.get_next_run_date!(cron, utc_to_localtime(ref_time, timezone))
    |> nearer_greater_time(timezone, ref_time)
  end

  def utc_to_localtime(time, timezone) do
    Timezone.convert(time, timezone)
    |> DateTime.to_naive()
  end

  def local_to_utc(naive_time, timezone) do
    case Timezone.resolve(timezone, Timex.to_erl(naive_time), :wall) do
      %DateTime{} = time ->
        Timezone.convert(time, "Etc/UTC")

      %AmbiguousDateTime{} = time ->
        %AmbiguousDateTime{
          before: Timezone.convert(time.before, "Etc/UTC"),
          after: Timezone.convert(time.after, "Etc/UTC")
        }
    end
  end

  def nearer_lesser_time(time, timezone, ref_time) do
    local_to_utc(time, timezone)
    |> case do
      %AmbiguousDateTime{} = time ->
        if lte(time.after, ref_time), do: time.after, else: time.before

      time ->
        time
    end
  end

  defp nearer_greater_time(time, timezone, ref_time) do
    local_to_utc(time, timezone)
    |> case do
      %AmbiguousDateTime{} = time ->
        if gte(time.before, ref_time), do: time.before, else: time.after

      time ->
        time
    end
  end

  def gte(a, b), do: !Timex.before?(a, b)

  def lte(a, b), do: !Timex.after?(a, b)

  def build_encoded_cron(schedule) do
    Crontab.CronExpression.Composer.compose(schedule.cron)
  end
end
