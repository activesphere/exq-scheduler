defmodule StorageTest do
  use ExqScheduler.Case, async: false
  import TestUtils
  alias ExqScheduler.Storage
  alias ExqScheduler.Time

  test "no duplicate jobs" do
    now = Time.now()

    pmap(1..20, fn idx ->
      build_and_enqueue("*/2 * * * *", 60, now, redis_pid(idx))
    end)

    assert_job_uniqueness()
  end

  test "it loads the schedules from the config file" do
    schedules = Storage.load_schedules_config(env())
    assert length(schedules) == 2
  end

  test "if schedule is enabled by default" do
    storage_opts = Storage.build_opts(env([:redis, :name], redis_pid("test")))
    schedules = Storage.load_schedules_config(env())
    schedule = Enum.at(schedules, 0)
    assert Storage.is_schedule_enabled?(storage_opts, schedule) == true
  end

  test "is_schedule_enabled?(): It checks if the schedule is enabled or not" do
    storage_opts = Storage.build_opts(env([:redis, :name], redis_pid("test")))
    schedules = Storage.load_schedules_config(env())
    assert length(schedules) >= 1

    Enum.map(schedules, fn schedule ->
      sch = ExqScheduler.Schedule.new(schedule.name,
      schedule.description,
      Crontab.CronExpression.Composer.compose(schedule.cron),
      Exq.Support.Job.encode(schedule.job),
      %{"enabled" => false})

      Storage.persist_schedule(sch, storage_opts)
      assert Storage.is_schedule_enabled?(storage_opts, sch) == false
    end)
  end

  test "Check if args getting passed to the scheduler" do
    env_local = put_in(env()[:schedules],[schedule_cron_1m: %{
                                                 "cron" => "* * * * * *",
                                                 "class" => "SidekiqWorker",
                                                 "args" => ["cron_1"]
                                              }])

    schedules = Storage.load_schedules_config(env_local)
    assert length(schedules) >= 1

    schedule = schedules |> Enum.at(0)
   assert length(schedule.job.args) >= 1
  end

end
