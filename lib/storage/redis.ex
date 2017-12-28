defmodule ExqScheduler.Storage.Redis do
  use GenServer

  def hkeys(key) do
    {:ok, keys} = Redix.command(pid(), ['HKEYS', key])
    keys
  end

  def hget(key, field) do
    {:ok, result} = Redix.command(pid(), ['HGET', key, field])
    result |> decode
  end

  def hset(key, field, val) do
    Redix.command(pid(), ['HSET', key, field, val])
  end

  def pid do
    "#{__MODULE__}.Client" |> String.to_atom
  end

  defp decode(result) do
    result |> Poison.decode!
  end
end
