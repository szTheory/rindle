# Phase 100: Cohort `/upload` Migration (all tabs) [Track B] - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in 100-CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-18
**Phase:** 100-cohort-upload-migration-all-tabs-track-b
**Mode:** assumptions (+ maintainer-requested deep subagent research)
**Areas analyzed:** Page shell, Tab navigation, Panel bodies/hooks/UX, Proof harness

## Assumptions Presented (initial draft)

### Page shell
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Compose existing `ck_page/1` for the `/upload` header + `.ck` shell | Confident | `cohort_components.ex:78` (built UNUSED in 99); `/ops`/dashboard precedent |

### Tab navigation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep URL-`patch` `<.link>` tab nav; restyle to `.ck-*`; do NOT adopt `ck_tabs/1` widget | Confident | `upload_live.ex` tab_link/tab_class; 6 specs click `upload-tab-#{tab}`; `ck_tabs/1` is in-page widget |

### Panel bodies/hooks
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Class-only swap; preserve every hook/id/testid; status/error → `.ck` treatments | Confident | `upload_live.ex` panels; behavior specs key off testids |

### Proof
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend `cohort-pages.spec.js` + `cohort_migration_contract_test.exs`, per-tab | Confident | the two Phase-99 harnesses; panels mutually exclusive in DOM |

## Maintainer Directive

Rather than lock the draft assumptions, the maintainer requested deep multi-subagent research for
each area: pros/cons/tradeoffs with examples, idiomatic Elixir/Phoenix/LiveView + ecosystem lessons
(what peer libs/apps did right and their footguns), DX, a11y/dark-light, brandbook alignment, UX
microcopy, creative direction, and user-psychology/JTBD — then a single coherent one-shot locked set.
Four `gsd-advisor-researcher` subagents were spawned in parallel (one per area), each reading the
target code + the inherited D-94/96/99 contracts + `prompts/` research + the LIVE `brandbook/`.

## Research Outcomes & Corrections (all HIGH confidence)

### Area 1 — Page shell → CONFIRMED (A)
Compose the existing `ck_page/1` exactly like `/ops`. Confirmed self-contained + scope-safe;
`--ck-maxw: 64rem` beats today's `max-w-3xl`; pass `nav={:upload}`; keep `upload-member-name`
byte-for-byte. Rejected: `Layouts.app` ck-mode (scope bleed, collides with Phase 101), bespoke inline
shell (drift), `/upload`-specific scaffold variant (slot-grammar overreach).

### Area 2 — Tab navigation → CONFIRMED intent, CORRECTED mechanism
- Confirmed: keep URL-`patch` links; do NOT adopt `ck_tabs/1`. Ecosystem consensus: routed/
  URL-addressable tabs must be **links with `aria-current="page"`, never `role=tablist`** (WAI-ARIA
  APG, Inclusive Components, GitHub/Stripe/gov.uk). `ck_tabs/1` is the in-page `role=tab` widget and
  would break the `?tab=` patch + `tus-resume` deep link + the class-only/`:if` contract.
- **CORRECTION:** the draft said "apply `.ck-tab`" — but `.ck-tab` is an **empty** polish-gate hook
  class; tab styling lives on **`.ck-tabs__tab`**. Locked: `class="ck-tabs__tab ck-tab"` on the
  existing `<.link>`, wrap in `.ck-tabs__list`, `aria-current="page"` on the active link, delete
  `tab_class/2`.
- **One new token-only CSS rule** required (`.ck-tabs__tab[aria-current="page"]`) for the selected
  cue — within the Phase 99 "one tiny token-only rule" allowance.

### Area 3 — Panel bodies/hooks → CONFIRMED, strengthened to ZERO new primitives
Status `<p>` → `.ck-output`; tus error → `.ck-error` + warning icon + `role="alert"` (fixes a
color-only violation); file inputs → `.ck-input`; hook/submit buttons → `.ck-btn`/`--primary` on the
EXISTING `<button>` (never link-only `ck_button/1`). Zero new CSS rules. Deferred (DOM/behavior
change): drag-drop dropzone, live percent progress, human-readable status microcopy.

### Area 4 — Proof → CONFIRMED, refined to per-tab + URL-driven
Extend both Phase-99 harnesses. Playwright: 6 flat per-tab polish cases via direct
`goto("/upload?tab=X")` (deterministic, not click) + 1 dark case (image tab, `emulateMedia` after
goto). ExUnit: one test, 6-entry per-`?tab=` comprehension. 6 behavior specs stay green. No new
screenshot infra. Refinement vs draft: navigation is by URL (not click) for the polish gate, and dark
is proven once not per-tab.

## Corrections Made

The four draft assumptions were all CONFIRMED in intent. One mechanism correction: the tab styling
class is `.ck-tabs__tab` (not the empty `.ck-tab`), and the selected cue needs one new token-only CSS
rule keyed on `aria-current="page"`. No assumption was reversed.

## External Research

Performed via 4 `gsd-advisor-researcher` subagents (parallel). Key external sources informing the
tab-navigation decision: W3C WAI-ARIA APG (Tabs pattern), Inclusive Components "Tabbed Interfaces"
(Heydon Pickering), Simply Accessible "Danger! ARIA tabs", aditus.io `aria-current`, MDN ARIA tab
role; GitHub/Stripe/gov.uk routed-tabs precedent. Upload-UX lessons drawn from
`prompts/phoenix-media-uploads-lib-deep-research.md` and peer libs (Uppy, tus.io, Mux, LiveView
upload examples).
