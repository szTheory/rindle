---
phase: 107-reliability-security-dx-hardening
plan: 04
subsystem: infra
tags: [playwright, docker, ci, brandbook, wcag, contrast, accessibility, e2e]

# Dependency graph
requires:
  - phase: 107-02
    provides: SHA-pinned ci.yml with settled surface (sole required check CI Summary / job ci-summary; name CI unchanged)
provides:
  - Shared WCAG_AA_NORMAL = 4.5 contrast constant (brandbook/src/contrast-constants.mjs) consumed by both the runtime polish gate and the token-pair gates
  - Faithful local E2E repro (scripts/ci/e2e_local.sh) running the SAME pinned mcr.microsoft.com/playwright:v1.57.0-noble container as CI
  - ci.yml adoption-demo-e2e lane moved onto the pinned v1.57.0-noble browser image (PLAYWRIGHT_IMAGE env single-sources the tag)
  - examples/adoption_demo @playwright/test pinned exact 1.57.0 (caret dropped), matching the container tag
affects: [milestone-completion, brandbook-tooling, ci-cd-performance]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-source WCAG threshold: one exported constant feeds both contrast gates (no per-gate re-derivation / drift)"
    - "Same-image-both-sides E2E: CI lane and local wrapper share one immutable pinned Playwright container tag (faithful repro by construction)"
    - "Exact npm pin == container tag: @playwright/test 1.57.0 matches v1.57.0-noble (no caret float, no MAJOR bump)"

key-files:
  created:
    - brandbook/src/contrast-constants.mjs
    - scripts/ci/e2e_local.sh
  modified:
    - brandbook/src/admin-gallery-check.mjs
    - brandbook/src/admin-design-system-data.mjs
    - brandbook/src/cohort-design-system-data.mjs
    - .github/workflows/ci.yml
    - examples/adoption_demo/package.json
    - examples/adoption_demo/package-lock.json

key-decisions:
  - "Canonical contrast threshold = WCAG_AA_NORMAL = 4.5 (WCAG 2.x AA, normal-size text); non-AA-normal floors (min: 3 large-text/non-text, min: 2.7 cohort decorative) keep their own per-pair values"
  - "Constant-extraction only — no threshold change: contrast 47/47, admin 58/58, cohort 28/28 pass counts byte-identical"
  - "Min: 4.5 literals live in the data modules (admin-design-system-data.mjs / cohort-design-system-data.mjs), not the gate runners — base contrast.mjs reads min from tokens.json (data, no JS literal); edited the data modules instead of contrast.mjs/cohort-contrast.mjs"
  - "CI e2e lane invokes the shared scripts/ci/e2e_local.sh so CI and local run byte-identical browser execution; PLAYWRIGHT_IMAGE env in ci.yml single-sources the v1.57.0-noble tag"
  - "Networking: Phoenix on host + browser-in-container over --network=host (container localhost == host server), reuse-server mode so the container skips the mix-based global-setup it cannot run"

patterns-established:
  - "WCAG_AA_NORMAL shared constant: the canonical 4.5:1 AA-normal threshold imported wherever a 4.5 gate exists"
  - "e2e_local.sh / ci.yml share one pinned Playwright image tag via PLAYWRIGHT_IMAGE env"

requirements-completed: [HARD-04]

# Metrics
duration: 5min
completed: 2026-06-22
status: complete
---

# Phase 107 Plan 04: Faithful Linux-Chromium Repro + Reconciled Contrast Threshold Summary

**Pinned `mcr.microsoft.com/playwright:v1.57.0-noble` E2E container shared by CI and a new `scripts/ci/e2e_local.sh`, exact `@playwright/test` 1.57.0 npm pin, and a single shared `WCAG_AA_NORMAL = 4.5` constant feeding both brandbook contrast gates — pass counts byte-identical.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-22T20:11:03Z
- **Completed:** 2026-06-22T20:16:06Z
- **Tasks:** 2
- **Files modified:** 8 (2 created, 6 modified)

