defmodule ExqScheduler.Storage do
  @schedule_key 'schedules'
  @cron_map %{
    y: :year,
    M: :month,
    w: :week,
    d: :day,
    h: :hour,
    m: :minute,
    s: :second
  }

  alias ExqScheduler.Scheduler.Schedule
  alias ExqScheduler.Storage.Redis
  alias Crontab.CronExpression

  def get_schedules() do
    keys = Redis.hkeys(@schedule_key)
    Enum.map(keys, fn(field) ->
      Redis.hget(@schedule_key, field)
      |> parse_schedule |> Schedule.new
    end)
  end

  def get_jobs(window) do
    win_start = elem(window, 0)
    win_end = elem(window, 1)
    IO.puts("Looking for jobs between: #{inspect(win_start)}, #{inspect(win_end)}")
    Enum.map(get_schedules(), &(&1.job))
  end

  def queue_jobs(jobs) do
    IO.puts("QUEUING JOBS: #{inspect(jobs)}")
  end

  defp parse_schedule(schedule = %{"cron" => cron}) do
    job = schedule
          |> Map.delete("cron")
          |> Poison.encode!
    {cron, job}
  end

  #Let's not support this rufus-scheduler type syntax yet. We'll move schedule parsing elsewhere
  defp parse_schedule(schedule = %{"every" => interval}) do
    job = schedule
          |> Map.delete("every")
          |> Poison.encode!
    cron = get_cron(interval)
    {cron, job}
  end

  defp get_cron(interval) when is_list(interval) do
    hd(interval) |> get_cron
  end

  defp get_cron(interval) when is_binary(interval) do
    String.split_at(interval, -1)
    |> get_cron
  end

  defp get_cron(interval) when is_tuple(interval) do
    qty = interval |> elem(0) |> String.to_integer
    period = interval |> elem(1) |> String.to_atom
    sym = Map.get(@cron_map, period)
    struct(CronExpression, [{sym, [qty]}])
    |> CronExpression.Composer.compose
  end
end
