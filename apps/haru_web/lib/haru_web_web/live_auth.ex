defmodule HaruWebWeb.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hooks for authentication.

  Used with `live_session` in the router to centralize auth guards,
  eliminating the need to repeat session checks in every `mount/3`.

  Available hooks:
  - `:ensure_authenticated` — halts and redirects to /login if not logged in
  - `:redirect_if_authenticated` — redirects to /dashboard if already logged in
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias HaruCore.Accounts

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, push_navigate(socket, to: "/login")}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:halt, push_navigate(socket, to: "/dashboard")}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(session, socket) do
    assign_new(socket, :current_user, fn ->
      case session do
        %{"user_token" => token} -> Accounts.get_user_by_session_token(token)
        _ -> nil
      end
    end)
  end
end
