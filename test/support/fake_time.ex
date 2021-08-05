defmodule ExqScheduler.Time.Fake do
  @moduledoc "An implementation of ExqScheduler.Time that uses simulated time"

  @behaviour ExqScheduler.Time

  @impl true
  def init(base, scale) do
    __MODULE__ = :ets.new(__MODULE__, [:public, :named_table])
    reset(base, scale)
  end

  @impl true
  def now do
    elapsed = Timex.diff(Timex.now(), set_at(), :microseconds)
    Timex.shift(base(), microseconds: elapsed * scale())
  end

  @impl true
  def scale_duration(duration) do
    div(duration, scale())
  end

  @impl true
  def reset(base, scale) do
    insert(:base, base)
    insert(:scale, scale)
    insert(:set_at, Timex.now())
    :ok
  end

  defp base(), do: get(:base)
  defp scale(), do: get(:scale)
  defp set_at(), do: get(:set_at)

  defp insert(key, value) do
    true = :ets.insert(__MODULE__, {key, value})
  end

  defp get(key) do
    [{^key, value}] = :ets.lookup(__MODULE__, key)
    value
  end
end
