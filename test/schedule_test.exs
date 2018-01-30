defmodule ScheduleTest do
  use ExUnit.Case, async: true
  import TestUtils

  test "get jobs for time range" do
    test_params = [
      %{cron: "* * * * *", offset: 60, length: 2},
      %{cron: "*/2 * * * *", offset: 60, length: 1},
      %{cron: "*/2 * * * *", offset: 120, length: 2},
      %{cron: "0 * * * *", offset: 1800, length: 1},
      %{cron: "0 */2 * * *", offset: 3600, length: 1}
    ]

    Enum.each(test_params, fn params ->
      jobs = build_scheduled_jobs(params.cron, params.offset)
      assert length(jobs) == params.length
    end)
  end

  test "correctly fetches prev and next dates when timezone specified" do
    now_utc = Timex.now()

    schedule = build_schedule("* * * * * Asia/Kolkata")
    offset = 2
    t_start = Timex.shift(now_utc, hours: -offset)
    t_end = Timex.shift(now_utc, hours: offset)

    prev_dates =
      ExqScheduler.Schedule.get_previous_run_dates(schedule.cron, schedule.tz_offset, t_start)

    Enum.with_index(prev_dates, 1)
    |> Enum.each(fn {prev_date, index} ->
      before_now_1min = Timex.add(now_utc, Timex.Duration.from_minutes(-index))
      assert Timex.between?(prev_date, before_now_1min, now_utc)
    end)

    next_dates =
      ExqScheduler.Schedule.get_next_run_dates(schedule.cron, schedule.tz_offset)

    Enum.with_index(next_dates, 1)
    |> Enum.each(fn {next_date, index} ->
      after_now_1min = Timex.add(now_utc, Timex.Duration.from_minutes(index))
      assert Timex.between?(next_date, now_utc, after_now_1min)
    end)
  end
end
