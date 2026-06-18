defmodule AdoptionDemoWeb.LaunchpadLiveTest do
  use AdoptionDemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders hero, access panel, credentials and task cards", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Rindle adoption demo"
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

  test "generator landing scaffold is absent from the launchpad source tree" do
    root = demo_root()

    retired_files = [
      Path.join([root, "lib/adoption_demo_web/controllers", "page_controller.ex"]),
      Path.join([root, "lib/adoption_demo_web/controllers", "page_html.ex"]),
      Path.join([root, "lib/adoption_demo_web/controllers", "page_html", "home.html.heex"]),
      Path.join([root, "test/adoption_demo_web/controllers", "page_controller_test.exs"])
    ]

    for path <- retired_files do
      refute File.exists?(path), "expected retired generator file to be absent: #{path}"
    end

    retired_terms = [
      Enum.join(["Page", "Controller"]),
      Enum.join(["Page", "HTML"]),
      Path.join(["page_html", "home.html"])
    ]

    source_files = Path.wildcard(Path.join(root, "{lib,test}/**/*.{ex,exs,heex}"))

    for file <- source_files, term <- retired_terms do
      refute File.read!(file) =~ term,
             "expected retired generator reference #{inspect(term)} to be absent from #{file}"
    end
  end

  defp demo_root do
    __DIR__
    |> Path.join("../../..")
    |> Path.expand()
  end
end
