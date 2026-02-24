defmodule HaruCore.Release do
  @moduledoc """
  Tasks for running database operations inside a production release,
  where Mix is not available.

  Usage:
    # Run migrations
    /app/bin/haru eval "HaruCore.Release.migrate()"

    # Rollback
    /app/bin/haru eval "HaruCore.Release.rollback(HaruCore.Repo, 20230101000000)"
  """

  @app :haru_core

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
