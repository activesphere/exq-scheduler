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

  def cas(redis, lock_key, commands) do
    setnx = ['SETNX', lock_key, true]
    {:ok, acquire_lock} = Redix.command(redis, setnx)

    if acquire_lock == 1 do
      pipeline_command =
        ['MULTI']
        |> Enum.concat(commands)
        |> Enum.concat(['EXEC'])

      Redix.pipeline(redis, pipeline_command)
    end
  end

  def queue_len(redis, queue) do
    Redix.command(redis, ['LLEN', queue])
  end

  def flushdb(redis) do
    Redix.command(redis, ['FLUSHDB'])
  end

  defp decode(result) do
    result |> Poison.decode!()
  end
end
