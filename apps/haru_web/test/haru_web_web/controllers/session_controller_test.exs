defmodule HaruWebWeb.SessionControllerTest do
  use HaruWebWeb.ConnCase, async: true

  alias HaruCore.Accounts

  setup do
    {:ok, user} = Accounts.register_user(%{email: "test@example.com", password: "password1234"})
    %{user: user}
  end

  describe "GET /login" do
    test "renders login page", %{conn: conn} do
      conn = get(conn, "/login")
      assert html_response(conn, 200) =~ "Sign in"
    end
  end

  describe "POST /login" do
    test "logs in user with valid credentials", %{conn: conn, user: user} do
      conn = post(conn, "/login", %{"email" => user.email, "password" => "password1234"})
      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_token)
    end

    test "renders errors with invalid credentials", %{conn: conn} do
      conn = post(conn, "/login", %{"email" => "unknown@example.com", "password" => "wrong"})
      assert html_response(conn, 200) =~ "Invalid email or password"
    end
  end

  describe "DELETE /logout" do
    test "logs out user", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete("/logout")
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :user_token)
    end
  end
end
