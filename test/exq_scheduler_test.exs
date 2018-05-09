defmodule ExqSchedulerTest do
  use ExqScheduler.Case, async: false
  import TestUtils
  alias ExqScheduler.Storage
  alias Exq.Support.Job
  require Logger

  setup do
    for i <- 0..4 do
      config =
        env()
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

  test "check continuity" do
    redis = redis_pid("continuity")
    storage_opts = Storage.build_opts(env([:redis, :name], redis))
    config =
      env()
      |> put_in([:server_opts, :timeout], 1500)
      |> put_in([:server_opts, :missed_jobs_threshold_duration], 1000)
      |> put_in([:schedules],[schedule_cron_1h: %{
                                          "cron" => "0 * * * * *",
                                          "class" => "DummyWorker1",
                                          "include_metadata" => true
                                       }])

    ExqScheduler.start_link(config)
    :timer.sleep(4000) # 3+ Hour

    jobs = get_jobs_from_storage(redis, Storage.queue_key("default", storage_opts))
           |> Enum.filter(fn job -> job.class == "DummyWorker1" end)

    schedule_times =
      jobs
      |> Enum.map(fn job -> List.first(job.args)["scheduled_at"] <> "Z" end) # ISO format requires Z at the end
      |> Enum.map(&convert_from_iso_to_unixtime(&1))
      |> Enum.sort()

    sum = calculate_sum(List.first(schedule_times), List.last(schedule_times), length(schedule_times))
    Logger.info(inspect("Values sum: #{schedule_times |> Enum.sum} calculated sum: #{sum}"))
    assert schedule_times |> Enum.sum == sum
  end

  test "check for missing jobs" do
    redis = redis_pid("missing_jobs")
    storage_opts = Storage.build_opts(env([:redis, :name], redis))
    config =
      env()
      |> put_in([:server_opts, :timeout], 1000)
      |> put_in([:server_opts, :missed_jobs_threshold_duration], 10000)
      |> put_in([:schedules],[schedule_cron_1m: %{
                                                 "cron" => "* * * * * *",
                                                 "class" => "DummyWorker2",
                                                 "include_metadata" => true
                                              }])
    ExqScheduler.start_link(config)
    :timer.sleep(3000) # 3+ Hour

    jobs = get_jobs_from_storage(redis, Storage.queue_key("default", storage_opts))
           |> Enum.filter(fn job -> job.class == "DummyWorker2" end)

    schedule_times =
      jobs
      |> Enum.map(fn job -> List.first(job.args)["scheduled_at"] <> "Z" end) # ISO format requires Z at the end
      |> Enum.map(&convert_from_iso_to_unixtime(&1))
      |> Enum.sort()


    expected_sum = calculate_sum(List.first(schedule_times), List.last(schedule_times), length(schedule_times))
    actual_sum = schedule_times |> Enum.sum

    Logger.info(inspect("Values sum: #{actual_sum} calculated sum: #{expected_sum}"))
    assert  actual_sum == expected_sum
  end

  test "Check schedules are gettinga added to correct queues" do
    redis = redis_pid("queue")
    storage_opts = Storage.build_opts(env([:redis, :name], redis))
    config =
      env()
      |> put_in([:server_opts, :timeout], 1000)
      |> put_in([:server_opts, :missed_jobs_threshold_duration], 10000)
      |> put_in([:schedules],[schedule_cron_1m: %{
                                                 "cron" => "* * * * * *",
                                                 "class" => "QWorker",
                                                 "queue" => "SuperQ"
                                              }])
    ExqScheduler.start_link(config)
    :timer.sleep(3000) # 3+ Hour

    jobs = get_jobs_from_storage(redis, Storage.queue_key("SuperQ", storage_opts))
           |> Enum.filter(fn job -> job.class == "QWorker" end)
    assert length(jobs) >= 1
  end

  defp get_jobs_from_storage(redis, queue_name) do
    jobs = Redix.command!(redis, ["LRANGE", queue_name, "0", "-1"])
    Enum.map(jobs, &Job.decode/1)
  end

  defp convert_from_iso_to_unixtime(date) do
    {:ok, dt, _} = DateTime.from_iso8601(date)
    DateTime.to_unix(dt)
  end

  defp calculate_sum(first, last, count) do
    count*(first+last)/2
  end
end
