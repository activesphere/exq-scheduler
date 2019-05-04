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
      Poison.decode!(serialized, as: %__MODULE__{})
    end

    def encode(job) do
      Poison.encode!(job)
    end
  end

  alias ExqScheduler.Schedule.Utils
  alias ExqScheduler.Storage
  alias Crontab.Scheduler

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
    |> Poison.encode!()
  end

  def get_jobs(storage_opts, schedule, time_range, ref_time) do
    get_missed_run_dates(storage_opts, schedule, time_range.t_start, ref_time)
    |> Enum.reverse()
    |> Enum.map(&ScheduledJob.new(schedule.job, &1))
  end

  def get_missed_run_dates(storage_opts, schedule, lower_bound_time, ref_time) do
    schedule_last_run_time = Storage.get_schedule_last_run_time(storage_opts, schedule)

    lower_bound_time =
      if schedule_last_run_time != nil do
        schedule_last_run_time =
          schedule_last_run_time
          |> Timex.parse!("{ISO:Extended:Z}")

        Utils.get_nearer_date(ref_time, lower_bound_time, schedule_last_run_time)
      else
        lower_bound_time
      end
      |> to_localtime(schedule.timezone)

    enum =
      Scheduler.get_previous_run_dates(schedule.cron, to_localtime(ref_time, schedule.timezone))

    collect_till = &(Timex.compare(&1, lower_bound_time) != -1)
    get_dates(enum, collect_till, schedule.timezone)
  end

  def get_previous_schedule_date(cron, timezone, ref_time) do
    Scheduler.get_previous_run_date!(cron, to_localtime(ref_time, timezone))
    |> to_utc(timezone)
  end

  def get_next_schedule_date(cron, timezone, ref_time) do
    Scheduler.get_next_run_date!(cron, to_localtime(ref_time, timezone))
    |> to_utc(timezone)
  end

  def to_localtime(time, timezone) do
    case Timex.Timezone.convert(time, timezone) do
      %Timex.AmbiguousDateTime{before: time} -> time
      %DateTime{} = time -> time
    end
    |> DateTime.to_naive()
  end

  def to_utc(naive_time, timezone) do
    case Timex.Timezone.resolve(timezone, Timex.to_erl(naive_time), :wall) do
      %DateTime{} = datetime -> datetime
      %Timex.AmbiguousDateTime{before: datetime} -> datetime
    end
    |> Timex.Timezone.convert("Etc/UTC")
  end

  defp get_dates(enum, collect_till, timezone) do
    if collect_till do
      Stream.take_while(enum, collect_till)
    else
      Stream.take(enum, 1)
    end
    |> Enum.map(fn time -> to_utc(time, timezone) end)
  end

  def build_encoded_cron(schedule) do
    Crontab.CronExpression.Composer.compose(schedule.cron)
  end
end
