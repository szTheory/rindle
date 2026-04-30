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
    for snippet <- [
          ~s(@version "0.1.0-dev"),
          "0.1.0",
          "v0.1.0",
          "Release Please",
          "main"
        ] do
      assert release_guide =~ snippet
    end
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
          "Authoritative signoff requires a green GitHub Actions run on the exact release-candidate SHA.",
          "waits for `ci.yml` on the exact release SHA",
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
          "Package Metadata Review",
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
      "Check whether Hex.pm release already exists",
      "Dry run Hex publish",
      "Publish to Hex.pm (live)",
      "Wait for Hex.pm index (post-publish)",
      "Verify public Hex.pm artifact"
    ]

    for step_name <- step_names do
      assert release_guide =~ step_name
      assert release_workflow =~ step_name
    end
  end

  test "release guide includes all shipped repo commands matching the live workflow contract", %{
    release_guide: release_guide,
    release_workflow: release_workflow
  } do
    commands = [
      "bash scripts/release_preflight.sh",
      "bash scripts/assert_version_match.sh",
      "bash scripts/hex_release_exists.sh",
      "mix hex.publish --dry-run --yes",
      "mix hex.publish --yes",
      "bash scripts/public_smoke.sh"
    ]

    for command <- commands do
      assert release_guide =~ command
      assert release_workflow =~ command
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
      refute release_guide =~ phrase
    end

    assert release_guide =~ "HEX_API_KEY"
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

  test "release guide keeps a tl dr cheatsheet within five lines", %{release_guide: release_guide} do
    [_, tl_dr | _] = String.split(release_guide, "## TL;DR\n\n", parts: 2)
    [section | _] = String.split(tl_dr, "\n\n", parts: 2)
    lines = section |> String.split("\n", trim: true)

    assert length(lines) <= 5
    assert Enum.all?(lines, &String.starts_with?(&1, "- "))
  end

  test "release guide footguns inventory covers the known publish traps", %{
    release_guide: release_guide
  } do
    for snippet <- [
          "Hex.pm versions are immutable",
          "Reverting the last release",
          "mix hex.owner add",
          "8MB",
          "Git dependencies",
          "Conventional commits",
          "autorelease: pending",
          "Manual tag pushes",
          "mix docs --warnings-as-errors",
          "Owner key and API key",
          "Component tags",
          "Trusted current tooling"
        ] do
      assert release_guide =~ snippet
    end
  end

  test "release guide appendix a captures the publish-window deviations", %{
    release_guide: release_guide
  } do
    for snippet <- [
          "Appendix A: Deviation Log",
          "a7efefd",
          "d5c21ad",
          "65728e5",
          "71a0f99",
          "6dd0d54",
          "idempotent recovery reruns"
        ] do
      assert release_guide =~ snippet
    end
  end

  test "release guide appendix b explains current tooling frozen source architecture", %{
    release_guide: release_guide
  } do
    for snippet <- [
          "Appendix B: Architecture Note",
          "current tooling",
          "frozen source",
          "git worktree",
          "recovery_ref",
          "main HEAD"
        ] do
      assert release_guide =~ snippet
    end
  end

  test "release guide voice is imperative and avoids stale hedge phrasing", %{
    release_guide: release_guide
  } do
    refute release_guide =~ "you should consider"
    refute release_guide =~ "the maintainer can"
    assert release_guide =~ "Run this sequence"
  end

  test "release guide rollback rewrite uses canonical commands and retirement caveats", %{
    release_guide: release_guide
  } do
    for snippet <- [
          "mix hex.publish --revert VERSION",
          "mix hex.retire rindle VERSION REASON --message",
          "renamed",
          "deprecated",
          "security",
          "invalid",
          "other",
          "mix hex.docs publish",
          "lockfiles still install the bad version",
          "24h for the first publish",
          "1h for subsequent releases",
          "Adopter advisory",
          "fix(release): retire BAD_VERSION, ship FIX_VERSION"
        ] do
      assert release_guide =~ snippet
    end

    assert release_guide =~ "mix hex.revert rindle VERSION"
    assert release_guide =~ "wrong legacy wording"
  end

  test "release guide bans replace in ci and explains the local-only exception", %{
    release_guide: release_guide
  } do
    assert release_guide =~ "Do not use `--replace` in CI."
    assert release_guide =~ "mix hex.publish --replace --yes"
  end

  test "release guide documents recovery skip semantics for already-published versions", %{
    release_guide: release_guide
  } do
    assert release_guide =~ "skips both publish steps"
    assert release_guide =~ "still runs public verification"
  end
end
