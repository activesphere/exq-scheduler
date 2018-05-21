defmodule ExqSchedulerTimeTest do
  use ExqScheduler.Case, async: false
  import TestUtils
  alias ExqScheduler.Time
  alias Timex.Duration
  alias ExqScheduler.Storage

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
    config = configure_env(env(), 10000000, [schedule_cron_1h: %{
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

  test "if last_run_time is future time, its handle gracefully or not" do
    config = configure_env(env(), 1000*60*60*2, [schedule_cron: %{
                                                "cron" => "*/20 * * * * *",
                                                "class" => "FutureWorker",
                                                "include_metadata" => true
                                             }])
    config =
      config
      |> put_in([:redis, :name], :redix)
      |> put_in([:name], String.to_atom("scheduler_0"))

    storage_opts = Storage.build_opts(config)
    schedules = Storage.load_schedules_config(config)
    start_time = Timex.add(Time.now(), Duration.from_hours(1))

    Storage.persist_schedule_times(schedules, storage_opts, start_time)

    start_scheduler(config)
    :timer.sleep(2000)

    jobs = get_jobs("FutureWorker")
    assert_continuity(jobs, 20*60)
  end
end
