defmodule ExqSchedulerFirstScheduleTest do
  use ExqScheduler.Case, async: false
  import TestUtils
  alias ExqScheduler.Time

  def start_scheduler(config) do
    for i <- 0..4 do
      config =
        config
        |> put_in([:redis, :name], String.to_atom("scheduler_redis_#{i}"))
        |> put_in([:name], String.to_atom("scheduler_#{i}"))

      {:ok, _} = start_supervised({ExqScheduler, config})
    end
    :ok
  end


  test "scheduler should not consider dates before its started" do
    config = configure_env(env(), 10, 10000000, [schedule_cron_1h: %{
                                                    "cron" => "0 * * * * *",
                                                    "class" => "TimeWorker",
                                                    "queue" => "TimeQ",
                                                    "include_metadata" => true
                                                 }])
    start_time = Timex.to_unix(Time.now())
    start_scheduler(config)
    :timer.sleep(100)

    jobs = get_jobs("TimeWorker", "TimeQ")

    is_jobs_scheduled_before_start =
      jobs
      |> Enum.all?(
         fn job ->
           st = schedule_time_from_job(job)
           iso_to_unixtime(st) >= start_time
         end)
    assert(is_jobs_scheduled_before_start,
      "Start time: #{start_time}  jobs: #{inspect(jobs)}")
  end
end
