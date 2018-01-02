defmodule ExqScheduler.Storage.Redis do
  use GenServer

  def hkeys(key) do
    Redix.command(pid(), ['HKEYS', key])
  end

  def hget(key, field) do
    {:ok, result} = Redix.command(pid(), ['HGET', key, field])
    result |> decode
  end

  def hset(key, field, val) do
    Redix.command(pid(), ['HSET', key, field, val])
  end

  def cas(compare_key, commands) do
    watch = ['WATCH', compare_key]
    multi = ['MULTI']
    set = ['SET', compare_key, true]
    exec = ['EXEC']
    pipeline_command = [watch, multi, set]
                       |> Enum.concat(commands)
                       |> Enum.concat([exec])
    Redix.pipeline(pid(), pipeline_command)
  end

  def pid do
    "#{__MODULE__}.Client" |> String.to_atom()
  end

  defp decode(result) do
    result |> Poison.decode!()
  end
end
