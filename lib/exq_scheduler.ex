defmodule ExqScheduler do
  @moduledoc false
  use Application

  alias ExqScheduler.Scheduler.Server
  alias ExqScheduler.Utils
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
          Utils.redix_spec(env),
          {Server, env}
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

  def schedules(name) do
    Server.schedules(Module.concat(name, "Server"))
  end

  def enqueue_now(name, schedule_name) do
    Server.enqueue_now(Module.concat(name, "Server"), schedule_name)
  end

  def enable(name, schedule_name) do
    Server.enable_schedule(Module.concat(name, "Server"), schedule_name, true)
  end

  def disable(name, schedule_name) do
    Server.enable_schedule(Module.concat(name, "Server"), schedule_name, false)
  end

  defmodule ConfigurationError do
    defexception message: "Invalid configuration!"
  end

  defp supervisor_opts(env) do
    opts = [strategy: :one_for_one]
    Keyword.merge(opts, ExqScheduler.Utils.name(env))
  end
end
