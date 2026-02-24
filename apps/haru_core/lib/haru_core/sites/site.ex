defmodule HaruCore.Sites.Site do
  @moduledoc "Ecto schema for a tracked website (site)."
  use Ecto.Schema
  import Ecto.Changeset

  schema "sites" do
    field(:name, :string)
    field(:domain, :string)
    field(:api_token, :string)
    field(:slug, :string)
    field(:is_public, :boolean, default: false)

    belongs_to(:user, HaruCore.Accounts.User)
    has_many(:events, HaruCore.Analytics.Event)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a site.
  Automatically generates an api_token if one is not provided.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(site, attrs) do
    site
    |> cast(attrs, [:name, :domain, :user_id])
    |> validate_required([:name, :domain, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_format(
      :domain,
      ~r/^(localhost(:\d+)?|(\d{1,3}\.){3}\d{1,3}(:\d+)?|[a-zA-Z0-9][a-zA-Z0-9\-\.]+[a-zA-Z0-9](:\d+)?)$/,
      message: "must be a valid domain (e.g. example.com, localhost:3000, 127.0.0.1:5500)"
    )
    |> unique_constraint(:domain)
    |> put_api_token()
    |> unique_constraint(:api_token)
  end

  @doc """
  Changeset for updating public sharing settings (slug and is_public).
  Separate from changeset/2 — does not touch name, domain, or api_token.
  """
  @spec sharing_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def sharing_changeset(site, attrs) do
    site
    |> cast(attrs, [:is_public, :slug])
    |> validate_length(:slug, min: 3, max: 60)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]*[a-z0-9]$/,
      message: "only lowercase letters, numbers, and hyphens; cannot start or end with a hyphen"
    )
    |> validate_slug_required_when_public()
    |> unique_constraint(:slug)
  end

  defp validate_slug_required_when_public(changeset) do
    is_public = get_field(changeset, :is_public)
    slug = get_field(changeset, :slug)

    if is_public && (is_nil(slug) || slug == "") do
      add_error(changeset, :slug, "is required when the site is public")
    else
      changeset
    end
  end

  defp put_api_token(%{data: %{api_token: nil}} = changeset) do
    put_change(changeset, :api_token, generate_token())
  end

  defp put_api_token(changeset), do: changeset

  @doc """
  Generates a secure random API token.
  """
  @spec generate_token() :: String.t()
  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
