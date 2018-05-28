defmodule ScheduleParserTest do
  use ExUnit.Case, async: false
  alias ExqScheduler.Schedule.Parser

  test "it correctly parses a cron-based schedule containing bitstrings" do
    schedule = %{
      :cron => "* * * * * *",
      :class => "SidekiqWorker",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert Parser.get_schedule(schedule) ==
             {
               "",
               "* * * * * * Asia/Kolkata",
               Poison.encode!(%{
                 :class => "SidekiqWorker",
                 :queue => "high",
                 :args => ["/tmp/poop"]
               }),
               %{enabled: true, include_metadata: false}
             }
  end

  test "it correctly parses the description of the schedule" do
    schedule = %{
      :description => "this is a test",
      :cron => "* * * * * *",
      :class => "SidekiqWorker",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert Parser.get_schedule(schedule) ==
             {
               "this is a test",
               "* * * * * * Asia/Kolkata",
               Poison.encode!(%{
                 :class => "SidekiqWorker",
                 :queue => "high",
                 :args => ["/tmp/poop"]
               }),
               %{enabled: true, include_metadata: false}
             }
  end

  test "it correctly parses a cron-based schedule containing charlists" do
    schedule = %{
      :cron => '* * * * * *',
      :class => "SidekiqWorker",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert Parser.get_schedule(schedule) ==
             {
               "",
               "* * * * * * Asia/Kolkata",
               Poison.encode!(%{
                 :class => "SidekiqWorker",
                 :queue => "high",
                 :args => ["/tmp/poop"]
               }),
               %{enabled: true, include_metadata: false}
             }
  end

  test "it normalizes the cron string to the enhanced cron syntax (* * * * * *)" do
    schedule = %{
      :cron => "1 * * * *",
      :class => "SidekiqWorker",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert Parser.get_schedule(schedule) ==
             {
               "",
               "1 * * * * * Asia/Kolkata",
               Poison.encode!(%{
                 :class => "SidekiqWorker",
                 :queue => "high",
                 :args => ["/tmp/poop"]
               }),
               %{enabled: true, include_metadata: false}
             }
  end

  test "Raise exception if class is not configured" do
    schedule = %{
      :cron => "1 * * * *",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert_raise(ExqScheduler.Schedule.Parser.ConfigurationError, fn ->
      Parser.get_schedule(schedule)
    end)
  end
end
