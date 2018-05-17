defmodule ExqScheduler.Scheduler.Server do
  @moduledoc false
  @storage_reconnect_timeout 500

  use GenServer
  alias ExqScheduler.Time

  defmodule State do
    @moduledoc false
    defstruct schedules: nil, storage_opts: nil, server_opts: nil, range: nil, env: nil, start_time: nil
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
      env: env,
      start_time: Time.now()
    }

    Process.send_after(self(), :first, @storage_reconnect_timeout)
    {:ok, state}
  end

  def handle_info(:first, state) do
    storage_opts = state.storage_opts
    if Storage.storage_connected?(storage_opts) do
      Enum.filter(state.schedules, &Storage.is_schedule_enabled?(storage_opts, &1))
      |> Enum.filter(fn schedule ->
        Storage.get_schedule_first_run_time(storage_opts, schedule) == nil
      end)
      |> Storage.persist_schedule_times(storage_opts, state.start_time)

      Enum.map(state.schedules, fn schedule ->
        Storage.persist_schedule(schedule, storage_opts)
      end)

      next_tick(self(), 0)
    else
      Process.send_after(self(), :first, @storage_reconnect_timeout)
    end
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    timeout =
    if Storage.storage_connected?(state.storage_opts) do
      handle_tick(state)
      state.server_opts.timeout
    else
      @storage_reconnect_timeout # sleep for a while and retry
    end

    next_tick(self(), timeout)
    {:noreply, state}
  end

  defp handle_tick(state) do
    now = Time.now()
    Storage.filter_active_jobs(state.storage_opts, state.schedules, get_range(state, now))
    |> Enum.map(fn {schedule, jobs} ->
      Storage.enqueue_jobs(schedule, jobs, state.storage_opts)
    end)
  end

  defp next_tick(server, timeout) do
    Process.send_after(server, :tick, timeout)
  end

  defp get_range(state, time) do
    TimeRange.new(time, state.server_opts.missed_jobs_threshold_duration)
  end

  defp build_opts(env) do
    Keyword.get(env, :server_opts)
    |> Opts.new()
  end
end
