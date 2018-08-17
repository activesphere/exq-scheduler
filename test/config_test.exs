defmodule ConfigTest do
  use ExqScheduler.Case, async: false
  import TestUtils

  test "config" do
    schedules = [
      a: %{
        :cron => "0 * * * * *",
        :class => "Worker1",
        :include_metadata => true
      },
      b: %{
        :cron => "0 * * * * *",
        :class => "Worker2",
        :include_metadata => true
      }
    ]

    config = configure_env(env(), 1000 * 60 * 120, schedules)
    {:ok, pid} = ExqScheduler.start_link(config)
    :timer.sleep(2000)
    assert_properties("Worker1", 3600)
    assert_properties("Worker2", 3600)
    :ok = ExqScheduler.stop(pid)

    worker1_last_scheduled = last_scheduled_time("Worker1")
    worker2_last_scheduled = last_scheduled_time("Worker2")

    schedules = Keyword.delete(schedules, :b)
    config = configure_env(env(), 1000 * 60 * 120, schedules)
    {:ok, pid} = ExqScheduler.start_link(config)
    :timer.sleep(2000)
    assert_properties("Worker1", 3600)

    assert worker1_last_scheduled < last_scheduled_time("Worker1")
    # shouldn't not schedule any new jobs
    assert worker2_last_scheduled == last_scheduled_time("Worker2")
    :ok = ExqScheduler.stop(pid)
  end
end
