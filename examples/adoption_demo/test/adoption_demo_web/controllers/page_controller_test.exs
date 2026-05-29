defmodule AdoptionDemoWeb.PageControllerTest do
  use AdoptionDemoWeb.ConnCase

  test "GET / renders adoption demo dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Rindle adoption demo"
  end
end
