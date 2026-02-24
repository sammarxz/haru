defmodule HaruCore.Repo.Migrations.CreateSites do
  use Ecto.Migration

  def change do
    create table(:sites) do
      add :name, :string, null: false
      add :domain, :string, null: false
      add :api_token, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sites, [:domain])
    create unique_index(:sites, [:api_token])
    create index(:sites, [:user_id])
  end
end
