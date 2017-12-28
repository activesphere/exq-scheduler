defmodule ExqScheduler.Scheduler.Server do
  use GenServer

  @window_prev 2000
  @window_next 2000
  @buffer 1000

  alias ExqScheduler.Storage
  alias ExqScheduler.Schedule

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
    |> get_window
    |> Storage.filter_active_jobs(schedules)
    |> Storage.queue_jobs
  end

  defp get_window(time) do
    { Timex.shift(time, milliseconds: -@window_prev),
      Timex.shift(time, milliseconds: @window_next) }
  end

  defp timeout do
    @window_prev + @window_next - @buffer
  end

  defp next_tick(server, timeout) do
    time = :calendar.local_time
    Process.send_after(server, {:tick, time}, timeout)
  end
end
