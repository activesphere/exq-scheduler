defmodule ScheduleTest do
  use ExUnit.Case, async: true
  import TestUtils
  alias ExqScheduler.Schedule

  test "get jobs for time range" do
    test_params = [
      %{cron: "* * * * *", offset: 60, length: 2},
      %{cron: "*/2 * * * *", offset: 60, length: 1},
      %{cron: "*/2 * * * *", offset: 120, length: 2},
      %{cron: "0 * * * *", offset: 1800, length: 1},
      %{cron: "0 */2 * * *", offset: 3600, length: 1}
    ]

    Enum.each(test_params, fn params ->
      schedule = build_schedule(params.cron)
      time_range = build_time_range(params.offset)
      jobs = Schedule.get_jobs(schedule, time_range)
      assert length(jobs) == params.length
    end)
  end
end
