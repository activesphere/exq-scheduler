defmodule ExqScheduler do
  @moduledoc false

  use Application
  import Supervisor.Spec
  alias ExqScheduler.Storage
  alias ExqScheduler.Scheduler.Server

  def start(_type, _args) do
    children = [
      worker(Redix, [[], [name: redis_pid()]]),
      worker(ExqScheduler.Scheduler.Server, [build_opts()])
    ]

    opts = [strategy: :one_for_one, name: ExqScheduler.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp build_opts do
    [
      storage_opts: build_storage_opts(),
      server_opts: build_server_opts()
    ]
  end

  defp build_server_opts do
    get_config(:server_opts)
    |> Server.Opts.new()
  end

  defp build_storage_opts do
    get_config(:storage_opts)
    |> Keyword.merge([redis_pid: redis_pid()])
    |> Storage.Opts.new()
  end

  defp get_config(key) do
    Application.get_env(:exq_scheduler, key)
  end

  defp redis_pid do
    "#{__MODULE__}.Client" |> String.to_atom()
  end
end
