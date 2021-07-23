defmodule ExqScheduler.Serializer do
  @serializer Application.fetch_env!(:exq_scheduler, :storage)[:json_serializer] || Poison

  def encode!(object, opts \\ []) do
    @serializer.encode!(object, opts)
  end

  def decode!(data, opts \\ []) do
    @serializer.decode!(data, opts)
  end
end
