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
      Supervisor.start_link([], [strategy: :one_for_one, name: supervisor_name(env)])
    end
  end

  def start_link(env) do
    children = [
      worker(Redix, [Keyword.get(env, :redis), [name: redis_name(env)]]),
      worker(Server, [env])
    ]

    opts = [strategy: :one_for_one, name: supervisor_name(env)]
    Supervisor.start_link(children, opts)
  end

  def redis_name(env) do
    Keyword.get(env, :redis)
    |> Keyword.get(:name, "#{__MODULE__}.Client" |> String.to_atom())
  end

  defp supervisor_name(env) do
    Keyword.get(env, :name, ExqScheduler.Supervisor)
  end
end
