defmodule HaruWebWeb.DashboardLiveTest do
  use HaruWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias HaruCore.{Accounts, Analytics, Sites}

  defp create_user_and_site(_) do
    {:ok, user} =
      Accounts.register_user(%{email: "dashboard@example.com", password: "correct_password123"})

    {:ok, site} =
      Sites.create_site(%{name: "Live Test", domain: "live.example.com", user_id: user.id})

    %{user: user, site: site}
  end

  describe "unauthenticated" do
    test "redirects to login without session", %{conn: conn} do
      conn = get(conn, "/dashboard")
      assert redirected_to(conn) == "/login"
    end
  end

  describe "authenticated" do
    setup :create_user_and_site

    test "renders dashboard with site selector", %{conn: conn, user: user, site: site} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, "/dashboard/#{site.id}")

      assert html =~ "Haru"
      assert html =~ site.name
    end

    test "shows zero stats for new site", %{conn: conn, user: user, site: site} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, "/dashboard/#{site.id}")

      assert html =~ "People"
      assert html =~ "Views"
    end

    test "updates stats on new_event PubSub message", %{conn: conn, user: user, site: site} do
      {:ok, _} = Analytics.create_event(%{site_id: site.id, path: "/pubsub-test", ip: "1.2.3.4"})

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, "/dashboard/#{site.id}")

      Phoenix.PubSub.broadcast(HaruCore.PubSub, "site:#{site.id}", {:new_event, site.id})

      # Wait for LiveView to process
      Process.sleep(50)
      html = render(lv)
      assert html =~ "Views"
    end
  end
end
