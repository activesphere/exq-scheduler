defmodule ExqScheduler.Schedule.Parser do
  @moduledoc false
  alias ExqScheduler.Schedule.Utils
  alias ExqScheduler.Schedule.Job
  @cron_key :cron
  @description_key :description
  @class_key :class
  @metadata_key :include_metadata
  @default_queue "default"
  @default_args []
  @non_job_keys [@cron_key, @description_key, @metadata_key]

  @doc """
    Parses the schedule as per the format (rufus-scheduler supported):
    %{
      cron => "* * * * *"
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
      opts = %{@metadata_key => Map.get(schedule, @metadata_key, false)}

      {
        description,
        normalize_time(schedule_time),
        create_job(schedule),
        opts
      }
    end
  end

  def convert_keys(schedule) do
    Map.new(
      schedule,
      fn {k, v} -> {String.to_atom(k), v} end
    )
  end

  defp normalize_time(time) do
    time = to_string(time)
    cron_str = Utils.strip_timezone(time)
    timezone = Utils.get_timezone(time)

    {cron_exp, _} = Utils.to_cron_exp(cron_str)
    [Crontab.CronExpression.Composer.compose(cron_exp), timezone] |> Enum.join(" ")
  end

  defp create_job(schedule) do
    validate_config(schedule)

    Map.drop(schedule, @non_job_keys)
    |> set_defaults()
    |> Job.encode()
  end

  def set_defaults(map) do
    Map.merge(%{queue: @default_queue, args: @default_args}, map)
  end

  defmodule ConfigurationError do
    defexception message: "Invalid configuration!"
  end

  defp validate_config(job) do
    if job[@class_key] == nil do
      cron = Map.get(job, @cron_key)

      raise ExqScheduler.Schedule.Parser.ConfigurationError,
        message: "Class is not configured for cron: #{inspect(cron)}. Scheduler: #{inspect(job)}"
    end

    :ok
  end
end
