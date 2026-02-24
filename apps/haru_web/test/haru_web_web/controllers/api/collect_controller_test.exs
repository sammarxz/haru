defmodule HaruWebWeb.Api.CollectControllerTest do
  use HaruWebWeb.ConnCase, async: false

  alias HaruCore.{Accounts, Analytics, Sites}

  defp create_user_and_site(_) do
    {:ok, user} =
      Accounts.register_user(%{email: "collect@example.com", password: "correct_password123"})

    {:ok, site} =
      Sites.create_site(%{name: "Test", domain: "collect.example.com", user_id: user.id})

    %{site: site}
  end

  describe "POST /api/collect" do
    setup :create_user_and_site

    test "returns 200 with valid bearer token", %{conn: conn, site: site} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{site.api_token}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/collect", %{"p" => "/test", "r" => "https://google.com"})

      assert conn.status == 200
    end

    test "returns 401 with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token_xyz")
        |> put_req_header("content-type", "application/json")
        |> post("/api/collect", %{"p" => "/test"})

      assert conn.status == 401
    end

    test "returns 401 with no token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/collect", %{"p" => "/test"})

      assert conn.status == 401
    end

    test "accepts token via query param", %{conn: conn, site: site} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/collect?t=#{site.api_token}", %{"p" => "/test"})

      assert conn.status == 200
    end

    test "event persists asynchronously", %{conn: conn, site: site} do
      conn
      |> put_req_header("authorization", "Bearer #{site.api_token}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/collect", %{"p" => "/async-test"})

      # Wait briefly for async task to complete
      Process.sleep(100)

      count = Analytics.recent_event_count(site.id, 5)
      assert count >= 1
    end
  end
end
