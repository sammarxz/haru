defmodule HaruCore.Analytics.Event do
  @moduledoc "Ecto schema for an analytics pageview or custom event."
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field(:name, :string, default: "pageview")
    field(:path, :string)
    field(:referrer, :string)
    field(:user_agent, :string)
    field(:screen_width, :integer)
    field(:screen_height, :integer)
    field(:country, :string)
    field(:ip_hash, :string)
    field(:duration_ms, :integer)

    belongs_to(:site, HaruCore.Sites.Site)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a new analytics event.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :site_id,
      :name,
      :path,
      :referrer,
      :user_agent,
      :screen_width,
      :screen_height,
      :country,
      :ip_hash,
      :duration_ms
    ])
    |> validate_required([:site_id, :path, :ip_hash])
    |> validate_length(:path, max: 2000)
    |> validate_length(:name, max: 100)
    |> validate_length(:referrer, max: 2000)
    |> validate_number(:screen_width, greater_than: 0, less_than: 10_000)
    |> validate_number(:screen_height, greater_than: 0, less_than: 10_000)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:site_id)
  end
end
