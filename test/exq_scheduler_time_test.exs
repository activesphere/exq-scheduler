defmodule ExqSchedulerTimeTest do
  use ExqScheduler.Case, async: false
  import TestUtils
  alias ExqScheduler.Time
  alias Timex.Duration
  alias ExqScheduler.Storage

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

  def stop_schedulers() do
    for i <- 0..4 do
      :ok = stop_supervised(String.to_atom("scheduler_#{i}"))
    end

    :ok
  end

  test "scheduler should not consider dates before its started" do
    config =
      configure_env(
        env(),
        10_000_000,
        schedule_cron_1h: %{
          :cron => "0 * * * * *",
          :class => "TimeWorker",
          :queue => "TimeQ",
          :include_metadata => true
        }
      )

    start_time = Timex.to_unix(Time.now())
    start_scheduler(config)
    :timer.sleep(100)

    jobs = get_jobs("TimeWorker", "TimeQ")

    is_jobs_scheduled_before_start =
      jobs
      |> Enum.all?(fn job ->
        schedule_time_from_job(job) >= start_time
      end)

    assert(
      is_jobs_scheduled_before_start,
      "Start time: #{start_time}  jobs: #{inspect(jobs)}"
    )
  end

  test "if last_run_time is future time, should be handled gracefully" do
    config =
      configure_env(
        env(),
        1000 * 60 * 60 * 2,
        schedule_cron: %{
          :cron => "*/20 * * * * *",
          :class => "FutureWorker",
          :include_metadata => true
        }
      )

    config =
      config
      |> add_redis_name(:redix)
      |> put_in([:name], String.to_atom("scheduler_0"))

    storage_opts = Storage.build_opts(config)
    schedules = Storage.load_schedules_config(config)
    start_time = Timex.add(Time.now(), Duration.from_hours(1))

    Storage.persist_schedule_times(schedules, storage_opts, start_time)

    start_scheduler(config)
    :timer.sleep(2000)

    assert_properties("FutureWorker", 20 * 60)
  end

  test "if scheduler key expire after pre-configured time" do
    config =
      configure_env(
        env(),
        1000 * 60 * 10,
        schedule_cron: %{
          :cron => "*/10 * * * * *",
          :class => "NamesakeWorker",
          :include_metadata => true
        }
      )

    config = config |> put_in([:key_expire_padding], 3600)
    start_scheduler(config)

    :timer.sleep(1000)
    keys = schedule_keys(config)

    :timer.sleep(2000)
    new_keys = schedule_keys(config)

    assert Enum.any?(keys, &Enum.member?(new_keys, &1)) == false
  end

  test "if scheduler loads scheduler config from storage" do
    class = "ImTooNamesakeWorker"
    storage_opts = add_redis_name(env(), :redix) |> Storage.build_opts()

    config =
      configure_env(
        env(),
        1000 * 60 * 10,
        schedule_cron: %{
          :cron => "*/10 * * * * *",
          :class => class,
          :include_metadata => true,
          :enabled => false
        }
      )

    start_scheduler(config)
    :timer.sleep(1000)

    storage_sch = Storage.schedule_from_storage(:schedule_cron, storage_opts)
    assert Map.get(storage_sch, :enabled) == false
    assert Map.get(storage_sch, :include_metadata) == true

    stop_schedulers()

    config =
      configure_env(
        config,
        1000 * 60 * 10,
        schedule_cron: %{
          :cron => "*/10 * * * * *",
          :class => class,
          :include_metadata => false
        }
      )

    start_scheduler(config)
    :timer.sleep(1000)

    storage_sch = Storage.schedule_from_storage(:schedule_cron, storage_opts)
    assert Map.get(storage_sch, :enabled) == false
    assert Map.get(storage_sch, :include_metadata) == false
  end
end
