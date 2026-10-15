---
phase: 133-evidence-charter-and-live-truth
type: rescope
decided: 2026-10-14
trigger: stop rule (Plans 203/204 closed no requirement and resolved no edge)
supersedes_open_plans: ["133-121", "133-122", "133-123", "133-169", "133-173", "133-178", "133-190", "133-192", "133-203", "133-204"]
new_plans: ["133-211", "133-212", "133-213"]
requirements: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
---

# Phase 133 Rescope

## Why

- **The behavior is done.** The 2026-10-04 verification marks all four roadmap truths VERIFIED: census validator, Nightly Dialyzer PLT policy, fail-closed aggregation and incident lifecycle, and live-truth parity.
- **No requirement has closed.** The five requirements stayed Pending only because of a self-imposed gate: a one-shot local qualification on an exact frozen subject, then terminal reconciliation through Plans 121–123.
- **The gate never produced credit.** It used about 130 gap plans (77–210). It produced about 100k lines of `phase_133_*` qualification tooling and zero requirement credit.
  - Every gap commit moves the subject.
  - Every one-shot route can be spent by an implementation defect. Plan 203 was spent by a circular top-level await in its CLI entry.
- **None of that work is on `main`.** `gsd/phase-133-execution` is 1343 commits ahead of `origin/main`.
- **`main` shows the exact defects this phase fixes.** Scheduled Nightly fails every day on Dialyzer (runs 38035071344 … 38529530511). Yet `Nightly Summary` reports success, which is the EVID-03 defect. The real fixes have never run where they matter.

## Decisions

- **D-133-R1 — Retire the bespoke qualification route.**
  - The ten open plans listed in `supersedes_open_plans` are superseded and stay as immutable history.
  - Plan 203 stays a terminal halt (`133-203-SUMMARY.md`).
  - No preparation, authorization literal, receipt or ledger from that route is reused or replayed.
- **D-133-R2 — Use GitHub Actions on `main` as the only live source.**
  - Acceptance comes from merge-blocking CI on the landing PR, plus the first scheduled Nightly run on the merged `main` SHA.
  - That run is verified read-only by the existing tested `scripts/ci/verify_nightly_run.sh verify-receipt`.
  - Local private chains, registry supply, Claude/Codex transport authentication and producer one-shots no longer count as sources.
- **D-133-R3 — Each requirement closes on its own evidence.**
  - There is no joint terminal gate. A red result on one requirement does not hold back the others.
  - | Requirement | Closes when (all automated) |
    |---|---|
    | EVID-01 | `validate_evidence_census.exs` accepts a census bound to the merged `main` SHA, and `evidence_census_test` passes in merge-blocking CI. |
    | EVID-02 | `test_nightly_dialyzer.sh` passes, and the verified scheduled Nightly on the merge SHA has every supported Dialyzer cell succeed. |
    | EVID-03 | `test_nightly_summary_gate.sh` passes, and in the verified run the `Nightly Summary` conclusion equals the strict aggregate of the gating jobs. |
    | EVID-04 | `test_nightly_incident.sh` passes (including the genesis/adoption rule), and a qualifying scheduled recovery closes the adopted incident citing its run id. |
    | TRUTH-08 | `live_truth_parity_test` and `check_adoption_proof_matrix.sh` pass on the merged `main` SHA in merge-blocking CI. |
- **D-133-R4 — Land only product code.**
  - The landing branch starts from `origin/main`. It carries the requirement-bearing files plus the full `.planning/` tree; per the faithful-branch rule, tests read `.planning/`.
  - It excludes the `phase_133_*` qualification tooling, its tests and its fixtures.
  - An automated closure check proves that no landed file references an excluded file.
- **D-133-R5 — Resolve the eleven edge rows with tests.**
  - Each row maps to a named focused test case in `133-EDGES.md`, or to a reasoned not-applicable classification that a test asserts.
  - The rows are: EVID-01 boundary/adjacency/empty/ordering/precision; EVID-02 unclassified; EVID-03 boundary/precision; EVID-04 idempotency/concurrency; TRUTH-08 unclassified.
- **D-133-R7 — Ship evidence tooling in the landing PR.**
  - `verify_nightly_run.sh verify-scheduled` and the incident genesis rule ship in the same landing PR, so the first scheduled run on the merge SHA can qualify.
  - A qualifying run's headSha is the merge SHA, or a descendant that touches no manifest file.
- **D-133-R6 — Human responses grant permission, not credit.**
  - Pushing the branch, opening the PR and merging are outward-facing, so each needs an authorization-only checkpoint.
  - No human response satisfies any requirement.

## Stop rule (carried forward)

If Plan 213 closes no requirement, plan no more gap plans for Phase 133. Instead:
- escalate to the maintainer with the first-red evidence;
- propose either deferring the failing requirement with a trigger, or moving it to Phase 136 (Measured Quality and CI Ratchets).
