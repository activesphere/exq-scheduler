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
      worker(Redix, redix_args(env)),
      worker(Server, [env])
    ]

    Supervisor.start_link(children, supervisor_opts(env))
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 500
    }
  end

  def redis_name(env) do
    Keyword.get(env, :redis)
    |> Keyword.get(:name, "#{__MODULE__}.Client" |> String.to_atom())
  end

  defp supervisor_opts(env) do
    opts = [strategy: :one_for_one]
    name = Keyword.get(env, :name)

    if name do
      Keyword.put(opts, :name, name)
    else
      opts
    end
  end

  def redix_args(env) do
    redis_opts = Keyword.get(env, :redis)
    [Keyword.drop(redis_opts,[:name, :backoff_initial, :backoff_max]),
     [name: redis_name(env),
      backoff_max: redis_opts[:backoff_max],
      backoff_initial: redis_opts[:backoff_initial]]]
  end
end
