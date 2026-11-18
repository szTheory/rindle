---
phase: 139-exact-head-readiness-closure
plan: "09"
subsystem: ci-evidence
tags: [workflow-policy, exact-head-readiness, fixtures, security]
requires:
  - phase: 139-08
    provides: Exact-SHA CI Summary receipts authenticated to GitHub Actions App ID 15368
provides:
  - Machine-checked review of the final workflow bytes and every changed workflow hunk
  - Fixture-scoped readiness graph passes with source-specific negative cases intact
affects: [readiness-ci-evidence, phase-139-verification]
actuals:
  tokens: 14729
  tasks: 3
  commits: 0
tech-stack:
  added: []
  patterns: [exact-byte review gate, FIFO-safe path validation, fixture-scoped evidence]
key-files:
  created:
    - scripts/maintainer/check_workflow_review.py
    - scripts/ci/test_workflow_review_gate.sh
    - .planning/phases/139-exact-head-readiness-closure/139-09-WORKFLOW-REVIEW.json
  modified:
    - scripts/maintainer/validate_exact_head_readiness.exs
    - scripts/maintainer/readiness_nightly.exs
    - scripts/ci/test_readiness_remote.sh
    - scripts/maintainer/readiness_acceptance.py
    - test/install_smoke/ci_cache_hygiene_test.exs
    - scripts/maintainer/live_residue_allowlist/automation_generators.json
    - scripts/maintainer/live_residue_allowlist/automation_workflows.json
requirements-completed: [READY-02, READY-04]
coverage:
  - id: D1
    description: Final workflow bytes and all changed hunks must have an approved, resolved review record before guard identities are trusted.
    requirement: READY-02
    verification:
      - kind: integration
        ref: bash scripts/ci/test_workflow_review_gate.sh
        status: pass
      - kind: other
        ref: python3 scripts/maintainer/check_workflow_review.py --record .planning/phases/139-exact-head-readiness-closure/139-09-WORKFLOW-REVIEW.json
        status: pass
    human_judgment: false
  - id: D2
    description: The complete canonical local evidence graph passes in fixture scope and reason-specific negative cases retain their own failure reasons.
    requirement: READY-04
    verification:
      - kind: integration
        ref: bash scripts/ci/test_exact_head_readiness.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_readiness_fixtures.sh
        status: pass
    human_judgment: false
duration: not captured
completed: 2026-11-17
status: complete
---

# Phase 139 Plan 09: Reviewed Workflow Identity and Fixture Closure

**An executable gate now binds workflow trust identities to a reviewed set of exact bytes, while the full local readiness fixture graph passes without granting current-readiness credit.**

## Performance

- **Duration:** Not captured
- **Started:** Not captured
- **Completed:** 2026-11-17
- **Tasks:** 3
- **Files modified:** See the candidate change list; unrelated dirty checkout paths are excluded.

## Accomplishments

- Added a review record for four workflow files, all 13 changed hunks, and five local policy contracts. The executable gate verifies the baseline commit, raw-byte digests, hunk coverage, findings, and contract outcomes.
- Hardened workflow file reads to reject symlinked paths and non-regular files before reading. The isolated fixture includes a FIFO and a five-second timeout; it confirms the checker returns the specific rejection without blocking.
- Reconciled the reviewed CI and release guard identities. The canonical readiness CLI and full fixture graph now pass, retaining fixture-only scope and reason-specific negative assertions.
- Re-reviewed the source changes; the final code review found no open issues.

## Task Commits

No task commits were created during execution. Delivery is packaged as a Phase 139-only candidate based on the Plan 08 commit; the shared checkout remains on `main`, and unrelated dirty files are excluded.

## Files Created/Modified

