defmodule HaruWebWeb.PublicDashboardLiveTest do
  use HaruWebWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias HaruCore.{Accounts, Analytics, Sites}

  defp create_public_site(_) do
    {:ok, user} = Accounts.register_user(%{email: "public@example.com", password: "password1234"})

    {:ok, site} =
      Sites.create_site(%{
        name: "Public Site",
        domain: "public.example.com",
        user_id: user.id
      })

    {:ok, site} = Sites.update_site_sharing(site, %{is_public: true, slug: "public-slug"})
    %{site: site}
  end

  describe "Public Dashboard" do
    setup :create_public_site

    test "renders public dashboard with slug", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, "/share/#{site.slug}")
      assert html =~ "Public Site"
      assert html =~ site.domain
    end

    test "redirects to home if site is not public", %{conn: conn, site: site} do
      {:ok, _site} = Sites.update_site_sharing(site, %{is_public: false})

      # In this specific implementation, it redirects to / for nil site
      # But get_site_by_slug only returns public sites? Let's check HaruCore.Sites
      conn = get(conn, "/share/#{site.slug}")
      assert redirected_to(conn) == "/"
    end

    test "updates on PubSub event", %{conn: conn, site: site} do
      {:ok, _} = Analytics.create_event(%{site_id: site.id, path: "/test", ip: "1.1.1.1"})

      {:ok, lv, _html} = live(conn, "/share/#{site.slug}")

      Phoenix.PubSub.broadcast(HaruCore.PubSub, "site:#{site.id}", {:new_event, site.id})

      # Wait for reload
      Process.sleep(50)
      html = render(lv)
      assert html =~ "People"
    end
  end
end
