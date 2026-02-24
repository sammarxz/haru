defmodule HaruCore.Repo.Migrations.AddPublicSharingToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :slug, :string, null: true
      add :is_public, :boolean, null: false, default: false
    end

    create unique_index(:sites, [:slug], where: "slug IS NOT NULL")
  end
end