## Accomplishments
- Extracted the WCAG-AA 4.5:1 threshold into one shared `brandbook/src/contrast-constants.mjs` (`WCAG_AA_NORMAL = 4.5`), imported by the runtime polish gate (`admin-gallery-check.mjs`) AND the token-pair data tables — killing threshold drift (D-12) with zero change to computed ratios or pass counts.
- Landed a faithful Linux-Chromium local repro (`scripts/ci/e2e_local.sh`) that runs the browser inside the SAME pinned `v1.57.0-noble` container CI uses — same image both sides (D-10).
- Moved the `adoption-demo-e2e` CI lane onto the pinned image via the shared wrapper; lane stays `needs: [quality, optional-dependencies]`, push:main/nightly-only, and is NOT a PR-required check.
- Pinned `@playwright/test` exact `1.57.0` (dropped the caret) so the npm version matches the container tag exactly (D-11); regenerated the demo lockfile to 1.57.0.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract shared WCAG_AA_NORMAL constant + wire both gates** - `7a03796` (refactor)
2. **Task 2: Pin Playwright container + exact npm version, both CI lane and e2e_local.sh** - `649e041` (ci)

## Files Created/Modified
- `brandbook/src/contrast-constants.mjs` - NEW: exports `WCAG_AA_NORMAL = 4.5` (WCAG 2.x AA normal-text minimum).
- `brandbook/src/admin-gallery-check.mjs` - Imports `WCAG_AA_NORMAL`; `ratio < 4.5` -> `ratio < WCAG_AA_NORMAL`.
- `brandbook/src/admin-design-system-data.mjs` - Imports `WCAG_AA_NORMAL`; all `min: 4.5` literals -> `min: WCAG_AA_NORMAL` (34 refs); `min: 3` non-text/large-text pairs untouched.
- `brandbook/src/cohort-design-system-data.mjs` - Imports `WCAG_AA_NORMAL`; `min: 4.5` literals -> `min: WCAG_AA_NORMAL` (19 refs); `min: 3` focus + `min: 2.7`/`min: 3` decorative pairs untouched.
- `scripts/ci/e2e_local.sh` - NEW (executable): host Phoenix bring-up + browser-in-container against the pinned `v1.57.0-noble` image over `--network=host`, reuse-server mode.
- `.github/workflows/ci.yml` - `adoption-demo-e2e` lane: added `PLAYWRIGHT_IMAGE: mcr.microsoft.com/playwright:v1.57.0-noble` env; swapped the browser step to `bash scripts/ci/e2e_local.sh`. Only the e2e lane changed; no `uses:`/SHA-pin lines touched.
- `examples/adoption_demo/package.json` - `@playwright/test` `^1.57.0` -> `1.57.0`.
- `examples/adoption_demo/package-lock.json` - regenerated; resolves `@playwright/test` and `playwright` to exact `1.57.0`.

## Canonical Thresholds Chosen + Reconciliation Summary
- **`WCAG_AA_NORMAL = 4.5`** — the WCAG 2.x AA minimum for normal-size text. This is the single value that was duplicated across the runtime gate (`admin-gallery-check.mjs:283` bare `ratio < 4.5`) and the dozens of `min: 4.5` token-pair literals.
- **Non-AA-normal floors deliberately NOT unified** (Pitfall 4): `min: 3` (large-text / non-text affordances: borders, focus rings, status markers, skeletons) and the cohort `min: 2.7` decorative-faint floor keep their own literal values. Only AA-normal `4.5` pairs received the shared import.
- **No real accessibility gate was weakened.** This is a pure constant-extraction — every computed ratio and every pass count is unchanged.

## Contrast-Gate Re-run Result
Baseline == post-refactor (byte-identical):
- `node brandbook/src/contrast.mjs` -> `47/47 pairs pass`
- `node brandbook/src/admin-contrast.mjs` -> `admin contrast: 58/58 pairs pass`
- `node brandbook/src/cohort-contrast.mjs` -> `cohort contrast: 28/28 pairs pass`
- `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` -> **24 tests, 0 failures** (asserted `N/N pairs pass` strings + `CONSOLE_CONTRAST_PAIRS` stay green).

## e2e_local.sh Validation Result
- `bash -n scripts/ci/e2e_local.sh` -> OK (parses).
- References `mcr.microsoft.com/playwright:v1.57.0-noble` (2 occurrences, via `PLAYWRIGHT_IMAGE` default + docker run).
- Executable bit set (`100755`); 78 lines (>= 20 required).
- Full container E2E NOT run locally (plan asked for script validity + dry checks only). One `shellcheck` SC1007 warning on `PHX_SERVER= mix run ...` is a false positive — it is the intentional clear-env-for-one-command idiom copied verbatim from the `adoption_demo_e2e.sh` analog.

