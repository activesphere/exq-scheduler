defmodule ExqScheduler.Schedule do
  @default_queue "default"

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

    def new(time, missed_jobs_threshold_duration) do
      %__MODULE__{
        t_start: Timex.shift(time, milliseconds: -missed_jobs_threshold_duration),
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
      retry: false,
      retry_count: 0,
      processor: nil,
      queue: nil,
      class: nil,
      args: nil,
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
  defstruct name: nil,
            description: nil,
            cron: nil,
            tz_offset: nil,
            job: nil,
            schedule_opts: nil

  def new(name, description, cron_str, job, schedule_opts) when is_binary(job) do
    {cron_exp, tz_offset} = Utils.to_cron_exp(cron_str)

    %__MODULE__{
      name: name,
      description: description,
      cron: cron_exp,
      tz_offset: tz_offset,
      job: Job.decode(job),
      schedule_opts: ScheduleOpts.new(schedule_opts)
    }
  end

  def encode(schedule) do
    schedule.job
    |> Map.merge(%{
      :description => schedule.description,
      :tz_offset => schedule.tz_offset,
      :queue => schedule.job.queue || @default_queue
    })
    |> Map.merge(%{cron: build_encoded_cron(schedule)})
    |> Poison.encode!()
  end

  def get_jobs(storage_opts, schedule, time_range, ref_time) do
    get_missed_run_dates(storage_opts, schedule, time_range.t_start, ref_time)
    |> Enum.reverse
    |> Enum.map(&ScheduledJob.new(schedule.job, &1))
  end

  def get_missed_run_dates(storage_opts, schedule, lower_bound_time, ref_time) do
    now = ref_time |> Timex.to_naive_datetime()
    schedule_last_run_time = Storage.get_schedule_last_run_time(storage_opts, schedule)
    
    lower_bound_time =
      if schedule_last_run_time != nil do
        schedule_last_run_time =
          schedule_last_run_time
          |> Timex.parse!("{ISO:Extended:Z}")

        Utils.get_nearer_date(now, lower_bound_time, schedule_last_run_time)
      else
        lower_bound_time
      end
      |> add_tz(schedule.tz_offset)

    now = add_tz(now, schedule.tz_offset)
    enum = Scheduler.get_previous_run_dates(schedule.cron, now)

    collect_till = &(Timex.compare(&1, lower_bound_time) != -1)
    get_dates(enum, schedule.tz_offset, collect_till)
  end

  def get_previous_schedule_date(cron, tz_offset, ref_time) do
    now = add_tz(ref_time, tz_offset)

    Scheduler.get_previous_run_date!(cron, now)
    |> Timex.subtract(tz_offset)
  end

  def get_next_schedule_date(cron, tz_offset, ref_time) do
    now = add_tz(ref_time, tz_offset)

    Scheduler.get_next_run_date!(cron, now)
    |> Timex.subtract(tz_offset)
  end

  defp add_tz(time, tz_offset) do
    if tz_offset != nil do
      time |> Timex.add(tz_offset) |> Timex.to_naive_datetime()
    else
      time |> Timex.to_naive_datetime()
    end
  end

  defp get_dates(enum, tz_offset, collect_till) do
    dates =
      if collect_till do
        Stream.take_while(enum, collect_till) |> Enum.to_list()
      else
        Stream.take(enum, 1) |> Enum.to_list()
      end

    Enum.map(dates, fn date -> Timex.subtract(date, tz_offset) end)
  end

  defp build_encoded_cron(schedule) do
    [
      Crontab.CronExpression.Composer.compose(schedule.cron),
      schedule.schedule_opts
    ]
  end
end
