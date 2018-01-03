defmodule StorageTest do
  use ExUnit.Case, async: true
  import TestUtils
  alias ExqScheduler.Storage

  setup do
    on_exit fn ->
      flush_redis()
    end
  end

  test "enqueue jobs" do
    opts = storage_opts()
    jobs = build_scheduled_jobs()
    Storage.enqueue_jobs(jobs, opts)
    assert default_queue_job_count() == {:ok, length(jobs)}
  end
end
