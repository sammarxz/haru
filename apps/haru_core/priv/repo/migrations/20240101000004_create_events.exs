defmodule HaruCore.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :name, :string, null: false, default: "pageview"
      add :path, :string, null: false
      add :referrer, :string
      add :user_agent, :string
      add :screen_width, :integer
      add :screen_height, :integer
      add :country, :string
      add :ip_hash, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:events, [:site_id, :inserted_at])
    create index(:events, [:site_id, :path])
  end
end
