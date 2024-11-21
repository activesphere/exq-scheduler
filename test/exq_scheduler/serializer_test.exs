defmodule ExqScheduler.SerializerTest do
  use ExUnit.Case
  import ExqScheduler.Serializer

  test "encode" do
    assert stable_encode!(%{"a" => 1}) == ~S({"a":1})
    assert stable_encode!(%{"b" => 1, "a" => 1}) == ~S({"a":1,"b":1})

    size = 100

    map =
      for n <- 1..size, do: {"element_#{String.pad_leading(to_string(n), 3, "0")}", n}, into: %{}

    json =
      for n <- 1..size,
          do: ~s("element_#{String.pad_leading(to_string(n), 3, "0")}":#{n})

    assert stable_encode!(map) == "{" <> Enum.join(json, ",") <> "}"
  end
end
