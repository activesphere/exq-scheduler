defmodule ExqScheduler.Schedule.Utils do
  alias Timex.Duration
  alias Crontab.CronExpression, as: Cron

  def get_elem(arr, index, default \\ "") do
    unless arr in [nil, []] do
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

  def to_cron(every, stringify \\ true) do
    unit = String.last(every)
    value = [String.replace(every, unit, "") |> str_to_int]

    cron_exp =
      case unit do
        "y" -> %Cron{year: value}
        "M" -> %Cron{month: value}
        "d" -> %Cron{day: value}
        "h" -> %Cron{hour: value}
        "m" -> %Cron{minute: value}
        "s" -> %Cron{extended: true, second: value}
      end

    if stringify do
      Cron.Composer.compose(cron_exp)
    else
      cron_exp
    end
  end

  def normalize_cron(cron_str) do
    Cron.Parser.parse(cron_str) |> elem(1) |> Cron.Composer.compose()
  end

  def strip_timezone(cron_str) do
    cron_splitted = String.split(cron_str, " ")
    last_part = List.last(cron_splitted)
    if Timex.Timezone.exists?(last_part) do
      cron_splitted |> List.delete_at(-1) |> Enum.join(" ")
    else
      cron_splitted
    end
  end

  def get_timezone(cron_str) do
    last_part = String.split(cron_str, " ") |> List.last
    if Timex.Timezone.exists?(last_part) do
      last_part
    else
      nil
    end
  end

  @doc """
    Converts a time string to a Timex.Duration object.
    Example:

    Input: 1y5d15m20s
    Output: %Timex.Duration{}
  """
  def to_duration(timestring) do
    # Parse week (W) syntax if present.
    week_part =
      Regex.run(~r/(\d+(\.{1}\d+)*w{1})/, timestring)
      |> get_elem(0)

    num_weeks = week_part |> String.trim("w") |> str_to_float

    # Remove week from timestring after parsing.
    timestring =
      unless week_part == "" do
        String.replace(timestring, week_part, "")
      else
        timestring
      end

    {date_part, time_part} =
      {
        Regex.run(~r/(\d+(\.{1}\d+)*y)?(\d+(\.{1}\d+)*M)?(\d+(\.{1}\d+)*d)?/, timestring)
        |> get_elem(0),
        Regex.run(~r/(\d+(\.{1}\d+)*h)?(\d+(\.{1}\d+)*m)?(\d+(\.{1}\d+)*s)?$/, timestring)
        |> get_elem(0)
      }

    if {date_part, time_part} == {"", ""} do
      if num_weeks != 0 do
        Duration.from_weeks(num_weeks)
      else
        nil
      end
    else
      {:ok, duration} =
        cond do
          # If it's only date.
          timestring == date_part ->
            Duration.parse("P#{String.upcase(date_part)}")

          # If it's only time.
          timestring == time_part ->
            Duration.parse("PT#{String.upcase(time_part)}")

          # If it's both date and time.
          true ->
            Duration.parse("P#{String.upcase(date_part)}" <> "T#{String.upcase(time_part)}")
        end

      Duration.add(duration, Duration.from_weeks(num_weeks))
    end
  end
end
