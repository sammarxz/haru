defmodule HaruWebWeb.Plugs.UserAuth do
  @moduledoc """
  Plugs for authentication: fetching the current user from the session
  and requiring authentication on protected routes.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias HaruCore.Accounts

  @doc """
  Fetches the current user from the session token and assigns it to conn.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  @doc """
  Plug that redirects unauthenticated users to the login page.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  @doc """
  Plug that redirects authenticated users away from guest-only pages.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: "/dashboard")
      |> halt()
    else
      conn
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: ["_haru_remember_me"])

      if token = conn.cookies["_haru_remember_me"] do
        {token, put_session(conn, :user_token, token)}
      else
        {nil, conn}
      end
    end
  end
end
