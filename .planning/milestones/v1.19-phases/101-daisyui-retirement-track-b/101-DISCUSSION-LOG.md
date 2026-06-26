# Phase 101: daisyUI Retirement [Track B] - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-18
**Phase:** 101-daisyui-retirement-track-b
**Mode:** assumptions (+ 3 parallel `gsd-advisor-researcher` subagents per user request)
**Areas analyzed:** Generator dead code & hero-icon dependency; Flash/alert primitive & Layouts
wrapper; Retirement proof gate & teardown ordering

## Process

1. `gsd-assumptions-analyzer` deep-read the codebase and surfaced 3 evidence-backed assumption
   areas (minimal_decisive calibration), flagging one research need: how to cleanly de-Tailwind
   `CoreComponents.flash`.
2. User directed a full research pass: spawn parallel subagents per gray area for
   pros/cons/tradeoffs, idiomatic-Elixir/Phoenix, lessons from successful libs (cross-ecosystem),
   DX, UI/UX/brand/microcopy, consulting `prompts/` + the live `brandbook/`, then one-shot a
   coherent locked recommendation set.
3. Three `gsd-advisor-researcher` subagents ran in parallel (Area A / B / C). All returned
   decisive, mutually-consistent recommendations. Synthesized into CONTEXT.md decisions
   D-101-01..11. No corrections needed — research confirmed and sharpened every assumption.

## Assumptions Presented

### Area A — Generator dead code & hero-icon dependency
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 8 routed pages already fully `.ck-*`; real daisyUI = Layouts wrapper + flash; home/Page* is dead code to DELETE | Confident | grep hits all `.ck-*` substrings; `router.ex:23` `/`→LaunchpadLive; contract test excludes Layouts "until Phase 101" |
| Hero icons live in default.css; deleting it breaks flash icons unless inlined first | Confident (post-research) | `default.css:1458-1560` mask/data-URL rules; `icon/1` is a glyphless span; flash uses 3 glyphs on every page |

### Area B — Flash/alert primitive & Layouts wrapper
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Migrate flash to token-only `.ck-flash`/`.ck-alert` BEFORE deleting default.css | Likely → Confident (post-research) | app.css empty; default.css sole daisyUI source; flash renders on all 8 pages via Layouts.app:47 |
| Delete the Layouts.app `<main>`/`<div>` Tailwind wrapper (ck_page/.ck__wrap owns width) | Confident | `.ck__wrap` 64rem+clamp (cohort.css:211) > max-w-3xl 48rem; no page uses Layouts.app without ck_page |

### Area C — Proof gate & teardown ordering
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Promote per-page scan to demo-wide + source/file `refute`s; anchor to `class="` boundary | Confident | flash daisyUI is conditionally-rendered → render-only scan false-greens; Phase-100 over-broad-substring defect |
| Delete default.css LAST behind green grep; screenshot/behavior lane as net | Confident | criterion 2 mandate; default.css is a committed static asset, no build pipeline |

## Research Findings (3 parallel gsd-advisor-researcher subagents)

### Area A
- DELETE `page_controller.ex` + `page_html.ex` + `home.html.heex` (dead/unrouted, ~19 grep hits);
  rename `page_controller_test.exs` → `LaunchpadLiveTest` (already tests LaunchpadLive). Migrating
  or excluding dead code rejected as cargo-cult / hiding.
- Hero glyphs verified in `default.css:1458-1560`; `icon/1` is a glyphless mask-dependent span.
  Inline the 3 needed glyphs (`information-circle`, `exclamation-circle`, `x-mark`) as token-only
  `<svg>` mirroring `ck_icon`/`task_icon` — adding a hero rule to cohort.css (re-imports the
  retired pattern) and dropping icons (a11y regression) both rejected. Hard prerequisite for
  default.css deletion, same PR.

### Area B
- New token-only `.ck-flash`+`.ck-alert`/`--info`/`--error` (option a) — reuse `.ck-error`
  (option b) under-delivers (inline form-error ≠ notification surface); restructuring markup
  (option c) churns the idiomatic Phoenix contract. Fixed top-end toast + colored left-border
  accent over `--ck-surface` (mirrors `.ck-stat`) sidesteps the missing per-state surface token.
  Wrap flash in `.ck` so reduced-motion (`.ck *`, D-96-13) + focus ring reach it.
- A11y: split `status`/polite (info) vs `alert`/assertive (error) per WCAG 4.1.3; no auto-dismiss
  (WCAG 2.2.1); icon+label not color-alone (D-96-15); 44px dismiss. Microcopy: developer-adopter,
  terse/factual, no emoji. Sources: Phoenix 1.8 blog, W3C ARIA22, Sara Soueidan live regions,
  Adrian Roselli toast, daisyUI/shadcn-sonner/Radix/GOV.UK precedent.
- Delete the Layouts wrapper; `.ck__wrap` (64rem) already owns width — `max-w-3xl` was narrowing
  it; double-padding. Re-home footer + flash_group. No page renders Layouts.app without ck_page.
- One token gap noted-not-fixed: no `--ck-*-surface` state token (brandbook has
  `--rindle-status-*-surface`); sidestepped, deferred.

### Area C
- Layered gate inside `cohort_migration_contract_test.exs` (merge-blocking `adoption-demo-unit`,
  no new CI tooling): (1) widen render scan demo-wide (drop `page_body/1` slice) + add wrapper
  literals; (2) source+file test — `File.read!` + `refute` the conditionally-rendered flash
  daisyUI literals (render-only scan false-greens on them), + `refute root.html.heex =~
  "default.css"` + `refute File.exists?(default.css)`; (3) anchor all literals to `class="`
  boundary (avoid `.ck-*` substring false-positive — the Phase-100 defect). Raw `rg 'btn'` CI step
  rejected. Forward-only idempotency ratchet; static gate is merge-blocking, e2e is the net.
- Ordering: migrate flash+wrapper + delete dead code → grep clean → promote gate + remove `<link>`
  → `git rm default.css` LAST (no build pipeline) → screenshot/behavior lane (criterion-3 net).

## Corrections Made

No corrections — research confirmed and sharpened all assumptions. The one research-flagged
uncertainty (how to de-Tailwind flash) resolved decisively to a hand-authored token-only
`.ck-flash`/`.ck-alert` (option a) + inline-SVG icons, consistent with the established
hand-authored token-only cohort.css discipline (D-94-05/06).
