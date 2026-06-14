defmodule AdoptionDemo.ReadmeWalkthroughTest do
  @moduledoc """
  Docs-parity gate for the Phase 91 deliverable: the demo README's "Admin Console
  Walkthrough" must keep matching reality. It documents the console URL, the seed
  command, and the click-around items — and the documented URL must actually
  resolve. Mirrors the library's `test/install_smoke/docs_parity_test.exs` pattern.

  Discharges UAT checkpoint "README Admin Walkthrough Accuracy". Prevents the
  walkthrough from drifting from the mounted routes without a human re-reading it.
  """
  use AdoptionDemoWeb.ConnCase

  @readme_path Path.expand("../README.md", __DIR__)

  defp readme, do: File.read!(@readme_path)

  test "README documents the admin console URL, seed command, and walkthrough items" do
    doc = readme()

    # Console entry point + the exact seed command developers must run first.
    assert doc =~ "/admin/rindle"
    assert doc =~ "mix run priv/repo/seeds.exs"

    # The three click-around surfaces called out in the walkthrough.
    assert doc =~ "Assets"
    assert doc =~ "Audio"
    assert doc =~ "Document"
    assert doc =~ ~r/Upload Sessions/i

    # Lifecycle edge cases the walkthrough promises are visible.
    assert doc =~ "quarantined"
    assert doc =~ "degraded"
  end

  test "the documented admin console URL actually resolves to the admin shell", %{conn: conn} do
    assert conn |> get("/admin/rindle") |> html_response(200) =~ "data-rindle-admin-root"
  end
end
