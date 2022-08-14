defmodule ExqScheduler.Utils do
  @moduledoc false

  def redix_spec(env) do
    spec = env[:redis][:child_spec]

    cond do
      is_tuple(spec) ->
        {module, args} = spec
        module.child_spec(args)

      is_atom(spec) ->
        spec.child_spec([])

      is_map(spec) ->
        spec

      true ->
        raise ExqScheduler.ConfigurationError,
          message:
            "Invalid redis specification in the configuration. :spec must be a map, Please refer documentation"
    end
  end

  def redis_module(env) do
    redix_spec(env).start() |> elem(0)
  end

  def redis_name(env), do: env[:redis][:name]
end
