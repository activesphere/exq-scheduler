defmodule ExqScheduler.Storage.Redis do
  @moduledoc false

  alias ExqScheduler.Serializer

  def hkeys(storage, key) do
    storage.module.command!(storage.name, ["HKEYS", key])
  end

  def hget(storage, key, field) do
    storage.module.command!(storage.name, ["HGET", key, field]) |> decode
  end

  def hset(storage, key, field, val) do
    storage.module.command!(storage.name, ["HSET", key, field, val])
  end

  def cas(storage, lock_key, ttl, commands) do
    watch = ["WATCH", lock_key]
    get = ["GET", lock_key]

    ["OK", is_locked] = storage.module.pipeline!(storage.name, [watch, get])

    if is_locked do
      ["OK"] = storage.module.pipeline!(storage.name, [["UNWATCH"]])
    else
      pipeline_command =
        [["MULTI"], ["SETEX", lock_key, ttl, true]]
        |> Enum.concat(commands)
        |> Enum.concat([["EXEC"]])

      expected =
        Enum.concat([
          ["OK"],
          ["QUEUED"],
          Enum.map(commands, fn _ -> "QUEUED" end)
        ])

      response = storage.module.pipeline!(storage.name, pipeline_command)
      ^expected = Enum.take(response, length(expected))
      response
    end
  end

  def queue_len(storage, queue) do
    storage.module.command!(storage.name, ["LLEN", queue])
  end

  def connected?(storage) do
    case storage.module.command(storage.name, ["PING"]) do
      {:error, _} -> false
      {:ok, _} -> true
    end
  end

  defp decode(result) do
    if result != nil do
      result |> Serializer.decode!()
    end
  end
end
