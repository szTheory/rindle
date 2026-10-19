defmodule Rindle.PublicSurfaceSnapshotTest do
  # Public modules, exported functions and macros, behaviour callbacks and migration
  # checksums must match test/fixtures/public_surface.txt. Docs chunks can differ between
  # Elixir minors, so the fixture is pinned to one lane and other lanes skip this module.
  use ExUnit.Case, async: true

  alias Rindle.Test.PublicSurface

  unless PublicSurface.canonical_lane?(System.version()) do
    @moduletag skip: "public surface fixture is pinned to the canonical Elixir 1.17 / OTP 27 lane"
  end

  @drift_module Rindle.Test.PublicSurface.DriftSample

  test "the rendered public surface matches the committed fixture" do
    expected = File.read!(PublicSurface.fixture_path())
    actual = PublicSurface.render()

    assert actual == expected, """
    The public surface differs from #{PublicSurface.fixture_path()}:

    #{Enum.join(PublicSurface.diff(expected, actual), "\n")}

    Regenerate the fixture only for a deliberate, separately approved API change:

        #{PublicSurface.regenerate_command()}
    """
  end

  test "rendering is deterministic" do
    first = PublicSurface.render()
    assert first == PublicSurface.render()
    lines = String.split(first, "\n", trim: true)
    assert lines == Enum.sort(lines)
    assert Enum.count(lines, &String.starts_with?(&1, "module Rindle")) >= 10
  end

  test "an extra exported function shows up as a diff naming it" do
    modules = PublicSurface.lib_modules()
    refute @drift_module in modules

    expected = PublicSurface.render(modules: modules, migrations_dir: "priv/repo/migrations")

    actual =
      PublicSurface.render(
        modules: modules ++ [@drift_module],
        migrations_dir: "priv/repo/migrations"
      )

    diff = PublicSurface.diff(expected, actual)

    assert "+ fun #{inspect(@drift_module)}.extra/1" in diff
    assert "+ module #{inspect(@drift_module)}" in diff
    refute Enum.any?(diff, &String.contains?(&1, "hidden_helper"))
    assert Enum.all?(diff, &String.starts_with?(&1, "+ "))
  end
end

defmodule Rindle.PublicSurfaceLaneTest do
  use ExUnit.Case, async: true

  alias Rindle.Test.PublicSurface

  test "only the Elixir 1.17 minor is the canonical snapshot lane" do
    assert PublicSurface.canonical_lane?("1.17.3")
    assert PublicSurface.canonical_lane?("1.17.0-rc.1")
    refute PublicSurface.canonical_lane?("1.15.8")
    refute PublicSurface.canonical_lane?("1.18.4")
    refute PublicSurface.canonical_lane?("not a version")
  end
end
