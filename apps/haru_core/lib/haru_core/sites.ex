defmodule HaruCore.Sites do
  @moduledoc """
  Context for managing sites (tracked websites).
  """

  import Ecto.Query
  alias HaruCore.Repo
  alias HaruCore.Sites.Site

  @doc """
  Lists all sites belonging to a user.
  """
  @spec list_sites_for_user(pos_integer()) :: [Site.t()]
  def list_sites_for_user(user_id) do
    Repo.all(from(s in Site, where: s.user_id == ^user_id, order_by: [asc: s.inserted_at]))
  end

  @doc """
  Lists all sites in the system.
  """
  @spec list_sites() :: [Site.t()]
  def list_sites do
    Repo.all(from(s in Site, order_by: [asc: s.inserted_at]))
  end

  @doc """
  Gets a site by ID, returning nil if not found.
  """
  @spec get_site(pos_integer()) :: Site.t() | nil
  def get_site(id), do: Repo.get(Site, id)

  @doc """
  Gets a site by ID, raising if not found.
  """
  @spec get_site!(pos_integer()) :: Site.t()
  def get_site!(id), do: Repo.get!(Site, id)

  @doc """
  Returns the site with the given API token, or nil if not found.
  Used by the tracking endpoint to identify incoming events.
  """
  @spec get_site_by_token(String.t()) :: Site.t() | nil
  def get_site_by_token(token) when is_binary(token) do
    Repo.get_by(Site, api_token: token)
  end

  def get_site_by_token(_), do: nil

  @doc """
  Creates a new site for the given user.
  Returns `{:ok, site}` or `{:error, changeset}`.
  """
  @spec create_site(map()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def create_site(attrs) do
    %Site{}
    |> Site.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a site and all its associated events (via DB cascade).
  """
  @spec delete_site(Site.t()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def delete_site(%Site{} = site) do
    Repo.delete(site)
  end

  @doc """
  Updates a site.
  """
  @spec update_site(Site.t(), map()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def update_site(%Site{} = site, attrs) do
    site
    |> Site.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking site changes.
  """
  @spec change_site(Site.t(), map()) :: Ecto.Changeset.t()
  def change_site(%Site{} = site, attrs \\ %{}) do
    Site.changeset(site, attrs)
  end

  @doc """
  Gets a site by its public slug. Returns nil if the site is not public or not found.
  """
  @spec get_site_by_slug(String.t()) :: Site.t() | nil
  def get_site_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Site, slug: slug, is_public: true)
  end

  def get_site_by_slug(_), do: nil

  @doc """
  Returns a changeset for tracking public sharing changes.
  """
  @spec change_site_sharing(Site.t(), map()) :: Ecto.Changeset.t()
  def change_site_sharing(%Site{} = site, attrs \\ %{}) do
    Site.sharing_changeset(site, attrs)
  end

  @doc """
  Updates the public sharing settings for a site.
  """
  @spec update_site_sharing(Site.t(), map()) :: {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def update_site_sharing(%Site{} = site, attrs) do
    site
    |> Site.sharing_changeset(attrs)
    |> Repo.update()
  end
end
