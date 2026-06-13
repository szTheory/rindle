defmodule AdoptionDemoWeb.LaunchpadLiveTest do
  use AdoptionDemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders hero, access panel, credentials and task cards", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "What do you want to do?"
    assert html =~ "Before you start"
    # MinIO credentials are surfaced inline.
    assert html =~ "minioadmin"

    # Task cards link to the live flows.
    assert has_element?(view, "a.ck-card", "Upload straight to storage")
    assert has_element?(view, ~s|a.ck-card[href="/upload?tab=image"]|)
    assert has_element?(view, ~s|a.ck-card[href="/admin/rindle"]|)

    # Primary CTA points at the seeded app browser.
    assert has_element?(view, ~s|a.ck-btn[href="/dashboard"]|, "Open the app")
  end

  test "copy buttons expose the value to copy", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ ~s|phx-hook="Copy"|
    assert html =~ ~s|data-copy="minioadmin"|
  end
end