- `scripts/maintainer/check_workflow_review.py` - Validates exact reviewed workflow bytes and hunk coverage.
- `scripts/ci/test_workflow_review_gate.sh` - Exercises positive and fail-closed review-record cases, including symlinks and FIFOs.
- `.planning/phases/139-exact-head-readiness-closure/139-09-WORKFLOW-REVIEW.json` - Records the reviewed workflow identities and dispositions.
- `scripts/maintainer/validate_exact_head_readiness.exs` - Updates the approved CI and release guard identities.
- `scripts/maintainer/readiness_nightly.exs` - Updates the raw Nightly workflow digest to match the reviewed workflow bytes.
- `scripts/ci/test_readiness_remote.sh` - Gives the expired-exception test an isolated expired record rather than depending on a currently active exception.
- `scripts/maintainer/readiness_acceptance.py` - Prefers the tracked Phase 02 preflight and falls back to its relocated runtime artifact when that is the available checkout layout.
- `scripts/ci/test_readiness_acceptance.sh` - Covers both tracked and relocated preflight inventory paths.

## Decisions Made

- Keep the workflow gate in the Python standard library and reject special filesystem objects before reading bytes.
- Keep the historical plan path intact; resolve the tracked artifact first and use the relocated runtime artifact only when the tracked path is absent.
- Preserve the Phase 133 `OPEN_THREATS` stop and the historical-only acceptance boundary.

## Deviations from Plan

Three narrow corrections were needed to make the planned local graph pass against the reconciled checkout:

- The Nightly collector had a strict raw workflow digest that also needed to follow the reviewed Nightly bytes.
- The remote fixture depended on an active exception that had since been resolved; it now creates its own expired exception fixture.
- The acceptance fixture referenced a preflight path moved to `.planning/evidence/runtime/`; the consumer now uses that artifact as a fallback while remaining compatible with clean checkouts that retain the tracked historical path.

These changes affect local identity and fixture wiring only. No current remote state was collected and no live acceptance was replayed.

The first hosted candidate CI run exposed two omissions in the Plan 09 delivery. The existing FFmpeg workflow test still required a token even though the reviewed installer downloads a fixed public asset, verifies its pinned SHA-256, and never reads GitHub credentials; the test now enforces the reviewed no-token boundary. The live-residue scanner also found three unclassified Phase 139 planning-path references in the new workflow and acceptance scripts; they are now recorded as contract entries with reasons. The two focused install-smoke suites pass (56 tests), and the live-residue scan passes with no pending entries. The hosted retry is the remaining candidate-delivery check; the PR remains unmerged, and current-evidence collection stays gated on protected-main delivery.

## Verification

- `git diff --check` passed.
- `bash scripts/ci/test_workflow_review_gate.sh` passed all positive and adverse cases.
- `mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/live_residue_scan_test.exs` passed 56 tests after aligning the FFmpeg assertion with the reviewed credential boundary and adding the three residue contracts.
- The live-residue scan passed across 712 tracked files, accounting for 291 hits with 258 entries and zero pending removals.
- The real workflow review gate passed for four workflow files, 13 hunks, zero unresolved findings, and five local contracts.
- `bash scripts/ci/test_exact_head_readiness.sh` passed 69 tests.
- `bash scripts/ci/test_readiness_runs.sh` passed 65 tests.
- The pinned `bash scripts/ci/test_readiness_fixtures.sh` aggregate passed; all component suites were green.
- `bash scripts/ci/test_readiness_acceptance.sh` passed 29 tests, including both preflight inventory layouts.
- Pinned Nightly/release policy tests passed 22 tests; CI summary, Nightly summary, and Nightly incident suites also passed.
- `./scripts/maintainer/automation_first_contract.sh` passed.
- The final Phase 139 code review is clean.

## Next Phase Readiness

Plan 09 is complete. The phase-level verdict remains `human_needed` until the reviewed changes pass protected-main review and the already-authorized current-evidence collection can run on an admitted subject. This plan establishes local fixture behavior only; it does not establish current remote readiness or satisfy the historical acceptance a second time. Preserve the Phase 133 `OPEN_THREATS` stop. The candidate is for CI review only and has not been merged.

---
*Phase: 139-exact-head-readiness-closure*
*Completed: 2026-11-17*
