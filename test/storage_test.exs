defmodule StorageTest do
  use ExUnit.Case, async: false
  import TestUtils
  alias ExqScheduler.Storage

  setup do
    start_supervised!({ExqScheduler, env([:schedules], [])})
    flush_redis()
    :ok
  end

  defp build_and_enqueue(cron, offset, now, redis) do
    opts = Storage.build_opts(env([:redis, :name], redis))
    {schedule, jobs} = build_scheduled_jobs(cron, offset, now)
    Storage.enqueue_jobs(schedule, jobs, opts)
    jobs
  end

  defp redis_pid(idx) do
    pid = "redis_#{idx}" |> String.to_atom()
    {:ok, _} = Redix.start_link(Keyword.get(env(), :redis), name: pid)
    pid
  end

  test "no duplicate jobs" do
    all_jobs =
      pmap(1..20, fn idx ->
        build_and_enqueue("*/2 * * * *", 60, Timex.now(), redis_pid(idx))
      end)

    assert default_queue_job_count() == length(hd(all_jobs))
  end

  test "it loads the schedules from the config file" do
    storage_opts = Storage.build_opts(env([:redis, :name], redis_pid("test")))
    schedules = Storage.load_schedules_config(storage_opts, env())
    assert length(schedules) == 2
  end

  test "is_schedule_enabled?(): It checks if the schedule is enabled or not" do
    storage_opts = Storage.build_opts(env([:redis, :name], redis_pid("test")))
    schedules = Storage.load_schedules_config(storage_opts, env())
    assert length(schedules) >= 1

    Enum.map(schedules, fn schedule ->
      schedule_props = {
        schedule.name,
        schedule.description,
        Crontab.CronExpression.Composer.compose(schedule.cron),
        Exq.Support.Job.encode(schedule.job),
        %{"enabled" => false}
      }

      Storage.persist_schedule(schedule_props, storage_opts)
      assert Storage.is_schedule_enabled?(storage_opts, schedule) == false
    end)
  end
end
