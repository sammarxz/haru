defmodule HaruCore.AnalyticsTest do
  use HaruCore.DataCase, async: true

  alias HaruCore.{Accounts, Analytics, Sites}

  defp create_user_and_site(_) do
    {:ok, user} =
      Accounts.register_user(%{email: "analytics@example.com", password: "correct_password123"})

    {:ok, site} = Sites.create_site(%{name: "Test", domain: "test.example.com", user_id: user.id})
    %{site: site}
  end

  describe "create_event/1" do
    setup :create_user_and_site

    test "creates an event with hashed IP", %{site: site} do
      attrs = %{site_id: site.id, path: "/test", ip: "1.2.3.4"}

      assert {:ok, event} = Analytics.create_event(attrs)
      assert event.path == "/test"
      assert event.ip_hash != "1.2.3.4"
      assert String.length(event.ip_hash) == 64
    end

    test "returns error changeset with missing path", %{site: site} do
      assert {:error, changeset} = Analytics.create_event(%{site_id: site.id, ip: "1.2.3.4"})
      assert %{path: [_]} = errors_on(changeset)
    end

    test "returns error changeset with missing ip_hash", %{site: site} do
      assert {:error, _changeset} = Analytics.create_event(%{site_id: site.id, path: "/test"})
    end
  end

  describe "compute_stats/2" do
    setup :create_user_and_site

    test "returns zeros for a site with no events", %{site: site} do
      for period <- Analytics.valid_periods() do
        stats = Analytics.compute_stats(site.id, period)
        assert stats.total_views == 0
        assert stats.unique_visitors == 0
        assert stats.top_pages == []
        assert stats.top_referrers == []
        assert stats.top_countries == []
        assert stats.chart_views == []
      end
    end

    test "counts total views correctly", %{site: site} do
      for n <- 1..5 do
        {:ok, _} =
          Analytics.create_event(%{site_id: site.id, path: "/page-#{n}", ip: "10.0.0.#{n}"})
      end

      stats = Analytics.compute_stats(site.id, "today")
      assert stats.total_views == 5
    end

    test "counts unique visitors by ip_hash", %{site: site} do
      for _ <- 1..2, do: Analytics.create_event(%{site_id: site.id, path: "/", ip: "1.1.1.1"})
      Analytics.create_event(%{site_id: site.id, path: "/", ip: "2.2.2.2"})

      stats = Analytics.compute_stats(site.id, "today")
      assert stats.unique_visitors == 2
    end

    test "returns top pages ordered by count", %{site: site} do
      for _ <- 1..3,
          do: Analytics.create_event(%{site_id: site.id, path: "/popular", ip: "1.1.1.1"})

      Analytics.create_event(%{site_id: site.id, path: "/less", ip: "2.2.2.2"})

      stats = Analytics.compute_stats(site.id, "today")
      [first | _] = stats.top_pages
      assert first.path == "/popular"
      assert first.count == 3
    end

    test "includes period in result", %{site: site} do
      for period <- Analytics.valid_periods() do
        stats = Analytics.compute_stats(site.id, period)
        assert stats.period == period
      end
    end

    test "week and 30d periods work correctly", %{site: site} do
      Analytics.create_event(%{site_id: site.id, path: "/weekly", ip: "5.5.5.5"})

      stats_week = Analytics.compute_stats(site.id, "week")
      stats_30d = Analytics.compute_stats(site.id, "30d")

      assert stats_week.total_views >= 1
      assert stats_30d.total_views >= stats_week.total_views
    end
  end

  describe "get_stats/2 with cache" do
    setup :create_user_and_site

    test "caches independently per period", %{site: site} do
      Analytics.create_event(%{site_id: site.id, path: "/cached", ip: "1.1.1.1"})

      stats_today = Analytics.get_stats(site.id, "today")
      stats_30d = Analytics.get_stats(site.id, "30d")

      assert stats_today.period == "today"
      assert stats_30d.period == "30d"
      assert stats_30d.total_views >= stats_today.total_views
    end

    test "returns cached result on second call", %{site: site} do
      Analytics.create_event(%{site_id: site.id, path: "/", ip: "1.1.1.1"})

      stats1 = Analytics.get_stats(site.id, "today")
      stats2 = Analytics.get_stats(site.id, "today")
      assert stats1.total_views == stats2.total_views
    end
  end
end
