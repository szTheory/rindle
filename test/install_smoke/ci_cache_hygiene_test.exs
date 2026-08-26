defmodule Rindle.InstallSmoke.CiCacheHygieneTest do
  @moduledoc """
  Phase 104 (Cache & Tooling Hygiene) regression lock. Mirrors the
  release_docs_parity_test / docs_parity_test `setup_all` + `File.read!`
  `=~`/`refute =~` style so the CI cache-hygiene contract regresses inside the
  default `mix test` / `mix ci` suite (no exclude tag — same as the sibling
  install_smoke parity tests).

  ASSERTS CURRENT SHIPPED STATE. Phase 106 later restructured these workflows:
  the Dialyzer/PLT job was MOVED out of ci.yml into nightly.yml, and the
  package-consumer job was split. Every string asserted here was grep-confirmed
  against the files as they exist on disk now — not the Phase-104-era layout.
  """
  use ExUnit.Case, async: true

  @setup_elixir_path Path.expand("../../.github/actions/setup-elixir/action.yml", __DIR__)
  @setup_minio_path Path.expand("../../.github/actions/setup-minio/action.yml", __DIR__)
  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @nightly_path Path.expand("../../.github/workflows/nightly.yml", __DIR__)
  @release_path Path.expand("../../.github/workflows/release.yml", __DIR__)
  @install_ffmpeg_path Path.expand("../../scripts/ci/install_ffmpeg.sh", __DIR__)
  @ffmpeg_release_fixture Path.expand(
                            "../fixtures/install_smoke/btbn_latest_release.json",
                            __DIR__
                          )
  @repo_root Path.expand("../..", __DIR__)
  @install_apt_packages_path Path.expand("../../scripts/ci/install_apt_packages.sh", __DIR__)
  @tool_versions_path Path.expand("../../.tool-versions", __DIR__)

  setup_all do
    {:ok,
     %{
       setup_elixir: File.read!(@setup_elixir_path),
       setup_minio: File.read!(@setup_minio_path),
       ci: File.read!(@ci_path),
       nightly: File.read!(@nightly_path),
       release: File.read!(@release_path),
       install_ffmpeg: File.read!(@install_ffmpeg_path),
       install_apt_packages: File.read!(@install_apt_packages_path),
       tool_versions: File.read!(@tool_versions_path)
     }}
  end

  # CACHE-01: both composites exist and are the single source of truth, adopted
  # by ci.yml + release.yml at their live counts (regression to inline setup
  # would drop these below the asserted floors).
  test "CACHE-01: both composites are real composite actions", %{
    setup_elixir: setup_elixir,
    setup_minio: setup_minio
  } do
    assert setup_elixir =~ "using: composite"
    assert setup_minio =~ "using: composite"
  end

  test "CACHE-01: ci.yml adopts both composites at the live adoption counts", %{ci: ci} do
    # Live counts (grep-confirmed): setup-elixir ×11, setup-minio ×7 in ci.yml.
    # Both went +1 in Phase 112: the lean `adoption-demo-e2e-smoke` PR lane
    # (clone of `adoption-demo-e2e`) adopts BOTH composites too — composite
    # reuse is the desired hygiene, so the lock tracks the new live counts.
    # `==` exact so adding inline `erlef/setup-beam` / inline MinIO bring-up back
    # into a job (dropping a composite adoption) regresses this lock.
    assert count(ci, "uses: ./.github/actions/setup-elixir") == 11,
           "ci.yml must adopt the setup-elixir composite 11× (single source of truth, CACHE-01)"

    assert count(ci, "uses: ./.github/actions/setup-minio") == 7,
           "ci.yml must adopt the setup-minio composite 7× (single source of truth, CACHE-01)"
  end

  test "CACHE-01: release.yml adopts the setup-minio composite twice", %{release: release} do
    assert count(release, "uses: ./.github/actions/setup-minio") == 2,
           "release.yml must adopt the setup-minio composite ×2 (CACHE-01)"
  end

  # CACHE-02: the setup-elixir composite deps/_build cache key carries the full
  # dimension set and hashes the repo-root mix.lock ONLY (never **/mix.lock).
  test "CACHE-02: setup-elixir cache key carries the full resolved dimension set", %{
    setup_elixir: setup_elixir
  } do
    for segment <- [
          "${{ runner.os }}",
          "${{ runner.arch }}",
          "otp${{ steps.beam.outputs.otp-version }}",
          "elixir${{ steps.beam.outputs.elixir-version }}",
          "${{ inputs.mix-env }}",
          "hashFiles('mix.lock')",
          # version buster
          "-v1-"
        ] do
      assert setup_elixir =~ segment,
             "setup-elixir cache key must carry #{inspect(segment)} (CACHE-02)"
    end
  end

  test "CACHE-02: setup-elixir hashes repo-root mix.lock, never the recursive glob", %{
    setup_elixir: setup_elixir
  } do
    refute setup_elixir =~ "**/mix.lock",
           "setup-elixir must hash repo-root mix.lock only — `**/mix.lock` recursive hashing is banned (CACHE-02)"
  end

  # CACHE-03: PLT restore/save split. Phase 106 MOVED the Dialyzer/PLT job out of
  # ci.yml into nightly.yml — assert against where it actually lives now.
  test "CACHE-03: the PLT restore/save split lives in nightly.yml (moved from ci.yml by Phase 106)",
       %{nightly: nightly, ci: ci} do
    assert nightly =~ "actions/cache/restore",
           "nightly.yml must restore the PLT via actions/cache/restore (CACHE-03)"

    assert nightly =~ "actions/cache/save",
           "nightly.yml must save the PLT via actions/cache/save (CACHE-03)"

    # The split moved out of ci.yml — guard against it silently reappearing there
    # (Phase 106 restructure invariant).
    refute ci =~ "actions/cache/save",
           "the PLT cache/save step must NOT live in ci.yml (moved to nightly.yml by Phase 106)"
  end

  test "CACHE-03: the PLT key hashes the dependency lock and has no broad fallback", %{
    nightly: nightly
  } do
    assert nightly =~ "hashFiles('mix.exs', 'mix.lock', '.dialyzer_ignore.exs')",
           "PLT key must hash mix.exs + mix.lock + .dialyzer_ignore.exs (CACHE-03)"

    refute nightly =~ "restore-keys:",
           "PLT restore must not fall back across dependency locks (CACHE-03)"
  end

  test "CACHE-03: the PLT save step is guarded on cache-miss, never if: always()", %{
    nightly: nightly
  } do
    # Scope to the `Save PLT cache` step block only — `if: always()` legitimately
    # appears elsewhere (the advisory nightly-summary job), so the refute must not
    # scan the whole file. The save step itself must carry the cache-miss guard.
    save_step = plt_save_step(nightly)

    assert save_step =~ "if: steps.plt_cache.outputs.cache-hit != 'true'",
           "PLT save must be guarded on a cache miss (CACHE-03)"

    refute save_step =~ "if: always()",
           "the PLT save step must NOT use `if: always()` — it is cache-miss guarded (CACHE-03)"
  end

  # CACHE-05: .tool-versions pins, FFmpeg retirement, version-invariant lint guard.
  test "CACHE-05: .tool-versions exists at repo root and pins the primary toolchain", %{
    tool_versions: tool_versions
  } do
    assert tool_versions =~ "elixir 1.17.3-otp-27",
           ".tool-versions must pin elixir 1.17.3-otp-27 (CACHE-05)"

    assert tool_versions =~ "erlang 27.2",
           ".tool-versions must pin erlang 27.2 (CACHE-05)"

    assert tool_versions =~ "nodejs 20.18.1",
           ".tool-versions must pin nodejs 20.18.1 (CACHE-05)"
  end

  test "CACHE-05: release.yml retires FedericoCarboni/setup-ffmpeg for install_ffmpeg.sh", %{
    release: release
  } do
    refute release =~ "FedericoCarboni/setup-ffmpeg",
           "release.yml must not use FedericoCarboni/setup-ffmpeg (retired, CACHE-05)"

    assert release =~ "install_ffmpeg",
           "release.yml must reference the install_ffmpeg.sh script (CACHE-05)"
  end

  test "CACHE-05: FFmpeg installer resolves the highest stable BtbN asset instead of a disappearing version pin",
       %{install_ffmpeg: install_ffmpeg} do
    assert install_ffmpeg =~ "api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest"
    assert install_ffmpeg =~ "max_by([.major, .minor, .patch])"
    assert install_ffmpeg =~ "browser_download_url"
    assert install_ffmpeg =~ "RINDLE_FFMPEG_RESOLVE_ONLY"
    refute install_ffmpeg =~ ~r/asset="ffmpeg-n[0-9]/
  end

  test "CACHE-05: FFmpeg installer resolves the current stable GPL asset and API download URL" do
    {output, 0} =
      System.cmd("bash", [@install_ffmpeg_path],
        cd: @repo_root,
        env: [
          {"RINDLE_FFMPEG_RELEASE_API", "file://#{@ffmpeg_release_fixture}"},
          {"RINDLE_FFMPEG_RESOLVE_ONLY", "1"}
        ],
        stderr_to_stdout: true
      )

    assert String.split(output, "\n", trim: true) == [
             "ffmpeg-n9.0.1-6-g9d4ca21220-linux64-gpl-9.0.tar.xz",
             "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n9.0.1-6-g9d4ca21220-linux64-gpl-9.0.tar.xz"
           ]
  end

  test "apt package installation is shared, bounded, and retryable across every workflow",
       %{
         ci: ci,
         nightly: nightly,
         release: release,
         install_apt_packages: install_apt_packages
       } do
    workflows = ci <> nightly <> release

    assert count(workflows, "bash scripts/ci/install_apt_packages.sh") == 18
    refute workflows =~ "apt-get install -y libvips-dev"
    refute workflows =~ "apt-get install -y ffmpeg"
    assert workflows =~ "install_apt_packages.sh ffmpeg"
    assert install_apt_packages =~ ~s(Acquire::Retries "2")
    assert install_apt_packages =~ ~s(Acquire::http::Timeout "15")
    assert install_apt_packages =~ "timeout --kill-after=15s 240s"
    assert install_apt_packages =~ "--no-install-recommends"
    assert install_apt_packages =~ "attempt 1/2"
    assert install_apt_packages =~ "attempt 2/2"
    assert install_apt_packages =~ "--configure-only"
    assert ci =~ "timeout --kill-after=15s 300s npx playwright install --with-deps chromium"
  end

  @tag :tmp_dir
  test "apt helper installs from cached indexes without refreshing them", %{tmp_dir: tmp_dir} do
    result = run_apt_helper(tmp_dir, ["libvips-dev", "ffmpeg"])

    assert result.status == 0

    assert result.log == [
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends libvips-dev ffmpeg",
             "apt-get install -y --no-install-recommends libvips-dev ffmpeg"
           ], result.output
  end

  @tag :tmp_dir
  test "apt helper refreshes once after a failed install before one final install", %{tmp_dir: tmp_dir} do
    result = run_apt_helper(tmp_dir, ["libvips-dev"], %{"RINDLE_FAKE_APT_FAIL_FIRST" => "1"})

    assert result.status == 0

    assert result.log == [
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends libvips-dev",
             "apt-get install -y --no-install-recommends libvips-dev",
             "timeout --kill-after=15s 240s apt-get update",
             "apt-get update",
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends libvips-dev",
             "apt-get install -y --no-install-recommends libvips-dev"
           ], result.output
  end

  @tag :tmp_dir
  test "apt helper preserves configure-only and empty-input contracts", %{tmp_dir: tmp_dir} do
    configure_only = run_apt_helper(tmp_dir, ["--configure-only"])
    empty_input = run_apt_helper(tmp_dir, [])

    assert configure_only.status == 0
    assert configure_only.log == []
    assert empty_input.status == 2
    assert empty_input.log == []
  end

  @tag :tmp_dir
  test "apt helper propagates bounded refresh and final-install failures", %{tmp_dir: tmp_dir} do
    refresh_failure =
      run_apt_helper(tmp_dir, ["libvips-dev"], %{
        "RINDLE_FAKE_APT_FAIL_FIRST" => "1",
        "RINDLE_FAKE_APT_UPDATE_FAIL" => "1"
      })

    final_install_failure =
      run_apt_helper(tmp_dir, ["ffmpeg"], %{"RINDLE_FAKE_APT_FAIL_INSTALLS" => "1"})

    assert refresh_failure.status == 1

    assert refresh_failure.log == [
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends libvips-dev",
             "apt-get install -y --no-install-recommends libvips-dev",
             "timeout --kill-after=15s 240s apt-get update",
             "apt-get update"
           ]

    assert final_install_failure.status == 1

    assert final_install_failure.log == [
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends ffmpeg",
             "apt-get install -y --no-install-recommends ffmpeg",
             "timeout --kill-after=15s 240s apt-get update",
             "apt-get update",
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends ffmpeg",
             "apt-get install -y --no-install-recommends ffmpeg"
           ]
  end

  test "CACHE-05: version-invariant lint steps in ci.yml are guarded by matrix.lint", %{ci: ci} do
    assert ci =~ "if: ${{ matrix.lint }}",
           "format/credo/doctor lint steps must be guarded by `if: ${{ matrix.lint }}` (CACHE-05)"

    assert ci =~ "lint: true",
           "ci.yml quality matrix must carry a `lint: true` include so the guard fires once on the home cell (CACHE-05)"
  end

  # Isolate the `Save PLT cache` step: from its `- name:` line up to (but not
  # including) the next step's `- name:` line.
  defp plt_save_step(nightly) do
    [_, after_name] = String.split(nightly, "- name: Save PLT cache", parts: 2)
    [step | _] = String.split(after_name, "\n      - name:", parts: 2)
    step
  end

  defp count(haystack, needle) do
    haystack
    |> String.split(needle)
    |> length()
    |> Kernel.-(1)
  end

  defp run_apt_helper(tmp_dir, args, extra_env \\ %{}) do
    run_root = Path.join(tmp_dir, "apt-helper-#{System.unique_integer([:positive])}")
    shim_dir = Path.join(run_root, "shims")
    log_path = Path.join(run_root, "apt-helper.log")
    first_failure_path = Path.join(run_root, "first-install-failure")

    File.mkdir_p!(shim_dir)
    install_apt_helper_shims!(shim_dir)

    {output, status} =
      System.cmd("bash", [@install_apt_packages_path | args],
        cd: @repo_root,
        env:
          Map.merge(
            %{
              "PATH" => shim_dir <> ":" <> System.get_env("PATH"),
              "RINDLE_APT_LOG" => log_path,
              "RINDLE_APT_FIRST_INSTALL_FAILURE" => first_failure_path
            },
            extra_env
          )
          |> Map.to_list(),
        stderr_to_stdout: true
      )

    %{status: status, output: output, log: read_log(log_path)}
  end

  defp install_apt_helper_shims!(shim_dir) do
    File.write!(Path.join(shim_dir, "sudo"), """
    #!/usr/bin/env bash
    if [ "$1" = "tee" ]; then
      cat >/dev/null
      exit 0
    fi
    exec "$@"
    """)

    File.write!(Path.join(shim_dir, "timeout"), """
    #!/usr/bin/env bash
    {
      printf 'timeout'
      printf ' %s' "$@"
      printf '\\n'
    } >> "$RINDLE_APT_LOG"
    while [[ "$1" == -* ]]; do shift; done
    shift
    exec "$@"
    """)

    File.write!(Path.join(shim_dir, "apt-get"), """
    #!/usr/bin/env bash
    {
      printf 'apt-get'
      printf ' %s' "$@"
      printf '\\n'
    } >> "$RINDLE_APT_LOG"
    if [ "$1" = "update" ] && [ "${RINDLE_FAKE_APT_UPDATE_FAIL:-}" = "1" ]; then
      exit 8
    fi
    if [ "$1" = "install" ] && [ "${RINDLE_FAKE_APT_FAIL_INSTALLS:-}" = "1" ]; then
      exit 9
    fi
    if [ "$1" = "install" ] && [ "${RINDLE_FAKE_APT_FAIL_FIRST:-}" = "1" ] && [ ! -f "$RINDLE_APT_FIRST_INSTALL_FAILURE" ]; then
      touch "$RINDLE_APT_FIRST_INSTALL_FAILURE"
      exit 7
    fi
    exit 0
    """)

    File.write!(Path.join(shim_dir, "sleep"), "#!/usr/bin/env bash\nexit 0\n")

    for executable <- ["sudo", "timeout", "apt-get", "sleep"] do
      File.chmod!(Path.join(shim_dir, executable), 0o755)
    end
  end

  defp read_log(path) do
    case File.read(path) do
      {:ok, content} -> String.split(content, "\n", trim: true)
      {:error, :enoent} -> []
    end
  end
end
