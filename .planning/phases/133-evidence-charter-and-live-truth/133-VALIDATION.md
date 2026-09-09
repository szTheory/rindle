---
phase: "133"
slug: "evidence-charter-and-live-truth"
status: ready
nyquist_compliant: true
wave_0_complete: false
created: "2026-09-09"
revised: "2026-09-09"
---

# Phase 133 — Validation Strategy

> Complete per-task validation contract for feedback sampling during execution. Wave 0 files are created test-first by their owning tasks; `wave_0_complete` remains false until execution creates them.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus repository-native Bash truth-table scripts |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `bash scripts/ci/test_nightly_summary_gate.sh && bash scripts/ci/test_nightly_dialyzer.sh && bash scripts/ci/test_nightly_incident.sh && bash scripts/ci/test_verify_nightly_run.sh` |
| **Full suite command** | `mix ci && bash scripts/maintainer/refactor_contract.sh && ./scripts/maintainer/automation_first_contract.sh` |
| **Clean-subject gate** | Detached-worktree census receipt plus `./scripts/maintainer/repo_hygiene_check.sh` at the ledger-recorded committed SHA |
| **Estimated runtime** | ~180 seconds excluding the bounded live supported-cell Nightly run |

## Sampling Rate

- After every task commit: run the task's focused Bash or ExUnit contract.
- After every plan wave: run all Phase 133 focused contracts affected by that wave and related existing policy tests.
- Before live dispatch: validate the final ledger and repository hygiene in an isolated detached worktree at its committed subject SHA.
- Final live gate: automated remote-ref/SHA preflight, first-attempt diagnostic Nightly collection, and receipt revalidation; human publication authorization is never acceptance evidence.
- Any listed failure direction halts the task; no human observation can convert red or missing evidence to green.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Test Type | Automated Command | Failure Direction | File State |
|---------|------|------|-------------|------------|-----------|-------------------|------------------|------------|
| 133-01-01 | 01 | 1 | EVID-01 | T-133-01 | tracer contract | `mix test test/install_smoke/evidence_census_test.exs` | Halt on nonzero or zero tests; validator/schema tracer remains red. | W0 create-first |
| 133-01-02 | 01 | 1 | EVID-01 | T-133-01/T-133-02 | mutation contract | `mix test test/install_smoke/evidence_census_test.exs` | Halt on nonzero, zero tests, unstable serialization, identity substitution, or missing transition rejection. | W0 create-first |
| 133-02-01 | 02 | 1 | EVID-02 | T-133-05/T-133-07 | shell/unit | `bash scripts/ci/test_nightly_dialyzer.sh` | Halt on nonzero, any FAIL row, or zero cases; do not modify the workflow. | W0 create-first |
| 133-02-02 | 02 | 1 | EVID-02 | T-133-05/T-133-06 | shell + structural | `bash scripts/ci/test_nightly_dialyzer.sh && mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs` | Halt on nonzero, zero cases/tests, major-only cache identity, one-mode topology, or suppression drift. | partial existing |
| 133-03-01 | 03 | 2 | EVID-03 | T-133-09/T-133-10 | truth table | `bash scripts/ci/test_nightly_summary_gate.sh` | Halt on nonzero, any FAIL row, zero cases, or a false-green state. | W0 create-first |
| 133-03-02 | 03 | 2 | EVID-03 | T-133-09/T-133-11 | shell + parsed topology | `bash scripts/ci/test_nightly_summary_gate.sh && mix test test/install_smoke/nightly_policy_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs` | Halt on nonzero, zero cases/tests, masked verdict, or CI identity/topology drift. | partial existing |
| 133-04-01 | 04 | 3 | EVID-04 | T-133-13/T-133-14 | fake-GitHub adapter | `bash scripts/ci/test_nightly_incident.sh` | Halt on nonzero, any FAIL row, zero cases, duplicate selection, or unauthorized mutation. | W0 create-first |
| 133-04-02 | 04 | 3 | EVID-04 | T-133-13/T-133-15/T-133-16 | shell + parsed topology | `bash scripts/ci/test_nightly_incident.sh && mix test test/install_smoke/nightly_policy_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs` | Halt on nonzero, zero cases/tests, dispatch mutation, stale-main closure, or permission/topology drift. | partial existing |
| 133-05-01 | 05 | 4 | TRUTH-08 | T-133-17/T-133-19 | derived-authority contract | `mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority` | Halt on nonzero, zero tests, authority mismatch, malformed marker, or stale active claim. | W0 create-first |
| 133-05-02 | 05 | 4 | TRUTH-08 | T-133-18 | built-package contract | `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority && mix test test/install_smoke/package_metadata_test.exs test/install_smoke/generated_app_smoke_test.exs` | Halt on nonzero, zero tests, missing unpacked provenance, or repository/prebuilt fallback. | partial existing |
| 133-06-01 | 06 | 5 | TRUTH-08 | T-133-21/T-133-22/T-133-23 | parity + adoption gate | `mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority && bash scripts/maintainer/check_adoption_proof_matrix.sh` | Halt on nonzero, zero tests, unmarked contradiction, or prose-only package proof. | partial existing |
| 133-06-02 | 06 | 5 | EVID-01–04, TRUTH-08 | T-133-21–T-133-24 | full local + detached authority | Execute all four `<automated>` commands in Plan 06 Task 2 in order. | Halt on the first nonzero/zero-case result; preserve caller changes and keep the ledger unfrozen if detached SHA, hygiene, census, or transition validation fails. | W0 + existing |
| 133-07-01 | 07 | 6 | EVID-02–04 | T-133-25–T-133-28 | fake-GitHub collector | `bash scripts/ci/test_verify_nightly_run.sh` | Halt on nonzero, any FAIL row, zero cases, wrong-head acceptance, partial receipt, or forbidden mutation. | W0 create-first |
| 133-07-02 | 07 | 6 | authorization only | T-133-27 | blocking-human decision | No automated acceptance command; choose `publish` or stop. | `stop` halts with live evidence incomplete; `publish` only authorizes Task 3 and supplies no acceptance credit. | N/A checkpoint |
| 133-07-03 | 07 | 6 | EVID-01–04, TRUTH-08 | T-133-25–T-133-28 | remote preflight + receipt | Execute Plan 07 Task 3's exact `git ls-remote`, `preflight`, and `verify-receipt` command. | Halt on auth/API/timeout, remote SHA mismatch, rerun/partial/red evidence, or changed incident snapshot; do not accept publication itself as proof. | W0 + live output |

