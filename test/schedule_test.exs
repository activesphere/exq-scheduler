defmodule ScheduleTest do
  use ExqScheduler.Case, async: false
  alias ExqScheduler.Time
  import TestUtils

  import Logger
  test "check get_next_run_dates for different timezone" do
    current_utc = Time.now()
    next_date = get_next_date("0 * * * * America/New_York")
    expected_next_date = {current_utc.hour()+1, 0}
    assert expected_next_date == next_date

    current_utc = Time.now()
    next_date = get_next_date("0 * * * * Asia/Kolkata")
    expected_next_date = {current_utc.hour()+1, 30}
    assert expected_next_date == next_date

    current_utc = Time.now()
    next_date = get_next_date("0 * * * * Asia/Katmandu")
    expected_next_date = {current_utc.hour()+1, 15}
    assert expected_next_date == next_date
  end

  test "correctly fetches prev and next dates when timezone specified" do
    now_utc = Time.now()
    schedule = build_schedule("* * * * * Asia/Kolkata")

    prev_dates = ExqScheduler.Schedule.get_previous_run_dates(schedule.cron, schedule.tz_offset)

    Enum.with_index(prev_dates, 1)
    |> Enum.each(fn {prev_date, index} ->
      before_now_1min = Timex.add(now_utc, Timex.Duration.from_minutes(-index))
      assert Timex.between?(prev_date, before_now_1min, now_utc)
    end)

    next_dates = ExqScheduler.Schedule.get_next_run_dates(schedule.cron, schedule.tz_offset)

    Enum.with_index(next_dates, 1)
    |> Enum.each(fn {next_date, index} ->
      after_now_1min = Timex.add(now_utc, Timex.Duration.from_minutes(index))
      assert Timex.between?(next_date, now_utc, after_now_1min)
    end)
  end

  test "clock should have correct precision" do
    ref =  Time.now()
    :timer.sleep(500)  # scaled: 30*60sec  (1sec <=> 1hour)
    received = Time.now()
    actual = add_seconds(ref, (30 * 60)) # scale time to (60*60)

    converted_received = convert_time(received)
    converted_actual = convert_time(actual)

    # Logger.info("actual: #{converted_actual} received: #{converted_received}")
    Logger.info("Ref: #{inspect(ref)}. After 30min Actual: #{inspect(actual)} Received: #{inspect(received)}")
    assert converted_actual == converted_received
  end

  defp convert_time(time) do
    ignore_precision = 10
    Timex.to_unix(time)
    |> div(ignore_precision)
  end

  defp add_seconds(time, seconds) do
    Timex.to_unix(time) + seconds
    |> Timex.from_unix
  end

  defp get_next_date(cron) do
    schedule = build_schedule(cron)
    date =
      ExqScheduler.Schedule.get_next_run_dates(schedule.cron, schedule.tz_offset)
      |> Enum.at(0)
    {date.hour(), date.minute()}
  end
end
