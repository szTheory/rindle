---
phase: 135-repository-and-code-craft-consolidation
plan: 12
subsystem: test-residue
tags: [craft, residue, tests, comments]
status: complete
requires: ["135-02", "135-04"]
provides:
  - "unit_tests_b area (ops, processor, profile, storage, streaming, telemetry, upload, workers, test/support) free of planning-era ids; unit_tests_b shard has zero entries"
affects: [scripts/maintainer/live_residue_allowlist/unit_tests_b.json]
tech-stack:
  added: []
  patterns: ["comment/test-name-only residue tranche; the shard shrinks in the same commit as the edit"]
key-files:
  created: []
  modified:
    - test/rindle/profile/validator_test.exs
    - test/rindle/ops/runtime_checks_streaming_test.exs
    - test/rindle/ops/sweep_orphaned_temp_files_test.exs
    - test/rindle/ops/variant_maintenance_test.exs
    - test/rindle/processor/av_test.exs
    - test/rindle/profile/presets/mux_web_test.exs
    - test/rindle/profile/profile_test.exs
    - test/rindle/storage/gcs/signer_test.exs
    - test/rindle/storage/gcs_test.exs
    - test/rindle/storage/local_test.exs
    - test/rindle/storage/local_tus_test.exs
    - test/rindle/storage/s3_tus_test.exs
    - test/rindle/streaming/capabilities_test.exs
    - test/rindle/streaming/provider/mux/event_test.exs
    - test/rindle/streaming/provider/mux/http_cancel_upload_test.exs
    - test/rindle/streaming/provider/mux/mux_test.exs
    - test/rindle/streaming/provider/mux/optional_dep_test.exs
    - test/rindle/streaming/provider/mux/telemetry_test.exs
    - test/rindle/streaming/provider_test.exs
    - test/rindle/telemetry/emission_test.exs
    - test/rindle/upload/broker_test.exs
    - test/rindle/upload/lifecycle_integration_test.exs
    - test/rindle/upload/tus_local_backing_test.exs
    - test/rindle/upload/tus_plug_test.exs
    - test/rindle/upload/tus_s3_integration_test.exs
    - test/rindle/workers/ingest_provider_webhook_test.exs
    - test/rindle/workers/maintenance_workers_test.exs
    - test/rindle/workers/mux_ingest_variant_test.exs
    - test/rindle/workers/mux_sync_coordinator_test.exs
    - test/rindle/workers/mux_sync_provider_asset_test.exs
    - test/support/gcs_signing_key_fixture.ex
    - test/support/host_oban_migration.ex
    - test/support/mux_webhook_fixtures.ex
    - scripts/maintainer/live_residue_allowlist/unit_tests_b.json
decisions:
  - "No id in the unit_tests_b area qualified as a present-tense policy contract (D-135-07), so every entry was removed rather than reclassified; the shard ends empty"
  - "The global_repo_swap justification comment now names the case it rules out (injecting a counting double) instead of citing a past decision id"
metrics:
  duration: "about 35 min"
  completed: 2026-10-19
estimate:
  tokens: 85000
actuals:
  tokens: 27300
  tasks: 3
  commits: 3
plan_head_before: d8bf703d
plan_head_after: 863ddc2d
---

# Phase 135 Plan 12: unit_tests_b residue tranche Summary

Comment and test-name rewrite across 33 unit test and test-support files. Decision, review (CR-/WR-/IN-), requirement, phase, plan and milestone ids were removed from test and describe names and failure messages, and fix-history narration ("Pre-WR-08 ...", "previously raised ...", "phase-gate for Phase 34") became present-tense statements of what each test protects. The unit_tests_b shard went from 153 pending-removal entries to 0 (empty `entries`).

## Tasks

| Task | Name | Commit | Shard entries removed |
|------|------|--------|-----------------------|
| 1 | Tracer: profile/validator_test.exs | bc646af4 | 21 |
| 2 | ops, processor, profile, storage, streaming, telemetry, upload, workers | 93f9b313 | 127 |
| 3 | test/support and the no-pending gate | 863ddc2d | 5 |

21 + 127 + 5 = 153. `--regen-baseline` ran after each task, and each time `unit_tests_b.json` was the only shard in the diff. Allowlist totals went 1215 → 1194 → 1067 → 1062.

## Baselines and counts

- Partition tests (ops, processor, profile, storage, streaming, telemetry, upload, workers): **641 tests, 0 failures, 16 excluded, 4 skipped** both before and after.
- assert/refute line counts for all 78 files under those subtrees and `test/support`: identical before and after. The per-file counts were diffed and no file changed.
- validator_test.exs diff: 0 removed and 0 added assert/refute lines.
- Lines in the diff that are not comments and not `test`/`describe` names: only failure-message strings (the `(D-14)` and `(D-29)` suffixes) and `@moduledoc` prose in test modules. No fixture data, provider payload or asserted value changed.
- Default suite after all edits: **3 doctests, 1639 tests, 0 failures, 87 excluded, 4 skipped**. That matches the 1639 recorded on origin/main by 135-04. Excluded tags: `:integration`, `:minio`, `:contract`, `:adopter`, `:migration_e2e`, `:canary`.

## Verification

- `scan_live_residue.exs --check --require-no-pending unit_tests_b`: ok (618 files, 1095 hits, 1062 allowlist entries), exit 0.
- `mix test test/rindle/public_surface_snapshot_test.exs test/install_smoke`: 363 tests, 0 failures, 17 excluded. The log has Postgres `too_many_connections` noise from concurrent agents sharing the local server, but no test failed.
- `mix format --check-formatted`: clean.
- `mix credo --strict` on the 33 touched .ex/.exs files: no issues.
- Strict partition grep (unit_tests_a paths, public_surface.txt, unit_tests_a.json, lib/): no matches.
- `! git grep ".planning/phases/135" scripts test .github lib`: clean.
- `automation_first_contract.sh`: passed.

## Deviations from Plan

**1. [Rule 2 - accuracy] Adjacent planning-era tokens cleaned beyond the worklist, inside blocks already being rewritten.** The scanner vocabulary does not flag these, but each sat in the same comment or describe block as a flagged hit:
- `s3_tus_test.exs`: "43-08".
- `gcs_test.exs`: "RESEARCH §Section 2".
- `event_test.exs`: "BL-03".
- `telemetry_test.exs`: "B1 fix:" on two extra lines.
- `tus_plug_test.exs`: the describe names "Task 2 —" and "Task 3 —".
- `broker_test.exs` and `maintenance_workers_test.exs`: TEL-01 and TEL-05 in describe names.
- `local_tus_test.exs`: "Pitfall 5".

**2. [Rule 1 - comment bug] Garbled DELETE abort comment repaired.** In `tus_plug_test.exs`, the "Plug half" comment had two merged sentences and an unbalanced parenthesis. It now reads as one coherent statement.

**3. Left unchanged on purpose:**
- `MUX-08` and "security invariant 14" in `telemetry_test.exs`, and `AV-02-06`/`AV-02-07` in validator_test describe names. The scanner does not flag them.
- The `~r/AV-02-08/` assertion. It asserts lib error-message text, which is contract under D-135-05.
- The handler-id literals `ingest-wr09-` and `wr08_`. They are code, not comments.

## Known Stubs

None.

## Self-Check: PASSED

- Commits bc646af4, 93f9b313 and 863ddc2d are on `test/135-12-unit-tests-b-residue`.
- `jq '[.entries[]|select(.reason_class=="pending-removal")]|length' unit_tests_b.json` returns 0.
