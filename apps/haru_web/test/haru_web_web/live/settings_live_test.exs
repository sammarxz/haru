defmodule HaruWebWeb.SettingsLiveTest do
  use HaruWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias HaruCore.Accounts

  defp create_user(_) do
    {:ok, user} =
      Accounts.register_user(%{email: "settings@example.com", password: "password12345"})

    %{user: user}
  end

  describe "Settings page" do
    setup :create_user

    test "renders settings page when authenticated", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, "/settings")

      assert html =~ "Account Settings"
      assert html =~ user.email
    end

    test "redirects to login when unauthenticated", %{conn: conn} do
      conn = get(conn, "/settings")
      assert redirected_to(conn) == "/login"
    end

    test "updates password with valid current password", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, "/settings")

      lv
      |> form("#password-form", %{
        "user" => %{
          "current_password" => "password12345",
          "password" => "newpassword123",
          "password_confirmation" => "newpassword123"
        }
      })
      |> render_submit()

      # All sessions are invalidated after password change; user is redirected to login
      assert_redirect(lv, "/login")

      # Verify new password works
      assert Accounts.get_user_by_email_and_password("settings@example.com", "newpassword123")
    end

    test "fails to update password with invalid current password", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, "/settings")

      lv
      |> form("#password-form", %{
        "user" => %{
          "current_password" => "wrongpassword",
          "password" => "newpassword123",
          "password_confirmation" => "newpassword123"
        }
      })
      |> render_submit()

      assert render(lv) =~ "is not valid"
    end
  end
end
