Code.require_file("support.ex", __DIR__)

defmodule Rindle.InstallSmoke.DocsParity.OperationsTest do
  import Rindle.InstallSmoke.DocsParity.Support
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../../README.md", __DIR__)
  @contributing_path Path.expand("../../../CONTRIBUTING.md", __DIR__)
  @guide_path Path.expand("../../../guides/getting_started.md", __DIR__)
  @troubleshooting_path Path.expand("../../../guides/troubleshooting.md", __DIR__)
  @running_path Path.expand("../../../RUNNING.md", __DIR__)
  @operations_path Path.expand("../../../guides/operations.md", __DIR__)
  @ci_workflow_path Path.expand("../../../.github/workflows/ci.yml", __DIR__)
  @ci_summary_path Path.expand("../../../scripts/ci/eval_ci_summary.sh", __DIR__)
  @tool_versions_path Path.expand("../../../.tool-versions", __DIR__)
  @stability_sentence "Rindle follows Semantic Versioning. While Rindle is 0.x, public APIs may change between minor versions; review CHANGELOG.md and guides/upgrading.md before upgrading. Rindle 1.0 will mean the public API is stable enough that breaking public API changes move to major versions."
  @nine_mix_tasks [
    "mix rindle.abort_incomplete_uploads",
    "mix rindle.backfill_metadata",
    "mix rindle.batch_owner_erasure",
    "mix rindle.cleanup_orphans",
    "mix rindle.doctor",
    "mix rindle.regenerate_variants",
    "mix rindle.runtime_status",
    "mix rindle.sweep_orphaned_temp_files",
    "mix rindle.verify_storage"
  ]

  setup_all do
    {:ok,
     load_docs!(%{
       readme: @readme_path,
       contributing: @contributing_path,
       guide: @guide_path,
       troubleshooting: @troubleshooting_path,
       running: @running_path,
       operations: @operations_path,
       ci_workflow: @ci_workflow_path,
       ci_summary: @ci_summary_path,
       tool_versions: @tool_versions_path
     })}
  end

  test "root documentation derives CI and supported-toolchain posture from shipped policy", %{
    readme: readme,
    contributing: contributing,
    running: running,
    ci_workflow: ci_workflow,
    ci_summary: ci_summary,
    tool_versions: tool_versions
  } do
    assert ci_workflow =~ "name: CI Summary"
    assert ci_workflow =~ "- package-consumer"
    refute ci_workflow =~ "- package-consumer-full\n    if: always()"
    assert ci_summary =~ "success|skipped"
    assert tool_versions =~ "elixir 1.17"
    assert tool_versions =~ "erlang 27"

    for doc <- [readme, contributing, running] do
      assert doc =~ "CI Summary"
    end

    for doc <- [readme, contributing, running] do
      assert Regex.match?(~r/Elixir 1\.17\/OTP\s+27/, doc)
    end

    assert running =~ "package-consumer-full"
    assert running =~ "off-critical-path"
    assert contributing =~ "skipped` counts as pass"
  end

  test "README and CONTRIBUTING state the shared pre-1.0 stability contract", %{
    readme: readme,
    contributing: contributing
  } do
    for {doc, name} <- [{readme, "README"}, {contributing, "CONTRIBUTING"}] do
      assert doc =~ "## Versioning and stability"
      assert doc =~ @stability_sentence

      assert doc |> String.split(@stability_sentence) |> length() == 2,
             "#{name} should contain the shared stability sentence exactly once"
    end

    assert_in_order!(readme, ["## Versioning and stability", "## Install"])

    assert_in_order!(contributing, [
      "## Versioning and stability",
      "## Reproduce the PR gate locally: `mix ci`"
    ])
  end

  test "README and getting-started describe CI-validated install smoke posture", %{
    readme: readme,
    guide: guide
  } do
    assert readme =~ "generated Phoenix app"
    assert readme =~ "Hex publish"

    for snippet <- [
          "install smoke",
          "generated Phoenix app",
          "image-only",
          "AV-enabled",
          "signed delivery"
        ] do
      assert guide =~ snippet
    end
  end

  test "docs distinguish public install guidance from maintainer-only release runbooks", %{
    readme: readme,
    guide: guide
  } do
    assert readme =~ "upgrade runbook"
    assert guide =~ "Maintainer-only release"
    assert guide =~ "orchestration lives in"
    assert guide =~ "[Release Publish](release_publish.html)"

    refute readme =~ "GSD Hygiene"

    for doc <- [readme, guide] do
      refute doc =~ "mix hex.user whoami"
      refute doc =~ "HEX_API_KEY"
    end
  end

  test "running guide publishes the durable libvips install matrix", %{running: running} do
    for snippet <- [
          "libvips",
          "libvips-dev",
          "brew install vips",
          "Image runtime (libvips)"
        ] do
      assert running =~ snippet
    end
  end

  test "running guide publishes the durable FFmpeg install matrix", %{running: running} do
    for snippet <- [
          "FFmpeg >= 6.0",
          "brew install ffmpeg",
          "apt-get install -y ffmpeg",
          "apk add --no-cache ffmpeg",
          "bash scripts/ci/install_ffmpeg.sh",
          "Fly.io Dockerfile",
          "Heroku Aptfile",
          "Render Dockerfile",
          "mix rindle.doctor"
        ] do
      assert running =~ snippet
    end

    refute running =~ "FedericoCarboni/setup-ffmpeg"
  end

  test "running guide publishes the maintainer CI lane severity matrix", %{running: running} do
    for snippet <- [
          "Maintainer: CI lane severity",
          "Adopters can skip this section",
          "merge-blocking",
          "advisory",
          "secret-gated soak",
          "package-consumer",
          "adopter",
          "`proof`",
          "repo_hygiene_check.sh",
          "docs_parity_test.exs",
          "batch_owner_erasure_task_test.exs",
          ".github/workflows/ci.yml"
        ] do
      assert running =~ snippet
    end
  end

  test "running guide documents proof job as merge-blocking", %{running: running} do
    assert running =~ "`proof`"
    assert running =~ "merge-blocking"
    refute running =~ "Canonical lifecycle + doc parity"
  end

  test "troubleshooting guide is part of the public AV docs surface", %{
    troubleshooting: troubleshooting
  } do
    assert troubleshooting =~ "mix rindle.doctor"
    assert troubleshooting =~ "mix rindle.runtime_status"
    assert troubleshooting =~ "Rindle.Error.message/1"
    refute troubleshooting =~ "test/rindle/error_test.exs"
    assert troubleshooting =~ "`:ffmpeg_not_found`"
    assert troubleshooting =~ "`:range_unparseable`"
  end

  test "operations guide lists all nine shipped mix tasks" do
    operations = File.read!(@operations_path)

    assert operations =~ "nine Mix tasks"
    refute operations =~ "six Mix tasks"

    for task <- @nine_mix_tasks do
      assert operations =~ task, "expected #{task} in operations.md"
    end
  end

  test "operations and troubleshooting guides teach the doctor vs runtime_status split" do
    operations = File.read!(Path.expand("../../../guides/operations.md", __DIR__))
    troubleshooting = File.read!(@troubleshooting_path)

    assert operations =~ "mix rindle.doctor"
    assert operations =~ "mix rindle.runtime_status"
    assert operations =~ "doctor validates setup and drift"
    assert operations =~ "runtime status reports degraded or stuck work"
    assert operations =~ "repair verbs perform change"

    # TRUTH-07: the facade now ships a mountable admin console, so operations.md
    # must affirm the console (not deny a dashboard) while retaining the honest
    # "no auto-remediation" contract. The old dashboard-denial assertion was
    # reworked ÃÂ¢ÃÂÃÂ re-asserting the bare denial phrase would relock the
    # scope-reversed claim Plan 01 removed (Pitfall 5 / T-93-05).
    assert operations =~ "no auto-remediation"

    assert operations =~ ~r/mountable admin console/i,
           "operations.md must affirm the mountable admin console in prose (TRUTH-07) ÃÂ¢ÃÂÃÂ " <>
             "a bare admin_console.html link substring must not satisfy this lock"

    refute operations =~ "intentionally has no dashboard",
           "operations.md must not deny a dashboard now that the console ships"

    assert troubleshooting =~ "mix rindle.doctor"
    assert troubleshooting =~ "mix rindle.runtime_status"
    assert troubleshooting =~ "doctor validates setup and drift"
    assert troubleshooting =~ "runtime status reports degraded or stuck work"

    assert troubleshooting =~ "no auto-remediation"

    refute troubleshooting =~ "intentionally has no dashboard",
           "troubleshooting.md must not deny a dashboard now that the console ships"
  end
end
