defmodule HaruWebWeb.PageController do
  use HaruWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
