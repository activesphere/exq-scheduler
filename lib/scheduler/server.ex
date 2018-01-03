defmodule ExqScheduler.Scheduler.Server do
  use GenServer

  @prev_offset 200_000
  @next_offset 1000

  defmodule State do
    defstruct schedules: nil, storage_opts: nil, server_opts: nil
  end

  defmodule Opts do
    @enforce_keys [:timeout]
    defstruct @enforce_keys

    def new(opts) do
      %__MODULE__{timeout: opts[:timeout]}
    end
  end

  alias ExqScheduler.Storage
  alias ExqScheduler.Schedule.TimeRange

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_schedule(name, cron, job, opts) do
    GenServer.cast(__MODULE__, {:add_schedule, {name, cron, job, opts}})
  end

  def init(opts) do
    storage_opts = opts[:storage_opts]

    state = %State{
      schedules: Storage.get_schedules(storage_opts),
      storage_opts: storage_opts,
      server_opts: opts[:server_opts]
    }

    next_tick(__MODULE__, 0)
    {:ok, state}
  end

  def handle_info({:tick, time}, state) do
    handle_tick(state, time)
    next_tick(__MODULE__, state.server_opts.timeout)
    {:noreply, state}
  end

  def handle_cast({:add_schedule, {name, cron, job, schedule_opts}}, state) do
    Storage.add_schedule(name, cron, job, schedule_opts, state.storage_opts)
    {:noreply, Storage.get_schedules(state.storage_opts)}
  end

  defp handle_tick(state, time) do
    range = TimeRange.new(time, @prev_offset, @next_offset)

    Storage.filter_active_jobs(state.schedules, range)
    |> Storage.enqueue_jobs(state.storage_opts)
  end

  defp next_tick(server, timeout) do
    time = Timex.now() |> Timex.to_naive_datetime()
    Process.send_after(server, {:tick, time}, timeout)
  end
end
