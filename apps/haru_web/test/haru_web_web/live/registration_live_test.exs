defmodule HaruWebWeb.RegistrationLiveTest do
  use HaruWebWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/register")
      assert html =~ "Create your account"
      assert html =~ "Email"
    end

    test "calculates password strength", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/register")

      html = render_change(lv, "validate", %{"password" => "weakpassword"})
      assert html =~ "Weak"

      html = render_change(lv, "validate", %{"password" => "StrongPassword123!"})
      assert html =~ "Strong"
    end
  end
end
