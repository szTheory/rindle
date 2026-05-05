defmodule Rindle.BackwardCompat.V13DigestSnapshotTest do
  @moduledoc """
  Load-bearing snapshot of the v1.3 recipe digest for the canonical adopter
  profile's :thumb variant.

  If this test fails on v1.4, the validator is persisting :kind into
  image-default specs (D-14 violation) and every existing adopter's image
  variants will silently flip to :stale on upgrade. This is a P0 regression
  class per RESEARCH.md Pitfall 1.

  The expected digest below was captured via:

      mix run -e \\
        'IO.puts(Rindle.Adopter.CanonicalApp.Profile.recipe_digest(:thumb))'

  ON THE v1.3 CODEBASE, BEFORE Phase 24 validator changes (Plan 04). Do NOT
  regenerate this value casually — recapturing AFTER validator edits defeats
  the purpose of the snapshot.

  Captured: 2026-05-02
  """

  use ExUnit.Case, async: true

  alias Rindle.Adopter.CanonicalApp.Profile, as: AdopterProfile

  # CAPTURED PRE-PHASE-24. DO NOT EDIT WITHOUT REGENERATING ON A v1.3 CHECKOUT.
  @v13_thumb_digest "3a9ab2f60b2d26217471f22cc329252acba546c6341111a3ef89a8d9978d30a7"

  test "image-default :thumb digest matches v1.3 snapshot (per D-14, D-22, D-23)" do
    assert AdopterProfile.recipe_digest(:thumb) == @v13_thumb_digest
  end

  test "explicit :kind => :image yields the same digest as omitted :kind" do
    explicit = compile_profile_with_explicit_image_kind()
    omitted = compile_profile_with_omitted_kind()

    assert explicit.recipe_digest(:thumb) == omitted.recipe_digest(:thumb)
  end

  test "validated :thumb spec does NOT carry a :kind key" do
    spec = AdopterProfile.variants()[:thumb]

    refute Map.has_key?(spec, :kind),
           "validator must omit :kind from validated map for image-default profiles (D-14)"
  end

  defp compile_profile_with_explicit_image_kind do
    compile_profile("""
    storage: Rindle.StorageMock,
    variants: [thumb: [kind: :image, mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/jpeg"],
    allow_extensions: [".jpg"],
    max_bytes: 5_000_000,
    max_pixels: 24_000_000
    """)
  end

  defp compile_profile_with_omitted_kind do
    compile_profile("""
    storage: Rindle.StorageMock,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/jpeg"],
    allow_extensions: [".jpg"],
    max_bytes: 5_000_000,
    max_pixels: 24_000_000
    """)
  end

  defp compile_profile(profile_opts_source) do
    module_name = unique_module_name("CompiledProfile")

    source = """
    defmodule #{module_name} do
      use Rindle.Profile,
        #{profile_opts_source}
    end
    """

    [{compiled_module, _bytecode}] = Code.compile_string(source)
    compiled_module
  end

  defp unique_module_name(prefix) do
    :"Elixir.Rindle.Profile.#{prefix}#{System.unique_integer([:positive])}"
  end
end
