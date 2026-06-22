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
  @tool_versions_path Path.expand("../../.tool-versions", __DIR__)

  setup_all do
    {:ok,
     %{
       setup_elixir: File.read!(@setup_elixir_path),
       setup_minio: File.read!(@setup_minio_path),
       ci: File.read!(@ci_path),
       nightly: File.read!(@nightly_path),
       release: File.read!(@release_path),
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
    # Live counts (grep-confirmed): setup-elixir ×10, setup-minio ×6 in ci.yml.
    # `==` exact so adding inline `erlef/setup-beam` / inline MinIO bring-up back
    # into a job (dropping a composite adoption) regresses this lock.
    assert count(ci, "uses: ./.github/actions/setup-elixir") == 10,
           "ci.yml must adopt the setup-elixir composite 10× (single source of truth, CACHE-01)"

    assert count(ci, "uses: ./.github/actions/setup-minio") == 6,
           "ci.yml must adopt the setup-minio composite 6× (single source of truth, CACHE-01)"
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

  test "CACHE-03: the PLT key hashes mix.exs + .dialyzer_ignore.exs and NOT mix.lock", %{
    nightly: nightly
  } do
    assert nightly =~ "hashFiles('mix.exs', '.dialyzer_ignore.exs')",
           "PLT key must hash mix.exs + .dialyzer_ignore.exs (anti-rot anchor, CACHE-03)"

    refute nightly =~
             "plt-v1-${{ runner.os }}-${{ runner.arch }}-otp27-elixir1.17-${{ hashFiles('mix.lock') }}",
           "PLT key must NOT hash mix.lock — it must survive unrelated dep bumps (CACHE-03)"
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
end
