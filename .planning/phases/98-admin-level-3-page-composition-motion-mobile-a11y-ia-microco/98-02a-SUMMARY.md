---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
plan: 02a
subsystem: ui
tags: [admin, a11y, aria, focus-wrap, modal, overlay, live-region, components, skip-link]

# Dependency graph
requires:
  - phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
    plan: "01"
    provides: ":focus-visible / skip-link / dialog permanent-border CSS (.rindle-admin-skip-link, .rindle-admin-confirm-dialog) + 300ms --rindle-motion-transition token this plan's markup/JS targets"
provides:
  - "theme_picker/1 server-owned aria-pressed via @theme assign threaded from shell/1 (D-98-07) — JS.set_attribute demoted to progressive enhancement"
  - "live_indicator/1 POLITE live region (role=status + aria-live=polite + aria-atomic) with the dead tabindex=0 removed"
  - "shell/1 skip-link (first focusable child -> #rindle-admin-main), <main id=rindle-admin-main tabindex=-1>, persistent ASSERTIVE role=alert region (empty at mount), @theme thread, @dialog_open server-assign-driven inert/aria-hidden on main+nav"
  - "error_state/1 role=alert"
  - "modal/1 + confirm_dialog/1 shared overlay primitive (focus_wrap, role=dialog/alertdialog, aria-modal, aria-labelledby, ESC, push/pop focus, JS.transition@300ms) + show_modal/2 + hide_modal/2 JS command helpers"
affects: [98-02b, 98-03, 98-04, admin-surface-migrations, admin-playwright-backstops]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Server-owned ARIA: aria-pressed rendered from an @theme assign threaded shell->theme_picker so the attribute is correct in dead/server-rendered markup and survives reconnect (D-98-06/07)"
    - "Server-assign-driven inert: main+nav inert/aria-hidden render off shell @dialog_open (not solely client JS) so a LiveView dead-render/reconnect re-renders correct state — main is NEVER left inert (D-98-11 landmine)"
    - "Overlay focus contract via Phoenix.Component.focus_wrap + JS framework focus stack (push_focus/focus_first on open, pop_focus on close) — no hand-rolled keydown Tab trap"

key-files:
  created: []
  modified:
    - lib/rindle/admin/components.ex

key-decisions:
  - "Theme threading shipped as attr :theme on shell/1 + theme_picker/1 (default \"auto\", values light|dark|auto). shell renders data-theme={@theme} and passes @theme down so aria-pressed is server-authoritative now; surfaces wire the real session/connect-param value when they adopt it (P3+). Default makes the fix live immediately while keeping P2a primitive-only."
  - "Server-assign-driven inert wired as attr :dialog_open on shell/1 (default false). The dialog open/close phx event (added per-surface in P3) flips dialog_open; show_modal/2 / hide_modal/2 chain onto the caller's on_cancel JS for focus/visibility progressive enhancement. inert source of truth is the assign."
  - "modal/1 and confirm_dialog/1 render LITERAL role=\"dialog\" / role=\"alertdialog\" in their own ~H templates (not a shared dialog/1 with role={@role}) so the §D static gate greps the role in server-rendered markup and the role is honestly dead-rendered."
  - "Overlay container reuses the existing .rindle-admin-confirm-dialog class (P1 CSS) — permanent visible border (var(--rindle-border-rule-strong)) + 300ms open-close transition + :focus-visible ring already authored — so a programmatically-focused container shows a boundary without new CSS (P2a authors markup/ARIA/wiring only)."

patterns-established:
  - "Two persistent server-rendered live regions: POLITE = live_indicator (routine flips), ASSERTIVE = shell role=alert region (run-failure/action-error). Both present at mount, the assertive one empty until content arrives."
  - "JS overlay command helpers (show_modal/2, hide_modal/2) accept an optional leading JS chain so callers prepend the server event that flips dialog_open, keeping inert assign-owned while the helper adds framework focus-stack + timed show/hide."

requirements-completed: [UPLIFT-06]

# Metrics
duration: 9min
completed: 2026-06-18
status: complete
---

