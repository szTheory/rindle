defmodule AdoptionDemoWeb.AdminMountTest do
  @moduledoc """
  Locks in the Phase 91 deliverable: the Rindle Admin Console is mounted at
  `/admin/rindle` and every top-level surface resolves to the admin shell.

  Discharges UAT checkpoint "Admin Console Mounted at /admin/rindle". The
  disconnected LiveView render is enough to prove the route is wired and the
  shell renders — no browser or storage required.
  """
  use AdoptionDemoWeb.ConnCase

  # The console's top-level surfaces, as documented in the demo README. The
  # router drift guard below asserts each of these is actually mounted, so this
  # list cannot silently rot away from reality.
  @admin_surfaces ~w(
    /admin/rindle
    /admin/rindle/assets
    /admin/rindle/upload-sessions
    /admin/rindle/variants-jobs
    /admin/rindle/runtime-doctor
    /admin/rindle/actions
  )

  test "every admin console surface returns 200 and renders the admin shell", %{conn: conn} do
    for path <- @admin_surfaces do
      resp = conn |> get(path) |> html_response(200)

      assert resp =~ "data-rindle-admin-root",
             "expected #{path} to render the Rindle admin shell, got a page without the admin root"
    end
  end

  test "admin surfaces are wired through the router (mount drift guard)", %{conn: _conn} do
    router_get_paths =
      AdoptionDemoWeb.Router.__routes__()
      |> Enum.filter(&(&1.verb == :get))
      |> Enum.map(& &1.path)
      |> MapSet.new()

    for path <- @admin_surfaces do
      assert MapSet.member?(router_get_paths, path),
             "expected #{path} to be mounted in AdoptionDemoWeb.Router — admin console unmounted?"
    end
  end
end
