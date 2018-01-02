defmodule ExqScheduler.Schedule.Parser do
  @cron_map %{
    y: :year,
    M: :month,
    w: :week,
    d: :day,
    h: :hour,
    m: :minute,
    s: :second
  }

  alias Crontab.CronExpression

  def parse_schedule(schedule = %{"cron" => cron_data}) do
    job = schedule
          |> Map.delete("cron")
          |> Poison.encode!
    {hd(cron_data), job, parse_schedule_opts(tl(cron_data))}
  end

  #Let's not support this rufus-scheduler type syntax yet. We'll move schedule parsing elsewhere
  def parse_schedule(schedule = %{"every" => interval}) do
    job = schedule
          |> Map.delete("every")
          |> Poison.encode!
    cron = get_cron(interval)
    {cron, job, parse_schedule_opts(tl(interval))}
  end

  defp parse_schedule_opts([]), do: nil
  defp parse_schedule_opts(opts), do: opts |> hd

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
