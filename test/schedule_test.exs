defmodule ScheduleTest do
  use ExUnit.Case, async: true
  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.Window

  defp build_schedule(cron) do
    {:ok, job} = %{class: "TestJob"} |> Poison.encode
    Schedule.new("test_schedule", cron, job)
  end

  defp build_window(offset) do
    t_start = Timex.now |> Timex.shift(seconds: -offset)
    t_end = Timex.now |> Timex.shift(seconds: offset)
    %Window{t_start: t_start, t_end: t_end}
  end

  test "get jobs for window" do
    test_params = [
      %{cron: "* * * * *", offset: 60, length: 2},
      %{cron: "*/2 * * * *", offset: 60, length: 1},
      %{cron: "*/2 * * * *", offset: 120, length: 2},
      %{cron: "0 * * * *", offset: 1800, length: 1},
      %{cron: "0 */2 * * *", offset: 3600, length: 1}
    ]
    Enum.each(test_params, fn params ->
      schedule = build_schedule(params.cron)
      window = build_window(params.offset)
      jobs = Schedule.get_jobs(schedule, window)
      assert length(jobs) == params.length
    end)
  end
end
