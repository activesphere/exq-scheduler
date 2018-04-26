defmodule ExqScheduler.Storage.Redis do
  @moduledoc false

  def hkeys(redis, key) do
    Redix.command!(redis, ["HKEYS", key])
  end

  def hget(redis, key, field) do
    Redix.command!(redis, ["HGET", key, field]) |> decode
  end

  def hset(redis, key, field, val) do
    Redix.command!(redis, ["HSET", key, field, val])
  end

  def cas(redis, lock_key, commands) do
    watch = ["WATCH", lock_key]
    get = ["GET", lock_key]

    ["OK", is_locked] = Redix.pipeline!(redis, [watch, get])

    if is_locked do
      Redix.pipeline!(redis, [["UNWATCH", lock_key]])
    else
      pipeline_command =
        [["MULTI"], ["SET", lock_key, true]]
        |> Enum.concat(commands)
        |> Enum.concat([["EXEC"]])

      Redix.pipeline!(redis, pipeline_command)
    end
  end

  def queue_len(redis, queue) do
    Redix.command!(redis, ["LLEN", queue])
  end

  def flushdb(redis) do
    Redix.command!(redis, ["FLUSHDB"])
  end

  defp decode(result) do
    if result != nil do
      result |> Poison.decode!()
    end
  end
end
