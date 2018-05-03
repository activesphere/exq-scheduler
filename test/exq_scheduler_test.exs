defmodule ExqSchedulerTest do
  use ExqScheduler.Case, async: false
  import TestUtils

  setup do
    for i <- 0..4 do
      config =
        env()
        |> put_in([:redis, :name], String.to_atom("scheduler_redis_#{i}"))
        |> put_in([:name], String.to_atom("scheduler_#{i}"))

      start_supervised!({ExqScheduler, config})
    end

    :ok
  end

  test "uniqueness" do
    :timer.sleep(2000)
    assert_job_uniqueness()
  end
end
