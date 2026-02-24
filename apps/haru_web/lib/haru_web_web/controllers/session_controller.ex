defmodule HaruWebWeb.SessionController do
  use HaruWebWeb, :controller

  alias HaruCore.Accounts

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        render(conn, :new, error_message: "Invalid email or password")

      user ->
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_session(:user_token, token)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: "/dashboard")
    end
  end

  def delete(conn, _params) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    conn
    |> delete_session(:user_token)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: "/login")
  end
end
