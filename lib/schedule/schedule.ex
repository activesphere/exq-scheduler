defmodule ExqScheduler.Schedule do
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
    defstruct t_start: nil, t_end: nil

    def new(time, prev_offset, next_offset) do
      %__MODULE__{
        t_start: Timex.shift(time, milliseconds: -prev_offset),
        t_end: Timex.shift(time, milliseconds: next_offset)
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
  alias Crontab.Scheduler

  @enforce_keys [:name, :cron, :job]
  defstruct name: nil,
            cron: nil,
            tz_offset: nil,
            job: nil,
            schedule_opts: nil,
            first_run: nil,
            last_run: nil

  def new(name, cron_str, job, schedule_opts \\ %{}) when is_binary(job) do
    {cron_exp, tz_offset} = Utils.to_cron_exp(cron_str)

    %__MODULE__{
      name: name,
      cron: cron_exp,
      tz_offset: tz_offset,
      job: Job.decode(job),
      schedule_opts: ScheduleOpts.new(schedule_opts)
    }
  end

  def encode(schedule) do
    schedule.job
    |> Map.merge(%{cron: build_encoded_cron(schedule)})
    |> Poison.encode!()
  end

  def get_jobs(schedule, time_range) do
    next_dates = get_next_run_dates(schedule.cron, schedule.tz_offset, time_range.t_end)
    prev_dates = get_previous_run_dates(schedule.cron, schedule.tz_offset, time_range.t_start)

    Enum.concat(prev_dates, next_dates)
    |> Enum.map(&ScheduledJob.new(schedule.job, &1))
  end

  def get_next_run_dates(cron, tz_offset, upper_bound_date) do
    now = add_tz(Timex.now(), tz_offset)
    enum = Crontab.Scheduler.get_next_run_dates(cron, now)
    upper_bound_date = add_tz(upper_bound_date, tz_offset)
    collect_till = &(Timex.compare(&1, upper_bound_date) != 1)
    reduce_dates(enum, collect_till, tz_offset)
  end

  def get_previous_run_dates(cron, tz_offset, lower_bound_date) do
    now = add_tz(Timex.now(), tz_offset)
    enum = Scheduler.get_previous_run_dates(cron, now)
    lower_bound_date = add_tz(lower_bound_date, tz_offset)
    collect_till = &(Timex.compare(&1, lower_bound_date) != -1)
    reduce_dates(enum, collect_till, tz_offset)
  end

  defp add_tz(time, tz_offset) do
    unless tz_offset == nil do
      time |> Timex.add(tz_offset) |> Timex.to_naive_datetime()
    else
      time |> Timex.to_naive_datetime()
    end
  end

  defp reduce_dates(enum, collect_till, tz_offset) do
    dates = Stream.take_while(enum, collect_till) |> Enum.to_list()

    if tz_offset == nil do
      dates
    else
      Enum.map(dates, fn date -> Timex.subtract(date, tz_offset) end)
    end
  end

  defp build_encoded_cron(schedule) do
    [schedule.cron, schedule.schedule_opts]
  end
end
