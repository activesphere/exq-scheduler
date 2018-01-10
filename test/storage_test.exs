defmodule StorageTest do
  use ExUnit.Case, async: true
  import TestUtils
  alias ExqScheduler.Storage

  setup do
    on_exit(fn ->
      flush_redis()
    end)
  end

  defp build_and_enqueue(cron, offset, now \\ Timex.now(), redis \\ nil) do
    opts = ExqScheduler.build_storage_opts(redis)
    jobs = build_scheduled_jobs(cron, offset, now)
    Storage.enqueue_jobs(jobs, opts)
    jobs
  end

  test "enqueue jobs" do
    jobs = build_and_enqueue("*/2 * * * *", 60)
    assert default_queue_job_count() == {:ok, length(jobs)}
  end

  test "no duplicate jobs" do
    all_jobs =
      pmap(1..20, fn idx ->
        pid = "redis_#{idx}" |> String.to_atom()
        {:ok, _} = Redix.start_link(ExqScheduler.get_config(:redis), name: pid)
        build_and_enqueue("*/2 * * * *", 60, Timex.now(), pid)
      end)

    assert default_queue_job_count() == {:ok, length(hd(all_jobs))}
  end
end
