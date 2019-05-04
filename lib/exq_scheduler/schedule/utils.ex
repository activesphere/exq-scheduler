defmodule ExqScheduler.Schedule.Utils do
  @moduledoc false
  alias Crontab.CronExpression, as: Cron

  def get_elem(arr, index, default \\ "") do
    if arr not in [nil, []] do
      Enum.at(arr, index)
    else
      default
    end
  end

  def str_to_float(numstr, default \\ 0) do
    if numstr == "" do
      default
    else
      Float.parse(numstr) |> elem(0)
    end
  end

  def str_to_int(numstr, default \\ 0) do
    if numstr == "" do
      default
    else
      Integer.parse(numstr) |> elem(0)
    end
  end

  def to_cron_exp(cron_str) do
    timezone = get_timezone(cron_str)

    cron_exp =
      strip_timezone(cron_str)
      |> Cron.Parser.parse!()

    {cron_exp, timezone}
  end

  def strip_timezone(cron_str) do
    cron_splitted = String.split(cron_str, " ")
    last_part = List.last(cron_splitted)

    if Timex.Timezone.exists?(last_part) do
      cron_splitted |> List.delete_at(-1) |> Enum.join(" ")
    else
      cron_str
    end
  end

  def get_timezone(cron_str) do
    last_part = String.split(cron_str, " ") |> List.last()

    cond do
      last_part && Timex.Timezone.exists?(last_part) ->
        last_part

      config_timezone() && Timex.Timezone.exists?(config_timezone()) ->
        config_timezone()

      true ->
        Timex.local().time_zone
    end
  end

  def config_timezone() do
    Application.get_env(:exq_scheduler, :time_zone)
  end

  def remove_nils(map) do
    if map do
      Enum.filter(map, fn {_, v} -> v != nil end) |> Map.new()
    else
      %{}
    end
  end

  def encode_to_epoc(time) do
    DateTime.to_unix(Timex.to_datetime(time), :microsecond) / 1.0e6
  end

  def decode_epoc(time) do
    Timex.from_unix(time * 1.0e6, :microsecond)
  end

  def get_nearer_date(ref_date, date1, date2) do
    diff1 = Timex.diff(ref_date, date1)
    diff2 = Timex.diff(ref_date, date2)

    if diff1 >= 0 && diff2 >= 0 do
      if diff1 < diff2 do
        date1
      else
        date2
      end
    else
      if diff1 >= 0 do
        date1
      else
        date2
      end
    end
  end
end
