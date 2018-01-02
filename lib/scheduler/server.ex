defmodule ExqScheduler.Scheduler.Server do
  use GenServer

  @prev_offset 200000
  @next_offset 200000
  @buffer 1000

  alias ExqScheduler.Storage
  alias ExqScheduler.Schedule.TimeRange

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add_schedule(name, cron, job, opts) do
    GenServer.cast(__MODULE__, {:add_schedule, {name, cron, job, opts}})
  end

  def init(_opts) do
    state = Storage.get_schedules()
    next_tick(__MODULE__, 0)
    {:ok, state}
  end

  def handle_info({:tick, time}, state) do
    handle_tick(state, time)
    next_tick(__MODULE__, timeout())
    {:noreply, state}
  end

  def handle_cast({:add_schedule, {name, cron, job, opts}}, _state) do
    Storage.add_schedule(name, cron, job, opts)
    {:noreply, Storage.get_schedules()}
  end

  defp handle_tick(schedules, time) do
    time
    |> get_time_range
    |> (&(Storage.filter_active_jobs(schedules, &1))).()
    |> Storage.queue_jobs
  end

  def get_time_range(time) do
    %TimeRange{
      t_start: Timex.shift(time, milliseconds: -@prev_offset),
      t_end: Timex.shift(time, milliseconds: @next_offset)
    }
  end

  defp timeout do
    @prev_offset + @next_offset - @buffer
  end

  defp next_tick(server, timeout) do
    time = NaiveDateTime.utc_now
    Process.send_after(server, {:tick, time}, timeout)
  end
end
