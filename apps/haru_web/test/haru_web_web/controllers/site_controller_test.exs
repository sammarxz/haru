defmodule HaruWebWeb.SiteControllerTest do
  use HaruWebWeb.ConnCase, async: true

  alias HaruCore.{Accounts, Sites}

  setup do
    {:ok, user} = Accounts.register_user(%{email: "owner@example.com", password: "password1234"})
    {:ok, site} = Sites.create_site(%{name: "To Delete", domain: "delete.me", user_id: user.id})
    %{user: user, site: site}
  end

  describe "DELETE /sites/:id" do
    test "deletes site when authorized", %{conn: conn, user: user, site: site} do
      conn = conn |> log_in_user(user) |> delete("/sites/#{site.id}")

      assert redirected_to(conn) == "/dashboard"
      assert get_flash(conn, :info) =~ "Site deleted"
      assert Sites.get_site(site.id) == nil
    end

    test "does not delete site when unauthorized", %{conn: conn, site: site} do
      {:ok, other_user} =
        Accounts.register_user(%{email: "other@example.com", password: "password1234"})

      conn = conn |> log_in_user(other_user) |> delete("/sites/#{site.id}")

      assert redirected_to(conn) == "/dashboard"
      assert get_flash(conn, :error) =~ "Not authorized"
      assert Sites.get_site(site.id) != nil
    end
  end
end
