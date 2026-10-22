---
phase: "139"
slug: "exact-head-readiness-closure"
status: planned
nyquist_compliant: true
wave_0_complete: false
created: "2026-10-22"
---

# Phase 139 — Validation Strategy

## Test Infrastructure

Use existing Bash/jq fixtures and ExUnit script tests. The planner must finalize the per-task map
with concrete test paths, creation dependencies, and observable failure signals before checking.

| Property | Value |
|----------|-------|
| Framework | Existing Bash script-test seam and ExUnit |
| Config | `.github/workflows/ci.yml`, `test/test_helper.exs`, `mix.exs` |
| Existing quick regression | `bash scripts/ci/test_nightly_summary_gate.sh` |
| New focused checks | Created by the first implementation tasks; exact paths finalized with plans |
| Full local verification | `mix ci` on the committed supported toolchain |
| Terminal acceptance | Plan 07 `verify-subject` then `accept` on the accepted merged main after all implementation and planning changes, with actual isolated qualification, live main CI, scheduled Nightly, protection, complete remote inventories, producer-digest-verified post-upload durable copy, validated refresh envelope and adoption parity; later GSD metadata is explicitly historical |
| Feedback budget | Focused pure fixtures target <60 seconds; measure during implementation |

## Sampling Rate

- Each task runs its focused deterministic regressions with nonzero exits for rejected evidence.
- After each Phase 139 plan writes its SUMMARY.md, run the automation-first contract check before that summary is committed. Plan 07 runs it again after REQUIREMENTS, ROADMAP, and STATE metadata edits and before `git_commit_metadata`.
- Every wave runs all phase fixtures and relevant existing script/Mix regressions.
- Before phase completion, collect and validate the actual same-subject qualification and live proof.
- Heavy qualification and privileged read-only queries stay outside the PR critical path.

## Per-Task Verification Map

The first task of each plan creates its own fixture driver before that command is run. Every command runs from the repository root. Focused fixture commands are implementation checks; terminal acceptance still requires post-merge main qualification and live observations.

| Task | Command | Created by | Observable red signal |
|---|---|---|---|
| 139 execution preflight | `bash .planning/phases/139-exact-head-readiness-closure/139-preflight-test.sh` | Planning reconciliation | nonzero for absent/uncommitted Phase 133–138 reports or summaries, stale Phase 138 covered digest, missing/tampered retained matrix, or altered zero-credit timing deferral; test forces missing retained inputs to fail |
| 139-00 T1–T2 | `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1 mix test test/rindle/doctor_test.exs test/install_smoke/twin_cli_test.exs` | 139-00 T1 | nonzero for versioned-host false failure or weakened legacy/upgrade/catalog/Oban diagnosis |
| 139-01 T1–T2 | `bash scripts/ci/test_exact_head_readiness.sh` | 139-01 T1 | nonzero exit or missing PASS/negative-case count, including corrupt refresh-envelope graph |
| 139-02 T1–T2 | `bash scripts/ci/test_exact_head_qualification.sh` | 139-02 T1 | nonzero exit or missing full-gate assertion |
| 139-03 T1–T2 | `bash scripts/ci/test_readiness_runs.sh` | 139-03 T1 | nonzero exit or missing scheduled/protection assertion |
| 139-04 T1–T2 | `bash scripts/ci/test_readiness_remote.sh` | 139-04 T1 | nonzero exit or missing source/edge assertion |
| 139-05 T1–T2 | `bash scripts/ci/test_exact_head_closure.sh` | 139-05 T1 | nonzero exit or missing bounded-wait or refreshed-receipt graph assertion |
| 139-06 T1 | `bash scripts/ci/test_readiness_retention.sh` | 139-06 T1 | nonzero exit or missing run-bound sidecar/archive/manifest byte-check assertion |
| 139-06 T2 | `bash scripts/ci/test_readiness_adoption.sh` | 139-06 T2 | nonzero exit or missing synthetic-rejection or historical-metadata/current-head parity assertion |
| 139-07 T1 | `bash scripts/maintainer/exact_head_readiness.sh verify-subject --repo szTheory/rindle --output "$READINESS_EVIDENCE_DIR"` | 139-06 T2 | nonzero exit, missing tracked Phase 139 change, dirty checkout, or local/remote SHA mismatch |
| 139-07 T2 | `bash scripts/maintainer/exact_head_readiness.sh accept --repo szTheory/rindle --output "$READINESS_EVIDENCE_DIR"` | 139-06 T2 | nonzero exit, non-ready terminal verdict, incomplete live input, changed main, missing producer sidecar, invalid refresh envelope, or missing verified durable copy; normal post-task metadata is then subject/interval qualified and checked by `claim-status` |
| 139-01–06 post-summary closeout | `./scripts/maintainer/automation_first_contract.sh --phase-dir .planning/phases/139-exact-head-readiness-closure` after each plan's SUMMARY.md is written, before its metadata commit | Existing `scripts/maintainer/automation_first_contract.sh` | nonzero exit or automation-first contract rejection blocks summary closeout and commit |
| 139-07 post-summary and final metadata closeout | `./scripts/maintainer/automation_first_contract.sh --phase-dir .planning/phases/139-exact-head-readiness-closure` after 139-07-SUMMARY.md and REQUIREMENTS/ROADMAP/STATE edits plus `claim-status` parity, before `git_commit_metadata` | Existing `scripts/maintainer/automation_first_contract.sh` | nonzero exit or automation-first contract rejection blocks metadata closeout and commit |

