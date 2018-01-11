defmodule ExqScheduler.Scheduler.Server do
  use GenServer

  defmodule State do
    defstruct schedules: nil, storage_opts: nil, server_opts: nil
  end

  defmodule Opts do
    @enforce_keys [:timeout, :prev_offset, :next_offset]
    defstruct @enforce_keys

    def new(opts) do
      %__MODULE__{
        timeout: opts[:timeout],
        prev_offset: opts[:prev_offset],
        next_offset: opts[:next_offset]
      }
    end
  end

  alias ExqScheduler.Storage
  alias ExqScheduler.Schedule.TimeRange

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def load_schedules_config() do
    GenServer.cast(__MODULE__, :load_schedules_config)
  end

  def init(opts) do
    storage_opts = opts[:storage_opts]

    Storage.load_schedules_config(storage_opts)

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

  def handle_cast(:load_schedules_config, state) do
    Storage.load_schedules_config(state.storage_opts)
    {:noreply, Storage.get_schedules(state.storage_opts)}
  end

  defp handle_tick(state, time) do
    range = TimeRange.new(time, state.server_opts.prev_offset, state.server_opts.next_offset)

    Storage.filter_active_jobs(state.schedules, range)
    |> Storage.enqueue_jobs(state.storage_opts)
  end

  defp next_tick(server, timeout) do
    time = Timex.now() |> Timex.to_naive_datetime()
    Process.send_after(server, {:tick, time}, timeout)
  end
end
