---
phase: 133-evidence-charter-and-live-truth
plan: "06"
subsystem: testing
tags: [elixir, exunit, evidence, packaging, nightly, git-worktree]
requires:
  - phase: 133-01
    provides: SHA-bound evidence census collector and validator
  - phase: 133-02
    provides: fresh/restored/stale-only Dialyzer evidence contracts
  - phase: 133-03
    provides: strict Nightly verdict policy
  - phase: 133-04
    provides: exact-run incident lifecycle policy
  - phase: 133-05
    provides: derived release, topology, and package-proof authority
provides:
  - Authority-reconciled active release, lane, Nightly, package, and adoption claims
  - Adoption gate backed by real unpacked generated-consumer provenance
  - Twelve-dimension post-repair census ledger frozen against committed subject 4f83e15
affects: [phase-133-plan-07, phase-134, phase-135, phase-136, release-evidence]
actuals:
  tokens: 9175
  tasks: 2
  commits: 6
tech-stack:
  added: []
  patterns:
    - Derived authority runs before supplementary prose diagnostics
    - Ledger commit remains separate from its inspected exact-SHA subject
    - Local newer-toolchain evidence stays diagnostic until supported-cell live proof
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json
  modified:
    - scripts/maintainer/check_adoption_proof_matrix.sh
    - examples/adoption_demo/docs/adoption-proof-matrix.md
    - RUNNING.md
    - .planning/INBOX-TRIAGE.md
    - .planning/JTBD-MAP.md
    - scripts/maintainer/evidence_census.exs
    - scripts/maintainer/validate_evidence_census.exs
    - test/install_smoke/evidence_census_test.exs
    - test/install_smoke/live_truth_parity_test.exs
key-decisions:
  - "Run both derived-truth and real package-authority tags before adoption-matrix copy diagnostics."
  - "Freeze the ledger against pre-ledger subject 4f83e15 so committing the ledger cannot create SHA self-reference."
  - "Record local Elixir 1.19/OTP 28 results as diagnostic and leave supported Elixir 1.17/OTP 27 exact-run acceptance to Plan 07."
patterns-established:
  - "Evidence-class separation: built package, maintainer-operated synthetic host, and named independent adopter are never interchangeable."
  - "Historical preservation: explicit bounded markers exclude immutable receipts while active anchors derive from live authorities."
requirements-completed: [EVID-01, EVID-03, TRUTH-08]
coverage:
  - id: D1
    description: Active release, CI lane, Nightly applicability, package, and adoption claims match derived authority.
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs --only derived_authority"
        status: pass
    human_judgment: false
  - id: D2
    description: The adoption gate executes real built/unpacked/no-fallback generated-consumer proof before supplementary copy checks.
    requirement: TRUTH-08
    verification:
      - kind: e2e
        ref: "bash scripts/maintainer/check_adoption_proof_matrix.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: The post-repair twelve-dimension ledger validates from a clean detached worktree at its exact committed subject.
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "evidence_census.exs + validate_evidence_census.exs at 4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2"
        status: pass
    human_judgment: false
  - id: D4
    description: Every implemented Phase 133 local policy and full repository gate passes without substituting for Plan 07 live evidence.
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "mix ci; Nightly shell contracts; focused Phase 133 ExUnit; refactor and automation-first contracts"
        status: pass
    human_judgment: false
duration: 28min
completed: 2026-09-09
status: complete
---

# Phase 133 Plan 06: Evidence Reconciliation and Local Closure Summary

**Active claims now derive from repository truth, package evidence comes from a real unpacked consumer, and a clean exact-SHA census freezes all twelve quality dimensions for live verification.**

## Performance

- **Duration:** 28 min
- **Started:** 2026-09-10T01:45:19Z
- **Completed:** 2026-09-10T02:13:00Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Reconciled current version anchors to 0.4.6 while preserving marked and archived historical receipts byte-for-byte.
- Corrected the adoption matrix to identify `adoption-demo-e2e-smoke` as merge-blocking, full `adoption-demo-e2e` as push-main/off-critical-path, and secret-absent Nightly work as not-run.
- Made the adoption gate execute derived topology plus fresh built/unpacked/no-fallback package proof before its bounded prose checks.
- Froze twelve stable candidates, twelve bijective observations, and eight explicit Phase 133 before/after transitions against clean subject `4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2`.
- Restored full-suite async safety and corrected the performance detector's archived receipt path after the reconciliation gate exposed both defects.

## Task Commits

1. **Task 1 RED: expose active evidence drift** - `39b6702` (test)
2. **Task 1 GREEN: reconcile active evidence claims** - `5897183` (fix)
3. **Task 1 formatting correction** - `d6212dc` (style)
4. **Task 2 blocking fix: classify isolated census fixture writes** - `ea72440` (fix)
5. **Task 2 blocking fix: resolve archived timing receipt** - `4f83e15` (fix)
6. **Task 2: freeze post-repair evidence census** - `dbede41` (test)

## Files Created/Modified

