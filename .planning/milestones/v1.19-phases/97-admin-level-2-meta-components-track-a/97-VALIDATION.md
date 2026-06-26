---
phase: 97
slug: admin-level-2-meta-components-track-a
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-17
---

# Phase 97 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from
> `97-RESEARCH.md` § Validation Architecture. Every success criterion maps to a deterministic,
> merge-blocking check — no human visual review.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node assertion scripts (`admin-css-build`/`admin-contrast`/`admin-gallery-check`), Playwright Chromium (`adoption-demo-e2e` lane), ExUnit/Mix |
| **Config file** | `examples/adoption_demo/playwright.config.js`; `test/brandbook/admin_design_system_validation_test.exs` |
| **Quick run command** | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` |
| **Full suite command** | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs && node brandbook/src/admin-gallery-check.mjs && node brandbook/src/sync-admin-css.mjs && cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css && mix test --include integration test/brandbook/admin_design_system_validation_test.exs` |
| **Phase gate (adds browser proof)** | full suite **plus** the merge-blocking `adoption-demo-e2e` Playwright lane (`admin-screenshots.spec.js`) green — this is where `assertConsistentRhythm` / `assertNoHorizontalScroll` / `assertNoInteractiveOverlap` run over real pages |
| **Estimated runtime** | ~90s scripts; +Playwright lane |

---

## Sampling Rate

- **After every task commit:** `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` (sub-second; catches selector/parity/contrast regressions immediately).
- **After every plan wave:** full suite command (adds gallery browser proof + sync + ExUnit).
- **Before `/gsd:verify-work`:** full suite **and** the `adoption-demo-e2e` lane must be green.
- **Max feedback latency:** ~90 seconds (scripts).

---

## Success Criterion → Deterministic Merge-Blocking Check

| SC (ROADMAP) | Behavior proven | Check / Command | Pass signal |
|----|----------|-----------------|-------|
| **SC1** — meta-components are composed units built only from Level-1 primitives | each `META_COMPONENTS` slug renders; composed only of `rindle-admin-*` classes; no unknown-class leakage | `node brandbook/src/admin-gallery-check.mjs` (`assertMetaUnits` + no-leakage scan) + `requiredMetaSelectors` self-check in `admin-css-build.mjs` | gallery check exits 0; generator self-check passes |
| **SC2** — rhythm / overlap / no-h-scroll consistency | intra-unit gaps on the 4px grid (∪ 12, 44); unit root has no horizontal overflow (sticky marker excepted); no interactive-sibling overlap | `assertConsistentRhythm` + `assertNoHorizontalScroll` + `assertNoInteractiveOverlap` (`OVERLAP_ENFORCED=true`) via `assertAdminPolish` in the `adoption-demo-e2e` lane | lane green; zero offenders aggregated per state |
| **SC3** — each meta-component appears in the gallery as a unit | one labeled `data-rindle-admin-meta="{slug}"` panel per meta, visible per theme, screenshotted | `admin-gallery-check.mjs` visibility + screenshot assertions; ExUnit pins screenshot count | `gallery check passed - {M} screenshots written`; ExUnit green |
| (seal) shipped-artifact parity | generated CSS == shipped package CSS, no drift | `sync-admin-css.mjs` + `cmp` + `git diff --exit-code` + `read!(priv)==read!(brandbook)` ExUnit | empty diff; ExUnit `0 failures` |

---

## Per-Task Verification Map

> Plan/task IDs are finalized by the planner. Mapping follows the research's 4-plan decomposition.

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 97-01-* | 01 data+CSS | 1 | UPLIFT-02 | unit | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` | ✅ | ⬜ pending |
| 97-02-* | 02 gallery+check | 2 | UPLIFT-02 | integration | `node brandbook/src/admin-gallery-check.mjs` | ✅ | ⬜ pending |
| 97-03-* | 03 rhythm + no-h-scroll gate (warn-only) | 3 | UPLIFT-02 | e2e | `adoption-demo-e2e` lane (`admin-polish.js`) | ❌ W0 | ⬜ pending |
| 97-04-* | 04 overlap-enforce + sync + ExUnit | 4 | UPLIFT-02 | e2e + unit | full suite + lane | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

New deterministic checks that must be authored before they can gate (no new framework install needed — all three harnesses exist):

- [ ] `assertConsistentRhythm` — new offender-returning sub-assertion in `examples/adoption_demo/e2e/support/admin-polish.js` (SC2 rhythm). Walk `[data-rindle-admin-meta]` subtrees; allowed gap/margin/padding set `{4,8,16,24,32,48,64}` ∪ `{12,44}`, 0 always valid, ±0.5px tolerance.
- [ ] `assertNoHorizontalScroll` (per-unit) — new sub-assertion in `admin-polish.js` (SC2 no-h-scroll). Per-unit `scrollWidth <= clientWidth + CLIP_TOLERANCE`; sticky-header internal-scroll region opted in by explicit container marker (no auto-detection, per D-94-07). Page-level variant already exists in `support/admin.js` — do not duplicate it.
- [ ] `assertMetaUnits` + meta no-leakage scan — new assertions in `brandbook/src/admin-gallery-check.mjs` (SC1, SC3).
- [ ] `requiredMetaSelectors` self-check block — new in `brandbook/src/admin-css-build.mjs` (SC1).
- [ ] Pinned-literal updates — keep `58/58` contrast pairs unchanged (meta adds no colors, D-97-02); bump `10 screenshots`→ new count in `admin_design_system_validation_test.exs` + the JS lists.

---

## Manual-Only Verifications

All phase behaviors have automated verification. The former human screenshot-review checkpoint
(Phase 92) was already replaced by `admin-polish.js` computed-style assertions; Phase 97 extends
that gate rather than reintroducing manual review.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all new checks (rhythm, no-h-scroll, meta-units, required-selectors)
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s (scripts)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
