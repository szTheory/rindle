---
phase: 135-repository-and-code-craft-consolidation
plan: 04
subsystem: lib-residue
tags: [craft, residue, comments, refactor]
status: complete
requires: ["135-01", "135-02"]
provides:
  - "lib/config/root tool-config comments free of planning-era ids (97 of 98 pending-removal entries removed)"
affects: [scripts/maintainer/live_residue_allowlist/lib.json]
tech-stack:
  added: []
  patterns: ["comment-only residue tranche; allowlist shrinks in the same commit as the edit"]
key-files:
  created: []
  modified:
    - mix.exs
    - lib/rindle/admin/components.ex
    - lib/rindle/admin/live/actions_live.ex
    - lib/rindle/admin/live/assets_live.ex
    - lib/rindle/admin/live/home_live.ex
    - lib/rindle/admin/live/runtime_doctor_live.ex
    - lib/rindle/admin/live/variants_jobs_live.ex
    - lib/mix/tasks/rindle.backfill_metadata.ex
    - lib/rindle/ops/metadata_backfill.ex
    - lib/rindle/ops/runtime_checks/ownership_checks.ex
    - lib/rindle/ops/sweep_orphaned_temp_files.ex
    - lib/rindle/ops/upload_maintenance.ex
    - lib/rindle/ops/variant_maintenance.ex
    - lib/rindle.ex
    - lib/rindle/av/subprocess.ex
    - lib/rindle/delivery.ex
    - lib/rindle/processor/image.ex
    - lib/rindle/profile/validator.ex
    - lib/rindle/storage/gcs/signer.ex
    - lib/rindle/storage/local.ex
    - lib/rindle/storage/s3.ex
    - lib/rindle/streaming/provider/mux.ex
    - lib/rindle/upload/tus_plug.ex
    - lib/rindle/workers/cleanup_orphans.ex
    - config/test.exs
    - .doctor.exs
    - .dialyzer_ignore.exs
    - scripts/maintainer/live_residue_allowlist/lib.json
decisions:
  - "The mix.exs duplicated MinIO clause stays until live_residue_scan_test.exs (test/install_smoke) may be edited; its seeded-entry assertion would go red otherwise"
metrics:
  duration: "about 45 min"
  completed: 2026-10-19
estimate:
  tokens: 90000
actuals:
  tokens: 22900
  tasks: 3
  commits: 3
plan_head_before: d19bd41f
plan_head_after: 3b7f960c
---

# Phase 135 Plan 04: lib residue tranche A Summary

Comment-only rewrite of 97 planning-era residue sites across lib/, config/test.exs, mix.exs, .doctor.exs and .dialyzer_ignore.exs. Decision ids, UI-SPEC sections, CR-/WR-/IN- review ids, milestone and phase references and "For now"/"Previously" narration became present-tense rationale, and the lib residue shard dropped from 98 to 1 pending-removal entry. Contract entries (19) are untouched.

## Tasks

| Task | Name | Commit | Shard entries removed |
|------|------|--------|-----------------------|
| 1 | mix.exs comments (partial, see Deviations) | bc3df27f | 1 |
| 2 | admin, ops, mix task comments | e13c0ef6 | 58 |
| 3 | core lib, config, root tool configs | 3b7f960c | 38 |

The three counts add to 97, which matches the drop from 98 pending-removal entries to 1. `--regen-baseline` was used after each task. In each case the only shard diff was deleted pending-removal entries: none were added or reclassified, and no other shard changed.

## Verification

- `scan_live_residue.exs --check`: ok (618 files, 1250 hits, 1216 allowlist entries)
- `scan_live_residue.exs --check --require-no-pending lib`: **FAILS on 1 entry**, the mix.exs `duplicated-prose` line (see Deviations)
- `mix compile --warnings-as-errors` (forced): clean. `mix format --check-formatted`: clean
- `refactor_contract.sh`: no cycles, 97 contract tests, 0 failures
- `mix credo_quality`: passed
- `MIX_ENV=dev mix doctor --full --raise`: passed (100% doc, moduledoc and spec coverage)
- These tests: public surface snapshot, `test/install_smoke/docs_parity`, error_test, live_residue_scan_test and quality_signal_policy_test. Result: 88 tests, 0 failures
- `craft_boundary_check.sh origin/main`: ok
- `automation_first_contract.sh`: passed
- `! grep -rn ".planning/phases/135" scripts test .github lib`: clean
- Full default `mix test` with local Postgres: 3 doctests, 1639 tests, 0 failures, 87 excluded, 4 skipped, 2 invalid.
  - The 2 invalid tests are `Rindle.DoctorThresholdsTest` failing in setup_all, because the scratch `MIX_BUILD_PATH` sits outside the worktree (provenance reports `outside_worktree`).
  - That is environmental. The same test passes with an in-worktree build path: 2 tests, 0 failures.
