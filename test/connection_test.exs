defmodule ConnectionTest do
  use ExqScheduler.Case, async: false
  import TestUtils
  alias ExqScheduler.Time

  setup do
    {:ok, _} = Toxiproxy.reset()
    :ok
  end

  setup context do
    config =
      if context[:config] do
        context[:config]
      else
        env()
      end

    config =
      config
      |> add_redis_name(String.to_atom("scheduler_redis"))
      # change redis port to use toxiproxy
      |> put_in([:redis, :port], 26379)
      |> put_in([:name], String.to_atom("scheduler"))

    {:ok, _} = start_supervised({ExqScheduler, config})
    :ok
  end

  @tag config:
         configure_env(
           env(),
           1000 * 60 * 60,
           schedule_cron_10m: %{
             :cron => "*/30 * * * * *",
             :class => "DummyWorker2",
             :include_metadata => true
           }
         )
  @tag :integration
  test "whether reconnects automatically" do
    down("redis")
    :timer.sleep(250)

    min_sch_time = Timex.to_unix(Time.now())
    up("redis")
    :timer.sleep(1000)

    assert_properties("DummyWorker2", 30 * 60)
    jobs = get_jobs("DummyWorker2")

    new_jobs_added? =
      Enum.any?(jobs, fn job ->
        sch_time = schedule_time_from_job(job) |> iso_to_unixtime()
        sch_time > min_sch_time
      end)

    assert new_jobs_added?
  end

  @tag config:
         configure_env(
           env(),
           1000 * 60 * 120,
           schedule_cron: %{
             :cron => "*/30 * * * * *",
             :class => "DummyWorker2",
             :include_metadata => true
           }
         )
  @tag :integration
  test "continuity during network failure" do
    :timer.sleep(2000)
    assert_properties("DummyWorker2", 30 * 60)

    down("redis")
    :timer.sleep(1000)

    up("redis")
    :timer.sleep(1000)
    assert_properties("DummyWorker2", 30 * 60)
  end

  @tag config:
         configure_env(
           env(),
           1000 * 60 * 60,
           schedule_cron: %{
             :cron => "*/10 * * * * *",
             :class => "DummyWorker2",
             :include_metadata => true
           }
         )
  @tag :integration
  test "to check whether scheduler considers window after reconnection" do
    down("redis")
    :timer.sleep(500)

    max_first_sch_time = Timex.to_unix(Time.now())
    up("redis")
    :timer.sleep(1000)
    jobs = get_jobs("DummyWorker2")

    assert_properties("DummyWorker2", 10 * 60)
    first_job = List.last(jobs)
    first_sch_time = schedule_time_from_job(first_job) |> iso_to_unixtime()

    assert first_sch_time < max_first_sch_time
  end

  @tag config:
         configure_env(
           env(),
           1000 * 60 * 120,
           schedule_cron: %{
             :cron => "*/10 * * * * *",
             :class => "NogoodWorker",
             :include_metadata => true
           }
         )
         |> put_in([:key_expire_padding], 900)
  @tag :integration
  test "if scheduler key expires before window time" do
    :timer.sleep(1000)
    down("redis")

    :timer.sleep(1000)

    up("redis")
    :timer.sleep(500)

    assert_properties("NogoodWorker", 10 * 60)
  end
end
