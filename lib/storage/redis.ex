defmodule ExqScheduler.Storage.Redis do
  use GenServer

  def hkeys(key) do
    conn = get_instance_name()
    {:ok, keys} = Redix.command(conn, ['HKEYS', key])
    keys
  end

  def hget(key, field) do
    conn = get_instance_name()
    {:ok, result} = Redix.command(conn, ['HGET', key, field])
    result |> decode
  end

  def get_instance_name do
    "#{__MODULE__}.Client" |> String.to_atom
  end

  defp decode(result) do
    result |> Poison.decode!
  end
end
