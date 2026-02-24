defmodule HaruWebWeb.PageControllerTest do
  use HaruWebWeb.ConnCase

  test "GET / renders landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Haru"
    assert html_response(conn, 200) =~ "Privacy-friendly website analytics"
    assert html_response(conn, 200) =~ "Start building for free"
  end
end
