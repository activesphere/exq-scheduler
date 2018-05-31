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
    cron_str = strip_timezone(cron_str)
    cron_exp = Cron.Parser.parse!(cron_str)

    if timezone == nil do
      {cron_exp, nil}
    else
      cron_tz = Timex.Timezone.get(timezone)
      d_utc = Timex.Duration.from_seconds(cron_tz.offset_utc)

      offset_duration =
        cond do
          cron_tz.offset_utc > 0 ->
            d_utc

          cron_tz.offset_utc < 0 ->
            Timex.Duration.from_hours(24)
            |> Timex.Duration.add(d_utc)

          true ->
            Timex.Duration.zero()
        end

      {cron_exp, offset_duration}
    end
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
    is_valid_tz = Timex.Timezone.exists?(last_part)
    tz_from_config = get_timezone_config()

    cond do
      is_valid_tz ->
        last_part

      tz_from_config != nil ->
        tz_from_config

      true ->
        nil
    end
  end

  def get_timezone_config() do
    server_opts = Application.get_all_env(:exq_scheduler)

    if server_opts != nil do
      tz_from_config = server_opts[:time_zone]

      if tz_from_config != nil and Timex.Timezone.exists?(tz_from_config) do
        tz_from_config
      else
        # by default use local timezone
        Timex.local().time_zone
      end
    else
      nil
    end
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
