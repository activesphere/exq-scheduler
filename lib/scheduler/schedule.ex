defmodule ExqScheduler.Scheduler.Schedule.ScheduleOpts do
  defstruct first_at: nil, last_at: nil
end

defmodule ExqScheduler.Scheduler.Schedule do
  alias Exq.Support.Job
  alias ExqScheduler.Scheduler.Schedule.ScheduleOpts

  @enforce_keys [:cron, :job]
  defstruct cron: nil, job: nil, schedule_opts: nil, last_run: nil

  def new({cron, serialized_job}, schedule_opts \\ %ScheduleOpts{}) do
    %__MODULE__{
      cron: cron,
      job: Job.decode(serialized_job),
      schedule_opts: schedule_opts
    }
  end
end
