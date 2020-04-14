defmodule ExqScheduler do
  @moduledoc false

  use Application
  import Supervisor.Spec
  alias ExqScheduler.Scheduler.Server
  require Logger

  def start(_type, _args) do
    env = Application.get_all_env(:exq_scheduler)

    if Keyword.get(env, :start_on_application, true) do
      start_link(env)
    else
      Supervisor.start_link([], supervisor_opts(env))
    end
  end

  def start_link(env) do
    children =
      if Enum.empty?(env[:schedules]) do
        Logger.info("No schedules found in the application config, not starting :exq_scheduler")
        []
      else
        [
          redix_spec(env),
          worker(Server, [env])
        ]
      end

    Supervisor.start_link(children, supervisor_opts(env))
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def stop(supervisor) do
    Supervisor.stop(supervisor)
  end

  defmodule ConfigurationError do
    defexception message: "Invalid configuration!"
  end

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

      is_list(spec) ->
        {module, args} = hd(spec)
        module.child_spec(args)

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

  defp supervisor_opts(env) do
    opts = [strategy: :one_for_one]
    name = Keyword.get(env, :name)

    if name do
      Keyword.put(opts, :name, name)
    else
      opts
    end
  end
end
