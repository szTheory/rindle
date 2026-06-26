defmodule Rindle.InstallSmoke.CiLaneSplitTest do
  @moduledoc """
  Phase 106 (Trigger Split + Matrix/Lane Refinement) LANE-topology regression
  lock. Mirrors the release_docs_parity_test / ci_cache_hygiene_test
  `setup_all` + `File.read!` `=~`/`refute =~` style so the trigger-split lane
  contract regresses inside the default `mix test` / `mix ci` suite (no exclude
  tag — same as the sibling install_smoke parity tests).

  ASSERTS CURRENT SHIPPED STATE. Phase 107 ran AFTER 106 and SHA-pinned every
  `uses:` + added job permissions, so NOTHING here asserts a mutable `@vX`
  action tag or any pre-107 detail — only the LANE topology facts (triggers,
  concurrency expression, the package-consumer lean/full split, the nightly
  lane placement, the A–E classification doc, and the release-coupling
  invariants) that are true on disk right now. Every literal asserted below was
  grep-confirmed against the live files.

  Deliberately does NOT duplicate ci_cache_hygiene_test.exs: composite adoption
  counts, the cache-key schema, .tool-versions, ffmpeg, and the PLT
  restore/save *split* (CACHE-03) are owned there. This file owns LANE
  *placement* only.
  """
  use ExUnit.Case, async: true

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @nightly_path Path.expand("../../.github/workflows/nightly.yml", __DIR__)
  @release_path Path.expand("../../.github/workflows/release.yml", __DIR__)
  @automerge_path Path.expand(
                    "../../.github/workflows/release-please-automerge.yml",
                    __DIR__
                  )
  @branch_protection_path Path.expand("../../scripts/setup_branch_protection.sh", __DIR__)
  @contributing_path Path.expand("../../CONTRIBUTING.md", __DIR__)
  @classification_path Path.expand(
                         "../../.planning/milestones/v1.20-phases/106-trigger-split-matrix-lane-refinement/106-LANE-CLASSIFICATION.md",
                         __DIR__
                       )

  setup_all do
    {:ok,
     %{
       ci: File.read!(@ci_path),
       nightly: File.read!(@nightly_path),
       release: File.read!(@release_path),
       automerge: File.read!(@automerge_path),
       branch_protection: File.read!(@branch_protection_path),
       contributing: File.read!(@contributing_path),
       classification: File.read!(@classification_path)
     }}
  end

  # ------------------------------------------------------------------
  # LANE-01: concurrency — stale PR runs cancel; push:main/dispatch serialize.
  # ------------------------------------------------------------------
  test "LANE-01: ci.yml has a top-level concurrency block keyed on workflow + ref", %{ci: ci} do
    assert ci =~ "concurrency:",
           "ci.yml must declare a top-level concurrency block (LANE-01)"

    assert ci =~ "group: ${{ github.workflow }}-${{ github.ref }}",
           "concurrency group must key on github.workflow + github.ref so each ref serializes independently (LANE-01)"
  end

  test "LANE-01: cancel-in-progress is true ONLY for pull_request events", %{ci: ci} do
    # The exact shipped expression: cancellation fires on PR, evaluates false on
    # push:main / workflow_dispatch (which then SERIALIZE and are never cancelled —
    # load-bearing for release.yml gate-ci-green reading the push:main conclusion).
    assert ci =~
             "cancel-in-progress: ${{ github.event_name == 'pull_request' }}",
           "cancel-in-progress must be true ONLY for pull_request — push:main/dispatch must never cancel (LANE-01)"

    # Guard against the D-06 footgun: a bare `cancel-in-progress: true` would
    # cancel push:main runs and destroy the full-matrix release evidence.
    refute ci =~ "cancel-in-progress: true",
           "cancel-in-progress must NOT be an unconditional `true` (would cancel push:main runs, D-06 footgun, LANE-01)"
  end

  # ------------------------------------------------------------------
  # LANE-02: package-consumer lean (PR) + package-consumer-full (off-PR) split.
  # ------------------------------------------------------------------
  test "LANE-02: both the lean package-consumer and the off-PR package-consumer-full jobs exist",
       %{ci: ci} do
    assert ci =~ "\n  package-consumer:\n",
           "the lean PR `package-consumer` job must exist (LANE-02)"

    assert ci =~ "\n  package-consumer-full:\n",
           "the off-PR `package-consumer-full` job must exist (LANE-02)"
  end

  test "LANE-02: package-consumer-full is off-PR (event gate) with a fail-fast:false 5-profile matrix and NO continue-on-error",
       %{ci: ci} do
    full = package_consumer_full_block(ci)

    assert full =~ "if: github.event_name != 'pull_request'",
           "package-consumer-full must be gated `if: github.event_name != 'pull_request'` to stay off the PR critical path (LANE-02)"

    assert full =~ "fail-fast: false",
           "package-consumer-full matrix must be `fail-fast: false` so one red profile never masks the others (LANE-02)"

    assert full =~ "profile: [video, image, tus, mux, gcs]",
           "package-consumer-full must carry the full 5-profile matrix video/image/tus/mux/gcs (LANE-02)"

    refute yaml_keys_only(full) =~ "continue-on-error",
           "package-consumer-full must have NO continue-on-error key — a failed leg must make the push:main conclusion non-success so the release gate blocks (LANE-02, D-08)"
  end

  test "LANE-02: ci-summary needs the lean package-consumer but OMITS package-consumer-full (D-09)",
       %{ci: ci} do
    needs = ci_summary_needs_block(ci)

    assert needs =~ "- package-consumer\n",
           "ci-summary.needs must include the lean `package-consumer` (the always-running PR representative, LANE-02)"

    refute needs =~ "package-consumer-full",
           "ci-summary.needs must OMIT `package-consumer-full` — it is `if: != pull_request`, so listing it would emit a green-checkmark lie about a skipped lane (D-09, LANE-02)"
  end

  # ------------------------------------------------------------------
  # LANE-03: nightly.yml lane placement (invisible to release-please-automerge).
  # ------------------------------------------------------------------
  test "LANE-03: nightly.yml is a separate `name: Nightly` workflow with schedule + dispatch and NO pull_request/push triggers",
       %{nightly: nightly} do
    assert nightly =~ "name: Nightly",
           "nightly.yml must be `name: Nightly` (a separate workflow id, invisible to release-please-automerge workflows:[CI], LANE-03)"

    assert nightly =~ "schedule:",
           "nightly.yml must carry a `schedule:` trigger (LANE-03)"

    assert nightly =~ "cron:",
           "nightly.yml schedule must declare a cron expression (LANE-03)"

    assert nightly =~ "workflow_dispatch:",
           "nightly.yml must allow manual workflow_dispatch (LANE-03)"

    # Structural invisibility to release consumers: a pull_request OR push
    # trigger would re-expose the nightly lane to the release/automerge train.
    refute nightly =~ "pull_request",
           "nightly.yml must have NO pull_request trigger — it must never become a PR-required check (LANE-03, D-12)"

    refute nightly =~ "push:",
           "nightly.yml must have NO push trigger — a `CI`/push run would fire release-please-automerge (LANE-03, D-12)"
  end

  test "LANE-03: nightly.yml carries the broad OTP×Elixir compat matrix (multiple cells)", %{
    nightly: nightly
  } do
    assert nightly =~ "compat-matrix:",
           "nightly.yml must declare the broad compat-matrix job (LANE-03)"

    # Multiple cells straddling the OTP-27 json_polyfill branch. Assert a few of
    # the literal diagonal cells that are present on disk now.
    for cell <- [
          ~s(elixir: "1.15"),
          ~s(otp: "25"),
          ~s(elixir: "1.18"),
          ~s(otp: "28")
        ] do
      assert nightly =~ cell,
             "compat-matrix must include the #{inspect(cell)} cell (broad OTP×Elixir breadth, LANE-03)"
    end
  end

  test "LANE-03: the owned nightly Dialyzer job runs gating (no continue-on-error YAML key in its block)",
       %{nightly: nightly} do
    dialyzer = nightly_dialyzer_block(nightly)

    assert dialyzer =~ "mix dialyzer",
           "the nightly Dialyzer job must actually run `mix dialyzer` (LANE-03, D-17)"

    # Scope to actual YAML keys, not the `# ... NO continue-on-error` doc comment
    # that legitimately appears inside the block (the verifier flagged these 5
    # grep hits as comment text, not keys). Strip comment lines, then refute the
    # real key in any form.
    refute yaml_keys_only(dialyzer) =~ "continue-on-error",
           "the nightly Dialyzer job must have NO continue-on-error key — it is the owned GATING type-contract signal (LANE-03, D-17)"
  end

  test "LANE-03: the moved gcs-soak + package-consumer-gcs-live jobs live in nightly.yml, not ci.yml",
       %{nightly: nightly, ci: ci} do
    assert nightly =~ "gcs-soak:",
           "gcs-soak must live in nightly.yml (moved off ci.yml by Phase 106, LANE-03/D-14)"

    assert nightly =~ "package-consumer-gcs-live:",
           "package-consumer-gcs-live must live in nightly.yml (moved off ci.yml by Phase 106, LANE-03/D-14)"

    refute ci =~ "gcs-soak:",
           "gcs-soak must NOT remain a job in ci.yml — it was moved to nightly.yml (LANE-03/D-14)"

    refute ci =~ "package-consumer-gcs-live:",
           "package-consumer-gcs-live must NOT remain a job in ci.yml — it was moved to nightly.yml (LANE-03/D-14)"
  end

  test "LANE-03: nightly-failure-issue declares least-privilege permissions (issues: write only)",
       %{nightly: nightly} do
    issue_job = nightly_failure_issue_block(nightly)

    assert issue_job =~ "permissions:",
           "nightly-failure-issue must declare a job-scoped permissions block (least privilege, LANE-03/D-16)"

    assert issue_job =~ "issues: write",
           "nightly-failure-issue must grant `issues: write` to open/update the tracking issue (LANE-03/D-16)"

    refute issue_job =~ "contents: write",
           "nightly-failure-issue must NOT grant contents: write — least privilege, it cannot push code (LANE-03/D-16)"
  end

  # ------------------------------------------------------------------
  # LANE-04: trust/speed label in CONTRIBUTING + the A–E classification doc.
  # ------------------------------------------------------------------
  test "LANE-04: CONTRIBUTING.md carries the trust/speed label (on-PR vs after-merge/nightly, ≤7-min, image smoke)",
       %{contributing: contributing} do
    for phrase <- [
          "what CI runs on your PR versus after merge",
          "after merge",
          "≤7 minutes",
          "representative `image` package-consumer install-smoke",
          "caught on `main` within one merge"
        ] do
      assert contributing =~ phrase,
             "CONTRIBUTING.md trust/speed label must contain #{inspect(phrase)} (LANE-04)"
    end
  end

  test "LANE-04: the internal A–E classification doc exists and documents the buckets", %{
    classification: classification
  } do
    assert classification =~ "LANE-04",
           "106-LANE-CLASSIFICATION.md must be the LANE-04 classification record (LANE-04)"

    # The doc places every ci.yml lane into exactly one of the five buckets;
    # quarantine (D) and delete (E) are explicitly EMPTY (do-not-invent).
    for bucket <- [
          "Bucket A",
          "Bucket B",
          "Bucket C",
          "Buckets D & E",
          "EMPTY"
        ] do
      assert classification =~ bucket,
             "106-LANE-CLASSIFICATION.md must document #{inspect(bucket)} (LANE-04)"
    end
  end

  # ------------------------------------------------------------------
  # RELEASE-COUPLING INVARIANT (supports LANE SC5): a future lane edit must not
  # silently break the release train.
  # ------------------------------------------------------------------
  test "RELEASE-COUPLING: ci.yml line 1 is `name: CI` (release-train coupling)", %{ci: ci} do
    [first_line | _] = String.split(ci, "\n", parts: 2)

    assert first_line == "name: CI",
           "ci.yml line 1 must be exactly `name: CI` — release-please-automerge workflows:[CI] + release.yml gate-ci-green couple on it (SC5)"
  end

  test "RELEASE-COUPLING: setup_branch_protection.sh requires exactly one check — `CI Summary`",
       %{branch_protection: branch_protection} do
    # Isolate the REQUIRED_CHECKS=( ... ) array and assert it has exactly one
    # entry, `CI Summary`. The string also appears in the print-expected heredoc,
    # so scope to the array to avoid a false multi-count.
    [_, after_open] = String.split(branch_protection, "REQUIRED_CHECKS=(\n", parts: 2)
    [array_body | _] = String.split(after_open, ")", parts: 2)

    entries =
      array_body
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    assert entries == ["\"CI Summary\""],
           "REQUIRED_CHECKS must be exactly one entry, \"CI Summary\" — got #{inspect(entries)} (SC5)"
  end

  test "RELEASE-COUPLING: automerge listens on the `CI` workflow and release.yml gate reads `ci.yml`",
       %{automerge: automerge, release: release} do
    # release-please-automerge.yml workflow_run listener keys on the `CI`
    # workflow name (which is ci.yml's `name: CI`).
    assert automerge =~ "workflows:\n      - CI",
           "release-please-automerge.yml must listen on the `CI` workflow (couples to ci.yml `name: CI`, SC5)"

    # release.yml gate-ci-green reads the ci.yml run conclusion by workflow_id.
    assert release =~ "workflow_id: 'ci.yml'",
           "release.yml gate-ci-green must read the ci.yml run by `workflow_id: 'ci.yml'` (SC5)"
  end

  # ------------------------------------------------------------------
  # Block isolators — scope `refute` assertions to a single job's YAML so a
  # legitimate occurrence elsewhere never produces a false pass/fail.
  # ------------------------------------------------------------------

  # `package-consumer-full:` job body, from its job key up to the next top-level
  # (2-space-indented) job key.
  defp package_consumer_full_block(ci) do
    [_, after_key] = String.split(ci, "\n  package-consumer-full:\n", parts: 2)
    [block | _] = String.split(after_key, "\n  adoption-demo-unit:\n", parts: 2)
    block
  end

  # `ci-summary:` job — isolate its `needs:` list (up to the `if:`/`steps:` keys).
  defp ci_summary_needs_block(ci) do
    [_, after_key] = String.split(ci, "\n  ci-summary:\n", parts: 2)
    [_, after_needs] = String.split(after_key, "\n    needs:\n", parts: 2)
    [needs | _] = String.split(after_needs, "\n    if:", parts: 2)
    needs
  end

  # nightly.yml `dialyzer:` job body, up to the next top-level job (`gcs-soak:`).
  defp nightly_dialyzer_block(nightly) do
    [_, after_key] = String.split(nightly, "\n  dialyzer:\n", parts: 2)
    [block | _] = String.split(after_key, "\n  gcs-soak:\n", parts: 2)
    block
  end

  # nightly.yml `nightly-failure-issue:` job body (last job — to EOF).
  defp nightly_failure_issue_block(nightly) do
    [_, block] = String.split(nightly, "\n  nightly-failure-issue:\n", parts: 2)
    block
  end

  # Drop full-line YAML comments (lines whose first non-space char is `#`) so a
  # `refute` over actual YAML keys is not tripped by documentation prose that
  # merely *names* a key it deliberately omits.
  defp yaml_keys_only(block) do
    block
    |> String.split("\n")
    |> Enum.reject(&(String.trim_leading(&1) |> String.starts_with?("#")))
    |> Enum.join("\n")
  end
end
