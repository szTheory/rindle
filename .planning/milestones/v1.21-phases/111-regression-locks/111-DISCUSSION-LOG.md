# Phase 111: Regression locks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 111-regression-locks
**Areas discussed:** Test placement, Dedupe helper API, LOCK-04 enforcement

> The *what* was research-locked by `.planning/research/v1.21-REGRESSION-LOCKS.md`
> (decide-by-default) + the Phase 111 ROADMAP success criteria. Only the three open *HOW*
> questions below were put to the user; all resolved to the stronger / research-default option.

---

## Test placement (LOCK-01 / LOCK-04 / LOCK-05)

| Option | Description | Selected |
|--------|-------------|----------|
| Split by scope (research default) | LOCK-01 → `test/install_smoke/` family; LOCK-04 + LOCK-05 → standalone `test/` root modules | ✓ |
| All in install_smoke/ family | All three under `test/install_smoke/` for locality | |
| All at test/ root | All three as top-level cross-cutting `Rindle.*Test` modules | |

**User's choice:** Split by scope (research default)
**Notes:** LOCK-01 is an install-smoke-script fact (sits by `package_metadata_test.exs`); LOCK-04/05
scan trees beyond install_smoke, so they live at `test/` root.

---

## Dedupe helper API (LOCK-03)

| Option | Description | Selected |
|--------|-------------|----------|
| `focusVisibly(page, locator)` (research default) | High-level helper: presses Tab then runs `locator.evaluate(el => el.focus({focusVisible:true}))`; removes every raw `focusVisible` call from sites | ✓ |
| `enterKeyboardModality(page)` | Low-level helper: presses Tab only; call sites keep their own `focus({focusVisible:true})` | |

**User's choice:** `focusVisibly(page, locator)` (research default)
**Notes:** Removing all raw `focus({focusVisible:true})` from call sites is the strongest guarantee
and rides the already-load-bearing `adoptionRequire(...admin-polish.js)` import in the gallery.

---

## LOCK-04 enforcement

| Option | Description | Selected |
|--------|-------------|----------|
| Helper presses Tab + ban raw calls outside it | Assert the shared helper Tab-presses AND no harness calls `focus({focusVisible:true})` outside it — forces every site through the helper, catches a future 4th copy | ✓ |
| Per-file presence check (research B1) | Any file with `focusVisible:true` must also contain `keyboard.press('Tab')` — simpler, but post-dedupe mostly guards the helper itself | |

**User's choice:** Helper presses Tab + ban raw calls outside it
**Notes:** Reinforces the `focusVisibly` dedupe — the combination eliminates the "duplicated in two
places at once" footgun that produced the original flake. Keep the anti-vacuous-pass guard
(`assert files != []`, key off `focusVisible:true` presence).

---

## Claude's Discretion

- LOCK-01 host file (fold into `package_metadata_test.exs` vs new `install_smoke_preflight_test.exs`)
  and assertion mechanics — match house idiom.
- LOCK-02 step name + exact position within the `package-consumer` job (before the smoke).
- The shared helper's internal `.catch(() => {})` on the `Tab` press — match existing call sites.

## Deferred Ideas

- B2 Playwright unit test of the `focusVisibly` helper — now feasible post-dedupe but out of scope
  for v1.21.
- `CountingFailingTxnRepo` `behaviour_info(:callbacks)` completeness lock — Phase 110 / Area 4 owns it.
