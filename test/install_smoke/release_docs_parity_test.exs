defmodule Rindle.InstallSmoke.ReleaseDocsParityTest do
  use ExUnit.Case, async: true

  @mix_exs_path Path.expand("../../mix.exs", __DIR__)
  @release_guide_path Path.expand("../../guides/release_publish.md", __DIR__)
  @operations_path Path.expand("../../guides/operations.md", __DIR__)
  @readme_path Path.expand("../../README.md", __DIR__)
  @getting_started_path Path.expand("../../guides/getting_started.md", __DIR__)

  setup_all do
    {:ok,
     %{
       mix_exs: File.read!(@mix_exs_path),
       release_guide: File.read!(@release_guide_path),
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
end
