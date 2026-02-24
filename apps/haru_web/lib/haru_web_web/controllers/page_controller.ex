defmodule HaruWebWeb.PageController do
  use HaruWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def terms(conn, _params) do
    render(conn, :terms, page_title: "Terms of Use")
  end

  def privacy(conn, _params) do
    render(conn, :privacy, page_title: "Privacy Policy")
  end
end
