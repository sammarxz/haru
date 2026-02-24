defmodule HaruWebWeb.PageControllerTest do
  use HaruWebWeb.ConnCase

  test "GET / renders landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Haru"
  end
end
