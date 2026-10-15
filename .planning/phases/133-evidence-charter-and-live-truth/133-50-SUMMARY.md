---
phase: 133-evidence-charter-and-live-truth
plan: "50"
subsystem: package-authority
tags: [elixir, git, package-consumer, provenance]
requires:
  - phase: 133
    provides: exact-subject package and release authority
provides:
  - Subject-authenticated generated-app helper materialization
  - Closed and blob-verified package lifecycle helper import set
affects: [phase-133-reconciliation, independent-review-gate]
actuals:
  tokens: 3269
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [Git-subject-bound helper materialization]
key-files:
  created: []
  modified:
    - scripts/maintainer/validate_live_truth.exs
    - test/install_smoke/live_truth_parity_test.exs
key-decisions:
  - "Load the finite generated-app helper closure from the authenticated subject and verify each materialized file against its Git blob ID."
patterns-established:
  - "Subject-bound test support: lifecycle helpers are materialized privately from Git objects and reject unlisted imports, symlinks, and missing members."
requirements-completed: []
coverage:
  - id: D1
    description: "Package lifecycle proof uses helper and support bytes from the exact authenticated Git subject, even when a disposable caller checkout edits those files."
    verification:
      - kind: integration
        ref: "ASDF_ERLANG_VERSION=27.3.4.15 mix test test/install_smoke/live_truth_parity_test.exs:831 --seed 0 (38 tests, 0 failures, 1 selected)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Missing, symlinked, nested, or extra helper imports fail closed, and materialized helper bytes match their subject blobs."
    verification:
      - kind: unit
        ref: "ASDF_ERLANG_VERSION=27.3.4.15 mix test test/install_smoke/live_truth_parity_test.exs:737 test/install_smoke/live_truth_parity_test.exs:763 test/install_smoke/live_truth_parity_test.exs:780 test/install_smoke/live_truth_parity_test.exs:798 test/install_smoke/live_truth_parity_test.exs:557 --seed 0 (38 tests, 0 failures, 33 excluded)"
        status: pass
      - kind: integration
        ref: "ASDF_ERLANG_VERSION=27.3.4.15 mix test test/install_smoke/live_truth_parity_test.exs --seed 0 (38 tests, 0 failures, 1 excluded)"
        status: pass
    human_judgment: false
duration: 43min
completed: 2026-09-25
status: complete
---

# Phase 133 Plan 50: Subject-bound package lifecycle helper Summary

**Package lifecycle evidence now executes the generated-app helper closure authenticated by the exact Git subject.**

## Performance

- **Duration:** 43 min
- **Started:** 2026-09-25T16:35:45Z
- **Completed:** 2026-09-25T17:18:25Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Reconstructed the generated-app helper and seven support modules from the validated subject into a private directory, preserving their relative layout.
- Closed the helper's literal `Code.require_file` set, rejected missing and symlink members and unlisted imports, and verified each written file against its subject blob ID.
- Proved the real generated package lifecycle remains valid when a disposable caller checkout changes the helper, while nested caller edits cannot affect the materialized bytes.
- Kept the canonical Nightly receipt and all five Phase 133 requirements unchanged and pending.

## Task Commits

1. **Task 1: Prove one package lifecycle through subject-owned helper code** - `6f6f409a` (`fix`)
2. **Task 2: Seal the helper import closure and cleanup on every outcome** - `598d3734` (`fix`)

## Files Created/Modified

- `scripts/maintainer/validate_live_truth.exs` - Loads a closed, Git-blob-verified helper closure from the authenticated subject.
- `test/install_smoke/live_truth_parity_test.exs` - Covers actual consumer execution under caller mutation and fast closure boundary fixtures.

## Decisions Made

- Resolve all runtime helper code from the exact subject SHA and require the finite support-file set to match its Git tree entries before execution.

## Deviations from Plan

- The expensive lifecycle verification was run by its exact tagged test location rather than running all package-authority tests together. The test completed successfully in 771 seconds; the full live-truth parity file and focused closure fixtures also passed.

## Issues Encountered

- The initial broad package-authority run remained silent in its generated-app lifecycle. It was stopped after ten minutes, then the exact lifecycle test was rerun to completion. The local checkout pins Erlang 27.2, which is unavailable on this machine; verification used installed Erlang 27.3.4.15 as a command-scoped diagnostic override without changing `.tool-versions`.

## Self-Check: PASSED

The previous canonical receipt and all earlier Nightly identities remain untouched; no requirement was marked complete; the caller-mutation regression and automated package lifecycle passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 51 is next and can recover item-level security finding provenance. EVID-01 through EVID-04 and TRUTH-08 remain pending until the terminal automated gate.

---
*Phase: 133*
*Completed: 2026-09-25*
