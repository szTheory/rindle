defmodule Rindle.InstallSmoke.ReleaseDocsParityTest do
  use ExUnit.Case, async: true

  @mix_exs_path Path.expand("../../mix.exs", __DIR__)
  @release_guide_path Path.expand("../../guides/release_publish.md", __DIR__)
  @release_workflow_path Path.expand("../../.github/workflows/release.yml", __DIR__)
  @operations_path Path.expand("../../guides/operations.md", __DIR__)
  @readme_path Path.expand("../../README.md", __DIR__)
  @getting_started_path Path.expand("../../guides/getting_started.md", __DIR__)

  setup_all do
    {:ok,
     %{
       mix_exs: File.read!(@mix_exs_path),
       release_guide: File.read!(@release_guide_path),
       release_workflow: File.read!(@release_workflow_path),
       operations: File.read!(@operations_path),
       readme: File.read!(@readme_path),
       getting_started: File.read!(@getting_started_path)
     }}
  end

  test "release guide states the first public versioning sequence", %{
    release_guide: release_guide
  } do
    assert release_guide =~ ~s(@version "0.1.0-dev")
    assert release_guide =~ ~s(0.1.0)
    assert release_guide =~ ~s(v0.1.0)
    assert release_guide =~ "Release Please"
    assert release_guide =~ "main"
  end

  test "release guide keeps one-time publish prerequisites and personal-first owner follow-up", %{
    release_guide: release_guide
  } do
    for snippet <- [
          "mix hex.user whoami",
          "HEX_API_KEY",
          "initial owner",
          "package-name availability",
          "mix hex.owner list rindle",
          "mix hex.owner add rindle USERNAME"
        ] do
      assert release_guide =~ snippet
    end
  end

  test "release guide separates local diagnostics from exact-SHA CI proof", %{
    release_guide: release_guide
  } do
    for snippet <- [
          "Local preflight is diagnostic preparation, not authoritative release proof.",
          "Authoritative signoff requires a green GitHub Actions run on the exact release-candidate SHA",
          "waits for `ci.yml` on the exact release SHA to finish green",
          "Package Consumer + Release Preflight",
          "outside `scripts/release_preflight.sh`",
          "outside secret-gated automation"
        ] do
      assert release_guide =~ snippet
    end
  end

  test "maintainer release guidance stays in maintainer docs and is cross-linked", %{
    mix_exs: mix_exs,
    release_guide: release_guide,
    operations: operations,
    readme: readme,
    getting_started: getting_started
  } do
    assert mix_exs =~ ~s("guides/release_publish.md")
    assert operations =~ "release_publish"
    assert release_guide =~ "guides/release_publish.md"

    for doc <- [readme, getting_started] do
      refute doc =~ "HEX_API_KEY"
      refute doc =~ "mix hex.user"
      refute doc =~ "mix hex.owner"
    end
  end

  test "release guide includes package metadata review and preflight commands", %{
    release_guide: release_guide
  } do
    for snippet <- [
          "CHANGELOG.md",
          "0.1.0",
          "Package metadata review",
          "mix hex.build --unpack",
          "hex_metadata.config",
          "rindle",
          "MIT",
          "GitHub",
          "guides/release_publish.md",
          "mix docs --warnings-as-errors"
        ] do
      assert release_guide =~ snippet
    end
  end

  test "release guide names all live workflow step names matching the shipped release workflow",
       %{
         release_guide: release_guide,
         release_workflow: release_workflow
       } do
    step_names = [
      "Release Please",
      "Wait for CI to finish green on release SHA",
      "Run release preflight",
      "Verify version alignment",
      "Dry run Hex publish",
      "Live publish to Hex",
      "Wait for Hex.pm index",
      "Verify public Hex.pm artifact"
    ]

    for step_name <- step_names do
      assert release_guide =~ step_name,
             "release_publish.md is missing shipped step name: #{inspect(step_name)}"

      assert release_workflow =~ step_name,
             "release.yml is missing step name: #{inspect(step_name)} — workflow may have drifted"
    end
  end

  test "release guide includes all shipped repo commands matching the live workflow contract", %{
    release_guide: release_guide,
    release_workflow: release_workflow
  } do
    commands = [
      "bash scripts/release_preflight.sh",
      "bash scripts/assert_version_match.sh",
      "mix hex.publish --dry-run --yes",
      "mix hex.publish --yes",
      "bash scripts/public_smoke.sh"
    ]

    for command <- commands do
      assert release_guide =~ command,
             "release_publish.md is missing shipped command: #{inspect(command)}"

      assert release_workflow =~ command,
             "release.yml is missing command: #{inspect(command)} — workflow may have drifted"
    end
  end

  test "release guide does not contain stale deferred-automation wording about HEX_API_KEY", %{
    release_guide: release_guide
  } do
    stale_phrases = [
      "Phase 11 adds write-capable automation",
      "does not wire live `HEX_API_KEY` automation",
      "HEX_API_KEY automation is not wired yet",
      "deferred to Phase 11"
    ]

    for phrase <- stale_phrases do
      refute release_guide =~ phrase,
             "release_publish.md still contains stale deferred-automation claim: #{inspect(phrase)}"
    end

    # The guide must still discuss HEX_API_KEY as current reality, not future work
    assert release_guide =~ "HEX_API_KEY",
           "release_publish.md must mention HEX_API_KEY as part of the live workflow description"
  end

  test "release guide documents recovery-only publish from an exact ref", %{
    release_guide: release_guide,
    release_workflow: release_workflow
  } do
    for snippet <- [
          "workflow_dispatch",
          "recovery_reason",
          "recovery_ref",
          "40-character commit SHA",
          "existing tag"
        ] do
      assert release_guide =~ snippet
      assert release_workflow =~ snippet
    end
  end
end
