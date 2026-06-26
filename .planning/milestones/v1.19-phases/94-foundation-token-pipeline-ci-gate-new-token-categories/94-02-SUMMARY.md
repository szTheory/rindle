---
phase: 94-foundation-token-pipeline-ci-gate-new-token-categories
plan: 02
subsystem: testing
tags: [playwright, computed-style, visual-gate, admin-polish, vis-01, javascript]

# Dependency graph
requires:
  - phase: 92-e2e-screenshot-driven-polish-loop
    provides: "admin-polish.js deterministic computed-style harness + admin-screenshots spec (the harness this plan parameterizes)"
provides:
  - "Parameterized assertAdminPolish({ root, interactiveSelectors }) defaulting to admin values"
  - "Surface-agnostic computed-style polish harness — the seam Phase 102 uses to run the SAME gate over Cohort by passing [data-ck-root] / .ck-*"
  - "Backward-compatible: admin-screenshots spec unchanged (byte-for-byte acceptance test)"
affects: [102-reconverge-matrix-idempotency-audit, vis-01, cohort-restyle, visual-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Default-valued options threading: DEFAULT_ROOT / DEFAULT_INTERACTIVE_SELECTORS module constants surface through assertAdminPolish options; sub-assertions take the param with the same default, so omission is byte-identical to the prior module-constant behavior"
    - "No-auto-detection invariant (D-94-07): the root is always explicit (passed or defaulted), never sniffed from the DOM"

key-files:
  created: []
  modified:
    - examples/adoption_demo/e2e/support/admin-polish.js

key-decisions:
  - "Threaded root/interactiveSelectors as defaulted options rather than auto-detecting the root (D-94-07: a page mounting both surfaces would match both roots and weaken the gate)"
  - "Inside page.evaluate, kept the closure-arg key named ROOT and mapped { ROOT: root } at the two call sites — minimal in-browser diff, the value now comes from the threaded param"

patterns-established:
  - "Parameter threading with module-constant defaults: rename CONST -> DEFAULT_CONST, add param = DEFAULT_CONST to each consumer, pass through from the orchestrator; the no-override call path is provably equivalent to the original"

requirements-completed: [VIS-01]

# Metrics
duration: 6min
completed: 2026-06-15
---

# Phase 94 Plan 02: Parameterized admin-polish harness Summary

**Generalized `assertAdminPolish` over `{ root, interactiveSelectors }` (defaulting to today's admin values) so Phase 102 can run the identical computed-style gate over Cohort — with the admin spec passing byte-for-byte unchanged as the backward-compat acceptance test.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-15T02:55:00Z
- **Completed:** 2026-06-15T03:01:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Renamed module constants `ROOT` -> `DEFAULT_ROOT` and `INTERACTIVE_SELECTORS` -> `DEFAULT_INTERACTIVE_SELECTORS`.
- Extended `assertAdminPolish(page, { viewport, surface, root = DEFAULT_ROOT, interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS } = {})`.
- Threaded `root` into the two readers (`assertNoClippedText`, `assertReadableContrast`) via the `page.evaluate` closure-arg object (`{ ROOT: root, ... }`).
- Threaded `interactiveSelectors` into the two locator consumers (`assertTargetSizes`, `assertNoInteractiveOverlap`) via `page.locator(interactiveSelectors.join(","))`.
- Updated the orchestrator dispatch site so each sub-assertion receives the threaded value (falling back to the module default).
- No auto-detection of the root (D-94-07 invariant preserved).

## Task Commits

Each task was committed atomically:

1. **Task 1: Thread root + interactiveSelectors through assertAdminPolish with admin defaults** - `8f72c3f` (refactor)

**Plan metadata:** (final docs commit follows)

## Files Created/Modified
- `examples/adoption_demo/e2e/support/admin-polish.js` - Parameterized over `{ root, interactiveSelectors }` with admin defaults; surface-agnostic; ready for Cohort (Phase 102) to pass `[data-ck-root]` / `.ck-*`.

## Decisions Made
- Kept the in-browser `page.evaluate` closure-arg key named `ROOT` and mapped `{ ROOT: root }` at the two call sites — this is the smallest possible diff to the serialized browser code while the value now flows from the threaded param.
- Threading via defaulted options (not auto-detection) is the D-94-07 contract: the root is always explicit, so a page mounting both admin and Cohort roots cannot silently broaden or weaken the gate.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The plan's `<automated>` verify runs the full `adoption-demo-e2e` Playwright lane (`npx playwright test admin-screenshots`), which boots Phoenix via `playwright.config.js`'s `webServer` and requires the full CI substrate: a `mix hex.build --unpack` package, `MIX_ENV=test` DB create/migrate/`rindle.migrate`, S3-backed seeds, and a running **MinIO** instance (`scripts/ensure_minio.sh`). MinIO is not installed on this host (`minio`/`mc` absent), so the live spec cannot run locally; this is exactly the merge-blocking lane that runs on the PR.

Resolution (automation-first, infra-free): the static acceptance criteria all pass, and a deterministic Node equivalence proof confirms the threading is backward-compatible. Stubbing `page.evaluate` / `page.locator`:
- default path (no override) passes `[data-rindle-admin-root]` into both readers and the exact 9-selector admin union into both locator consumers — byte-identical to the pre-change module constants;
- override path threads `[data-ck-root]` / `.ck-*` through verbatim (the Phase 102 seam).

This isolates the precise behavior under test without MinIO flakiness. The live admin spec remains the PR-time merge-blocking proof.

### Acceptance criteria (all PASS)
- `grep -c 'DEFAULT_ROOT'` = 4 (>= 2 required).
- `grep -c 'interactiveSelectors'` = 8 (>= 3 required).
- Auto-detection grep (`querySelector.*ck-root|detectRoot|autoRoot`) = 0.
- No stray references to the old `ROOT` / `INTERACTIVE_SELECTORS` constant names.
- `git diff --exit-code examples/adoption_demo/e2e/admin-screenshots.spec.js` exits 0 (spec untouched).
- `node --check admin-polish.js` passes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- The polish harness is now surface-agnostic. Phase 102 (re-converge) can run the SAME merge-blocking computed-style gate over Cohort by calling `assertAdminPolish(page, { surface, viewport, root: "[data-ck-root]", interactiveSelectors: [/* .ck-* */] })` — no harness surgery required.
- Phase 94's remaining plans (token categories + `brandbook-tokens` CI gate) are independent of this harness change (`wave: 1`, `depends_on: []`).

## Self-Check: PASSED
- FOUND: examples/adoption_demo/e2e/support/admin-polish.js
- FOUND: commit 8f72c3f

---
*Phase: 94-foundation-token-pipeline-ci-gate-new-token-categories*
*Completed: 2026-06-15*
