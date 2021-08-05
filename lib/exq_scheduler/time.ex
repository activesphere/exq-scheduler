defmodule ExqScheduler.Time do
  @callback init(base :: integer(), scale :: integer()) :: :ok
  @callback now() :: DateTime.t()
  @callback scale_duration(Timex.Duration.t()) :: Timex.Duration.t()
  @callback reset(base :: integer(), scale :: integer()) :: :ok

  @mod Application.get_env(:exq_scheduler, :time_module, __MODULE__.Real)

  def init(base, scale), do: @mod.init(base, scale)

  def now, do: @mod.now()

  def scale_duration(duration), do: @mod.scale_duration(duration)

  def reset(base, scale), do: @mod.reset(base, scale)
end
