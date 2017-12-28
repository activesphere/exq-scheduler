defmodule ExqScheduler.Scheduler.Server do
  use GenServer
  alias ExqScheduler.Storage

  @window_prev 2000
  @window_next 2000
  @buffer 1000

  def start_link() do
    {:ok, server} = GenServer.start_link(__MODULE__, :ok, [])
    tick(server)
    {:ok, server}
  end

  def tick(server) do
    time = :calendar.local_time
    GenServer.cast(server, {:tick, time})
    :timer.sleep(timeout())
    tick(server)
  end

  def handle_cast({:tick, time}, _state) do
    IO.puts("Time is #{inspect(time)}")
    handle_tick(time)
    {:noreply, time}
  end

  defp handle_tick(time) do
    time
    |> get_window
    |> Storage.get_jobs
    |> Storage.queue_jobs
  end

  defp get_window(time) do
    { Timex.shift(time, milliseconds: -@window_prev),
      Timex.shift(time, milliseconds: @window_next) }
  end

  defp timeout do
    @window_prev + @window_next - @buffer
  end
end
