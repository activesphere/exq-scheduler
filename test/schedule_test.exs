defmodule ScheduleTest do
  use ExUnit.Case, async: true
  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.TimeRange

  defp build_schedule(cron) do
    {:ok, job} = %{class: "TestJob"} |> Poison.encode
    Schedule.new("test_schedule", cron, job)
  end

  defp build_time_range(offset) do
    t_start = Timex.now |> Timex.shift(seconds: -offset)
    t_end = Timex.now |> Timex.shift(seconds: offset)
    %TimeRange{t_start: t_start, t_end: t_end}
  end

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
