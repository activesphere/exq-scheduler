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

  defmodule ConfigurationError do
    defexception message: "Invalid configuration!"
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
end
