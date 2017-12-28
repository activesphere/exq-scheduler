defmodule ExqScheduler.Schedule.ScheduleOpts do
  defstruct first_at: nil, last_at: nil

  def new(opts) do
    %__MODULE__ {
      first_at: Map.get(opts, :first_at),
      last_at: Map.get(opts, :last_at)
    }
  end
end

defmodule ExqScheduler.Schedule do
  alias Exq.Support.Job
  alias ExqScheduler.Schedule.ScheduleOpts

  @enforce_keys [:name, :cron, :job]
  defstruct name: nil, cron: nil, job: nil, schedule_opts: nil, first_run: nil, last_run: nil

  def new(name, {cron, job}, schedule_opts \\ %{}) when is_binary(job) do
    %__MODULE__{
      name: name,
      cron: cron,
      job: Job.decode(job),
      schedule_opts: ScheduleOpts.new(schedule_opts)
    }
  end

  def encode(schedule) do
    schedule.job
    |> Map.merge(%{cron: build_encoded_cron(schedule)})
    |> Poison.encode!
  end

  defp build_encoded_cron(schedule) do
    [schedule.cron, schedule.schedule_opts]
  end
end
