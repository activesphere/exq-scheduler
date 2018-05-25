defmodule ExqScheduler do
  @moduledoc false

  use Application
  import Supervisor.Spec
  alias ExqScheduler.Scheduler.Server

  def start(_type, _args) do
    env = Application.get_all_env(:exq_scheduler)

    if Keyword.get(env, :start_on_application, true) do
      start_link(env)
    else
      Supervisor.start_link([], supervisor_opts(env))
    end
  end

  def start_link(env) do
    children = [
      redix_spec(env),
      worker(Server, [env])
    ]

    Supervisor.start_link(children, supervisor_opts(env))
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  defmodule ConfigurationError  do
    defexception message: "Invalid configuration!"
  end

  def redix_spec(env) do
    spec = env[:redis][:spec]

    if !is_map(spec) do
      raise ExqScheduler.ConfigurationError,
        message: "Invalid redis specification in the configuration. :spec must be a map, Please refer documentation"
    end
    spec
  end

  def redis_module(env), do: redix_spec(env).start |> elem(0)

  def redis_name(env), do: redix_spec(env).id

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
