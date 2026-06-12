defmodule Rindle.Admin.OptionalDependencyTest do
  use ExUnit.Case, async: true

  @admin_live_modules [
    Rindle.Admin.Live.HomeLive,
    Rindle.Admin.Live.AssetsLive,
    Rindle.Admin.Live.UploadSessionsLive,
    Rindle.Admin.Live.VariantsJobsLive,
    Rindle.Admin.Live.RuntimeDoctorLive,
    Rindle.Admin.Live.ActionsLive
  ]

  test "admin router exports the mount macro when LiveView dependencies are loaded" do
    assert Code.ensure_loaded?(Rindle.Admin.Router),
           "Rindle.Admin.Router must compile when Phoenix and LiveView are loaded"

    assert macro_exported?(Rindle.Admin.Router, :rindle_admin, 2),
           "Rindle.Admin.Router must export rindle_admin/2 as a router macro"
  end

  test "admin components and LiveViews load when LiveView dependencies are available" do
    assert Code.ensure_loaded?(Rindle.Admin.Components),
           "Rindle.Admin.Components must compile when Phoenix.Component is loaded"

    for module <- @admin_live_modules do
      assert Code.ensure_loaded?(module),
             "#{inspect(module)} must compile when Phoenix.LiveView is loaded"
    end
  end

  test "phoenix_live_view remains optional and no runtime UI framework dependency is added" do
    mix_source = File.read!("mix.exs")

    assert mix_source =~ ~r/{:phoenix_live_view,\s*"~> 1\.0",\s*optional:\s*true}/

    for forbidden_dependency <- ~w(tailwind daisy shadcn radix tailwind_ui) do
      refute mix_source =~ forbidden_dependency
    end
  end
end