- `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json` - Exact-subject ledger for twelve dimensions, candidates, baselines, and transitions.
- `scripts/maintainer/check_adoption_proof_matrix.sh` - Runs derived and package authorities before copy diagnostics.
- `examples/adoption_demo/docs/adoption-proof-matrix.md` - Truthful smoke/full-E2E and synthetic/independent evidence classification.
- `RUNNING.md` - Explicit fresh/restored, strict verdict, not-run, and live-authority guidance.
- `.planning/INBOX-TRIAGE.md`, `.planning/JTBD-MAP.md` - Active 0.4.6 anchors with historical receipts preserved.
- `test/install_smoke/live_truth_parity_test.exs` - Active-surface regression contract.
- `test/install_smoke/evidence_census_test.exs` - Justified process-local file-mutation classification and corrected detector fixture.
- `scripts/maintainer/evidence_census.exs`, `scripts/maintainer/validate_evidence_census.exs` - Correct Phase 132 performance receipt input.

## Decisions Made

- Package authority is an executed generated-consumer contract, not the presence of expected strings or filenames.
- The ledger records `4f83e15`, the clean production/test subject before the ledger commit; `dbede41` is intentionally not relabeled as that subject.
- Local Elixir 1.19.5 / OTP 28.4.1 verification is diagnostic. Plan 07 still owns supported Elixir 1.17 / OTP 27 and exact-run GitHub acceptance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Classified isolated census fixture mutation for async safety**

- **Found during:** Task 2 full `mix ci`
- **Issue:** The static async-safety guard treated per-test unique temporary Git repositories as shared file mutation.
- **Fix:** Added a justified module-tag allowance scoped to `:file_mutation`; all fixture roots remain unique and cleaned by `on_exit`.
- **Files modified:** `test/install_smoke/evidence_census_test.exs`
- **Verification:** Async-safety guard and full `mix ci` pass.
- **Committed in:** `ea72440`

**2. [Rule 1 - Bug] Corrected a stale archived Phase 132 receipt path**

- **Found during:** Task 2 detached clean-subject census collection
- **Issue:** The collector, validator, and fixture registry named a non-existent `132-final-craft-truth-and-feedback-proof` archive path.
- **Fix:** Pointed all three registries to the actual immutable `132-measured-closure/132-02-SUMMARY.md` receipt.
- **Files modified:** `scripts/maintainer/evidence_census.exs`, `scripts/maintainer/validate_evidence_census.exs`, `test/install_smoke/evidence_census_test.exs`
- **Verification:** Focused census tests and the detached collector/validator gate pass.
- **Committed in:** `4f83e15`

---

**Total deviations:** 2 auto-fixed bugs
**Impact on plan:** Both fixes were required for the planned full-suite and detached-authority gates; no public API, dependency, schema, workflow topology, or remote disposition changed.

## Issues Encountered

- The pinned Elixir 1.17.3 / OTP 27.2 toolchain is unavailable locally. Verification ran on Elixir 1.19.5 / OTP 28.4.1 and is recorded as diagnostic; Plan 07 remains the only supported-cell exact-run authority.
- Hex dependency resolution reported current security advisories for locked transitive `cowlib` and `mint`. Phase 133 intentionally made no dependency disposition; Phase 134 owns live dependency triage.
- The Plan 07 `test_verify_nightly_run.sh` Wave 0 artifact does not exist yet and was not counted as a Plan 06 local gate. All implemented Plans 01-06 contracts passed.

## Known Stubs

| File | Line | Stub | Reason |
|------|------|------|--------|
| `examples/adoption_demo/docs/adoption-proof-matrix.md` | 43 | Optional demo placeholder for GCS resumable browser path | Pre-existing and explicitly non-authoritative; live generated-app GCS proof is a separate evidence class. |

Recorded in `.planning/WINDOWS.md` as open stub 16.

## Authentication Gates

None. The expired local Hex user session did not block public dependency resolution or any planned check.

## Verification

- `bash scripts/ci/test_nightly_summary_gate.sh` - 49 cases, 0 failures.
- `bash scripts/ci/test_nightly_dialyzer.sh` - 24 cases, 0 failures.
- `bash scripts/ci/test_nightly_incident.sh` - 22 cases, 0 failures.
- Focused Phase 133 ExUnit command - 84 tests, 0 failures, 17 excluded.
- `bash scripts/maintainer/check_adoption_proof_matrix.sh` - 6 derived-authority tests and 4 package-authority tests passed; fresh unpacked generated image consumer passed.
- `mix ci` - 3 doctests and 1,460 tests, 0 failures, 4 skipped; 97 contract tests passed separately inside the alias.
- `bash scripts/maintainer/refactor_contract.sh` - 97 contract tests, 0 failures.
- `./scripts/maintainer/automation_first_contract.sh` - passed after planning changes.
- Detached worktree at `4f83e15` - repository hygiene 11 PASS / 1 expected ahead-of-origin WARN / 0 BLOCK; census receipt validated; worktree remained clean; caller `.planning/config.json` digest remained unchanged.

## Threat Flags

None. This plan added no endpoint, authentication path, file-access capability, schema boundary, or external mutation surface.

## Self-Check: PASSED

- All ten created/modified outcome files exist.
- All six task/deviation commits exist in repository history.
- Ledger subject `4f83e15` exists, was inspected detached and clean, and differs intentionally from ledger commit `dbede41`.
- The pre-existing `.planning/config.json` edit and generated `.planning/milestone.lock` / `.planning/state.json` files remain untouched and uncommitted.

## Next Phase Readiness

- Plan 07 can collect first-attempt diagnostic Nightly evidence only after exact remote-ref/SHA preflight and can close requirements only with the supported-cell exact-run receipt.
- The local evidence plane is green; no human observation is needed or accepted as requirement proof.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-09*
