defmodule ExqScheduler.Scheduler.Server do
  @moduledoc false
  @storage_reconnect_timeout 500
  @failsafe_delay 10 # milliseconds
  @max_timeout 1000*3600*24*10 # 10 days

  use GenServer
  alias ExqScheduler.Time

  defmodule State do
    @moduledoc false
    defstruct schedules: nil, storage_opts: nil, server_opts: nil, range: nil, env: nil, start_time: nil
  end

  defmodule Opts do
    @moduledoc false
    defstruct missed_jobs_threshold_duration: nil

    def new(opts) do
      missed_jobs_threshold_duration = opts[:missed_jobs_threshold_duration]

      %__MODULE__{
        missed_jobs_threshold_duration: missed_jobs_threshold_duration
      }
    end
  end

  alias ExqScheduler.Storage
  alias ExqScheduler.Schedule
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
      now = Time.now()
      handle_tick(state, now)

      sch_time = nearest_schedule_time(state, now)

      # Use *immediate* current time, not previous time to find the timeout
      timeout = get_timeout(sch_time, Time.now())
      Time.scale_duration(timeout)
    else
      @storage_reconnect_timeout # sleep for a while and retry
    end

    next_tick(self(), timeout)
    {:noreply, state}
  end

  defp handle_tick(state, ref_time) do
    Storage.filter_active_jobs(state.storage_opts, state.schedules, get_range(state, ref_time), ref_time)
    |> Enum.map(fn {schedule, jobs} ->
      Storage.enqueue_jobs(schedule, jobs, state.storage_opts, ref_time)
    end)

    Storage.persist_schedule_times(state.schedules, state.storage_opts, ref_time)
  end

  defp next_tick(server, timeout) do
    Process.send_after(server, :tick, timeout)
  end

  defp nearest_schedule_time(state, ref_time) do
    state.schedules
    |> Enum.map(fn schedule ->
      Schedule.get_next_schedule_date(schedule.cron, schedule.tz_offset, ref_time)
    end)
    |> Enum.min_by(&Timex.to_unix(&1))
  end

  defp get_timeout(schedule_time, current_time) do
    diff = Timex.diff(schedule_time, current_time, :milliseconds)
    if diff > 0 do
      if diff > @max_timeout do
        @max_timeout + @failsafe_delay
      else
        diff + @failsafe_delay
      end
    else
      0
    end
  end

  defp get_range(state, time) do
    TimeRange.new(time, state.server_opts.missed_jobs_threshold_duration)
  end

  defp build_opts(env) do
    Keyword.get(env, :server_opts)
    |> Opts.new()
  end
end
