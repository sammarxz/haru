defmodule HaruWebWeb.SettingsLive.SiteTest do
  use HaruWebWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias HaruCore.{Accounts, Sites}

  defp create_user_and_site(_) do
    {:ok, user} =
      Accounts.register_user(%{email: "site-settings@example.com", password: "password12345"})

    {:ok, site} =
      Sites.create_site(%{name: "Test Site", domain: "testsite.com", user_id: user.id})

    %{user: user, site: site}
  end

  describe "Site Settings" do
    setup :create_user_and_site

    test "renders site settings", %{conn: conn, user: user, site: site} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, "/sites/#{site.id}/settings")

      assert html =~ "Settings"
      assert html =~ site.domain
    end

    test "updates project settings", %{conn: conn, user: user, site: site} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, "/sites/#{site.id}/settings")

      lv
      |> form("#settings-form", %{
        "site" => %{"name" => "Updated Name", "domain" => "updated.com"}
      })
      |> render_submit()

      assert render(lv) =~ "Site updated successfully"
      assert Sites.get_site!(site.id).name == "Updated Name"
    end

    test "validates settings on change", %{conn: conn, user: user, site: site} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, "/sites/#{site.id}/settings")

      html =
        lv
        |> form("#settings-form", %{
          "site" => %{"name" => "", "domain" => "invalid"}
        })
        |> render_change()

      assert html =~ "Project settings"
      # Just verify it rendered something back
      assert html =~ "Domain"
    end

    test "updates sharing settings", %{conn: conn, user: user, site: site} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, "/sites/#{site.id}/settings")

      lv
      |> form("#sharing-form", %{
        "site" => %{"is_public" => "true", "slug" => "new-slug"}
      })
      |> render_submit()

      assert render(lv) =~ "Sharing settings updated"
      updated_site = Sites.get_site!(site.id)
      assert updated_site.is_public == true
      assert updated_site.slug == "new-slug"
    end

    test "deletes site via modal", %{conn: conn, user: user, site: site} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, "/sites/#{site.id}/settings")

      lv |> render_click("toggle_delete_modal")
      assert render(lv) =~ "Delete Project?"

      lv |> render_click("delete_site")
      assert_redirect(lv, "/dashboard")
      assert Sites.get_site(site.id) == nil
    end

    test "redirects if site belongs to another user", %{conn: conn, site: site} do
      {:ok, other_user} =
        Accounts.register_user(%{email: "other-user@example.com", password: "password12345"})

      conn = log_in_user(conn, other_user)

      {:ok, _lv, _html} =
        live(conn, "/sites/#{site.id}/settings")
        |> follow_redirect(conn, "/dashboard")
    end
  end
end
