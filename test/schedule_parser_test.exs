defmodule ScheduleParserTest do
  use ExUnit.Case, async: false
  alias ExqScheduler.Schedule.Parser
  alias ExqScheduler.Serializer

  test "it correctly parses a cron-based schedule containing bitstrings" do
    schedule = %{
      :cron => "* * * * * *",
      :class => "SidekiqWorker",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert_schedule(
      Parser.get_schedule(schedule),
      {
        "",
        "* * * * * * Asia/Kolkata",
        %{
          "class" => "SidekiqWorker",
          "queue" => "high",
          "args" => ["/tmp/poop"]
        },
        %{}
      }
    )
  end

  test "it correctly parses the description of the schedule" do
    schedule = %{
      :description => "this is a test",
      :cron => "* * * * * *",
      :class => "SidekiqWorker",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert_schedule(
      Parser.get_schedule(schedule),
      {
        "this is a test",
        "* * * * * * Asia/Kolkata",
        %{
          "class" => "SidekiqWorker",
          "args" => ["/tmp/poop"],
          "queue" => "high"
        },
        %{}
      }
    )
  end

  test "it correctly parses a cron-based schedule containing charlists" do
    schedule = %{
      :cron => ~c"* * * * * *",
      :class => "SidekiqWorker",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert_schedule(
      Parser.get_schedule(schedule),
      {
        "",
        "* * * * * * Asia/Kolkata",
        %{
          "class" => "SidekiqWorker",
          "queue" => "high",
          "args" => ["/tmp/poop"]
        },
        %{}
      }
    )
  end

  test "it normalizes the cron string to the enhanced cron syntax (* * * * * *)" do
    schedule = %{
      :cron => "1 * * * *",
      :class => "SidekiqWorker",
      :queue => "high",
      :args => ["/tmp/poop"]
    }

    assert_schedule(
      Parser.get_schedule(schedule),
      {
        "",
        "1 * * * * * Asia/Kolkata",
        %{
          "class" => "SidekiqWorker",
          "queue" => "high",
          "args" => ["/tmp/poop"]
        },
        %{}
      }
    )
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

  defp assert_schedule(
         {actual_description, actual_time, actual_job, actual_opts},
         {expected_description, expected_time, expected_job, expected_opts}
       ) do
    assert actual_description == expected_description
    assert actual_time == expected_time
    assert Serializer.decode!(actual_job) == expected_job
    assert actual_opts == expected_opts
  end
end
