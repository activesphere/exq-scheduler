defmodule ExqScheduler.Schedule.Parser do
  @moduledoc false
  alias ExqScheduler.Schedule.Utils
  @cron_key "cron"
  @description_key "description"
  @include_metadata "include_metadata"
  @non_job_keys [@cron_key, @description_key, @include_metadata]

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
      opts = %{"include_metadata" => Map.get(schedule, @include_metadata, false)}

      if !is_binary(schedule_time) do
        [schedule_time, schedule_opts] = schedule_time

        {
          description,
          normalize_time(schedule_time),
          create_job(schedule),
          Map.merge(opts, schedule_opts)
        }
      else
        {
          description,
          normalize_time(schedule_time),
          create_job(schedule),
          opts
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
    validate_config(schedule)
    Map.drop(schedule, @non_job_keys)
    |> Poison.encode!()
  end

  defmodule ConfigurationError do
    defexception message: "Invalid configuration!"
  end

  defp validate_config(job) do
    if job["class"] == nil do
      cron = Map.get(job, "cron")
      raise ExqScheduler.Schedule.Parser.ConfigurationError,
        message: "Class is not configured for cron: #{inspect(cron)}. Scheduler: #{inspect(job)}"
    end
    :ok
  end
end