## Playwright Pin Applied
- `examples/adoption_demo/package.json`: `"@playwright/test": "1.57.0"` (no caret).
- Lockfile resolves `@playwright/test` and `playwright` to exact `1.57.0`.
- Matches container tag `v1.57.0-noble`; no action/browser MAJOR bump.

## Verify-Gate Outcomes
- Task 1 automated verify: PASS (3 gates byte-identical + validation test green).
- Task 2 automated verify: PASS (`bash -n` + image refs in both files + exact npm pin grep).
- Plan-level: no `lib/` change (0 files); `adoption-demo-e2e` absent from `scripts/setup_branch_protection.sh`; `name: CI` and `CI Summary` required check unchanged; ci.yml valid YAML; 107-02 SHA pins preserved (diff scoped to the e2e lane only).

## Decisions Made
See `key-decisions` frontmatter. Headline: canonical `WCAG_AA_NORMAL = 4.5`; non-AA-normal floors preserved; data modules (not the gate runners) carry the literals so they were the edit target; CI and local share one pinned image tag via the `PLAYWRIGHT_IMAGE` env + shared wrapper.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Edited the contrast DATA modules instead of the gate-runner modules listed in `files_modified`**
- **Found during:** Task 1 (contrast-constant extraction)
- **Issue:** The plan's `files_modified` named `brandbook/src/contrast.mjs` and `brandbook/src/cohort-contrast.mjs`, but those are gate *runners*: `contrast.mjs` reads `min` from `brandbook/tokens/tokens.json` (JSON data — cannot import a JS constant and has no inline `4.5` literal), and `cohort-contrast.mjs` reads its pairs from `brandbook/src/cohort-design-system-data.mjs`. The actual `min: 4.5` literals live in the DATA modules `admin-design-system-data.mjs` and `cohort-design-system-data.mjs`. The plan's own `<action>` text explicitly says "import the constant at the top of each data module," so the data modules are the correct, intended edit target.
- **Fix:** Imported `WCAG_AA_NORMAL` into `admin-design-system-data.mjs` and `cohort-design-system-data.mjs` and swapped only their AA-normal `min: 4.5` literals. Left `contrast.mjs` / `cohort-contrast.mjs` runners unchanged (no literal to swap; `contrast.mjs`'s tokens.json source is data, out of scope for a JS import).
- **Files modified:** brandbook/src/admin-design-system-data.mjs, brandbook/src/cohort-design-system-data.mjs (in place of contrast.mjs/cohort-contrast.mjs)
- **Verification:** All three gates print byte-identical pass counts; validation test green.
- **Committed in:** `7a03796` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking — file-target reconciliation, no behavior/threshold change).
**Impact on plan:** None to outcomes. The deviation realigns the edit onto the files that actually hold the literals (which the plan's action text already named); the threshold value, computed ratios, and pass counts are unchanged. No scope creep, no `lib/` change.

## Issues Encountered
- The base `contrast.mjs` gate sources its `min` thresholds from `brandbook/tokens/tokens.json` (a data file), not a JS literal — so it (correctly) received no edit. Documented as the deviation above.
- One out-of-scope pre-existing full-suite failure is known at `test/install_smoke/release_docs_parity_test.exs:319` (per execution context). It is unrelated to this plan, was NOT touched, and did NOT surface in this plan's targeted gates (brandbook validation test + contrast gates all green). Reported distinctly; left for its own track.

## User Setup Required
None - no external service configuration required. (`scripts/ci/e2e_local.sh` requires a local Docker daemon to run the container, but no account/secret setup.)

## Next Phase Readiness
- HARD-04 complete; this is the final plan of phase 107 (and the v1.20 milestone). All four phase requirements (HARD-01..04) now have completed plans.
- Milestone-completion state and milestone archival were intentionally NOT touched here — the execute-phase orchestrator runs phase verification next, then `/gsd-complete-milestone`.
- No blockers introduced.

## Self-Check: PASSED
- Created files exist on disk: `brandbook/src/contrast-constants.mjs`, `scripts/ci/e2e_local.sh`, `107-04-SUMMARY.md`.
- Task commits exist: `7a03796` (Task 1), `649e041` (Task 2).

---
*Phase: 107-reliability-security-dx-hardening*
*Completed: 2026-06-22*
