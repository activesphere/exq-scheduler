defmodule ExqScheduler.Scheduler.Server do
  @moduledoc false
  @storage_reconnect_timeout 500
  # 1 day (unit: seconds)
  @key_expire_padding 3600 * 24
  # 10 milliseconds (unit: milliseconds)
  @failsafe_delay 10
  # 1 hour
  @max_timeout 1000 * 3600

  use GenServer
  alias ExqScheduler.Time

  defmodule State do
    @moduledoc false
    defstruct schedules: nil,
              storage_opts: nil,
              server_opts: nil,
              range: nil,
              env: nil,
              start_time: nil
  end

  defmodule Opts do
    @moduledoc false
    defstruct missed_jobs_window: nil

    # 3 hour
    @default_missed_jobs_window 3 * 60 * 60 * 1000

    def new(opts) do
      missed_jobs_window = opts[:missed_jobs_window] || @default_missed_jobs_window

      %__MODULE__{
        missed_jobs_window: missed_jobs_window
      }
    end
  end

  alias ExqScheduler.Storage
  alias ExqScheduler.Schedule
  alias ExqScheduler.Schedule.TimeRange

  def start_link(env) do
    GenServer.start_link(
      __MODULE__,
      env,
      ExqScheduler.Utils.name(env, "Server")
    )
  end

  def init(env) do
    env = add_key_expire_duration(env)
    storage_opts = Storage.build_opts(env)

    state = %State{
      # will be updated when redis is connected
      schedules: nil,
      storage_opts: storage_opts,
      server_opts: build_opts(env),
      env: env,
      start_time: Time.now()
    }

    {:ok, state, {:continue, :first}}
  end

  def schedules(name) do
    GenServer.call(name, :scheduled)
  end

  def enable_schedule(name, schedule_name, enable?) do
    GenServer.call(name, {:enable_schedule, schedule_name, enable?})
  end

  def enqueue_now(name, schedule_name) do
    GenServer.call(name, {:enqueue_now, schedule_name})
  end

  def handle_call({:enqueue_now, name}, _from, state) do
    schedule = Enum.find(state.schedules, fn schedule -> schedule.name == name end)

    if schedule do
      Storage.enqueue_now(state.storage_opts, schedule)
      {:reply, :ok, state}
    else
      {:reply, {:error, "Schedule not found"}, state}
    end
  end

  def handle_call({:enable_schedule, name, enable?}, _from, state) do
    schedule = Enum.find(state.schedules, fn schedule -> schedule.name == name end)

    if schedule do
      Storage.enable_schedule(state.storage_opts, schedule, enable?)
      {:reply, :ok, update_schedules(state)}
    else
      {:reply, {:error, "Schedule not found"}, state}
    end
  end

  def handle_call(:scheduled, _from, state) do
    ref_time = Time.now()

    schedules =
      Enum.map(state.schedules, fn schedule ->
        %{
          cron: Crontab.CronExpression.Composer.compose(schedule.cron),
          schedule: schedule,
          last_run:
            Schedule.get_previous_schedule_date(schedule.cron, schedule.timezone, ref_time),
          next_run: Schedule.get_next_schedule_date(schedule.cron, schedule.timezone, ref_time)
        }
      end)

    {:reply, schedules, state}
  end

  def handle_continue(:first, state) do
    do_init(state)
  end

  def handle_info(:first, state) do
    do_init(state)
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
        # sleep for a while and retry
        @storage_reconnect_timeout
      end

    next_tick(self(), timeout)
    {:noreply, state}
  end

  defp do_init(state) do
    storage_opts = state.storage_opts

    state =
      if Storage.storage_connected?(storage_opts) do
        state = update_schedules(state)

        Enum.map(state.schedules, &Storage.persist_schedule(&1, storage_opts))

        Enum.filter(state.schedules, &Storage.is_schedule_enabled?(storage_opts, &1))
        |> Enum.filter(&(!Storage.get_schedule_first_run_time(storage_opts, &1)))
        |> Storage.persist_schedule_times(storage_opts, state.start_time)

        next_tick(self(), 0)
        state
      else
        Process.send_after(self(), :first, @storage_reconnect_timeout)
        state
      end

    {:noreply, state}
  end

  defp handle_tick(state, ref_time) do
    window_duration = state.server_opts.missed_jobs_window

    Storage.filter_active_schedules(
      state.storage_opts,
      state.schedules,
      get_range(window_duration, ref_time),
      ref_time
    )
    |> Enum.map(fn {schedule, jobs} ->
      Storage.enqueue_jobs(
        schedule,
        jobs,
        state.storage_opts,
        # window_duration will be in milliseconds
        Time.scale_duration(div(window_duration, 1000) + get_in(state.env, [:key_expire_padding]))
      )
    end)

    Storage.persist_schedule_times(state.schedules, state.storage_opts, ref_time)
  end

  defp next_tick(server, timeout) do
    Process.send_after(server, :tick, timeout)
  end

  defp nearest_schedule_time(state, ref_time) do
    state.schedules
    |> Enum.map(&Schedule.get_next_schedule_date(&1.cron, &1.timezone, ref_time))
    |> Enum.min_by(&Timex.to_unix(&1))
  end

  defp get_timeout(schedule_time, current_time) do
    diff = Timex.diff(schedule_time, current_time, :milliseconds)

    cond do
      diff > @max_timeout ->
        @max_timeout + @failsafe_delay

      diff > 0 ->
        diff + @failsafe_delay

      true ->
        0
    end
  end

  def update_schedules(state) do
    schedules =
      Enum.map(
        Keyword.get(state.env, :schedules),
        fn config_sch ->
          # convert: { name, %{_configs_} } --> %{_config_,  name: _name_}
          {name, config_sch} = config_sch
          config_sch = Map.put(config_sch, :name, name)

          # Merge the config in order:   defaults -> storage -> config
          schedule =
            Storage.schedule_from_storage(config_sch.name, state.storage_opts)
            |> Map.merge(config_sch)

          Storage.map_to_schedule(name, schedule)
        end
      )

    Map.put(state, :schedules, schedules)
  end

  defp add_key_expire_duration(env) do
    if !get_in(env, [:key_expire_padding]) do
      put_in(env[:key_expire_padding], @key_expire_padding)
    else
      env
    end
  end

  defp get_range(window_duration, time) do
    TimeRange.new(time, window_duration)
  end

  defp build_opts(env) do
    Opts.new(env)
  end
end
