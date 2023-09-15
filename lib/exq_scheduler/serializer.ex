defmodule ExqScheduler.Serializer do
  @storage Application.get_env(:exq_scheduler, :storage, [])
  @serializer Keyword.get(@storage, :json_serializer, Poison)

  def encode!(object, opts \\ []) do
    @serializer.encode!(object, opts)
  end

  def decode!(data, opts \\ []) do
    @serializer.decode!(data, opts)
  end
end