*Status during execution: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. The map has 14 automated implementation tasks plus one authorization-only checkpoint introduced by revision.*

## Wave 0 Requirements

- [ ] `test/install_smoke/evidence_census_test.exs` — schema, exact-head, deduplication, disposition, stable-ID transition, and mutation fixtures.
- [ ] `scripts/ci/test_nightly_dialyzer.sh` — fresh, restored, stale, corrupt, build-failure, and genuine-warning fixtures.
- [ ] `scripts/ci/test_nightly_summary_gate.sh` — complete result/applicability truth table.
- [ ] `scripts/ci/test_nightly_incident.sh` — scheduled-only fake-`gh` lifecycle tests.
- [ ] `test/install_smoke/nightly_policy_test.exs` — parsed topology, permissions, and verdict/lifecycle wiring.
- [ ] `test/install_smoke/live_truth_parity_test.exs` — version, lane, package-proof, and exact historical-marker fixtures.
- [ ] `scripts/ci/test_verify_nightly_run.sh` — remote preflight, exact-run, partial-state, and nonmutation fixtures.

## Manual-Only Verifications

None. The sole human checkpoint authorizes a reversible publication action; it does not verify behavior or satisfy a requirement.

## Validation Sign-Off

- [x] Every implementation task has an automated command and explicit failure direction.
- [x] All actual waves and all 14 implementation tasks are mapped; the added authorization checkpoint is mapped separately.
- [x] Sampling continuity has no unverified implementation-task gap.
- [x] Wave 0 creation ownership is explicit for every missing test artifact.
- [x] No watch-mode flags or vacuous human acceptance.
- [x] Clean-worktree authority is isolated from the user's unrelated `.planning/config.json` edit.
- [x] `nyquist_compliant: true` is set because the map is complete; `wave_0_complete` remains false until execution.

**Approval:** validation design complete; execution pending
