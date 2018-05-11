defmodule ScheduleTest do
  use ExqScheduler.Case, async: false
  alias ExqScheduler.Time
  import TestUtils

  test "check get_next_run_dates for different timezone" do
    next_date = get_next_date("0 2 * * * America/New_York") # -06:00
    expected_next_date = {7, 0}
    assert expected_next_date == next_date

    next_date = get_next_date("0 9 * * * Asia/Kolkata") # +05:30
    expected_next_date = {3, 30}
    assert expected_next_date == next_date

    next_date = get_next_date("0 12 * * * Asia/Katmandu") # -05:45
    expected_next_date = {6, 15}
    assert expected_next_date == next_date
  end

  test "check get_prev_run_dates for different timezone" do
    prev_date = get_prev_date("0 2 * * * America/New_York") # -06:00
    expected_prev_date = {7, 0}
    assert expected_prev_date == prev_date

    prev_date = get_prev_date("0 9 * * * Asia/Kolkata") # +05:30
    expected_prev_date = {3, 30}
    assert expected_prev_date == prev_date

    prev_date = get_prev_date("0 12 * * * Asia/Katmandu") # +05:045
    expected_prev_date = {6, 15}
    assert expected_prev_date == prev_date
  end

  test "clock should have correct precision" do
    acceptable_err = 60

    ref =  Time.now()
    :timer.sleep(500)  # scaled: 30*60sec  (1sec <=> 1hour)
    diff = Timex.diff(Time.now(), ref, :seconds)
    assert abs(diff-1800) < acceptable_err
  end

  defp get_next_date(cron) do
    schedule = build_schedule(cron)
    date =
      ExqScheduler.Schedule.get_next_run_dates(schedule.cron, schedule.tz_offset)
      |> Enum.at(0)
    {date.hour(), date.minute()}
  end

  defp get_prev_date(cron) do
    schedule = build_schedule(cron)
    date =
      ExqScheduler.Schedule.get_previous_run_dates(schedule.cron, schedule.tz_offset)
      |> Enum.at(0)
    {date.hour(), date.minute()}
  end
end
