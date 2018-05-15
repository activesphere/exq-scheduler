defmodule ExqScheduler.Scheduler.Server do
  @moduledoc false
  @storage_reconnect_timeout 500

  use GenServer
  alias ExqScheduler.Time

  defmodule State do
    @moduledoc false
    defstruct schedules: nil, storage_opts: nil, server_opts: nil, range: nil, env: nil
  end

  defmodule Opts do
    @moduledoc false
    @enforce_keys [:timeout]
    defstruct timeout: nil, enqueue_missed_jobs: false, missed_jobs_threshold_duration: nil

    def new(opts) do
      timeout = opts[:timeout]
      enqueue_missed_jobs = opts[:enqueue_missed_jobs]

      missed_jobs_threshold_duration =
        if enqueue_missed_jobs do
          opts[:missed_jobs_threshold_duration]
        else
          timeout
        end

      %__MODULE__{
        timeout: timeout,
        enqueue_missed_jobs: enqueue_missed_jobs,
        missed_jobs_threshold_duration: missed_jobs_threshold_duration
      }
    end
  end

  alias ExqScheduler.Storage
  alias ExqScheduler.Schedule.TimeRange

  def start_link(env) do
    GenServer.start_link(__MODULE__, env)
  end

  def init(env) do
    storage_opts = Storage.build_opts(env)
    schedules = Storage.load_schedules_config(env)

    state = %State{
      schedules: schedules,
      storage_opts: storage_opts,
      server_opts: build_opts(env),
      env: env
    }

    update_initial_schedule_times(:first, state)
    {:ok, state}
  end

  def update_initial_schedule_times(:first, state) do
    if Storage.storage_connected?(state.storage_opts) do
      Enum.filter(state.schedules, &Storage.is_schedule_enabled?(state.storage_opts, &1))
      |> Storage.persist_schedule_times(state.storage_opts)

      next_tick(self(), 0)
    else
      Process.send_after(self(), :first, @storage_reconnect_timeout)
    end
  end

  def handle_info({:tick, time}, state) do
    timeout =
    if not Storage.storage_connected?(state.storage_opts) do
      @storage_reconnect_timeout # sleep for a while and retry
    else
      handle_tick(state, time)
      state.server_opts.timeout
    end

    next_tick(self(), timeout)
    {:noreply, state}
  end

  defp handle_tick(state, time) do
    Storage.filter_active_jobs(state.storage_opts, state.schedules, get_range(state, time))
    |> Enum.map(fn {schedule, jobs} ->
      Storage.enqueue_jobs(schedule, jobs, state.storage_opts)
    end)
  end

  defp next_tick(server, timeout) do
    time = Time.now() |> Timex.to_naive_datetime()
    Process.send_after(server, {:tick, time}, timeout)
  end

  defp get_range(state, time) do
    TimeRange.new(time, state.server_opts.missed_jobs_threshold_duration)
  end

  defp build_opts(env) do
    Keyword.get(env, :server_opts)
    |> Opts.new()
  end
end
