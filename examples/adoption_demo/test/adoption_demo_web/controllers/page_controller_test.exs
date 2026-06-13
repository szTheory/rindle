defmodule AdoptionDemoWeb.PageControllerTest do
  use AdoptionDemoWeb.ConnCase

  test "GET / renders the launchpad", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Rindle adoption demo"
    assert body =~ "What do you want to do?"
    assert body =~ "Before you start"
  end

  test "GET /dashboard renders the seeded app browser", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")
    body = html_response(conn, 200)
    assert body =~ "Members"
  end
end
