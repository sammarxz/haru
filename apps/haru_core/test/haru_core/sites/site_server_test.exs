defmodule HaruCore.Sites.SiteServerTest do
  use ExUnit.Case, async: true
  alias HaruCore.Sites.SiteServer

  setup do
    site_id = System.unique_integer([:positive])
    start_supervised!({SiteServer, site_id})
    %{site_id: site_id}
  end

  test "active_visitor_count/1 starts at 0", %{site_id: site_id} do
    assert SiteServer.active_visitor_count(site_id) == 0
  end

  test "record_event/2 increments active visitors", %{site_id: site_id} do
    SiteServer.record_event(site_id, %{ip_hash: "hash1"})
    SiteServer.record_event(site_id, %{ip_hash: "hash2"})
    assert SiteServer.active_visitor_count(site_id) == 2
  end

  test "record_event/2 handles missing ip_hash", %{site_id: site_id} do
    SiteServer.record_event(site_id, %{something: :else})
    assert SiteServer.active_visitor_count(site_id) == 0
  end
end
