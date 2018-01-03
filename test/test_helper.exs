ExUnit.start()

defmodule TestUtils do
  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.TimeRange

  def build_schedule(cron) do
    {:ok, job} = %{class: "TestJob"} |> Poison.encode()
    Schedule.new("test_schedule", cron, job)
  end

  def build_time_range(offset) do
    t_start = Timex.now() |> Timex.shift(seconds: -offset)
    t_end = Timex.now() |> Timex.shift(seconds: offset)
    %TimeRange{t_start: t_start, t_end: t_end}
  end
end
