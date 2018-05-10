defmodule ExqSchedulerTest do
  use ExqScheduler.Case, async: false
  import TestUtils
  alias ExqScheduler.Storage
  alias Exq.Support.Job
  require Logger
  alias ExqScheduler.Time

  setup context do
    for i <- 0..4 do
      config = if context[:config] do
        context[:config]
      else
        env()
      end
      config =
        config
        |> put_in([:redis, :name], String.to_atom("scheduler_redis_#{i}"))
        |> put_in([:name], String.to_atom("scheduler_#{i}"))

      {:ok, _} = start_supervised({ExqScheduler, config})
    end

    :ok
  end

  test "uniqueness" do
    :timer.sleep(2000)
    assert_job_uniqueness()
  end

  @tag config: configure_env(env(), 1500, 1000,[schedule_cron_1h: %{
                                                 "cron" => "0 * * * * *",
                                                 "class" => "QWorker",
                                                 "queue" => "SuperQ",
                                                 "include_metadata" => true}])
  test "check continuity" do
    redis = redis_pid("continuity")
    storage_opts = Storage.build_opts(env([:redis, :name], redis))
    :timer.sleep(4000) # 3+ Hour

    jobs = get_jobs_from_storage(redis, Storage.queue_key("default", storage_opts))
           |> Enum.filter(fn job -> job.class == "DummyWorker1" end)

    assert_continuity(jobs, 3600)
  end

  @tag config: configure_env(env(), 1, 10000000, [schedule_cron_1m: %{
                                                   "cron" => "* * * * * *",
                                                   "class" => "DummyWorker2",
                                                   "include_metadata" => true
                                                }])
  test "check for missing jobs" do
    redis = redis_pid("missing_jobs")
    storage_opts = Storage.build_opts(env([:redis, :name], redis))
    :timer.sleep(3000) # 3+ Hour

    jobs = get_jobs_from_storage(redis, Storage.queue_key("default", storage_opts))
           |> Enum.filter(fn job -> job.class == "DummyWorker2" end)
    assert_continuity(jobs, 10*60)
  end

  @tag config: configure_env(env(), 1000, 10000, [schedule_cron_1m: %{
                                                   "cron" => "* * * * * *",
                                                   "class" => "QWorker",
                                                   "queue" => "SuperQ"
                                                }])
  test "Check schedules are getting added to correct queues" do
    redis = redis_pid("queue")
    storage_opts = Storage.build_opts(env([:redis, :name], redis))
    :timer.sleep(3000) # 3+ Hour

    jobs = get_jobs_from_storage(redis, Storage.queue_key("SuperQ", storage_opts))
           |> Enum.filter(fn job -> job.class == "QWorker" end)
    assert length(jobs) >= 1
  end

  @tag config: configure_env(env(), 10, 10000000, [schedule_cron_1h: %{
                                                    "cron" => "0 * * * * *",
                                                    "class" => "TimeWorker",
                                                    "queue" => "TimeQ",
                                                    "include_metadata" => true
                                                 }])
  test "scheduler should not consider dates before its started" do
    redis = redis_pid("old_dates")
    storage_opts = Storage.build_opts(env([:redis, :name], redis))
    start_time = Timex.to_unix(Time.now())
    :timer.sleep(100) # 3+ Hour

    jobs =
      get_jobs_from_storage(redis, Storage.queue_key("TimeQ", storage_opts))
      |> Enum.filter(fn job -> job.class == "TimeWorker" end)

    is_jobs_scheduled_before_start =
      jobs
      |> Enum.all?(
         fn job ->
           st = List.first(job.args)["scheduled_at"]
           convert_from_iso_to_unixtime(st) > start_time
         end)
    assert(is_jobs_scheduled_before_start == true, inspect(jobs))
  end

  defp get_jobs_from_storage(redis, queue_name) do
    jobs = Redix.command!(redis, ["LRANGE", queue_name, "0", "-1"])
    Enum.map(jobs, &Job.decode/1)
  end

  defp convert_from_iso_to_unixtime(date) do
    Timex.parse!(date, "{ISO:Extended:Z}")
    |> Timex.to_unix()
  end

  defp assert_continuity(jobs, diff) do
    schedule_times =
      jobs
      |> Enum.map(fn job -> List.first(job.args)["scheduled_at"] end)
      |> Enum.map(&convert_from_iso_to_unixtime(&1))

    len = length(schedule_times)
    Enum.with_index(schedule_times)
    |> Enum.map(
      fn {time, index} ->
        if index < len-1 do
          assert(diff == time - Enum.at(schedule_times, index+1),
            "index: #{index} job: #{inspect(Enum.at(jobs, index))} job+1: #{inspect(Enum.at(jobs, index+1))} ")
        end
     end)
  end
end
