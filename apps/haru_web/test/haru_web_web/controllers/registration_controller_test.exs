defmodule HaruWebWeb.RegistrationControllerTest do
  use HaruWebWeb.ConnCase, async: true

  alias HaruCore.Accounts

  describe "POST /register" do
    test "creates account and logs in user with valid data", %{conn: conn} do
      conn =
        post(conn, "/register", %{
          "email" => "newuser@example.com",
          "password" => "password123456"
        })

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_token)
      assert get_flash(conn, :info) =~ "Account created successfully"
    end

    test "redirects with errors for invalid data", %{conn: conn} do
      conn =
        post(conn, "/register", %{
          "email" => "invalid",
          "password" => "short"
        })

      assert redirected_to(conn) == "/register"
      assert get_flash(conn, :error)
    end

    test "redirects with error if email is taken", %{conn: conn} do
      {:ok, _user} =
        Accounts.register_user(%{email: "taken@example.com", password: "password1234"})

      conn =
        post(conn, "/register", %{
          "email" => "taken@example.com",
          "password" => "password1234"
        })

      assert redirected_to(conn) == "/register"
      assert get_flash(conn, :error) =~ "email has already been taken"
    end
  end
end
