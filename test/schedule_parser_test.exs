defmodule ScheduleParserTest do
  use ExUnit.Case
  alias ExqScheduler.Schedule.Parser

  test "it correctly parses a cron-based schedule containing bitstrings" do
    schedule = %{
      "cron" => ["* * * * * *", %{"first_in" => "3m"}],
      "class" => "SidekiqWorker",
      "queue" => "high",
      "args" => "/tmp/poop"
    }

    assert Parser.get_schedule(schedule) ==
             {
               "",
               "* * * * * *",
               Poison.encode!(%{
                 "class" => "SidekiqWorker",
                 "queue" => "high",
                 "args" => "/tmp/poop"
               }),
               %{"first_in" => "3m"}
             }
  end

  test "it correctly parses the description of the schedule" do
    schedule = %{
      "description" => "this is a test",
      "cron" => ["* * * * * *", %{"first_in" => "3m"}],
      "class" => "SidekiqWorker",
      "queue" => "high",
      "args" => "/tmp/poop"
    }

    assert Parser.get_schedule(schedule) ==
             {
               "this is a test",
               "* * * * * *",
               Poison.encode!(%{
                 "class" => "SidekiqWorker",
                 "queue" => "high",
                 "args" => "/tmp/poop"
               }),
               %{"first_in" => "3m"}
             }
  end

  test "it correctly parses a cron-based schedule containing charlists" do
    schedule = %{
      "cron" => ['* * * * * *', %{"first_in" => "3m"}],
      "class" => "SidekiqWorker",
      "queue" => "high",
      "args" => "/tmp/poop"
    }

    assert Parser.get_schedule(schedule) ==
             {
               "",
               "* * * * * *",
               Poison.encode!(%{
                 "class" => "SidekiqWorker",
                 "queue" => "high",
                 "args" => "/tmp/poop"
               }),
               %{"first_in" => "3m"}
             }
  end

  test "it normalizes the cron string to the enhanced cron syntax (* * * * * *)" do
    schedule = %{
      "cron" => "1 * * * *",
      "class" => "SidekiqWorker",
      "queue" => "high",
      "args" => "/tmp/poop"
    }

    assert Parser.get_schedule(schedule) ==
             {
               "",
               "1 * * * * *",
               Poison.encode!(%{
                 "class" => "SidekiqWorker",
                 "queue" => "high",
                 "args" => "/tmp/poop"
               }),
               %{}
             }
  end
end
