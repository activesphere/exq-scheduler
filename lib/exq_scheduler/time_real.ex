defmodule ExqScheduler.Time.Real do
  @moduledoc """
  An implementation of `ExqScheduler.Time` that is based on real time
  """
  @behaviour ExqScheduler.Time

  def init(_, _), do: :ok

  def now, do: Timex.now()

  def scale_duration(duration), do: duration

  def reset(_, _), do: :ok
end
