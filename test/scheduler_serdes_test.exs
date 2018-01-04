defmodule SchedulerSerdesTest do
  use ExUnit.Case, async: false

  setup context do
    {:ok, redis_conn} = Redix.start_link()
    Redix.command(redis_conn, ['FLUSHALL'])

    sidekiq_path = System.cwd() |> Path.join("./sidekiq")

    sidekiq_task =
      Task.async(fn ->
        System.cmd("#{sidekiq_path}/setup_sidekiq", [], cd: sidekiq_path)
      end)

    IO.puts("Wait for 5 seconds for Sidekiq to initialize.")
    :timer.sleep(5000)

    on_exit(context, fn ->
      System.cmd("#{sidekiq_path}/stop_sidekiq", [], cd: sidekiq_path)
      assert_down(sidekiq_task.pid)
      Redix.stop(redis_conn, 1000)
    end)
  end

  test "it makes sure the schedule has been serialized properly" do
    [{_, storage_opts}, _] = ExqScheduler.build_opts()

    schedules = ExqScheduler.Storage.get_schedules(storage_opts)
    assert length(schedules) != 0

    schedule = Enum.at(schedules, 0)
    target_cron = Crontab.CronExpression.Parser.parse("5 * * * * *") |> elem(1)
    assert schedule.cron == target_cron
    assert schedule.job.class == "SidekiqWorker"
  end

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
