defmodule HaruCore.Application do
  @moduledoc """
  HaruCore OTP Application.

  Supervision tree:
    - Repo (database connection pool)
    - PubSub (cross-app real-time messaging)
    - SiteRegistry (Registry for named SiteServer processes)
    - DynamicSupervisor (manages per-site SiteServer processes)
    - StatsCache (ETS-backed stats cache)
    - StatsRefresher (periodic ETS flush)
    - Task.Supervisor (async fire-and-forget DB writes)
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HaruCore.Repo,
      {Phoenix.PubSub, name: HaruCore.PubSub},
      {Registry, keys: :unique, name: HaruCore.SiteRegistry},
      {DynamicSupervisor, name: HaruCore.Sites.DynamicSupervisor, strategy: :one_for_one},
      HaruCore.Cache.StatsCache,
      HaruCore.Cache.StatsRefresher,
      {Task.Supervisor, name: HaruCore.Tasks.Supervisor}
    ]

    opts = [strategy: :one_for_one, name: HaruCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
