defmodule ScheduleTest do
  use ExqScheduler.Case, async: false
  alias ExqScheduler.{Schedule, Storage, Time}
  alias Crontab.CronExpression, as: Cron
  alias Timex.Duration
  import TestUtils

  @config add_redis_name(env(), :redix)
  @storage_opts Storage.build_opts(@config)
  @timezone "Europe/Copenhagen"
  @schedule %Schedule{
    name: "schedule",
    cron: Cron.Parser.parse!("*/5 * * * * *"),
    timezone: @timezone,
    job: "some job"
  }

  describe "get_next_schedule_date/3" do
    test "for different timezone" do
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
  end

  describe "get_next_schedule_date/3 for forward DST switch" do
    test "when current time is before switch" do
      ref_time = utc(~N[2019-03-31 01:55:01], "Europe/Copenhagen")
      next_date = Schedule.get_next_schedule_date(@schedule.cron, @schedule.timezone, ref_time)
      assert next_date == utc(~N[2019-03-31 03:00:00], "Europe/Copenhagen")
    end
  end

  describe "get_next_schedule_date/3 for backward DST switch" do
    test "when current time is before switch" do
      ref_time = utc(~N[2019-10-27 01:55:01], "Europe/Copenhagen")
      next_date = Schedule.get_next_schedule_date(@schedule.cron, @schedule.timezone, ref_time)
      %_{before: time} = Timex.to_datetime(~N[2019-10-27 02:00:00], "Europe/Copenhagen")
      assert next_date == utc(time)
    end

    test "when current time is in the first occurrence of repeated hour" do
      ref_time = first(~N[2019-10-27 02:30:01], "Europe/Copenhagen") |> utc
      next_date = Schedule.get_next_schedule_date(@schedule.cron, @schedule.timezone, ref_time)
      %_{before: time} = Timex.to_datetime(~N[2019-10-27 02:35:00], "Europe/Copenhagen")
      assert next_date == utc(time)
    end

    test "when current time is at the end of the first occurrence repeated hour" do
      ref_time = first(~N[2019-10-27 02:55:01], "Europe/Copenhagen") |> utc
      next_date = Schedule.get_next_schedule_date(@schedule.cron, @schedule.timezone, ref_time)
      assert next_date == utc(~N[2019-10-27 03:00:00], "Europe/Copenhagen")
    end

    test "when current time is in second occurrence repeated hour" do
      ref_time = second(~N[2019-10-27 02:30:01], "Europe/Copenhagen") |> utc
      next_date = Schedule.get_next_schedule_date(@schedule.cron, @schedule.timezone, ref_time)
      %_{after: time} = Timex.to_datetime(~N[2019-10-27 02:35:00], "Europe/Copenhagen")
      assert next_date == utc(time)
    end

    test "when current time is at the end of the second occurrence repeated hour" do
      ref_time = second(~N[2019-10-27 02:55:01], "Europe/Copenhagen") |> utc
      next_date = Schedule.get_next_schedule_date(@schedule.cron, @schedule.timezone, ref_time)
      assert next_date == utc(~N[2019-10-27 03:00:00], "Europe/Copenhagen")
    end
  end

  describe "get_previous_schedule_date/3" do
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
  end

  describe "get_previous_schedule_date/3 for forward DST switch" do
    test "when current time is before switch" do
      ref_time = utc(~N[2019-03-31 03:00:01], "Europe/Copenhagen")
      cron = Cron.Parser.parse!("40 * * * * *")
      prev_date = Schedule.get_previous_schedule_date(cron, @schedule.timezone, ref_time)
      assert prev_date == utc(~N[2019-03-31 03:00:00], "Europe/Copenhagen")

      cron = Cron.Parser.parse!("30 * * * * *")
      prev_date = Schedule.get_previous_schedule_date(cron, @schedule.timezone, ref_time)
      assert prev_date == utc(~N[2019-03-31 03:00:00], "Europe/Copenhagen")
    end
  end

  describe "get_previous_schedule_date/3 for backward DST switch" do
    test "when current time is after switch" do
      ref_time = utc(~N[2019-10-27 03:00:01], "Europe/Copenhagen")
      cron = Cron.Parser.parse!("40 * * * * *")
      prev_date = Schedule.get_previous_schedule_date(cron, @schedule.timezone, ref_time)

      %_{after: time} = Timex.to_datetime(~N[2019-10-27 02:40:00], "Europe/Copenhagen")
      assert prev_date == utc(time)
    end

    test "when current time is at the beginning of first occurrence of repeated hour" do
      ref_time = first(~N[2019-10-27 02:00:01], "Europe/Copenhagen") |> utc
      cron = Cron.Parser.parse!("40 * * * * *")
      prev_date = Schedule.get_previous_schedule_date(cron, @schedule.timezone, ref_time)
      assert prev_date == utc(~N[2019-10-27 01:40:00], "Europe/Copenhagen")
    end

    test "when current time is in the first occurrence of repeated hour" do
      ref_time = first(~N[2019-10-27 02:34:59], "Europe/Copenhagen") |> utc

      prev_date =
        Schedule.get_previous_schedule_date(@schedule.cron, @schedule.timezone, ref_time)

      %_{before: time} = Timex.to_datetime(~N[2019-10-27 02:30:00], "Europe/Copenhagen")
      assert prev_date == utc(time)
    end

    test "when current time is at the beginning of second occurrence of repeated hour" do
      ref_time = second(~N[2019-10-27 02:00:01], "Europe/Copenhagen") |> utc
      cron = Cron.Parser.parse!("40 * * * * *")
      prev_date = Schedule.get_previous_schedule_date(cron, @schedule.timezone, ref_time)
      assert prev_date == utc(~N[2019-10-27 01:40:00], "Europe/Copenhagen")
    end

    test "when current time is in the second occurrence of repeated hour" do
      ref_time = second(~N[2019-10-27 02:34:59], "Europe/Copenhagen") |> utc

      prev_date =
        Schedule.get_previous_schedule_date(@schedule.cron, @schedule.timezone, ref_time)

      %_{after: time} = Timex.to_datetime(~N[2019-10-27 02:30:00], "Europe/Copenhagen")
      assert prev_date == utc(time)
    end
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

  describe "utc_to_localtime/2" do
    test "if it returns naive time" do
      time = utc(~N[2019-01-03 00:00:00])
      assert Schedule.utc_to_localtime(time, "Asia/Kolkata") == ~N[2019-01-03 05:30:00]
    end

    test "for DST forward switch" do
      time = utc(~N[2019-03-31 01:45:00], "Europe/Copenhagen")
      assert Schedule.utc_to_localtime(time, "Europe/Copenhagen") == ~N[2019-03-31 01:45:00]

      time = Timex.add(time, Duration.from_minutes(30))
      assert Schedule.utc_to_localtime(time, "Europe/Copenhagen") == ~N[2019-03-31 03:15:00]
    end

    test "for DST backward switch" do
      time = utc(~N[2019-10-27 01:45:00], "Europe/Copenhagen")
      assert Schedule.utc_to_localtime(time, "Europe/Copenhagen") == ~N[2019-10-27 01:45:00]

      time = Timex.add(time, Duration.from_hours(2))
      assert Schedule.utc_to_localtime(time, "Europe/Copenhagen") == ~N[2019-10-27 02:45:00]
    end
  end

  describe "local_to_utc/2" do
    test "if it returns utc time" do
      time = ~N[2019-01-03 10:00:00]
      assert Schedule.local_to_utc(time, "Etc/UTC") == utc(~N[2019-01-03 10:00:00])
    end

    test "if it works with different timezones" do
      time = ~N[2019-01-03 10:00:00]
      assert Schedule.local_to_utc(time, "Asia/Kolkata") == utc(~N[2019-01-03 04:30:00])
    end

    test "for DST forward switch" do
      time = ~N[2019-03-31 01:59:00]
      assert Schedule.local_to_utc(time, "Europe/Copenhagen") == utc(~N[2019-03-31 00:59:00])

      time = Timex.add(time, Duration.from_hours(1))
      assert Schedule.local_to_utc(time, "Europe/Copenhagen") == utc(~N[2019-03-31 01:00:00])
    end

    test "for DST backward switch" do
      time = ~N[2019-10-27 02:00:00]

      %_{before: before_time, after: after_time} =
        Schedule.local_to_utc(time, "Europe/Copenhagen")

      assert before_time == utc(~N[2019-10-27 00:00:00])
      assert after_time == utc(~N[2019-10-27 01:00:00])

      time = ~N[2019-10-27 03:00:00]
      assert Schedule.local_to_utc(time, "Europe/Copenhagen") == utc(~N[2019-10-27 02:00:00])
    end
  end

  describe "get_jobs/4" do
    test "if it works with daylight saving adjusted to be forward" do
      time = utc(~N[2019-03-31 03:00:00], "Europe/Copenhagen")
      # 1 min
      time_range = Schedule.TimeRange.new(time, 60 * 1000)
      sch = schedule(%{cron: Cron.Parser.parse!("*/20 * * * * *")})

      jobs = Schedule.get_jobs(@storage_opts, sch, time_range, time)

      # 3 jobs from 02:XX AM and 1 from 03:00 AM
      assert_jobs(jobs, "some job", [
        ~N[2019-03-31 02:00:00Z],
        ~N[2019-03-31 02:20:00Z],
        ~N[2019-03-31 02:40:00Z],
        ~N[2019-03-31 03:00:00Z]
      ])

      # 30 min
      time_range = Schedule.TimeRange.new(time, 30 * 60 * 1000)
      sch = schedule(%{cron: Cron.Parser.parse!("40 * * * * *")})
      jobs = Schedule.get_jobs(@storage_opts, sch, time_range, time)

      assert_jobs(jobs, "some job", [
        ~N[2019-03-31 01:40:00Z],
        ~N[2019-03-31 02:40:00Z]
      ])
    end
  end

  describe "get_jobs/4 for backward DST switch" do
    test "when current time is after switch" do
      time = utc(~N[2019-10-27 03:00:00], "Europe/Copenhagen")
      time_range = Schedule.TimeRange.new(time, 40 * 60 * 1000)
      sch = schedule(%{cron: Cron.Parser.parse!("*/20 * * * * *")})

      jobs = Schedule.get_jobs(@storage_opts, sch, time_range, time)

      assert_jobs(jobs, "some job", [
        ~N[2019-10-27 02:20:00Z],
        ~N[2019-10-27 02:40:00Z],
        ~N[2019-10-27 03:00:00Z]
      ])
    end

    test "when current time is at the beginning of first occurrence" do
      time = first(~N[2019-10-27 02:00:01], "Europe/Copenhagen") |> utc()
      time_range = Schedule.TimeRange.new(time, 40 * 60 * 1000)
      sch = schedule(%{cron: Cron.Parser.parse!("*/20 * * * * *")})

      jobs = Schedule.get_jobs(@storage_opts, sch, time_range, time)

      expected = [
        ~N[2019-10-27 01:40:00],
        ~N[2019-10-27 02:00:00]
      ]

      assert_jobs(jobs, "some job", expected)
    end

    test "when current time is in the first occurrence of repeated hour" do
      time = first(~N[2019-10-27 02:30:01], "Europe/Copenhagen") |> utc()

      time_range = Schedule.TimeRange.new(time, 15 * 60 * 1000)
      sch = schedule(%{cron: Cron.Parser.parse!("*/5 * * * * *")})

      jobs = Schedule.get_jobs(@storage_opts, sch, time_range, time)

      expected = [
        ~N[2019-10-27 02:20:00],
        ~N[2019-10-27 02:25:00],
        ~N[2019-10-27 02:30:00]
      ]

      assert_jobs(jobs, "some job", expected)
    end

    test "when current time is at the beginning of second occurrence of repeated hour" do
      time = second(~N[2019-10-27 02:00:01], "Europe/Copenhagen") |> utc()

      # local_lower_bound_time = ~N[2019-10-27 02:00:01]
      time_range = Schedule.TimeRange.new(time, 60 * 60 * 1000)

      jobs = Schedule.get_jobs(@storage_opts, @schedule, time_range, time)

      # last hour is first occurrence of repeated time ( 02:00 ~ 02:59)
      # hence, job filter criteria will be: job_time >= 02:01 && job_time <= 02:01.
      # ie. zero jobs
      assert_jobs(jobs, "some job", [])

      time_range = Schedule.TimeRange.new(time, 70 * 60 * 1000)
      jobs = Schedule.get_jobs(@storage_opts, @schedule, time_range, time)

      expected = [
        ~N[2019-10-27 01:55:00],
        ~N[2019-10-27 02:00:00]
      ]

      assert_jobs(jobs, "some job", expected)
    end

    test "when current time is in the second occurrence of repeated hour" do
      time = second(~N[2019-10-27 02:30:01], "Europe/Copenhagen") |> utc()

      time_range = Schedule.TimeRange.new(time, 15 * 60 * 1000)
      sch = schedule(%{cron: Cron.Parser.parse!("*/5 * * * * *")})

      jobs = Schedule.get_jobs(@storage_opts, sch, time_range, time)

      expected = [
        ~N[2019-10-27 02:20:00],
        ~N[2019-10-27 02:25:00],
        ~N[2019-10-27 02:30:00]
      ]

      assert_jobs(jobs, "some job", expected)
    end

    test "after DST switch and time_range covers complete DST switch" do
      time = utc(~N[2019-10-27 03:00:01], "Europe/Copenhagen")

      time_range = Schedule.TimeRange.new(time, 180 * 60 * 1000)
      sch = schedule(%{cron: Cron.Parser.parse!("50 * * * * *")})

      jobs = Schedule.get_jobs(@storage_opts, sch, time_range, time)

      expected = [
        ~N[2019-10-27 01:50:00],
        ~N[2019-10-27 02:50:00]
      ]

      assert_jobs(jobs, "some job", expected)
    end
  end

  test "get_missed_run_dates()" do
    time = Time.now()
    time_range = Schedule.TimeRange.new(time, 60 * 60 * 1000)

    recent_schedule =
      Schedule.get_missed_run_dates(@storage_opts, @schedule, time_range.t_start, time)
      |> hd

    now = Schedule.utc_to_localtime(time, @timezone)
    assert Timex.compare(recent_schedule, now, :second) != 1
  end

  @sample_date Timex.parse!("2018-12-01T00:00:00Z", "{ISO:Extended:Z}")

  defp get_next_date(cron, ref_time \\ @sample_date) do
    schedule = build_schedule(cron)
    date = Schedule.get_next_schedule_date(schedule.cron, schedule.timezone, ref_time)
    {date.hour(), date.minute()}
  end

  defp get_prev_date(cron, ref_time \\ @sample_date) do
    schedule = build_schedule(cron)
    date = Schedule.get_previous_schedule_date(schedule.cron, schedule.timezone, ref_time)
    {date.hour(), date.minute()}
  end

  defp schedule(map) do
    Map.merge(@schedule, map)
  end

  defp assert_jobs(jobs, expected_job, expected_jobs_time) do
    assert Enum.all?(jobs, &(&1.job == expected_job))
    assert Enum.map(jobs, & &1.time) == expected_jobs_time
  end
end
