defmodule ExqScheduler.Schedule.Parser do
  alias ExqScheduler.Schedule.Utils
  @cron_key "cron"
  @description_key "description"
  @non_job_keys [@cron_key, @description_key]

  @doc """
    Parses the schedule as per the format (rufus-scheduler supported):
    %{
      cron => "* * * * *" or ["* * * * *", {first_in: "5m"}]
      class => "SidekiqWorker",
      queue => "high",
      args => "/tmp/poop"
    }
  """
  def get_schedule(schedule) do
    has_cron = Map.has_key?(schedule, @cron_key)

    if !has_cron do
      nil
    else
      schedule_time = Map.fetch!(schedule, @cron_key)
      description = Map.get(schedule, @description_key, "")

      if not Utils.is_string?(schedule_time) do
        [schedule_time, schedule_opts] = schedule_time

        {
          description,
          normalize_time(schedule_time),
          create_job(schedule),
          schedule_opts
        }
      else
        {
          description,
          normalize_time(schedule_time),
          create_job(schedule),
          %{}
        }
      end
    end
  end

  defp normalize_time(time) do
    time = to_string(time)
    Utils.to_cron_exp(time)
    |> elem(0)
    |> Crontab.CronExpression.Composer.compose()
  end

  defp create_job(schedule) do
    Map.drop(schedule, @non_job_keys) |> Poison.encode!()
  end
end
