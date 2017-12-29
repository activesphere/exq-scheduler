defmodule ScheduleUtilsTest do
    use ExUnit.Case
    alias ExqScheduler.Schedule.Utils
    alias Timex.Duration

    test "to_duration(): it converts the time string to timex duration object" do
      assert Utils.to_duration("3m") == {:ok, Duration.from_minutes(3)}
      assert Utils.to_duration("1d") == {:ok, Duration.from_days(1)}
      assert Utils.to_duration("1d3m") ==
        {:ok, Duration.from_minutes(3) |> Duration.add(Duration.from_days(1))}
      assert Utils.to_duration("2.5d3m1s") ==
        {:ok,
        Duration.from_minutes(3) |> Duration.add(Duration.from_days(2.5)) |>
          Duration.add(Duration.from_seconds(1))}
    end
  end
