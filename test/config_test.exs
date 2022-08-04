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

  test "if no schedules configured" do
    name = ExqScheduler.Sup
    env = Keyword.merge(env(), schedules: [], name: name)

    {:ok, _} = start_supervised({ExqScheduler, env})
    assert Supervisor.which_children(name) == []
  end

  test "if redix config is a list" do
    redis_config = Application.get_env(:exq_scheduler, :redis)
    child_spec = redis_config[:child_spec]
    wrapped_redis_config = Keyword.put(redis_config, :child_spec, [child_spec])
    Application.put_env(:exq_scheduler, :redis, wrapped_redis_config)

    config = configure_env(env(), 1000 * 60 * 120, [])
    assert {:ok, pid} = ExqScheduler.start_link(config)
  end
end
