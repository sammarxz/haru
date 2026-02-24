defmodule HaruWebWeb.SiteController do
  use HaruWebWeb, :controller

  alias HaruCore.Sites

  def delete(conn, %{"id" => id}) do
    site = Sites.get_site!(id)

    if site.user_id == conn.assigns.current_user.id do
      {:ok, _} = Sites.delete_site(site)

      conn
      |> put_flash(:info, "Site deleted.")
      |> redirect(to: "/dashboard")
    else
      conn
      |> put_flash(:error, "Not authorized.")
      |> redirect(to: "/dashboard")
    end
  end
end
