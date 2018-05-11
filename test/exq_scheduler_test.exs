defmodule ExqSchedulerTest do
  use ExqScheduler.Case, async: false
  import TestUtils
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
                                                 "class" => "DummyWorker1",
                                                 "include_metadata" => true}])
  test "check continuity" do
    :timer.sleep(4000)

    jobs = get_jobs("DummyWorker1")
    assert_continuity(jobs, 3600)
  end

  @tag config: configure_env(env(), 100, 1000*1200, [schedule_cron_1m: %{
                                                   "cron" => "*/10 * * * * *",
                                                   "class" => "DummyWorker2",
                                                   "include_metadata" => true}])
  test "check for missing jobs" do
    :timer.sleep(4000)

    jobs = get_jobs("DummyWorker2")
    assert_continuity(jobs, 10*60)
  end

  @tag config: configure_env(env(), 1000, 10000, [schedule_cron_1m: %{
                                                   "cron" => "* * * * * *",
                                                   "class" => "QWorker",
                                                   "queue" => "SuperQ"
                                                }])
  test "Check schedules are getting added to correct queues" do
    :timer.sleep(3000)

    jobs = get_jobs("QWorker", "SuperQ")
    assert length(jobs) >= 1
  end

  defp assert_continuity(jobs, diff) do
    assert length(jobs) > 0, "Jobs list is empty"
    jobs
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map( fn [job1, job2] ->
      %{"scheduled_at" => t1} = List.last(job1.args)
      %{"scheduled_at" => t2} = List.last(job2.args)
      assert(diff == iso_to_unixtime(t1)-iso_to_unixtime(t2),
        "Failed. job1: #{inspect(job1)} job2: #{inspect(job2)} ")
    end)
  end
end
