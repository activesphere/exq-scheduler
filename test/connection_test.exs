defmodule ConnectionTest do
  use ExqScheduler.Case, async: false
  import TestUtils
  require Logger
  alias ExqScheduler.Time

  setup do
    {:ok, _} = Toxiproxy.reset()
    :ok
  end

  setup context do
    config = if context[:config] do
      context[:config]
    else
      env()
    end
    config =
      config
      |> put_in([:redis, :name], String.to_atom("scheduler_redis"))
      |> put_in([:redis, :port], 26379) # change redis port to use toxiproxy
      |> put_in([:name], String.to_atom("scheduler"))

    {:ok, _} = start_supervised({ExqScheduler, config})
    :ok
  end

  @tag config: configure_env(env(), 100, 1000*1200, [schedule_cron_10m: %{
                                                        "cron" => "*/30 * * * * *",
                                                        "class" => "DummyWorker2",
                                                        "include_metadata" => true}])
  test "reconnects automatically" do
    down("redis")
    :timer.sleep(500)
    up("redis")
    :timer.sleep(2000)
    jobs = get_jobs("DummyWorker2")
    assert_continuity(jobs, 1800)
  end
end