Terminal automated acceptance: after all tracked implementation, workflow, documentation, and planning changes are merged, Plan 07 runs `verify-subject` and then `accept` from the restricted durable maintainer host with an external evidence directory. `accept` triggers a matching main workflow run, waits for upload, retrieves the exact run/attempt producer digest sidecar and archive, verifies retained archive and manifest bytes, validates the subject-preserving refresh envelope against new mutable receipt bytes and authoritative adoption parity, and checks the final machine-readable ready verdict. A nonzero exit, `not_ready`, changed main, missing scheduled Nightly, incomplete upstream acceptance, or absent verified local copy leaves READY-01–05 open. Only after actual acceptance may normal GSD summary/requirement/progress metadata record historical completion, qualified by accepted SHA and observation interval. Its later commit cannot inherit current-head readiness; `claim-status` proves this in a negative fixture and on any advanced main. The controller has bounded waiting; fixture checks and a candidate `close` verdict are implementation progress only.

The automation-first closeout check validates active planning-artifact edits; it does not create or refresh an exact-head readiness verdict. Keep Plan 07's accepted SHA, interval and locator as historical metadata when that metadata later reaches main.

| Requirement | Automated proof | New infrastructure |
|-------------|-----------------|--------------------|
| READY-01 | Exact tool/input and subject identity, all gates executed, archive/payload binding, clean initial/final checkout, cleanup and residue rejection | Isolated runner and receipt fixtures |
| READY-02 | Full exact-head push-main CI and scheduled Nightly attempts, newest eligible run, complete topology-derived matrix/event job sets, effective protection parity | Read-only collector and fake API regressions with omitted-job negatives |
| READY-03 | Complete per-source pagination/visibility, current dispositions, missing historical items, independent Hex audit, two bounded observations | Upstream contract adapter and inventory fixtures |
| READY-04 | Finite schema, required/duplicate/unknown proof IDs, raw byte digests, crash/timeout/unfinished manifest, mutable drift, original manifest to refresh-envelope to new receipt graph | Pure manifest validator and adversarial fixtures |
| READY-05 | Live authoritative requirements/release/adoption state rejects PILOT-01/02 or real-adopter/1.0 claims from synthetic evidence | Automated parity wired into close/refresh/accept, plus mutated-real-state fixtures |

## Wave 0 Requirements

Existing test infrastructure needs no new dependency. The execution preflight now verifies delivered Phase 133–138 artifacts and Phase 138's current covered digest and retained matrix; it grants implementation readiness only. Plan 00 repairs public Doctor. Plan 01 establishes the validator consumed by plans 02–04; plan 02 depends on both 00 and 01. Plan 05 requires 02–04 outputs; plan 06 requires 05; plan 07 requires all tracked Phase 139 changes merged onto main. Missing fixture, matching uploaded artifact, or durable verified copy is a nonpassing executable prerequisite, never credited by planning status. The deferred exact-ten CI timing target remains unfinished, has zero credit, and is excluded from READY acceptance; the original blocked receipt stays immutable.

## Manual-Only Verifications

None. Every acceptance behavior uses executable tests, probes, or evidence collectors. Credential or
irreversible-action authorization cannot satisfy a requirement. Unavailable live proof leaves acceptance open.

## Validation Sign-Off

- [ ] Final per-task map matches plans and creation dependencies.
- [ ] Every task has an automated check with observable failing direction.
- [ ] No three consecutive tasks omit automated verification.
- [ ] All missing references have earlier creation tasks.
- [ ] Focused feedback duration measured; no watch-mode commands.
- [ ] Actual terminal proof validated on final merged main subject.

Planning review does not establish execution success or requirement completion.
