defmodule ExqScheduler.Schedule.Utils do
    alias Timex.Duration

    def to_cron(every) do
        every
    end

    def to_duration(timestring) do
        datetime = String.upcase(timestring) |> String.split("D")
        cond do
            # If it's only date i.e. day(s) (we're not supporting week, month, year).
            Regex.match?(~r/^\d+[dD]+$/, timestring) ->
                Duration.parse "P#{Enum.at(datetime, 0)}D"
            # If it's only time.
            length(datetime) == 1 ->
                Duration.parse "PT#{Enum.at(datetime, 0)}"
            # If it's both date and time.
            true ->
                Duration.parse "P#{Enum.at(datetime,0)}DT#{Enum.at(datetime, 1)}"
        end
    end
end
