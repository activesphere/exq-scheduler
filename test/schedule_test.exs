defmodule ScheduleTest do
  use ExqScheduler.Case, async: false
  alias ExqScheduler.Time
  alias Timex.Duration
  alias ExqScheduler.Schedule
  alias ExqScheduler.Storage
  alias ExqScheduler.Schedule.Utils
  alias ExqScheduler.Schedule.Job
  alias Crontab.CronExpression, as: Cron
  import TestUtils

  @config add_redis_name(env(), :redix)
  @storage_opts Storage.build_opts(@config)

  @schedule %Schedule{
    name: "schedule",
    cron: Cron.Parser.parse!("*/5 * * * * *"),
    timezone: "Europe/Copenhagen",
    job: "some job"
  }

  test "check get_next_schedule_date for different timezone" do
    # -06:00
    next_date = get_next_date("0 2 * * * America/New_York")
    expected_next_date = {7, 0}
    assert expected_next_date == next_date

    # +05:30
    next_date = get_next_date("0 9 * * * Asia/Kolkata")
    expected_next_date = {3, 30}
    assert expected_next_date == next_date

    # -05:45
    next_date = get_next_date("0 12 * * * Asia/Katmandu")
    expected_next_date = {6, 15}
    assert expected_next_date == next_date
  end

  test "check get_previous_schedule_date for different timezone" do
    # -06:00
    prev_date = get_prev_date("0 2 * * * America/New_York")
    expected_prev_date = {7, 0}
    assert expected_prev_date == prev_date

    # +05:30
    prev_date = get_prev_date("0 9 * * * Asia/Kolkata")
    expected_prev_date = {3, 30}
    assert expected_prev_date == prev_date

    # +05:045
    prev_date = get_prev_date("0 12 * * * Asia/Katmandu")
    expected_prev_date = {6, 15}
    assert expected_prev_date == prev_date
  end

  test "clock should have correct precision" do
    acceptable_err = 60

    ref = Time.now()
    # scaled: 30*60sec  (1sec <=> 1hour)
    :timer.sleep(500)
    diff = Timex.diff(Time.now(), ref, :seconds)
    assert abs(diff - 1800) < acceptable_err
  end

  test "order of the jobs should be reverse (recent job first)" do
    build_and_enqueue("* * * * *", 240, Time.now(), redis_pid(0))
    :timer.sleep(100)
    assert_properties("TestJob", 60)
  end

  describe "to_localtime/2" do
    test "if it returns naive time" do
      time = Timex.to_datetime(~N[2019-01-03 00:00:00], "Asia/Kolkata")
      assert Schedule.to_localtime(time, "Asia/Kolkata") == ~N[2019-01-03 00:00:00]
    end

    test "if it works with different timezones" do
      time = Timex.to_datetime(~N[2019-01-03 00:00:00], "Etc/UTC")
      assert Schedule.to_localtime(time, "Asia/Kolkata") == ~N[2019-01-03 05:30:00]
    end

    test "if it works with daylight saving adjusted to be forward" do
      # Time advances from 2:00 AM to 3:00 AM.
      time =
        Timex.to_datetime(~N[2019-03-31 01:45:00], "Europe/Copenhagen")
        |> utc()

      assert Schedule.to_localtime(time, "Europe/Copenhagen") == ~N[2019-03-31 01:45:00]

      time = Timex.add(time, Duration.from_minutes(30))
      assert Schedule.to_localtime(time, "Europe/Copenhagen") == ~N[2019-03-31 03:15:00]
    end

    test "if it works with daylight saving adjusted to be backward" do
      # Time comes backward from 3:00 AM to 2:00 AM.
      # ie 2:00 - 3:00 maps to 2 times
      time =
        Timex.to_datetime(~N[2019-10-27 01:45:00], "Europe/Copenhagen")
        |> utc()

      assert Schedule.to_localtime(time, "Europe/Copenhagen") == ~N[2019-10-27 01:45:00]

      time = Timex.add(time, Duration.from_hours(2))
      assert Schedule.to_localtime(time, "Europe/Copenhagen") == ~N[2019-10-27 02:45:00]
    end
  end

  describe "to_utc/2" do
    test "if it returns utc time" do
      time = ~N[2019-01-03 10:00:00]
      assert Schedule.to_utc(time, "Etc/UTC") == utc(~N[2019-01-03 10:00:00])
    end

    test "if it works with different timezones" do
      time = ~N[2019-01-03 10:00:00]
      assert Schedule.to_utc(time, "Asia/Kolkata") == utc(~N[2019-01-03 04:30:00])
    end

    test "if it works with daylight saving adjusted to be forward" do
      # Time advances from 2:00 AM to 3:00 AM.
      time = ~N[2019-03-31 01:59:00]
      assert Schedule.to_utc(time, "Europe/Copenhagen") == utc(~N[2019-03-31 00:59:00])

      time = Timex.add(time, Duration.from_hours(1))
      assert Schedule.to_utc(time, "Europe/Copenhagen") == utc(~N[2019-03-31 01:00:00])
    end

    test "if it works with daylight saving adjusted to be backward" do
      # Time comes backward from 3:00 AM to 2:00 AM.
      # ie 2:00 - 3:00 maps to 2 times
      time = ~N[2019-10-27 02:00:00]
      assert Schedule.to_utc(time, "Europe/Copenhagen") == utc(~N[2019-10-27 00:00:00])

      time = ~N[2019-10-27 03:00:00]
      assert Schedule.to_utc(time, "Europe/Copenhagen") == utc(~N[2019-10-27 02:00:00])
    end
  end

  describe "get_jobs/4" do
    test "if it works with daylight saving adjusted to be forward" do
      time = Timex.to_datetime(~N[2019-03-31 03:00:01], "Europe/Copenhagen") |> utc()
      time_range = Schedule.TimeRange.new(time, 60 * 1000)

      jobs = Schedule.get_jobs(@storage_opts, @schedule, time_range, time)

      # 12 jobs from 02:XX AM and 1 from 03:00 AM
      assert length(jobs) == 13

      expected_time =
        Timex.to_datetime(~N[2019-03-31 03:00:00], "Europe/Copenhagen")
        |> utc()

      jobs
      |> Enum.each(fn job ->
        assert job.job == "some job"
        assert job.time == expected_time
      end)
    end

    test "if it works with daylight saving adjusted to be backward" do
      time = Timex.to_datetime(~N[2019-10-27 03:00:01], "Europe/Copenhagen") |> utc()
      time_range = Schedule.TimeRange.new(time, 121 * 60 * 1000)

      jobs = Schedule.get_jobs(@storage_opts, @schedule, time_range, time)

      # 12 jobs from 02:XX AM and 1 from 03:00 AM
      assert length(jobs) == 13
      assert Enum.all?(jobs, &(&1.job == "some job"))

      job_times = Enum.map(jobs, & &1.time)

      expected_times = [
        utc(~N[2019-10-27 00:00:00Z]),
        utc(~N[2019-10-27 00:05:00Z]),
        utc(~N[2019-10-27 00:10:00Z]),
        utc(~N[2019-10-27 00:15:00Z]),
        utc(~N[2019-10-27 00:20:00Z]),
        utc(~N[2019-10-27 00:25:00Z]),
        utc(~N[2019-10-27 00:30:00Z]),
        utc(~N[2019-10-27 00:35:00Z]),
        utc(~N[2019-10-27 00:40:00Z]),
        utc(~N[2019-10-27 00:45:00Z]),
        utc(~N[2019-10-27 00:50:00Z]),
        utc(~N[2019-10-27 00:55:00Z]),
        utc(~N[2019-10-27 02:00:00Z])
      ]

      assert job_times == expected_times
    end
  end

  test "get_missed_run_dates(): should work correct across different timezones" do
    time = Time.now()
    time_range = Schedule.TimeRange.new(time, 60 * 60 * 1000)

    recent_schedule =
      Schedule.get_missed_run_dates(@storage_opts, @schedule, time_range.t_start, time)
      |> hd

    assert Timex.compare(recent_schedule, time, :seconds) != 1
  end

  @sample_date Timex.parse!("2018-12-01T00:00:00Z", "{ISO:Extended:Z}")

  defp get_next_date(cron) do
    schedule = build_schedule(cron)

    date =
      ExqScheduler.Schedule.get_next_schedule_date(
        schedule.cron,
        schedule.timezone,
        @sample_date
      )

    {date.hour(), date.minute()}
  end

  defp get_prev_date(cron) do
    schedule = build_schedule(cron)

    date =
      ExqScheduler.Schedule.get_previous_schedule_date(
        schedule.cron,
        schedule.timezone,
        @sample_date
      )

    {date.hour(), date.minute()}
  end

  defp utc(time) do
    Timex.to_datetime(time, "Etc/UTC")
  end
end
