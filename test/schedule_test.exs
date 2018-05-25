defmodule ScheduleTest do
  use ExqScheduler.Case, async: false
  alias ExqScheduler.Time
  alias Timex.Duration
  alias ExqScheduler.Schedule
  alias ExqScheduler.Storage
  import TestUtils

  test "check get_next_schedule_date for different timezone" do
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

  test "check get_previous_schedule_date for different timezone" do
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

  test "order of the jobs should be reverse (recent job first)" do
    build_and_enqueue("* * * * *", 240, Time.now(), redis_pid(0))
    :timer.sleep(100)
    assert_properties("TestJob", 60)
  end

  test "get_missed_run_dates(): should work correct across different timezones" do
    config = configure_env(env(), 1000*60*60, [schedule_cron: %{
                                                  :cron => "*/20 * * * * *",
                                                  :class => "FutureWorker",
                                                  :include_metadata => true
                                               }])
    config =
      config
      |> add_redis_name(:redix)
      |> put_in([:name], String.to_atom("scheduler_0"))

    storage_opts = Storage.build_opts(config)
    schedules = Storage.load_schedules_config(config)

    now = Time.now()
    start_time = Timex.subtract(now, Duration.from_hours(1))
    lower_bound_time = Timex.subtract(now, Duration.from_hours(2))

    Storage.persist_schedule_times(schedules, storage_opts, start_time)

    newest_schedule =
      Schedule.get_missed_run_dates(storage_opts, Enum.at(schedules, 0), lower_bound_time, now)
      |> List.first()

    assert Timex.compare(newest_schedule, now, :seconds) != 1
  end
  
  defp get_next_date(cron) do
    schedule = build_schedule(cron)
    date =
      ExqScheduler.Schedule.get_next_schedule_date(schedule.cron, schedule.tz_offset, Time.now())
    {date.hour(), date.minute()}
  end

  defp get_prev_date(cron) do
    schedule = build_schedule(cron)
    date =
      ExqScheduler.Schedule.get_previous_schedule_date(schedule.cron, schedule.tz_offset, Time.now())
    {date.hour(), date.minute()}
  end
end
