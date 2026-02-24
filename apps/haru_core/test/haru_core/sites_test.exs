defmodule HaruCore.SitesTest do
  use HaruCore.DataCase, async: true

  alias HaruCore.Sites
  alias HaruCore.Sites.Site

  @valid_attrs %{name: "My Site", domain: "example.com"}
  @update_attrs %{name: "Updated Site", domain: "new.example.com"}
  @invalid_attrs %{name: nil, domain: nil}

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      HaruCore.Accounts.register_user(
        Enum.into(attrs, %{
          email: "user#{System.unique_integer([:positive])}@example.com",
          password: "password12345"
        })
      )

    user
  end

  def site_fixture(user, attrs \\ %{}) do
    {:ok, site} =
      attrs
      |> Enum.into(@valid_attrs)
      |> Map.put(:user_id, user.id)
      |> Sites.create_site()

    site
  end

  describe "sites" do
    test "list_sites_for_user/1 returns all sites for a user" do
      user = user_fixture()
      site = site_fixture(user)
      assert Sites.list_sites_for_user(user.id) == [site]
    end

    test "get_site!/1 returns the site with given id" do
      user = user_fixture()
      site = site_fixture(user)
      assert Sites.get_site!(site.id) == site
    end

    test "create_site/1 with valid data creates a site" do
      user = user_fixture()
      valid_attrs = Map.put(@valid_attrs, :user_id, user.id)
      assert {:ok, %Site{} = site} = Sites.create_site(valid_attrs)
      assert site.name == "My Site"
      assert site.domain == "example.com"
      assert is_binary(site.api_token)
    end

    test "create_site/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sites.create_site(%{user_id: nil})
    end

    test "update_site/2 with valid data updates the site" do
      user = user_fixture()
      site = site_fixture(user)
      assert {:ok, %Site{} = site} = Sites.update_site(site, @update_attrs)
      assert site.name == "Updated Site"
      assert site.domain == "new.example.com"
    end

    test "update_site/2 with invalid data returns error changeset" do
      user = user_fixture()
      site = site_fixture(user)
      assert {:error, %Ecto.Changeset{}} = Sites.update_site(site, @invalid_attrs)
      assert site == Sites.get_site!(site.id)
    end

    test "delete_site/1 deletes the site" do
      user = user_fixture()
      site = site_fixture(user)
      assert {:ok, %Site{}} = Sites.delete_site(site)
      assert_raise Ecto.NoResultsError, fn -> Sites.get_site!(site.id) end
    end

    test "change_site/1 returns a site changeset" do
      user = user_fixture()
      site = site_fixture(user)
      assert %Ecto.Changeset{} = Sites.change_site(site)
    end
  end
end
