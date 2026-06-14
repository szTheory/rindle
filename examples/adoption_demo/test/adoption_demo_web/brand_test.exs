defmodule AdoptionDemoWeb.BrandTest do
  @moduledoc """
  Locks in the Phase 91 brand deliverable: the Cohort demo presents its own
  green mortarboard mark and "Cohort · Rindle demo" wordmark — never the default
  Phoenix placeholder logo or page title.

  Discharges UAT checkpoint "Logo Rendering" (formerly human-verified in
  91-HUMAN-UAT.md). No browser, no storage — fast and deterministic.
  """
  use AdoptionDemoWeb.ConnCase

  import Phoenix.LiveViewTest

  @logo_path Path.join([:code.priv_dir(:adoption_demo), "static", "images", "logo.svg"])

  test "launchpad header renders the Cohort logo and demo wordmark", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ ~s|src="/images/logo.svg"|
    assert html =~ "Cohort"
    assert html =~ "Rindle demo"
  end

  test "page title defaults to the Cohort brand, not the Phoenix placeholder", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Cohort · Rindle demo"
    # The HUMAN-UAT flagged a stale "· Phoenix Framework" tab title; this guards
    # against the placeholder ever returning to the rendered document title.
    refute html =~ "Phoenix Framework"
  end

  test "logo asset is the emerald mortarboard mark, not the Phoenix firebird" do
    svg = File.read!(@logo_path)

    # Selected Cohort brand palette (emerald/teal).
    assert svg =~ "#059669"
    assert svg =~ "#047857"
    assert svg =~ "#10B981"

    # Never the default Phoenix placeholder artwork.
    refute svg =~ ~r/phoenix/i
    refute svg =~ ~r/firebird/i
  end
end
