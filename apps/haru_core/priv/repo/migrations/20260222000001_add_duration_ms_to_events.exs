defmodule HaruCore.Repo.Migrations.AddDurationMsToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :duration_ms, :integer, null: true
    end
  end
end
