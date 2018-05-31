defmodule ScheduleUtilsTest do
  use ExUnit.Case
  alias ExqScheduler.Schedule.Utils
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

  test "to_cron_exp(): It normalizes cron expression with timezone support" do
    assert Utils.to_cron_exp("* * * * * Asia/Kolkata") ==
             {
               Crontab.CronExpression.Parser.parse!("* * * * *"),
               Timex.Duration.from_clock({5, 30, 0, 0})
             }
  end

  test "get_nearer_date(): It returns the date nearer to the reference date" do
    now = Time.now()
    date1 = Timex.shift(now, seconds: -5)
    date2 = Timex.shift(now, seconds: -10)
    assert Utils.get_nearer_date(now, date1, date2) |> Timex.equal?(date1)
  end

  test "get_nearer_date(): If dates are greater than ref_date ignore that date" do
    now = Time.now()
    date1 = Timex.shift(now, seconds: 5)
    date2 = Timex.shift(now, seconds: -10)
    assert Utils.get_nearer_date(now, date1, date2) |> Timex.equal?(date2)
  end
end
