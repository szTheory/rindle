---
phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
plan: 02
subsystem: testing
tags: [playwright, visual-gate, admin-polish, cohort, focus-contract]

requires:
  - phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
    provides: strict-safe admin root helper and preserved admin visual matrix from Plan 01
  - phase: 96-cohort-component-layer-dark-reduced-motion-contract-track-b
    provides: Cohort `[data-ck-root]`, `--ck-focus`, and `.ck-*` focus contract
  - phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
    provides: admin-only Phase 98 computed-style backstops
provides:
  - Surface-aware `assertAdminPolish` focus contract option with admin defaults
  - Cohort-compatible focus token resolution from the explicit selected root
  - Root-scoped interactive offender collection for target, focus, and overlap checks
  - Admin-only backstop gating that leaves Cohort hard-fail calls free of admin layout checks
affects: [Phase 102, VIS-01, VIS-02, adoption-demo-e2e, cohort-pages, cohort-styleguide]

tech-stack:
  added: []
  patterns:
    - Explicit surface contracts for shared Playwright visual helpers
    - Admin-only backstops behind an opt-in/auto-admin option set

key-files:
  created:
    - examples/adoption_demo/e2e/support/admin-polish.test.js
    - .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-02-SUMMARY.md
  modified:
    - examples/adoption_demo/e2e/support/admin-polish.js

key-decisions:
  - "Focus contracts now resolve CSS custom properties from the explicit surface root first; documentElement fallback remains limited to the default admin contract."
  - "Admin dialog-inert backstops default on only for the default admin root; Cohort callers can opt into admin backstops explicitly but do not inherit them."

patterns-established:
  - "Shared visual-gate options carry root, interactive selectors, focusContract, and adminBackstops instead of branching on detected surfaces."
  - "Cheap Node tests cover browser-helper option plumbing without requiring a running Phoenix server."

requirements-completed: [VIS-01, VIS-02]

duration: 7 min
completed: 2026-06-19
status: complete
---

# Phase 102 Plan 02: Surface-Aware Polish Gate Summary

**The single `admin-polish.js` gate now accepts explicit surface focus contracts and keeps admin-only backstops out of Cohort root-scoped runs.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-19T15:21:51Z
- **Completed:** 2026-06-19T15:29:18Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `focusContract` support with admin-compatible defaults for `--rindle-focus-width`, `--rindle-focus-ring`, and `--rindle-focus-offset`.
- Let Cohort callers pass `{ width: "2px", color: "--ck-focus", offset: "2px" }`, resolving token values from `[data-ck-root]`.
- Scoped target-size, focus, overlap, and outline offender collection to the selected root.
- Added `adminBackstops` handling so the dialog-inert Phase 98 check stays enabled by default for admin, but disabled by default for Cohort.
- Added Node regression coverage for Cohort focus contracts, admin-backstop defaults, and root-scoped interactive selectors.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: explicit focus contract tests** - `ae226d8` (test)
2. **Task 1 GREEN: surface focus contract support** - `2ca56f7` (feat)
3. **Task 2: root-scoped checks and admin-only backstops** - `be40a14` (fix)

**Plan metadata:** recorded in the final docs commit for this SUMMARY.

## Files Created/Modified

- `examples/adoption_demo/e2e/support/admin-polish.test.js` - Node tests for focus-contract and surface-option behavior.
- `examples/adoption_demo/e2e/support/admin-polish.js` - Shared computed-style gate now supports explicit focus contracts, root-scoped interactive checks, and admin-only backstop defaults.
- `.planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-02-SUMMARY.md` - This execution summary.

## Verification

- PASS: `node --test examples/adoption_demo/e2e/support/admin-polish.test.js` (4 tests, 0 failures)
- PASS: `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js`
- PASS: `node -e "const mod=require('./examples/adoption_demo/e2e/support/admin-polish.js'); for (const k of ['assertAdminPolish','DEFAULT_ROOT','DEFAULT_INTERACTIVE_SELECTORS','DEFAULT_FOCUS_CONTRACT','DEFAULT_ADMIN_BACKSTOPS','normalizeFocusContract','normalizeAdminBackstops']) { if (!(k in mod)) throw new Error('missing '+k); }"`
- PASS: source assertion for `assertTwoPaneBand`, `assertDialogInert`, and `focusContract`
- PASS: `cd examples/adoption_demo && mix precommit` (33 tests, 0 failures; existing Mox warnings emitted)

## Decisions Made

- Kept the default admin call signature backward-compatible: existing callers can keep using `assertAdminPolish(page, { viewport, surface })`.
- Used root-first CSS variable resolution for focus contracts so Cohort dark/light root state owns `--ck-focus`.
- Limited `documentElement` fallback to the default admin focus contract, preventing Cohort from silently reading admin variables.
- Modeled Phase 98 admin backstops as an explicit option set instead of surface detection or a second gate.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- `mix precommit` formatted unrelated adoption-demo Elixir files even though this plan changed only JavaScript helper code. Those formatter edits were reverted by path before close-out.
- `mix precommit` still emits the known test-environment Mox warnings from `AdoptionDemo.MuxCassette`, but exited 0 with 33 tests passing.

## Known Stubs

None. Stub scan over the created/modified files found no TODO/FIXME/placeholders or hardcoded empty UI data.

## Authentication Gates

None.

## Threat Flags

None. The changes do not introduce network endpoints, auth paths, file access patterns, schema changes, or new trust boundaries beyond the plan's visual-helper surface.

## Next Phase Readiness

Ready for `102-03`: Cohort callers can now pass an explicit focus contract and run the shared gate without inheriting admin dialog/layout backstops.

## Self-Check: PASSED

- FOUND: `examples/adoption_demo/e2e/support/admin-polish.test.js`
- FOUND: `examples/adoption_demo/e2e/support/admin-polish.js`
- FOUND: `.planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-02-SUMMARY.md`
- FOUND commits: `ae226d8`, `2ca56f7`, `be40a14`

---
*Phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit*
*Completed: 2026-06-19*
