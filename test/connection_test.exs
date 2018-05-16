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

  @tag config: configure_env(env(), 500, 1000*60*60, [schedule_cron_10m: %{
                                                        "cron" => "*/30 * * * * *",
                                                        "class" => "DummyWorker2",
                                                        "include_metadata" => true}])
  @tag :connection_test
  test "reconnects automatically" do
    down("redis")
    :timer.sleep(1000)
    max_first_sch_time = Timex.to_unix(Time.now())

    up("redis")
    :timer.sleep(1000)
    jobs = get_jobs("DummyWorker2")

    assert_continuity(jobs, 30*60)
    first_job = List.last(jobs)
    first_sch_time = schedule_time_from_job(first_job) |> iso_to_unixtime()

    assert first_sch_time < max_first_sch_time
  end
end
