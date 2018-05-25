defmodule RedisSentinelTest do
  use ExqScheduler.Case, async: false
  import TestUtils

  def start_scheduler(config) do
    for i <- 0..4 do
      config =
        config
        |> add_redis_name(String.to_atom("scheduler_redis_#{i}"))
        |> put_in([:name], String.to_atom("scheduler_#{i}"))

      {:ok, _} = start_supervised({ExqScheduler, config})
    end

    :ok
  end

  @tag :integration
  test "RedixSentinel" do
    config =
      configure_env(
        env(),
        1000 * 60 * 60,
        schedule_cron_1h: %{
          :cron => "*/20 * * * * *",
          :class => "SentinelWorker",
          :include_metadata => true
        }
      )

    config =
      put_in(
        config[:redis][:spec],
        %{
          id: :redis_test,
          start: {
            RedixSentinel,
            :start_link,
            [
              [group: "exq", sentinels: [[host: "127.0.0.1", port: 6555]], role: "master"],
              [database: 1],
              [name: :redis_test]
            ]
          }
        }
      )

    start_scheduler(config)
    :timer.sleep(2000)

    assert_properties("SentinelWorker", 20 * 60)
  end
end