# Phase 98 Plan 02a: §D A11y Primitives + Overlay Primitive Summary

**Centralized every §D primitive a11y fix in `components.ex` (theme_picker server-owned `aria-pressed` threaded from shell mount, `live_indicator` polite live region minus the dead tabindex, skip-link + identified focusable `<main>` + a persistent empty assertive `role="alert"` region, `error_state` role=alert) and introduced the shared `modal/1` + `confirm_dialog/1` overlay primitive built on `Phoenix.Component.focus_wrap` with the framework focus stack, ESC close, `aria-modal`/`aria-labelledby`, and server-assign-driven `inert`/`aria-hidden` on `main`+`nav` that survives reconnect — primitive-only, no surface wired, so the six P2b migrations inherit correct ARIA without re-implementing it.**

## Performance

- **Duration:** ~9 min
- **Tasks:** 2 completed
- **Files modified:** 1 (`lib/rindle/admin/components.ex`, +232/-9)

## Accomplishments

- **Task 1 — §D primitive fixes (D-98-07):**
  - `theme_picker/1`: `aria-pressed={@theme == "light"}` / `== "dark"` / `== "auto"` rendered server-side from a new `attr :theme`; `shell/1` gained `attr :theme` (default `"auto"`), renders `data-theme={@theme}`, and threads it into `theme_picker`. `select_theme/1` (`JS.set_attribute`) is now progressive enhancement only, not the source of truth.
  - `live_indicator/1`: removed `tabindex="0"` (dead tab stop on a non-interactive `<p>`); added `role="status"` + `aria-live="polite"` + `aria-atomic="true"`; decorative `<span>` keeps `aria-hidden="true"`.
  - `shell/1`: skip-link (`<a href="#rindle-admin-main">`, class `rindle-admin-skip-link`) is the FIRST focusable child; `<main>` got `id="rindle-admin-main"` + `tabindex="-1"`; added a persistent ASSERTIVE `role="alert"` region (`aria-live="assertive"`, `aria-atomic`, `data-rindle-admin-alert-region`) present at mount and initially empty.
  - `error_state/1`: added `role="alert"`.
  - `status_chip` left untouched (stays a non-focusable `<span>`, no role — §D). No microcopy changes (P3, §F).
- **Task 2 — overlay primitive (D-98-11):**
  - `modal/1` (`role="dialog"`) and `confirm_dialog/1` (`role="alertdialog"`) wrap content in `Phoenix.Component.focus_wrap` (no hand-rolled trap), with `aria-modal="true"` + `aria-labelledby` → the `#{id}-title` element, `tabindex="-1"`, slots `title` (required) / `inner_block` / `actions`. ESC closes via `phx-window-keydown` + `phx-key="escape"`; backdrop click closes.
  - `show_modal/2` = `JS.push_focus() |> JS.show(time: 300, …) |> JS.focus_first(to: "#…-content")`; `hide_modal/2` = `JS.hide(time: 300, …) |> JS.pop_focus()`. `:time` is 300ms to match `--rindle-motion-transition` (RESEARCH A2 — reduced-motion users wait the same window, see no animation).
  - `inert` + `aria-hidden` on `main`+`nav` is rendered off `shell/1`'s new `attr :dialog_open` (server-assign-driven). The per-surface open/close phx event (P3) flips `dialog_open`; the JS helpers chain the caller's `on_cancel` for focus/visibility. This is the D-98-11 landmine mitigation — a dead-render/reconnect re-renders correct state and `main` is never left inert.
  - Container reuses `.rindle-admin-confirm-dialog` (P1 CSS: permanent border + 300ms transition + focus ring). No surface wired (P3).

## Task Commits

1. **Task 1: Fix §D primitive a11y bugs in components.ex** — `5412ec9` (feat)
2. **Task 2: Add shared modal/1 + confirm_dialog/1 overlay primitive** — `38d32dc` (feat)

## Files Created/Modified

