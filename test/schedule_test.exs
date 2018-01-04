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
      jobs = build_scheduled_jobs(params.cron, params.offset)
      assert length(jobs) == params.length
    end)
  end
end
