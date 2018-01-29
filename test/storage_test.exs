defmodule StorageTest do
  use ExUnit.Case, async: true
  import TestUtils
  alias ExqScheduler.Storage

  setup do
    flush_redis()

    on_exit(fn ->
      flush_redis()
    end)
  end

  defp build_and_enqueue(cron, offset, now, redis) do
    opts = ExqScheduler.build_storage_opts(redis)
    jobs = build_scheduled_jobs(cron, offset, now)
    Storage.enqueue_jobs(jobs, opts)
    jobs
  end

  defp redis_pid(idx) do
    pid = "redis_#{idx}" |> String.to_atom()
    {:ok, _} = Redix.start_link(ExqScheduler.get_config(:redis), name: pid)
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
    storage_opts = ExqScheduler.build_storage_opts(redis_pid("test"))
    schedules = Storage.load_schedules_config(storage_opts)
    assert length(schedules) == 2
  end
end
