defmodule ExqScheduler do
  @moduledoc false

  use Application
  import Supervisor.Spec
  alias ExqScheduler.Storage.Redis

  def start(_type, _args) do
    children = [
      worker(Redix, [[], [name: Redis.pid()]]),
      worker(ExqScheduler.Scheduler.Server, [])
    ]

    opts = [strategy: :one_for_one, name: ExqScheduler.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
