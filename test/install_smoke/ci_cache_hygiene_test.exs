defmodule Rindle.InstallSmoke.CiCacheHygieneTest do
  @moduledoc """
  CI cache and tooling hygiene regression lock. Mirrors the
  release_docs_parity_test / docs_parity_test `setup_all` + `File.read!`
  `=~`/`refute =~` style so the CI cache-hygiene contract regresses inside the
  default `mix test` / `mix ci` suite (no exclude tag — same as the sibling
  install_smoke parity tests).

  ASSERTS CURRENT SHIPPED STATE. The Dialyzer/PLT job lives in nightly.yml, not
  ci.yml, and the package-consumer job is split into lean and full lanes. Every
  string asserted here was grep-confirmed against the files as they exist on
  disk now.
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

  # Both composites exist and are the single source of truth, adopted
  # by ci.yml + release.yml at their live counts (regression to inline setup
  # would drop these below the asserted floors).
  test "both composites are real composite actions", %{
    setup_elixir: setup_elixir,
    setup_minio: setup_minio
  } do
    assert setup_elixir =~ "using: composite"
    assert setup_minio =~ "using: composite"
  end

  # The upstream minio/minio + minio/mc images and dl.min.io binaries are no
  # longer published. Every MinIO bring-up uses one digest-pinned image, which
  # also supplies the `mc` client.
  @minio_image "cgr.dev/chainguard/minio@sha256:2136d593beacf4461187035eca949fe49abd589d5079735025c711ca58fee0c8"
  @minio_consumers ~w(
    .github/actions/setup-minio/action.yml
    scripts/ensure_minio.sh
    docker/compose.cohort-demo.yml
    docker/dx-template/compose.__app__.yml
  )

  test "MinIO bring-up uses the digest-pinned image and no retired upstream source" do
    for rel <- @minio_consumers do
      body = File.read!(Path.join(@repo_root, rel))
      assert body =~ @minio_image, "#{rel} must use the digest-pinned MinIO image"
      refute body =~ "dl.min.io", "#{rel} must not download retired dl.min.io binaries"

      refute body =~ ~r{(^|[\s"'])minio/(minio|mc)\b}m,
             "#{rel} must not use retired minio/* images"
    end
  end

  # The adoption matrix gate runs the :package_authority proof, which generates
  # a Phoenix app; a cold runner has no phx_new archive unless Proof installs it.
  test "Proof installs the pinned Phoenix generator before the adoption matrix gate", %{ci: ci} do
    [_, proof] = String.split(ci, "\n  proof:\n", parts: 2)
    [proof | _] = String.split(proof, ~r/\n  [a-z][a-z0-9_-]*:\n/, parts: 2)

    installer = :binary.match(proof, "bash scripts/ci/ensure_phx_new.sh")
    gate = :binary.match(proof, "bash scripts/maintainer/check_adoption_proof_matrix.sh")

    assert installer != :nomatch, "Proof must run scripts/ci/ensure_phx_new.sh"
    assert gate != :nomatch
    assert elem(installer, 0) < elem(gate, 0)
  end

  test "ci.yml adopts both composites at the live adoption counts", %{ci: ci} do
    # Live counts (grep-confirmed): setup-elixir ×11, setup-minio ×8 in ci.yml.
    # The lean `adoption-demo-e2e-smoke` PR lane (clone of `adoption-demo-e2e`)
    # adopts BOTH composites too — composite reuse is the desired hygiene, so the
    # lock tracks the live counts.
    # `==` exact so adding inline `erlef/setup-beam` / inline MinIO bring-up back
    # into a job (dropping a composite adoption) regresses this lock.
    assert count(ci, "uses: ./.github/actions/setup-elixir") == 11,
           "ci.yml must adopt the setup-elixir composite 11× (single source of truth)"

    assert count(ci, "uses: ./.github/actions/setup-minio") == 8,
           "ci.yml must adopt the setup-minio composite 8× (single source of truth)"
  end

  test "release.yml adopts the setup-minio composite twice", %{release: release} do
    assert count(release, "uses: ./.github/actions/setup-minio") == 2,
           "release.yml must adopt the setup-minio composite ×2"
  end

  # The setup-elixir composite deps/_build cache key carries the full
  # dimension set and hashes the repo-root mix.lock ONLY (never **/mix.lock).
  test "setup-elixir cache key carries the full resolved dimension set", %{
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
             "setup-elixir cache key must carry #{inspect(segment)}"
    end
  end

  test "setup-elixir hashes repo-root mix.lock, never the recursive glob", %{
    setup_elixir: setup_elixir
  } do
    refute setup_elixir =~ "**/mix.lock",
           "setup-elixir must hash repo-root mix.lock only — `**/mix.lock` recursive hashing is banned"
  end

  # PLT restore/save split. The Dialyzer/PLT job lives in nightly.yml, not
  # ci.yml — assert against where it actually lives.
  test "the PLT restore/save split lives in nightly.yml, not ci.yml",
       %{nightly: nightly, ci: ci} do
    assert nightly =~ "actions/cache/restore",
           "nightly.yml must restore the PLT via actions/cache/restore"

    assert nightly =~ "actions/cache/save",
           "nightly.yml must save the PLT via actions/cache/save"

    # Guard against the split silently reappearing in ci.yml.
    refute ci =~ "actions/cache/save",
           "the PLT cache/save step must NOT live in ci.yml (it lives in nightly.yml)"
  end

  test "the PLT key hashes the dependency lock and has no broad fallback", %{
    nightly: nightly
  } do
    assert nightly =~ "hashFiles('mix.exs', 'mix.lock', '.dialyzer_ignore.exs')",
           "PLT key must hash mix.exs + mix.lock + .dialyzer_ignore.exs"

    refute nightly =~ "restore-keys:",
           "PLT restore must not fall back across dependency locks"
  end

  test "the fresh PLT is saved before exact restore, never if: always()", %{
    nightly: nightly
  } do
    # Fresh construction is now unconditional evidence. Save it before clearing
    # the local PLT and restoring that same exact key for the independent restored
    # analysis; `if: always()` would still permit saving after failed analysis.
    save_step = plt_save_step(nightly)
    {fresh_position, _} = :binary.match(nightly, "run_nightly_dialyzer.sh fresh")
    {save_position, _} = :binary.match(nightly, "- name: Save PLT cache")
    {restore_position, _} = :binary.match(nightly, "- name: Restore exact PLT cache")

    assert fresh_position < save_position and save_position < restore_position,
           "fresh analysis must precede PLT save, which must precede exact restore"

    refute save_step =~ "if: always()",
           "the PLT save step must NOT use `if: always()`"
  end

  # .tool-versions pins, FFmpeg retirement, version-invariant lint guard.
  test ".tool-versions exists at repo root and pins the primary toolchain", %{
    tool_versions: tool_versions
  } do
    assert tool_versions =~ "elixir 1.17.3-otp-27",
           ".tool-versions must pin elixir 1.17.3-otp-27"

    assert tool_versions =~ "erlang 27.2",
           ".tool-versions must pin erlang 27.2"

    assert tool_versions =~ "nodejs 20.18.1",
           ".tool-versions must pin nodejs 20.18.1"
  end

  test "release.yml retires FedericoCarboni/setup-ffmpeg for install_ffmpeg.sh", %{
    release: release
  } do
    refute release =~ "FedericoCarboni/setup-ffmpeg",
           "release.yml must not use FedericoCarboni/setup-ffmpeg (retired)"

    assert release =~ "install_ffmpeg",
           "release.yml must reference the install_ffmpeg.sh script"
  end

  test "FFmpeg installer exposes a reviewed dated asset and digest without fetching" do
    {output, 0} =
      System.cmd("bash", [@install_ffmpeg_path],
        cd: @repo_root,
        env: [{"RINDLE_FFMPEG_RESOLVE_ONLY", "1"}, {"RINDLE_FFMPEG_RELEASE_API", nil}],
        stderr_to_stdout: true
      )

    [asset, url, digest] = String.split(output, "\n", trim: true)
    assert asset == "ffmpeg-n9.0.2-29-g6dfaba896f-linux64-gpl-9.0.tar.xz"

    assert url ==
             "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-20-13-08/" <>
               asset

    assert digest == "6a40dd0b5a020854573aa8bf11449694fabd4fdff1be09b43f6713ca8a2abab1"
    refute url =~ "/latest/"

    assert {_, 64} =
             System.cmd("bash", [@install_ffmpeg_path],
               cd: @repo_root,
               env: [
                 {"RINDLE_FFMPEG_RELEASE_API", "https://example.invalid/latest"},
                 {"RINDLE_FFMPEG_RESOLVE_ONLY", "1"}
               ],
               stderr_to_stdout: true
             )
  end

  @tag :tmp_dir
  test "FFmpeg verified archive reaches extraction and both installs", %{tmp_dir: dir} do
    result = run_ffmpeg_fixture(dir, true)
    assert result.status == 0, result.output
    assert result.log == ["extract", "install", "install"]
  end

  @tag :tmp_dir
  test "FFmpeg checksum mismatch fails before extraction or installation", %{tmp_dir: dir} do
    result = run_ffmpeg_fixture(dir, false)
    assert result.status != 0
    refute "extract" in result.log
    refute "install" in result.log
  end

  defp run_ffmpeg_fixture(dir, valid?) do
    shim_dir = Path.join(dir, "shims")
    File.mkdir_p!(shim_dir)
    script = Path.join(dir, "installer.sh")
    log = Path.join(dir, "calls.log")
    content = "verified fixture archive"
    digest = Base.encode16(:crypto.hash(:sha256, content), case: :lower)

    File.write!(
      script,
      File.read!(@install_ffmpeg_path)
      |> String.replace(~r/archive_sha256="[0-9a-f]{64}"/, "archive_sha256=\"#{digest}\"")
    )

    File.write!(Path.join(shim_dir, "curl"), """
    #!/usr/bin/env bash
    if [[ "$*" == *api.github.com* ]]; then
      cat "#{@ffmpeg_release_fixture}"
      exit 0
    fi
    while [[ "$#" -gt 0 ]]; do
      if [[ "$1" == -o ]]; then shift; printf '%s' '#{if valid?, do: content, else: "tampered bytes"}' > "$1"; exit 0; fi
      shift
    done
    exit 97
    """)

    File.write!(Path.join(shim_dir, "tar"), """
    #!/usr/bin/env bash
    echo extract >> "#{log}"
    while [[ "$#" -gt 0 ]]; do
      if [[ "$1" == -C ]]; then shift; mkdir -p "$1/bin"; touch "$1/bin/ffmpeg" "$1/bin/ffprobe"; fi
      shift
    done
    """)

    File.write!(Path.join(shim_dir, "sudo"), "#!/usr/bin/env bash\nexec \"$@\"\n")
    File.write!(Path.join(shim_dir, "install"), "#!/usr/bin/env bash\necho install >> '#{log}'\n")

    File.write!(
      Path.join(shim_dir, "ffmpeg"),
      "#!/usr/bin/env bash\necho 'ffmpeg version n9.0.2'\n"
    )

    for executable <- ~w(curl tar sudo install ffmpeg),
        do: File.chmod!(Path.join(shim_dir, executable), 0o755)

    {output, status} =
      System.cmd("bash", [script],
        cd: @repo_root,
        env: [
          {"PATH", shim_dir <> ":" <> System.get_env("PATH")},
          {"RINDLE_FFMPEG_RELEASE_API", nil},
          {"RINDLE_FFMPEG_RESOLVE_ONLY", nil}
        ],
        stderr_to_stdout: true
      )

    %{output: output, status: status, log: read_log(log)}
  end

  test "every static FFmpeg install authenticates its release lookup" do
    for {workflow_name, workflow_path} <- [
          {"ci.yml", @ci_path},
          {"nightly.yml", @nightly_path},
          {"release.yml", @release_path}
        ] do
      installer_steps =
        workflow_path
        |> YamlElixir.read_from_file!()
        |> get_in(["jobs"])
        |> Map.values()
        |> Enum.flat_map(&Map.get(&1, "steps", []))
        |> Enum.filter(&(Map.get(&1, "run") == "bash scripts/ci/install_ffmpeg.sh"))

      assert installer_steps != [], "#{workflow_name} must retain its static FFmpeg install"

      assert Enum.all?(installer_steps, fn step ->
               get_in(step, ["env", "GITHUB_TOKEN"]) == "${{ github.token }}"
             end),
             "#{workflow_name} must pass github.token to every static FFmpeg release lookup"
    end
  end

  test "apt package installation is shared, bounded, and retryable across every workflow",
       %{
         ci: ci,
         nightly: nightly,
         release: release,
         install_apt_packages: install_apt_packages
       } do
    workflows = ci <> nightly <> release

    assert count(workflows, "bash scripts/ci/install_apt_packages.sh") == 21
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

  test "native CI lanes declare the SDK before direct Mix builds" do
    ci = YamlElixir.read_from_file!(@ci_path)
    assert ci["env"]["VIX_COMPILATION_MODE"] == "PLATFORM_PROVIDED_LIBVIPS"

    native_jobs =
      Enum.filter(ci["jobs"], fn {_id, job} ->
        Enum.any?(job["steps"] || [], &(&1["uses"] == "./.github/actions/setup-elixir"))
      end)

    assert native_jobs != []

    for {id, job} <- native_jobs do
      steps = job["steps"]

      sdk =
        Enum.find_index(
          steps,
          &(&1["run"] == "bash scripts/ci/install_apt_packages.sh libvips-dev cmake")
        )

      assert is_integer(sdk), "#{id} must declare its native SDK"

      build =
        Enum.find_index(steps, fn step ->
          String.contains?(step["run"] || "", [
            "mix compile",
            "mix test",
            "mix coveralls",
            "mix doctor",
            "mix hex.build",
            "mix hex.publish",
            "mix ecto."
          ])
        end)

      if build, do: assert(sdk < build, "#{id} must install its SDK before compilation")
    end
  end

  test "release compilation and public verification use the installed libvips SDK" do
    release = YamlElixir.read_from_file!(@release_path)

    for id <- ["publish", "public_verify"] do
      job = release["jobs"][id]
      env = Map.merge(release["env"] || %{}, job["env"] || %{})
      assert env["VIX_COMPILATION_MODE"] == "PLATFORM_PROVIDED_LIBVIPS"

      steps = job["steps"]

      sdk =
        Enum.find_index(steps, fn step ->
          String.contains?(step["run"] || "", "install_apt_packages.sh libvips-dev")
        end)

      build =
        Enum.find_index(steps, fn step ->
          String.contains?(step["run"] || "", [
            "release_preflight.sh",
            "mix hex.info",
            "public_smoke.sh"
          ])
        end)

      assert is_integer(sdk) and is_integer(build) and sdk < build,
             "#{id} must install its SDK before compilation"
    end
  end

  @tag :tmp_dir
  test "apt helper gives the official archive explicit priority and preserves fallbacks", %{
    tmp_dir: tmp_dir
  } do
    mirrors_path = Path.join(tmp_dir, "apt-mirrors.txt")

    File.write!(mirrors_path, """
    http://azure.archive.ubuntu.com/ubuntu/\tpriority:1
    https://archive.ubuntu.com/ubuntu/\tpriority:2
    https://security.ubuntu.com/ubuntu/\tpriority:3
    """)

    env = %{"RINDLE_APT_MIRRORS_FILE" => mirrors_path}
    assert run_apt_helper(tmp_dir, ["--configure-only"], env).status == 0
    configured = File.read!(mirrors_path)
    assert configured =~ "https://archive.ubuntu.com/ubuntu\tpriority:0\n"
    assert configured =~ "http://azure.archive.ubuntu.com/ubuntu/\tpriority:1"
    assert configured =~ "https://security.ubuntu.com/ubuntu/\tpriority:3"
    assert length(Regex.scan(~r{https://archive\.ubuntu\.com/ubuntu}, configured)) == 1
    assert run_apt_helper(tmp_dir, ["--configure-only"], env).status == 0
    assert File.read!(mirrors_path) == configured

    File.write!(mirrors_path, "https://deb.debian.org/debian\n")
    assert run_apt_helper(tmp_dir, ["--configure-only"], env).status == 0
    assert File.read!(mirrors_path) == "https://deb.debian.org/debian\n"
  end

  @tag :tmp_dir
  test "apt helper installs from cached indexes without refreshing them", %{tmp_dir: tmp_dir} do
    result = run_apt_helper(tmp_dir, ["libvips-dev", "ffmpeg"])

    assert result.status == 0

    assert result.log == [
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends libvips-dev ffmpeg",
             "apt-get install -y --no-install-recommends libvips-dev ffmpeg"
           ],
           result.output
  end

  @tag :tmp_dir
  test "apt helper refreshes once after a failed install before one final install", %{
    tmp_dir: tmp_dir
  } do
    result = run_apt_helper(tmp_dir, ["libvips-dev"], %{"RINDLE_FAKE_APT_FAIL_FIRST" => "1"})

    assert result.status == 0

    assert result.log == [
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends libvips-dev",
             "apt-get install -y --no-install-recommends libvips-dev",
             "timeout --kill-after=15s 240s apt-get update",
             "apt-get update",
             "timeout --kill-after=15s 240s apt-get install -y --no-install-recommends libvips-dev",
             "apt-get install -y --no-install-recommends libvips-dev"
           ],
           result.output
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

  test "version-invariant lint steps in ci.yml are guarded by matrix.lint", %{ci: ci} do
    assert ci =~ "if: ${{ matrix.lint }}",
           "format/credo/doctor lint steps must be guarded by `if: ${{ matrix.lint }}`"

    assert ci =~ "lint: true",
           "ci.yml quality matrix must carry a `lint: true` include so the guard fires once on the home cell"
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
              "RINDLE_APT_MIRRORS_FILE" => Path.join(run_root, "absent-mirrors.txt"),
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
      if [ "$2" = "${RINDLE_APT_MIRRORS_FILE}" ]; then
        cat >"$2"
      else
        cat >/dev/null
      fi
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
