defmodule ExqSchedulerTest do
  use ExqScheduler.Case, async: false
  import TestUtils
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
        |> add_redis_name(String.to_atom("scheduler_redis_#{i}"))
        |> put_in([:name], String.to_atom("scheduler_#{i}"))

      {:ok, _} = start_supervised({ExqScheduler, config})
    end

    :ok
  end

  test "uniqueness" do
    :timer.sleep(2000)
    assert_job_uniqueness()
  end

  @tag config: configure_env(env(), 1000*60*120, [schedule_cron_1h: %{
                                                    "cron" => "0 * * * * *",
                                                    "class" => "DummyWorker1",
                                                    "include_metadata" => true}])
  test "check continuity" do
    :timer.sleep(4000)
    assert_properties("DummyWorker1", 3600)
  end

  @tag config: configure_env(env(), 1000*3600, [schedule_cron_1m: %{
                                                   "cron" => "*/20 * * * * *",
                                                   "class" => "DummyWorker2",
                                                   "include_metadata" => true}])
  test "check for missing jobs" do
    :timer.sleep(4000)
    assert_properties("DummyWorker2", 20*60)
  end

  @tag config: configure_env(env(), 1000*60*45, [schedule_cron_1m: %{
                                                         "cron" => "*/20 * * * * *",
                                                         "class" => "QWorker",
                                                         "queue" => "SuperQ",
                                                         "include_metadata" => true
                                                      }])
  test "Check schedules are getting added to correct queues" do
    :timer.sleep(1000)

    jobs = get_jobs("QWorker", "SuperQ")
    assert_properties("QWorker", 20*60, "SuperQ")
    assert length(jobs) >= 1
  end

  @tag config: configure_env(env(), 10000, [schedule_cron_1m: %{
                                                     "cron" => "0 0 30 1 * *",
                                                     #1st of jan every year
                                                     "class" => "AheadTimeWorker",
                                                     "include_metadata" => true
                                                  }])
  test "jobs should not be added ahead of time" do
    :timer.sleep(500)
    
    jobs = get_jobs("AheadTimeWorker")
    now = Time.now()

    if length(jobs) > 0 do
      latest_job_time =
        List.first(jobs)
        |> schedule_time_from_job()
        |> Timex.parse!( "{ISO:Extended:Z}")
      assert latest_job_time.year() < now.year()
    end
  end

  @tag config: configure_env(env(), 1000*60*60, [schedule_cron: %{
                                                    "cron" => "*/10 * * * * *",
                                                    "class" => "TestWorker",
                                                    "include_metadata" => true
                                                 }])
  test "after re-enabling should not consider too old jobs" do
    class = "TestWorker"
    sch_name = "schedule_cron"

    :timer.sleep(750)

    assert_properties(class, 10*60)

    set_scheduler_state(sch_name, false)
    old_last_sch = List.first(get_jobs(class)) |> schedule_unix_time()
    :timer.sleep(750)

    set_scheduler_state(sch_name, true)
    :timer.sleep(750)

    jobs = get_jobs(class)
    new_schs =
      Enum.map(jobs, &schedule_unix_time(&1))
      |> Enum.filter(fn time -> (time > old_last_sch) end)

    # Should have a missing job between 'disabled' and 'enabled' states
    assert (List.last(new_schs) - old_last_sch) > 10*60

    # Check properties for newly added jobs
    new_jobs = Enum.take(jobs, length(new_schs))
    assert_job_uniqueness(new_jobs)
    assert_continuity(new_jobs, 10*60)
  end

  defp schedule_unix_time(job) do
    schedule_time_from_job(job)
    |> iso_to_unixtime()
  end
end
