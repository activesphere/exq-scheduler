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
               "* * * * * *",
               Poison.encode!(%{
                 "class" => "SidekiqWorker",
                 "queue" => "high",
                 "args" => "/tmp/poop"
               }),
               %{"first_in" => "3m"}
             }
  end

  test "it respects cron more than every in case both are present" do
    schedule = %{
      "cron" => ["2 * * * * *", %{"first_in" => "3m"}],
      "every" => "1m",
      "class" => "SidekiqWorker",
      "queue" => "high",
      "args" => "/tmp/poop"
    }

    assert Parser.get_schedule(schedule) ==
             {
               "2 * * * * *",
               Poison.encode!(%{
                 "class" => "SidekiqWorker",
                 "queue" => "high",
                 "args" => "/tmp/poop"
               }),
               %{"first_in" => "3m"}
             }
  end

  test "it converts every to normalized cron string" do
    schedule = %{
      "every" => "1m",
      "class" => "SidekiqWorker",
      "queue" => "high",
      "args" => "/tmp/poop"
    }

    assert Parser.get_schedule(schedule) ==
             {
               "1 * * * * *",
               Poison.encode!(%{
                 "class" => "SidekiqWorker",
                 "queue" => "high",
                 "args" => "/tmp/poop"
               }),
               nil
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
               "1 * * * * *",
               Poison.encode!(%{
                 "class" => "SidekiqWorker",
                 "queue" => "high",
                 "args" => "/tmp/poop"
               }),
               nil
             }
  end
end
