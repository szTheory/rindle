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
    assert release_guide =~ "publish"
    assert release_guide =~ "next `-dev`"
  end

  test "release guide states auth and personal-first owner follow-up", %{
    release_guide: release_guide
  } do
    for snippet <- [
          "mix hex.user whoami",
          "mix hex.owner list rindle",
          "mix hex.owner add rindle USERNAME",
          "initial owner"
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

  test "release guide names all live workflow step names matching the shipped release workflow", %{
    release_guide: release_guide,
    release_workflow: release_workflow
  } do
    step_names = [
      "Run release preflight",
      "Verify version alignment",
      "Live publish to Hex",
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
end
