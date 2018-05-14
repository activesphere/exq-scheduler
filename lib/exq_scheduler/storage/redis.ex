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
      ["OK"] = Redix.pipeline!(redis, [["UNWATCH"]])
    else
      pipeline_command =
        [["MULTI"], ["SET", lock_key, true]]
        |> Enum.concat(commands)
        |> Enum.concat([["EXEC"]])

      expected = Enum.concat([
        ["OK"],
        ["QUEUED"],
        Enum.map(commands, fn _ -> "QUEUED" end)
      ])

      response = Redix.pipeline!(redis, pipeline_command)
      ^expected = Enum.take(response, length(expected))
      response
    end
  end

  def queue_len(redis, queue) do
    Redix.command!(redis, ["LLEN", queue])
  end

  defp decode(result) do
    if result != nil do
      result |> Poison.decode!()
    end
  end
end
