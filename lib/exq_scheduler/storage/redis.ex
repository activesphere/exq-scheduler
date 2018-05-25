defmodule ExqScheduler.Storage.Redis do
  @moduledoc false

  def hkeys(lib, pid, key) do
    lib.command!(pid, ["HKEYS", key])
  end

  def hget(lib, pid, key, field) do
    lib.command!(pid, ["HGET", key, field]) |> decode
  end

  def hset(lib, pid, key, field, val) do
    lib.command!(pid, ["HSET", key, field, val])
  end

  def cas(lib, pid, lock_key, commands) do
    watch = ["WATCH", lock_key]
    get = ["GET", lock_key]

    ["OK", is_locked] = lib.pipeline!(pid, [watch, get])

    if is_locked do
      ["OK"] = lib.pipeline!(pid, [["UNWATCH"]])
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

      response = lib.pipeline!(pid, pipeline_command)
      ^expected = Enum.take(response, length(expected))
      response
    end
  end

  def queue_len(lib, pid, queue) do
    lib.command!(pid, ["LLEN", queue])
  end

  def connected?(lib, pid) do
    case lib.command(pid, ["PING"]) do
      {:error, _} -> false
      {:ok, _} -> true
    end
  end

  defp decode(result) do
    if result != nil do
      result |> Poison.decode!()
    end
  end
end
