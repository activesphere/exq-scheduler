defmodule DaylightSavingTest do
  use ExqScheduler.Case, async: false
  alias ExqScheduler.Time
  import TestUtils

  import Timex.Duration,
    only: [to_seconds: 1, to_milliseconds: 2, from_hours: 1, from_minutes: 1]

  @worker "SomeWorker"
  @timezone "Europe/Copenhagen"
  @missed_job_window to_milliseconds(from_hours(1), truncate: true)

  setup do
    {:ok, _} = Toxiproxy.reset()
    :ok
  end

  setup context do
    schedules = [
      schedule: %{
        cron: "*/5 * * * * * #{@timezone}",
        class: @worker,
        include_metadata: true
      }
    ]

    config =
      configure_env(env(), context[:missed_jobs_window] || @missed_job_window, schedules)
      |> add_redis_name(String.to_atom("scheduler_redis"))
      |> add_redis_port(26379)
      |> put_in([:name], String.to_atom("scheduler"))

    set_time(context[:start_time])
    {:ok, _} = start_supervised({ExqScheduler, config})
    :ok
  end

  describe "forward DST switch" do
    @tag start_time: utc(~N[2019-03-31 01:40:00], @timezone)
    test "for daylight saving forward" do
      :timer.sleep(1000)
      jobs = get_jobs(@worker)

      {valid_hour_jobs, skiped_hour_jobs} =
        dedup_jobs(jobs, to_unix(~N[2019-03-31 03:00:00], @timezone))

      assert length(skiped_hour_jobs) == 12

      Enum.filter(valid_hour_jobs, fn job ->
        Timex.after?(
          scheduled_at_local(job, @timezone),
          ~N[2019-03-31 02:00:00]
        )
      end)
      |> assert_jobs_properties(to_seconds(from_minutes(5)), @timezone)
    end
  end

  describe "backward DST switch" do
    @tag start_time: utc(~N[2019-10-27 01:45:00], @timezone),
         missed_jobs_window: to_milliseconds(from_hours(3), truncate: true)
    test "basic execution" do
      :timer.sleep(2500)

      get_jobs(@worker)
      |> assert_jobs_properties(to_seconds(from_minutes(5)), @timezone)
    end

    @tag start_time: utc(~N[2019-10-27 01:45:00], @timezone)
    test "when it crosses first occurrence of repeated hour" do
      :timer.sleep(1500)

      get_jobs(@worker)
      |> assert_jobs_properties(to_seconds(from_minutes(5)), @timezone)
    end

    @tag start_time: first(~N[2019-10-27 02:45:00], @timezone)
    test "when it starts at first occurrence of repeated hour" do
      :timer.sleep(1000)

      get_jobs(@worker)
      |> assert_jobs_properties(to_seconds(from_minutes(5)), @timezone)
    end

    @tag start_time: utc(~N[2019-10-27 01:30:00], @timezone),
         missed_jobs_window: to_milliseconds(from_hours(3), truncate: true)
    test "when first occurrence of repeated hour is missed" do
      :timer.sleep(100)

      down("redis")
      :timer.sleep(1600)

      # wakeup after missing first occurrence of repetition
      up("redis")

      :timer.sleep(1500)

      jobs = get_jobs(@worker)

      # no jobs should be added during first repetition
      Enum.each(jobs, fn job ->
        enqueued_at = job.enqueued_at

        assert enqueued_at < Timex.to_unix(first(~N[2019-10-27 02:00:00], @timezone)) ||
                 enqueued_at > Timex.to_unix(first(~N[2019-10-27 02:59:59], @timezone))
      end)

      assert_jobs_properties(jobs, to_seconds(from_minutes(5)), @timezone)
    end

    @tag start_time: utc(~N[2019-10-27 01:30:00], @timezone),
         missed_jobs_window: to_milliseconds(from_hours(3), truncate: true)
    test "when both occurrence repetition is missed" do
      :timer.sleep(100)

      down("redis")
      :timer.sleep(2500)

      # wakeup after missing both occurrence of repetition
      up("redis")

      :timer.sleep(1000)

      jobs = get_jobs(@worker)

      # no jobs should be added during both repetition
      Enum.each(jobs, fn job ->
        enqueued_at = job.enqueued_at

        assert enqueued_at < Timex.to_unix(first(~N[2019-10-27 02:00:00], @timezone)) ||
                 enqueued_at > Timex.to_unix(second(~N[2019-10-27 02:59:59], @timezone))
      end)

      assert_jobs_properties(jobs, to_seconds(from_minutes(5)), @timezone)
    end
  end

  def set_time(time) do
    Time.reset(utc(time), 60 * 60)
  end

  defp dedup_jobs(jobs, time) do
    {normal, duplicate} =
      Enum.reduce(
        jobs,
        {[], []},
        fn job, {acc, duplicate} ->
          prev_time = if !Enum.empty?(acc), do: scheduled_at(hd(acc)), else: nil

          if scheduled_at(job) == time && prev_time == time do
            {acc, [job | duplicate]}
          else
            {[job | acc], duplicate}
          end
        end
      )

    {Enum.reverse(normal), Enum.reverse(duplicate)}
  end

  def to_unix(time, zone) do
    Timex.to_datetime(time, zone)
    |> Timex.to_unix()
  end
end
