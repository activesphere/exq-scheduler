defmodule ExqScheduler.Schedule.Utils do
    alias Timex.Duration
    alias __MODULE__

    def get_elem(arr, index) do
        unless arr in [nil, []] do Enum.at(arr, index) else "" end
    end

    def str_to_float(numstr) do
        if numstr == "" do 0 else Float.parse(numstr) |> elem(0) end
    end

    def to_cron(every) do
        every
    end

    def to_duration(timestring) do

        # Parse week (W) syntax if present.
        weekPart = Regex.run(~r/(\d+(\.{1}\d+)*w{1})/, timestring)
            |> get_elem(0)
        numWeeks = weekPart |> String.trim("w") |> str_to_float
        timestring = String.replace(timestring, weekPart, "")

        {datePart, timePart} = {
            Regex.run(
                ~r/(\d+(\.{1}\d+)*y)?(\d+(\.{1}\d+)*M)?(\d+(\.{1}\d+)*d)?/,
                    timestring)
                |> Utils.get_elem(0),
            Regex.run(
                ~r/(\d+(\.{1}\d+)*h)?(\d+(\.{1}\d+)*m)?(\d+(\.{1}\d+)*s)?$/,
                    timestring)
                |> Utils.get_elem(0)
        }

        if {datePart, timePart} == {"", ""} do
            if numWeeks != 0 do Duration.from_weeks(numWeeks) else nil end
        else
            {:ok, duration} = cond do
                # If it's only date.
                timestring == datePart ->
                    Duration.parse "P#{String.upcase(datePart)}"
                # If it's only time.
                timestring == timePart ->
                    Duration.parse "PT#{String.upcase(timePart)}"
                # If it's both date and time.
                true ->
                    Duration.parse "P#{String.upcase(datePart)}" <>
                        "T#{String.upcase(timePart)}"
            end
            Duration.add(duration, Duration.from_weeks(numWeeks))
        end
    end
end