- `lib/rindle/admin/components.ex` — `shell/1` (skip-link, `<main id tabindex>`, assertive alert region, `@theme` + `@dialog_open` threading), `theme_picker/1` (server-owned `aria-pressed` via `@theme`), `live_indicator/1` (polite live region, no tabindex), `error_state/1` (role=alert); new `modal/1`, `confirm_dialog/1`, `show_modal/2`, `hide_modal/2`.

## Decisions Made

- **Theme threading via `attr :theme` with `"auto"` default.** `shell/1` and `theme_picker/1` both declare `attr :theme, default: "auto", values: [light, dark, auto]`. shell renders `data-theme={@theme}` and passes it down so `aria-pressed` is server-authoritative immediately, while surfaces can wire the real session/connect-param value when they adopt it (P3+) without changing the primitive. Keeps P2a primitive-only while making the fix live.
- **`inert` source of truth = `shell/1` `attr :dialog_open`.** Rendered conditionally off the assign, not solely toggled by client JS — directly satisfies the D-98-11 reconnect-safety requirement and the plan's acceptance criterion that inert is server-assign-driven.
- **Literal `role` strings in separate `~H` templates** for `modal/1` vs `confirm_dialog/1` (not a shared `dialog/1` with `role={@role}`) so the §D static gate can grep `role="dialog"`/`role="alertdialog"` in dead markup.

## Deviations from Plan

None — plan executed exactly as written. Both tasks were implemented per the §D contract, RESEARCH idioms (focus_wrap + push/pop focus + assign-driven inert), and acceptance criteria. The `attr :theme`/`attr :dialog_open` additions to `shell/1` are the explicit "real wiring task" the plan called for (shell mount → assign → component attr), not deviations.

## Issues Encountered

- The brandbook validation suite is `@tag :integration` — `mix test test/brandbook/admin_design_system_validation_test.exs` alone reports "All tests excluded"; it must be run with `--include integration` (4 tests, 0 failures). Documented so the verifier uses the right invocation.

## Verification Results

- `MIX_ENV=test mix compile` — clean (no errors/warnings in components.ex).
- `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` — **4 tests, 0 failures** (ExUnit static gate green).
- `mix test test/rindle/admin` — **51 tests, 0 failures** (existing admin tests still pass).
- Task 1 greps: `aria-pressed={@theme` ✓; `role="status"` ✓ and `live_indicator` has 0 `tabindex` ✓; `id="rindle-admin-main"` + `tabindex="-1"` ✓; `href="#rindle-admin-main"` ✓; `role="alert"` count = 2 (assertive shell region + error_state) ✓.
- Task 2 greps: `def modal(` + `def confirm_dialog(` ✓; `focus_wrap` rendered ✓ (no manual Tab-cycling logic — only a doc comment mentions Tab); literal `role="dialog"` + `role="alertdialog"` rendered ✓; `aria-modal="true"` ✓; `aria-labelledby` ✓; `phx-key="escape"` ✓; `push_focus`/`pop_focus`/`focus_first` ✓; `inert={@dialog_open}` (assign-driven, ×2 on main+nav) ✓.

## Non-Inferable Backstops Deferred to P4 (Playwright, by design)

Per the plan's `<verification>` and threat T-98-02a-01, the dialog `inert`/`aria-hidden` behavior is NOT provable by this plan's static gate and is proven later via Playwright in P4:
1. Open dialog sets `inert`+`aria-hidden` on `main`+`nav`.
2. `inert` resets on close.
3. `inert` survives a simulated reconnect with the dialog closed (`main` never left inert — the D-98-11 critical landmine).

## Known Stubs

None that block the plan goal. `modal/1`/`confirm_dialog/1` are intentionally unwired to any surface this plan (the per-surface confirm flows adopt them in P3) — this is the planned P2a/P3 staging boundary, not a stub. `shell/1`'s `@dialog_open` defaults to `false` and `@theme` defaults to `"auto"`; surfaces supply real values when they wire the overlay/theme persistence (P3+).

## Self-Check: PASSED

- `lib/rindle/admin/components.ex` present on disk with all changes.
- Both task commits (`5412ec9`, `38d32dc`) present in git history.
