defmodule ExqScheduler.Scheduler.Server do
  use GenServer

  @prev_offset 200_000
  @next_offset 200_000
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
    range = TimeRange.new(time, @prev_offset, @next_offset)

    Storage.filter_active_jobs(schedules, range)
    |> Storage.enqueue_jobs()
  end

  defp timeout do
    @prev_offset + @next_offset - @buffer
  end

  defp next_tick(server, timeout) do
    time = Timex.now() |> Timex.to_naive_datetime()
    Process.send_after(server, {:tick, time}, timeout)
  end
end
