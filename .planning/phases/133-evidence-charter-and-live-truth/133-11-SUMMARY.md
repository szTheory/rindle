---
phase: 133-evidence-charter-and-live-truth
plan: 11
subsystem: ci-evidence-safety
tags: [elixir, exunit, bash, dialyzer, plt, git-preimage, nyquist]

requires:
  - phase: 133-10
    provides: Exact supported-toolchain and cache-identity receipt validation
provides:
  - Immutable reconciliation of Plans 01-10 history with 27 exact pending verification pairs for Plans 11-17
  - Repository-owned physical containment gate for every Nightly PLT reset
  - Non-destructive traversal, root, external-path, and symlink-escape regression matrix
affects: [133-12, 133-13, 133-14, 133-15, 133-16, 133-17, EVID-02, TRUTH-08]

actuals:
  tokens: 14872
  tasks: 3
  commits: 6

tech-stack:
  added: []
  patterns:
    - Immutable Git commit/blob/byte-length/SHA-256 preimage validation
    - Exact-text XML-like verification-pair reconciliation
    - Lexical allowlisting plus physical-path containment before destructive shell work

key-files:
  created:
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - test/install_smoke/phase_133_reconciliation_test.exs
  modified:
    - .planning/ROADMAP.md
    - .planning/phases/133-evidence-charter-and-live-truth/133-VALIDATION.md
    - scripts/ci/run_nightly_dialyzer.sh
    - scripts/ci/test_nightly_dialyzer.sh

key-decisions:
  - "Bind the Plans 01-10 validation preimage to commit 6e0d961, blob 59eb44c, 13,899 bytes, and SHA-256 c3df0a57 before parsing any pending addendum."
  - "Reject every caller-supplied PLT_DIR and derive the sole lexical target as repository-owned priv/plts."
  - "Run the same physical containment gate before either Dialyzer mode invokes Mix and again immediately before recursive reset."

patterns-established:
  - "Pending evidence records: source-scoped pair ordinals preserve raw trimmed command and failure-direction bytes without entity or whitespace normalization."
  - "Destructive path safety: exact lexical authority and physical descendant checks both pass before reset."

requirements-completed: [EVID-02, TRUTH-08]

coverage:
  - id: D1
    description: Historical validation remains byte-identical while all 27 Plans 11-17 verification pairs are represented exactly once as pending.
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: mix test test/install_smoke/phase_133_reconciliation_test.exs
        status: pass
      - kind: other
        ref: MIX_ENV=test mix run --no-deps-check --no-compile scripts/maintainer/validate_phase_133_reconciliation.exs --root .
        status: pass
      - kind: other
        ref: ./scripts/maintainer/automation_first_contract.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Fresh and exact Old PLT recovery reset only the approved repository-owned physical priv/plts child.
    requirement: EVID-02
    verification:
      - kind: integration
        ref: bash scripts/ci/test_nightly_dialyzer.sh
        status: pass
    human_judgment: false
  - id: D3
    description: Empty, dot, root, traversal, external absolute, and symlink escape paths fail before deletion or analysis.
    requirement: EVID-02
    verification:
      - kind: integration
        ref: bash scripts/ci/test_nightly_dialyzer.sh
        status: pass
      - kind: other
        ref: shellcheck -S warning scripts/ci/run_nightly_dialyzer.sh scripts/ci/test_nightly_dialyzer.sh
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 11: Evidence Reconciliation and Safe PLT Reset Summary

**Immutable Phase 133 validation reconciliation plus a physically contained Nightly PLT reset boundary with non-destructive escape proofs**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-10T20:30:36Z
- **Completed:** 2026-09-10T20:43:01Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Preserved the entire committed Plans 01-10 validation preimage while appending 27 exact, source-ordinal pending mappings for every runnable Plans 11-17 verification pair.
- Reconciled the active roadmap to ten historical completions and seven individually pending gap-closure plans before implementation began.
- Confined fresh and restored Old PLT recovery resets to the physical repository-owned `priv/plts` directory and rejected all named escape families before Mix or deletion.

## Task Commits

Each TDD task was committed through a fail-first test followed by its verified implementation:

1. **Task 1: Reconcile pending Phase 133 planning truth before implementation**
   - `eda1f2b` — failing reconciliation contract
   - `37254ca` — validator, pending addendum, and roadmap reconciliation
2. **Task 2: Prove one approved physical PLT reset end to end**
   - `be25a5d` — failing copied-repository reset case
   - `9c2c16e` — repository-derived physical PLT containment
3. **Task 3: Reject traversal, root, external, and symlink escape paths without deletion**
   - `ffe3460` — failing restored symlink/escape matrix
   - `b19e29e` — pre-analysis containment for both modes

## Files Created/Modified

- `scripts/maintainer/validate_phase_133_reconciliation.exs` — validates immutable historical bytes, fail-closed plan markup, exact pending mappings, and temporal roadmap truth.
- `test/install_smoke/phase_133_reconciliation_test.exs` — 19 positive and adversarial isolated-Git fixtures.
- `.planning/phases/133-evidence-charter-and-live-truth/133-VALIDATION.md` — append-only pending addendum for 27 verification pairs.
- `.planning/ROADMAP.md` — historical 01-10 completions plus individually pending 11-17 plans.
- `scripts/ci/run_nightly_dialyzer.sh` — sole lexical PLT authority and shared physical containment gate.
- `scripts/ci/test_nightly_dialyzer.sh` — 34-case approved/reset/escape and preserved-behavior matrix.

## Decisions Made

- Used immutable Git object identity and byte equality as the historical boundary instead of treating a digest alone as sufficient authority.
- Kept exact command and failure-direction bodies in delimiter records so equal commands from distinct source scopes remain independently attributable.
- Rejected the `PLT_DIR` override entirely; test injection now copies the runner under a temporary repository rather than weakening production path authority.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository pins Elixir 1.17.3/OTP 27, which is not installed in the current asdf environment. Focused ExUnit and validator commands ran successfully on the already-installed diagnostic Elixir 1.19.5/OTP 28.4.1 toolchain; supported-cell authority remains owned by the exact Nightly evidence path and was not redefined.

## Known Stubs

None. The empty shell locals found by the stub scan are initialized runtime variables, not UI/data placeholders.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 12-17 now have exact pending Nyquist mappings and can execute without altering the Plans 01-10 validation preimage.
- Plan 12 can build on a safe Nightly runner; the remaining fresh exact-subject receipt work stays pending through Plan 17.

## Self-Check: PASSED

- All six created/modified deliverable files exist.
- All six TDD task commits resolve as Git commits.
- Coverage classification reports 3/3 deliverables automatically covered with passing evidence.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
