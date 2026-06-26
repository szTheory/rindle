---
phase: 98
slug: admin-level-3-page-composition-motion-mobile-a11y-ia-microco
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-18
---

# Phase 98 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source of truth: `98-RESEARCH.md` § Validation Architecture (per-clause gate-home split, D-98-05/06).

---

## Test Infrastructure

Dual gate home — the split line is D-98-05: "does proving it need the cascade to resolve?"

| Property | Value |
|----------|-------|
| **ExUnit home** | `test/brandbook/admin_design_system_validation_test.exs` (substring / token-presence / regenerate-diff / `render_to_string` grep) + `brandbook/src/admin-contrast.mjs` (contrast source of truth) |
| **Playwright home** | `examples/adoption_demo/e2e/support/admin-polish.js` (computed-style) + `examples/adoption_demo/e2e/admin-screenshots.spec.js` (`toHaveLength(22)` literal — bump deliberately) |
| **Quick run command** | `mix test test/brandbook/admin_design_system_validation_test.exs` |
| **Full suite command** | `mix test` then `cd examples/adoption_demo && npx playwright test` |
| **Estimated runtime** | ExUnit ~seconds; Playwright ~minutes |

---

## Sampling Rate

- **After every task commit:** Run the ExUnit quick command (`mix test test/brandbook/admin_design_system_validation_test.exs`)
- **After every plan wave:** Run the full suite (ExUnit + Playwright)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ExUnit gate < 60s

---

## Per-Task Verification Map

> Populated by the planner/executor from each PLAN.md `<verify>` / `must_haves`. Each of the six
> §A–§F merge-gates maps to its proving home below. Five clauses are flagged in RESEARCH.md as
> NOT inferable from static tests (computed-style backstops): the 760–1023px two-pane band,
> `::before content:attr(data-label)`, reduced-motion `0s` (must run un-frozen), dialog `inert`
> reset-on-reconnect, and `:focus-visible`-vs-pointer differentiation → all Playwright.

| Gate | Clause class | Proving home | Notes |
|------|--------------|--------------|-------|
| §A Composition | unconditional (radius/bg token, no page-local `display:grid`) | ExUnit | conditional two-pane track count → Playwright |
| §A Composition | two-pane `grid-template-columns` track count @ viewport | Playwright | backstop (cascade must resolve) |
| §B Motion | `transition-property ⊆ {opacity,transform}`, no `transition:all` | ExUnit | |
| §B Motion | reduced-motion `0s` vs token duration | Playwright | backstop — run **un-frozen** (freezeMotion footgun) |
| §C Responsive | `display` flip @ 759/761 + 1023/1025; `content:attr()` stacked card | Playwright | backstop |
| §D A11y | contrast (58/58 source hexes), dead-markup `aria-pressed`, DOM structure | ExUnit | contrast stays ExUnit-only |
| §D A11y | `:focus-visible`-vs-pointer, dialog-open `inert` reset-on-reconnect | Playwright | backstop |
| §E IA | nav order/labels, deep-link hrefs, route presence | ExUnit primary | nav order + hrefs also asserted in Playwright |
| §F Microcopy | denylist over rendered markup | ExUnit primary | Playwright mirror only if interpolated copy exists |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Both gate homes already exist — no framework install needed.
- New Playwright sub-assertions extend `admin-polish.js` (already HARD admin-root-only); the
  `toHaveLength(22)` literal in `admin-screenshots.spec.js` is bumped deliberately when net-new
  e2e states are added (P4, mirrors 97-04's 10→18 bump).

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification — computed-style assertions are the merge-blocking
gate for this milestone (no human UAT for the gate clauses).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or map to a gate home above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Five computed-style backstops land in Playwright (un-frozen where required)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (ExUnit gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
</content>
</invoke>
