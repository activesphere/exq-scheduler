defmodule ExqScheduler.Storage.Redis do
  def hkeys(redis, key) do
    Redix.command(redis, ['HKEYS', key])
  end

  def hget(redis, key, field) do
    {:ok, result} = Redix.command(redis, ['HGET', key, field])
    result |> decode
  end

  def hset(redis, key, field, val) do
    Redix.command(redis, ['HSET', key, field, val])
  end

  def cas(redis, compare_key, commands) do
    watch = ['WATCH', compare_key]
    multi = ['MULTI']
    set = ['SET', compare_key, true]
    exec = ['EXEC']

    pipeline_command =
      [watch, multi, set]
      |> Enum.concat(commands)
      |> Enum.concat([exec])

    Redix.pipeline(redis, pipeline_command)
  end

  defp decode(result) do
    result |> Poison.decode!()
  end
end
