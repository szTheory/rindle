defmodule Rindle.InstallSmoke.PackageMetadataTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @preflight_script Path.join(@repo_root, "scripts/release_preflight.sh")
  @install_smoke_script Path.join(@repo_root, "scripts/install_smoke.sh")
  @public_smoke_script Path.join(@repo_root, "scripts/public_smoke.sh")
  @docs_assertion_script Path.join(@repo_root, "scripts/assert_release_docs_html.sh")
  @release_exists_script Path.join(@repo_root, "scripts/hex_release_exists.sh")
  @assert_version_script Path.join(@repo_root, "scripts/assert_version_match.sh")
  @release_workflow Path.join(@repo_root, ".github/workflows/release.yml")
  @ci_workflow Path.join(@repo_root, ".github/workflows/ci.yml")
  @required_paths [
    "mix.exs",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "guides/getting_started.md",
    "guides/release_publish.md"
  ]
  @prohibited_paths ["_build", ".planning", "test", ".github", "coveralls.json"]

  setup_all do
    package_root = build_package!()
    metadata_path = Path.join(package_root, "hex_metadata.config")

    on_exit(fn ->
      File.rm_rf(Path.dirname(package_root))
    end)

    {:ok,
     %{
       package_root: package_root,
       metadata: File.read!(metadata_path),
       script: File.read!(@preflight_script),
       install_smoke_script: File.read!(@install_smoke_script),
       public_smoke_script: File.read!(@public_smoke_script),
       docs_assertion_script: File.read!(@docs_assertion_script),
       release_exists_script: File.read!(@release_exists_script),
       assert_version_script: File.read!(@assert_version_script),
       release_workflow: File.read!(@release_workflow),
       ci_workflow: File.read!(@ci_workflow)
     }}
  end

  test "unpacked metadata contains the expected identity and shipped paths", %{
    metadata: metadata,
    package_root: package_root
  } do
    assert metadata =~ ~s({<<"name">>,<<"rindle">>}.)
    assert metadata =~ ~s({<<"version">>,<<"#{Mix.Project.config()[:version]}">>}.)
    assert metadata =~ ~s({<<"description">>,)
    assert metadata =~ "Phoenix/Ecto-native media lifecycle library. Media, made durable."
    assert metadata =~ ~s({<<"licenses">>,[<<"MIT">>]}.)

    assert metadata =~
             ~s({<<"links">>,[{<<"GitHub">>,<<"https://github.com/szTheory/rindle">>}]}.)

    for rel_path <- @required_paths do
      assert metadata =~ ~s(<<"#{rel_path}">>)
      assert File.exists?(Path.join(package_root, rel_path))
    end
  end

  test "unpacked changelog ships with the first-release entry and pipeline-iteration note", %{
    metadata: metadata,
    package_root: package_root
  } do
    changelog = package_root |> Path.join("CHANGELOG.md") |> File.read!()

    assert metadata =~ ~s(<<"CHANGELOG.md">>)
    assert changelog =~ "0.1.0-0.1.3 were release-pipeline shakedown iterations"
    assert changelog =~ "## 0.1.0"
    assert changelog =~ "First public Hex.pm release of Rindle."
  end

  test "unpacked artifact excludes prohibited repo-only paths", %{package_root: package_root} do
    for rel_path <- @prohibited_paths do
      refute File.exists?(Path.join(package_root, rel_path))
    end
  end

  test "release preflight script runs the release gates in order", %{script: script} do
    commands = [
      "MIX_ENV=dev mix hex.build --unpack --output \"$PACKAGE_ROOT\"",
      "MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs",
      "MIX_ENV=test mix test test/install_smoke/release_docs_parity_test.exs",
      "MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs",
      "MIX_ENV=test RINDLE_PROJECT_ROOT=\"$ROOT_DIR\" bash \"$SCRIPT_DIR/install_smoke.sh\"",
      "MIX_ENV=dev mix docs --warnings-as-errors",
      "RINDLE_PROJECT_ROOT=\"$ROOT_DIR\" bash \"$SCRIPT_DIR/assert_release_docs_html.sh\""
    ]

    positions = Enum.map(commands, &command_position(script, &1))

    assert Enum.all?(positions, &is_integer/1)
    assert positions == Enum.sort(positions)
    assert script =~ "mktemp -d"
    assert script =~ "export RINDLE_INSTALL_SMOKE_PACKAGE_ROOT=\"$PACKAGE_ROOT\""
    assert script =~ "rm -rf \"$WORK_DIR\""
    assert script =~ "RINDLE_RELEASE_PREFLIGHT_KEEP_ARTIFACT"
    assert script =~ "Keeping unpacked artifact at $PACKAGE_ROOT"

    refute script =~ "HEX_API_KEY"
    refute script =~ "mix hex.publish"
  end

  test "docs HTML assertion script checks generated navigation and adopter boundary", %{
    docs_assertion_script: script
  } do
    assert script =~ "release_publish.html"
    assert script =~ "sidebar_items-*.js"
    assert script =~ ~s("id":"release_publish")
    assert script =~ "operations.html"
    assert script =~ "readme.html"
    assert script =~ "getting_started.html"
    assert script =~ "HEX_API_KEY|mix hex\\.user|mix hex\\.owner"
  end

  test "local smoke scripts bootstrap MinIO before MinIO-tagged generated-app tests", %{
    install_smoke_script: install_smoke_script,
    public_smoke_script: public_smoke_script
  } do
    for script <- [install_smoke_script, public_smoke_script] do
      assert script =~ "bash \"$SCRIPT_DIR/ensure_minio.sh\""
      assert script =~ "generated_app_smoke_test.exs --include minio"
    end
  end

  test "release workflow automates public verification on a fresh runner", %{
    release_workflow: workflow
  } do
    assert workflow =~ "Release Please"
    assert workflow =~ "Gate on Exact-SHA Green CI"
    assert workflow =~ "workflow_dispatch:"
    assert workflow =~ "recovery_reason:"
    assert workflow =~ "recovery_ref:"
    assert workflow =~ "Wait for CI to finish green on release SHA"
    assert workflow =~ "workflow_id: 'ci.yml'"
    assert workflow =~ "name: Check whether Hex.pm release already exists"
    assert workflow =~ "mix hex.publish --dry-run --yes"
    assert workflow =~ "name: Publish to Hex.pm (live)"
    assert workflow =~ "mix hex.publish --yes"
    assert workflow =~ "public_verify:"
    assert workflow =~ "needs: [gate-ci-green, publish]"
    assert workflow =~ "name: Wait for Hex.pm index (post-publish)"
    assert workflow =~ "name: Verify public Hex.pm artifact"
    assert workflow =~ ~s(HEX_API_KEY: "")
    assert workflow =~ ~s(mix hex.info rindle "$VERSION")
    assert workflow =~ ~s(bash scripts/public_smoke.sh "$VERSION")
  end

  test "release workflow gates publish on idempotency probe", %{release_workflow: workflow} do
    assert workflow =~ "bash scripts/hex_release_exists.sh"
    assert workflow =~ "id: idempotency"
    assert workflow =~ "if: ${{ steps.idempotency.outputs.already_published != 'true' }}"
  end

  test "release workflow writes an idempotent publish summary", %{release_workflow: workflow} do
    assert workflow =~ "Idempotent publish summary"
    assert workflow =~ "GITHUB_STEP_SUMMARY"
    assert workflow =~ "Skipped publish: rindle $VERSION was already on Hex.pm."
  end

  test "release workflow uses a single global concurrency token", %{release_workflow: workflow} do
    assert workflow =~ "group: release-publish-rindle"
    refute workflow =~ "release-recovery-{0}"
    refute workflow =~ "release-main"
  end

  test "release workflow parses version from mix.exs without compiling the frozen source", %{
    release_workflow: workflow
  } do
    assert workflow =~ "elixir -e '"
    assert workflow =~ "source = File.read!(\"mix.exs\")"
    assert workflow =~ "capture: :all_but_first"
    assert workflow =~ "Unable to parse version from mix.exs"
    refute workflow =~ "sed -nE"
  end

  test "release workflow has the improved HEX_API_KEY guard message", %{
    release_workflow: workflow
  } do
    assert workflow =~ "Settings → Environments → release"
    assert workflow =~ "guides/release_publish.md"
  end

  test "release workflow documents the four-job topology near the top", %{
    release_workflow: workflow
  } do
    [top | _] = String.split(workflow, "jobs:", parts: 2)
    assert top =~ "release-please / recovery-validation"
    assert top =~ "gate-ci-green"
    assert top =~ "publish runs preflight"
    assert top =~ "public_verify"
  end

  test "CI shifts release-proof contract left before live publish", %{ci_workflow: workflow} do
    assert workflow =~ "package-consumer:"
    assert workflow =~ "name: Run release preflight"
    assert workflow =~ "name: Verify version alignment (mocking tag)"
    assert workflow =~ "name: Dry-run Hex publish"
    assert workflow =~ "HEX_API_KEY: dryrun-placeholder"
    assert workflow =~ "mix hex.publish --dry-run --yes"
  end

  test "release scripts accept RINDLE_PROJECT_ROOT discipline", %{
    release_exists_script: release_exists_script,
    assert_version_script: assert_version_script,
    install_smoke_script: install_smoke_script,
    public_smoke_script: public_smoke_script,
    script: preflight_script,
    docs_assertion_script: docs_assertion_script
  } do
    for script <- [
          release_exists_script,
          assert_version_script,
          install_smoke_script,
          public_smoke_script,
          preflight_script,
          docs_assertion_script
        ] do
      assert script =~ "RINDLE_PROJECT_ROOT"
    end
  end

  defp build_package! do
    output_root =
      Path.join(
        System.tmp_dir!(),
        "rindle-package-metadata-#{System.unique_integer([:positive])}"
      )

    package_root = Path.join(output_root, "rindle-#{Mix.Project.config()[:version]}")

    File.mkdir_p!(output_root)

    {output, 0} =
      System.cmd("mix", ["hex.build", "--unpack", "--output", package_root],
        cd: @repo_root,
        env: [{"MIX_ENV", "dev"}],
        stderr_to_stdout: true
      )

    assert output =~ "Building rindle"
    assert output =~ "Saved to"

    package_root
  end

  defp command_position(script, command) do
    case :binary.match(script, command) do
      {position, _length} -> position
      :nomatch -> nil
    end
  end
end
