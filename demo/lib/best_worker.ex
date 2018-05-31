defmodule BestWorker do
  def perform(msg \\"World") do
    :timer.sleep(500)
    IO.write("Hello #{msg}!")
  end
end
