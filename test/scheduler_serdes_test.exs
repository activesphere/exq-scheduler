defmodule SchedulerSerdesTest do
  use ExqScheduler.Case, async: false
  alias ExqScheduler.Storage
  import TestUtils
  require Logger

  setup context do
    sidekiq_path = Path.join(__DIR__, "../sidekiq") |> Path.expand()

    sidekiq_task =
      Task.async(fn ->
        {_, 0} = System.cmd(Path.join(sidekiq_path, "setup_sidekiq"), [], cd: sidekiq_path)
      end)

    Logger.info("Wait for 5 seconds for Sidekiq to initialize.")
    :timer.sleep(5000)

    on_exit(context, fn ->
      System.cmd(Path.join(sidekiq_path, "stop_sidekiq"), [], cd: sidekiq_path)
      assert_down(sidekiq_task.pid)
    end)
  end

  test "it makes sure the schedule has been serialized properly" do
    storage_opts = Storage.build_opts(add_redis_name(env(), redis_pid("test")))

    sch_names = Storage.get_schedule_names(storage_opts)

    schedules =
      Enum.map(
        sch_names,
        &Storage.map_to_schedule(&1, Storage.schedule_from_storage(&1, storage_opts))
      )

    assert length(schedules) != 0

    schedule = Enum.at(schedules, 0)
    target_cron = Crontab.CronExpression.Parser.parse!("5 * * * * *")
    assert schedule.cron == target_cron
    assert schedule.job.class == "SidekiqWorker"
  end

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
