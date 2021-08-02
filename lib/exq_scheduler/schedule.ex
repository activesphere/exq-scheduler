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
      # Deserialize to a plain map w/ string keys
      deserialized = Serializer.decode!(serialized)
      # Convert all top-level keys to atoms
      params =
        deserialized
        |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)

      # Convert to struct
      struct(__MODULE__, params)
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
          |> Timex.to_datetime("Etc/UTC")

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
    time
    |> Timex.Timezone.convert(timezone)
    |> DateTime.to_naive()
  end

  def local_to_utc(naive_time, timezone) do
    case Timex.to_datetime(naive_time, timezone) do
      {:error, {:could_not_resolve_timezone, _, seconds, :wall}} ->
        # This occurs when the naive time we are trying to convert is not a valid
        # wall clock time in the target timezone. To address this, we have to manually
        # resolve the timezone period using the UTC clock, which should produce exactly
        # one result period
        tzinfo = Timezone.resolve(timezone, seconds, :utc)

        case Timezone.convert(naive_time, tzinfo) do
          %AmbiguousDateTime{before: a, after: b} ->
            %AmbiguousDateTime{
              before: Timezone.convert(a, "Etc/UTC"),
              after: Timezone.convert(b, "Etc/UTC")
            }
            |> maybe_coalesce()

          datetime ->
            datetime
        end

      %AmbiguousDateTime{before: a, after: b} ->
        %AmbiguousDateTime{
          before: Timezone.convert(a, "Etc/UTC"),
          after: Timezone.convert(b, "Etc/UTC")
        }
        |> maybe_coalesce()

      datetime ->
        Timezone.convert(datetime, "Etc/UTC")
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

  def nearer_greater_time(time, timezone, ref_time) do
    local_to_utc(time, timezone)
    |> case do
      %AmbiguousDateTime{} = time ->
        if gte(time.before, ref_time), do: time.before, else: time.after

      time ->
        time
    end
  end

  # In cases where there is a timezone gap, the `before` date/time is the last valid
  # date/time in the previous zone, i.e. it has a time of HH:59:59.999999. When converting
  # both before/after to UTC, the two may converge to essentially the same point in time,
  # i.e. they have a difference of exactly 1 microsecond. In this situation we can not only
  # automatically resolve the ambiguity, but we want to select the `after` date/time, as it
  # will hold the canonical date/time that is expected, whereas `before` will have the clock
  # time as shown above, which is not what we generally want
  defp maybe_coalesce(%AmbiguousDateTime{before: a, after: b} = amb) do
    case Timex.to_gregorian_microseconds(a) - Timex.to_gregorian_microseconds(b) do
      n when n in [-1, 0, 1] ->
        b

      _ ->
        amb
    end
  end

  defp maybe_coalesce(datetime), do: datetime

  def gte(a, b), do: Timex.compare(a, b) in [1, 0]

  def lte(a, b), do: Timex.compare(a, b) in [-1, 0]

  def build_encoded_cron(schedule) do
    Crontab.CronExpression.Composer.compose(schedule.cron)
  end
end
