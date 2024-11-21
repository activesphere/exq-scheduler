defmodule ExqScheduler.Serializer do
  def encode!(object, opts \\ []) do
    Jason.encode!(object, opts)
  end

  def stable_encode!(object, opts \\ []) do
    to_ordered_map(object)
    |> Jason.encode!(opts)
  end

  def decode!(data, opts \\ []) do
    Jason.decode!(data, opts)
  end

  defp to_ordered_map(list) when is_list(list) do
    Enum.map(list, &to_ordered_map/1)
  end

  defp to_ordered_map(map) when is_map(map) do
    Enum.map(map, fn {key, value} -> {key, to_ordered_map(value)} end)
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Jason.OrderedObject.new()
  end

  defp to_ordered_map(term) do
    term
  end
end
