defmodule ScheduleUtilsTest do
  use ExUnit.Case
  alias ExqScheduler.Schedule.Utils
  alias Timex.Duration
  alias ExqScheduler.Time

  test "strip_timezone(): It strips out the timezone from a cron string" do
    assert Utils.strip_timezone("* * * * * * Asia/Kolkata") == "* * * * * *"
    assert Utils.strip_timezone("* * * * * * * Asia/Kolkata") == "* * * * * * *"
  end

  test "get_timezone(): It gets the timezone from a cron string" do
    assert Utils.get_timezone("* * * * * * Asia/Kolkata") == "Asia/Kolkata"
    assert Utils.get_timezone("* * * * * * * Asia/Kolkata") == "Asia/Kolkata"
  end

  test "get_timezone(): It uses the timezone from the config file is not specified" do
    assert Utils.get_timezone("* * * * * *") == "Asia/Kolkata"
  end

  test "get_timezone_config(): It fetches the time_zone from config" do
    assert Utils.get_timezone_config() == "Asia/Kolkata"
  end

  test "to_duration(): it converts the time string to timex duration object" do
    assert Utils.to_duration("15.64s") == Duration.from_seconds(15.64)
    assert Utils.to_duration("1s") == Duration.from_seconds(1)

    assert Utils.to_duration("3.5m") == Duration.from_minutes(3.5)
    assert Utils.to_duration("30m") == Duration.from_minutes(30)

    assert Utils.to_duration("1.64h") == Duration.from_hours(1.64)
    assert Utils.to_duration("100h") == Duration.from_hours(100)

    assert Utils.to_duration("1.555d") == Duration.from_days(1.555)
    assert Utils.to_duration("1500d") == Duration.from_days(1500)

    assert Utils.to_duration("1.5d30m") ==
             Duration.from_minutes(30) |> Duration.add(Duration.from_days(1.5))

    assert Utils.to_duration("35.5w") == Duration.from_weeks(35.5)
    assert Utils.to_duration("3w") == Duration.from_weeks(3)

    assert Utils.to_duration("4.66M") == Duration.from_days(4.66 * 30)
    assert Utils.to_duration("400M") == Duration.from_days(400 * 30)

    year = 4 * 30 + 7 * 31 + 28

    assert Utils.to_duration("3.5y") == Duration.from_days(3.5 * year)
    assert Utils.to_duration("45y") == Duration.from_days(45 * year)

    assert Utils.to_duration("10w2.5d3.55m1.0s") ==
             Duration.from_weeks(10)
             |> Duration.add(Duration.from_days(2.5))
             |> Duration.add(Duration.from_minutes(3.55))
             |> Duration.add(Duration.from_seconds(1))

    assert Utils.to_duration("1y2M31w2.5d3m1s") ==
             Duration.from_days(1 * year)
             |> Duration.add(Duration.from_days(2 * 30))
             |> Duration.add(Duration.from_weeks(31))
             |> Duration.add(Duration.from_days(2.5))
             |> Duration.add(Duration.from_minutes(3))
             |> Duration.add(Duration.from_seconds(1))
  end

  test "to_cron_exp(): It normalizes cron expression with timezone support" do
    assert Utils.to_cron_exp("* * * * * Asia/Kolkata") ==
             {
               Crontab.CronExpression.Parser.parse!("* * * * *"),
               Timex.Duration.from_clock({5, 30, 0, 0})
             }
  end

  test "get_nearer_date(): It returns the date nearer to the reference date" do
    now = Time.now()
    date1 = Timex.shift(now, seconds: 5)
    date2 = Timex.shift(now, seconds: 10)
    assert Utils.get_nearer_date(now, date1, date2) |> Timex.equal?(date1)
  end
end