- `lib/rindle/error.ex`: no diff

### Lines the comment-only diff filter still prints

The plan's filter only exempts lines that begin with `#` or `<%!--`, so it still prints the continuation lines of multi-line HEEx comments (`<%!-- ... --%>`). All of them are comment text, not code:
- `Rindle.Admin.Live.ActionsLive` (batch-erasure preview comment)
- `Rindle.Admin.Live.AssetsLive` (quarantine review comment)
- `Rindle.Admin.Live.RuntimeDoctorLive` (reconcile action comment)
- `Rindle.Admin.Live.VariantsJobsLive` (count_map atom-key comment)

No `@doc` or `@moduledoc` text changed, and no hidden-doc edits were needed.

## Deviations from Plan

**1. [Blocked - scope fence] mix.exs duplicated MinIO clause left in place.**
- Rewriting the clause turns `test/install_smoke/live_residue_scan_test.exs` red. Its test "the live mix.exs clause and regression literal are seeded as expected" asserts that the lib shard still holds a mix.exs `duplicated-prose` entry.
- The orchestrator fenced off `test/install_smoke/**` because Plan 135-03 is running at the same time. 135-03's `files_modified` does not list that file, but the fence was explicit, and the edit was refused when attempted.
- Done in Task 1: the ADMIN-06 requirement id became the Optional Dependencies CI lane, and the broken wrap around `brandbook-tokens` was rejoined.
- Still open: the duplicated "clone without a running MinIO" line, its pending-removal entry, and therefore the `--require-no-pending lib` gate.
- To close it in one follow-up commit:
  1. In mix.exs, merge the two lines into "...runs on a fresh clone without a running MinIO and never hard-fails for its absence. The full-parity storage command is documented in CONTRIBUTING."
  2. In live_residue_scan_test.exs, flip that assertion to `refute`.
  3. Run `--regen-baseline`.

**2. [Rule 2 - accuracy] Stale build-sequence narration rewritten beyond the worklist.**
- These sentences were not on the worklist. They described the system as it was mid-build, and they are now false:
  - in `components.ex`: "P2a ships ONLY the primitive; surfaces adopt it in P3", "Ends this plan existing-but-UNUSED", "RESEARCH A2" and "CSS authored in P1". `page/1` and `confirm_dialog/1` are in use on every surface.
  - in `local.ex`: the "Pitfall 5" token was removed together with the flagged sentence.
- All of these were comments.

**3. [Scope] Unflagged ids left alone.** The scanner's vocabulary does not cover `TUS-09`, `T-43-07` (upload_maintenance.ex) or `Pitfall 5` (local.ex). The plan says to work only from the worklist, so they stay.

## Deferred Issues

- `test/rindle/av/subprocess_epipe_canary_test.exs:14` points to the "`# NOTE (EPIPE-07, MuonTrap #98)` block", which now reads `# NOTE (MuonTrap #98)`. That comment belongs to a test shard owned by a later tranche, and editing it here would make that shard's entry stale.
- The mix.exs duplicated-prose entry (Deviation 1).

## Known Stubs

None.

## Self-Check: PASSED

- Commits bc3df27f, e13c0ef6 and 3b7f960c are on `refactor/135-04-lib-residue`.
- `jq '[.entries[]|select(.reason_class=="pending-removal")]|length' lib.json` returns 1, the mix.exs entry documented above.

## Orchestrator follow-up (2026-10-19)

The orchestrator joined the duplicated mix.exs "clone without a running MinIO" line, flipped the scanner test's seeded-entry assertion to `refute` (the duplicate must stay gone), and regenerated the baseline. `--check --require-no-pending lib` now passes (618 files, 1249 hits, 1215 entries); scan test 28/28.
