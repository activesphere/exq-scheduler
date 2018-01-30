defmodule ExqScheduler.Schedule do
  @default_queue "default"

  defmodule ScheduleOpts do
    defstruct first_at: nil, last_at: nil

    def new(opts) do
      %__MODULE__{
        first_at: Map.get(opts, :first_at),
        last_at: Map.get(opts, :last_at)
      }
    end
  end

  defmodule TimeRange do
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
    @enforce_keys [:job, :time]
    defstruct @enforce_keys

    def new(job, time) do
      %__MODULE__{
        job: job,
        time: time
      }
    end
  end

  alias Exq.Support.Job
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
      job: Map.merge(Job.decode(job), %{args: []}),
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

  def get_jobs(storage_opts, schedule, time_range) do
    get_missed_run_dates(storage_opts, schedule, time_range.t_start)
    |> Enum.concat(get_next_run_dates(schedule.cron, schedule.tz_offset))
    |> Enum.map(&ScheduledJob.new(schedule.job, &1))
  end

  def get_missed_run_dates(storage_opts, schedule, lower_bound_time) do
    now = add_tz(Timex.now(), schedule.tz_offset)

    schedule_last_run_time =
      Storage.get_schedule_last_run_time(storage_opts, schedule)
      |> Timex.parse!("{ISO:Extended:Z}")

    lower_bound_time =
      Utils.get_nearer_date(now, lower_bound_time, schedule_last_run_time)
      |> add_tz(schedule.tz_offset)

    enum = Scheduler.get_previous_run_dates(schedule.cron, now)

    collect_till = &(Timex.compare(&1, lower_bound_time) != -1)
    get_dates(enum, schedule.tz_offset, collect_till)
  end

  def get_previous_run_dates(cron, tz_offset) do
    now = add_tz(Timex.now(), tz_offset)

    Scheduler.get_previous_run_dates(cron, now)
    |> get_dates(tz_offset)
  end

  def get_next_run_dates(cron, tz_offset) do
    now = add_tz(Timex.now(), tz_offset)

    Scheduler.get_next_run_dates(cron, now)
    |> get_dates(tz_offset)
  end

  defp add_tz(time, tz_offset) do
    if tz_offset != nil do
      time |> Timex.add(tz_offset) |> Timex.to_naive_datetime()
    else
      time |> Timex.to_naive_datetime()
    end
  end

  defp get_dates(enum, tz_offset, collect_till \\ nil) do
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
