---
phase: 94-foundation-token-pipeline-ci-gate-new-token-categories
plan: 04
subsystem: ci-pipeline
tags: [brandbook, design-tokens, css-pipeline, ci-gate, drift, wcag-contrast, github-actions, idempotency]

# Dependency graph
requires:
  - phase: 94-01
    provides: sync-admin-css.mjs single-mirror mechanism + drift-free baseline
  - phase: 94-03
    provides: four new token categories in tokens.json + admin generators
provides:
  - Merge-blocking brandbook-tokens CI job (PIPE-01) — regen + WCAG contrast + gallery proof + sync + git diff --exit-code
  - Closed un-gated-pipeline gap (PITFALL #6): generated CSS can no longer drift from tokens.json source
  - tokens.css regenerated to match tokens.json (Plan 03 base-generator drift corrected)
affects: [95, 96, 97, 98, 99, 100, 101, 102, token-pipeline, brandbook-tokens-ci-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Standalone Node/Playwright proof-lane job (no Elixir/Postgres/MinIO/ffmpeg, no secrets) cloning the cohort-demo-smoke skeleton + adoption-demo-e2e setup-node/upload-artifact blocks"
    - "git diff --exit-code over the regenerated tree as both the drift merge-blocker AND the idempotency anchor (a single deterministic regen suffices)"
    - "playwright-resolution anchor: npm ci in examples/adoption_demo BEFORE the generators so a missing-module error cannot masquerade as a passing gate (D-94-02)"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - brandbook/tokens/tokens.css

key-decisions:
  - "Standalone top-level brandbook-tokens job (D-94-01) — not folded into any Elixir lane; the brandbook pipeline shares no Elixir/Postgres/MinIO/ffmpeg setup"
  - "Regenerated the stale committed tokens.css (Plan 03 ran admin-css-build but not the base tokens-build) — the gate's clean-tree dry-run must exit 0, and this is exactly the drift PIPE-01 exists to catch"
  - "git diff --exit-code is tree-wide (not artifact-pinned) so it transparently covers both CSS copies + tokens.css + gallery index.html as every generator + sync write the working tree first"

requirements-completed: [PIPE-01]

# Metrics
duration: 4min
completed: 2026-06-15
---

# Phase 94 Plan 04: Merge-Blocking brandbook-tokens CI Gate Summary

**Stood up the standalone `brandbook-tokens` CI job (PIPE-01) in `.github/workflows/ci.yml` — `needs: [quality, optional-dependencies]`, node-20, the playwright-in-adoption_demo resolution anchor, the LOCKED D-94-02 step order (tokens-build → admin-css-build → admin-contrast → admin-gallery-check → sync-admin-css → `git diff --exit-code`), the verbatim locked drift message, and a tree-wide diff merge-blocker covering both committed CSS copies + tokens.css + the gallery index.html — closing the canonical un-gated-pipeline gap (PITFALL #6). Surfaced and corrected one real pre-existing drift (Plan 03's stale `tokens.css`) so the gate lands honestly on an empty-diff tree.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-15T03:03:00Z
- **Completed:** 2026-06-15T03:06:22Z
- **Tasks:** 1
- **Files modified:** 2 (0 created, 2 modified)

## Accomplishments

- **New standalone `brandbook-tokens` job** appended as a top-level job in `.github/workflows/ci.yml` (D-94-01): cloned the `cohort-demo-smoke` skeleton (`name`, `runs-on: ubuntu-22.04`, `needs: [quality, optional-dependencies]`, `if: github.repository == 'szTheory/rindle'`, `actions/checkout@v4`) and the `adoption-demo-e2e` `setup-node@v4 / node-version: "20"` block verbatim.
- **D-94-02 LOCKED step order:** (1) `npm ci` in `examples/adoption_demo` (the `admin-gallery-check.mjs:14-15` createRequire playwright anchor; RESEARCH Pitfall 2), (2) `npx playwright install --with-deps chromium` in `examples/adoption_demo`, (3) `node brandbook/src/tokens-build.mjs`, (4) `node brandbook/src/admin-css-build.mjs`, (5) `node brandbook/src/admin-contrast.mjs` (WCAG gate), (6) `node brandbook/src/admin-gallery-check.mjs` (browser proof; internally re-runs css-build + gallery.mjs so `index.html` is regenerated), (7) `node brandbook/src/sync-admin-css.mjs` (Plan 01's sync to the shipped priv/ copy), (8) `git diff --exit-code` merge-blocker that prints the locked message via `::error::` and exits 1 on any diff.
- **Locked drift message present verbatim** (94-UI-SPEC line 206): `Generated CSS is out of sync with tokens.json. Run the brandbook generators and commit the result.`
- **Tree-wide diff coverage** (D-94-03/04): the gate covers `brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`, `brandbook/tokens/tokens.css`, and `brandbook/admin-gallery/index.html` because every generator + the sync script write the working tree before the diff.
- **Optional failure-artifact block** (`if: failure()`, `upload-artifact@v4`) uploads the gallery screenshots on failure for triage.
- **No secrets, zero new dependencies** (T-94-12/14 dispositions hold); scope fence respected — gates `rindle-admin.css` only, `cohort.css` (Phase 96) explicitly excluded.

## Task Commits

Each task was committed atomically:

1. **[Rule 1 - Bug] Regenerate stale tokens.css (Plan 03 base-generator drift)** — `de32fed` (fix)
2. **Task 1: Add the standalone brandbook-tokens job to ci.yml in the D-94-02 step order** — `2471fdd` (feat)

## Files Modified

- `.github/workflows/ci.yml` — new top-level `brandbook-tokens` job (proof-lane skeleton + node-20 + playwright-in-adoption_demo anchor + D-94-02 step order + locked drift message + tree-wide `git diff --exit-code` merge-blocker + failure-artifact upload).
- `brandbook/tokens/tokens.css` — regenerated from `tokens.json` to include Plan 03's new dark status-surface (6), elevation (4), and motion-easing (3) vars that the base `tokens-build.mjs` had not yet emitted into the committed copy.

## Decisions Made

- **Standalone job, not folded into an Elixir lane (D-94-01):** the brandbook pipeline is pure Node/Playwright and shares no Elixir/Postgres/MinIO/ffmpeg setup, so a dedicated job keeps failure attribution clean and avoids pulling unrelated services.
- **Regenerate the stale `tokens.css` rather than relax the gate:** Plan 03 ran `admin-css-build.mjs` (regenerating `rindle-admin.css`) but did not re-run the base `tokens-build.mjs`, leaving the committed `tokens.css` missing the new categories. The PIPE-01 gate's whole purpose is to catch exactly this drift, and the regenerated values trace directly to `tokens.json` raw hexes (e.g. `--rindle-dark-ready-surface: #16241E`, `--rindle-elevation-1: #161E23`). Committing the regenerated file is the honest red→green fix.
- **Tree-wide `git diff --exit-code`, not artifact-pinned:** a single tree-wide diff transparently covers all four artifacts (and any future generated file) without an enumerated path list that could silently miss a new artifact (D-94-10 idempotency anchor).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Regenerated stale committed tokens.css**
- **Found during:** Task 1 (the plan's acceptance-criterion #6 clean-tree dry-run of the full D-94-02 sequence)
- **Issue:** `node brandbook/src/tokens-build.mjs` regenerated `brandbook/tokens/tokens.css` with the four new token categories Plan 03 added to `tokens.json`, producing a non-empty `git diff`. Plan 03 regenerated `rindle-admin.css` (via `admin-css-build.mjs`) and both shipped copies but did not re-run the base `tokens-build.mjs`, so the committed `tokens.css` was stale — the gate's clean-tree dry-run (acceptance #6) would not have exited 0.
- **Fix:** Ran `tokens-build.mjs` and committed the regenerated `tokens.css`. Verified determinism (a second full regen produces a byte-identical, stable diff — not growing), confirmed the new values come straight from `tokens.json` raw hexes, and confirmed `rindle-admin.css`/priv/gallery were already clean. This is precisely the drift PIPE-01 exists to gate, so the regenerated artifact is the correct contract.
- **Files modified:** `brandbook/tokens/tokens.css`
- **Commit:** `de32fed`

## Authentication Gates

None — the job is pure Node + git + Playwright; no secrets read (T-94-14 accept disposition holds; the job declares no `HEX_API_KEY` / MinIO creds).

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`. T-94-11 (un-regenerated artifact ships) is mitigated by the tree-wide `git diff --exit-code` over both CSS copies + tokens.css + gallery index.html; T-94-13 (gallery red-herrings on missing playwright, masking drift) is mitigated by the D-94-02 ordering (npm ci + playwright in `examples/adoption_demo` BEFORE the generators); T-94-12 (CI supply-chain) holds — zero new packages, `npm ci` is lockfile-pinned to pre-existing deps. No network endpoints, auth paths, or schema changes introduced.

## Known Stubs

None — the job runs every real generator + the sync script and a live tree-wide diff; no placeholder/mock steps.

## Issues Encountered

- The local `admin-gallery-check.mjs` step required Playwright's chromium to be installed in `examples/adoption_demo` (the createRequire anchor); it resolved successfully in the dev environment, matching the CI job's step-1/2 install order.
- `tokens.css` drift (documented above as the Rule 1 fix) was the only real diff surfaced; `rindle-admin.css`, the priv/ copy, and the gallery `index.html` were already byte-clean from Plans 01+03.

## Next Phase Readiness

- The token→CSS pipeline is now **gated in CI** — the structural prerequisite the whole milestone was blocked on (STATE: "the `.mjs` token→CSS pipeline is not gated in CI today"). Phases 95–102 inherit a merge-blocking drift gate; any future hand-edit of a generated artifact, or any `tokens.json` change committed without re-running the generators, fails `brandbook-tokens`.
- Phase 96 hand-authors the `--ck-*` Cohort analogs — explicitly OUT of this gate's scope (no `cohort.css` generation/diff).
- No blockers.

## Self-Check: PASSED

- FOUND: .github/workflows/ci.yml (brandbook-tokens job)
- FOUND: brandbook/tokens/tokens.css
- FOUND: 94-04-SUMMARY.md
- FOUND commit: de32fed (Rule 1 drift fix)
- FOUND commit: 2471fdd (Task 1 — brandbook-tokens job)

---
*Phase: 94-foundation-token-pipeline-ci-gate-new-token-categories*
*Completed: 2026-06-15*
