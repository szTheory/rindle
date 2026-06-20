---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
plan: 02a
type: execute
wave: 2
depends_on: ["98-01"]
files_modified:
  - lib/rindle/admin/components.ex
autonomous: true
requirements: [UPLIFT-06]
tags: [admin, a11y, aria, focus-wrap, modal, overlay, live-region, components]

must_haves:
  truths:
    - "theme_picker emits aria-pressed in SERVER-RENDERED (dead) markup driven by an @theme assign threaded from shell mount; JS.set_attribute remains progressive enhancement only (D-98-07, §D)."
    - "live_indicator has role=status + aria-live=polite + aria-atomic=true and NO tabindex (dead tab stop dropped); decorative span keeps aria-hidden (§D)."
    - "shell renders a skip-link as the FIRST focusable child pointing to #rindle-admin-main, and <main> has id=rindle-admin-main + tabindex=-1 (§D, D-98-07)."
    - "shell renders a persistent ASSERTIVE role=alert region present at mount and initially empty (§D)."
    - "error_state has role=alert (§D)."
    - "A new shared modal/1 + confirm_dialog/1 overlay primitive exists using Phoenix.Component.focus_wrap (NOT a hand-rolled keydown trap), with role=dialog (or alertdialog for destructive) + aria-modal=true + aria-labelledby->title, ESC via phx-window-keydown phx-key=escape, JS.push_focus/JS.focus_first on open + JS.pop_focus on close (D-98-11)."
    - "The open/close commands toggle inert AND aria-hidden on main+nav, server-assign-driven so a LiveView reconnect/dead-render re-renders correct state — main is NEVER left inert (D-98-11 critical landmine)."
    - "[NON-INFERABLE / Playwright-backstop, asserted in P4] Open dialog sets inert+aria-hidden on main+nav; inert resets on close AND survives a simulated reconnect with the dialog closed."
  artifacts:
    - path: "lib/rindle/admin/components.ex"
      provides: "Fixed theme_picker/live_indicator/shell(skip-link,main,alert region)/error_state + new modal/1 & confirm_dialog/1 overlay primitive"
      contains: "def modal("
  key_links:
    - from: "lib/rindle/admin/components.ex shell/1 mount"
      to: "lib/rindle/admin/components.ex theme_picker/1"
      via: "shell learns current theme (session/connect param) at mount and passes @theme down so theme_picker renders aria-pressed server-side"
      pattern: "aria-pressed"
    - from: "lib/rindle/admin/components.ex modal/1 / confirm_dialog/1"
      to: "Phoenix.Component.focus_wrap + Phoenix.LiveView.JS"
      via: "focus_wrap traps Tab; JS.push_focus/focus_first on open, JS.pop_focus on close; inert+aria-hidden toggled server-assign-driven on main+nav"
      pattern: "focus_wrap"
---

<objective>
Fix the §D primitive a11y bugs that live centrally in `lib/rindle/admin/components.ex` (single-touch → all six surfaces inherit), and introduce the shared `modal/1` + `confirm_dialog/1` overlay primitive. Implements D-98-07 and D-98-11.

Purpose: These are the a11y primitives the six surface migrations (P2b) compose. Centralizing them BEFORE the migrations means each surface inherits correct ARIA/focus/live-region behavior without re-implementing it. Relief-valve split of P2 (D-98-02): P2a = a11y primitives, P2b = the six atomic migrations.

Output: theme_picker server-owned `aria-pressed`; `live_indicator` polite live region without dead tabindex; skip-link + `<main id tabindex>`; persistent assertive alert region; `error_state` role=alert; and a `focus_wrap`-based overlay primitive with server-assign-driven inert/aria-hidden that survives reconnect.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-CONTEXT.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-UI-SPEC.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-PATTERNS.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-RESEARCH.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-01-SUMMARY.md
</context>

<artifacts_this_phase_produces>
This plan (P2a) creates/modifies these symbols — exclude the net-new ones from drift/undefined verification:
- NEW: `modal/1` and `confirm_dialog/1` function components in `components.ex` (overlay primitive — no prior overlay analog; the inline confirm panels in `actions_live.ex:609-779` are the anti-pattern being replaced, wired in P2b/P3).
- NEW: open/close `JS` command helpers for the overlay (chained `JS.push_focus`/`JS.focus_first`/`JS.pop_focus` + inert/aria-hidden toggles).
- MODIFIED (existing): `theme_picker/1` (server-owned aria-pressed via `@theme`), `live_indicator/1` (role/aria-live, drop tabindex), `shell/1` (skip-link, `<main id tabindex>`, persistent assertive alert region, `@theme` thread from mount), `error_state/1` (role=alert).
NOTE: the `<caption>`/`<thead>`/`scope` table fix is NOT here — it rides each surface migration in P2b (D-98-08). The CSS for `:focus-visible`/skip-link/dialog border was authored in P1 — P2a authors ONLY the markup/ARIA/wiring.
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Fix the §D primitive a11y bugs in components.ex (theme_picker, live_indicator, shell skip-link/main/alert region, error_state)</name>
  <read_first>
    - lib/rindle/admin/components.ex (READ FULLY — shell/1 ~L23-57 incl <main> ~L45; theme_picker/1 ~L59-67 + select_theme/1 ~L209-213; live_indicator/1 ~L71-78; error_state/1 ~L134-143; admin_path/2 ~L186-194)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-UI-SPEC.md §D (ARIA-per-primitive table, live-regions, keyboard/skip-link)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-CONTEXT.md (D-98-07)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-RESEARCH.md (§ "Server-owned aria-pressed theme threading" — shell learns theme at mount, real wiring task; live read can't prove server-ownership)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-PATTERNS.md (§D primitive fixes — analogs are the primitives themselves)
  </read_first>
  <action>
    Apply the five centralized §D fixes (D-98-07):
    1. theme_picker: make `aria-pressed` SERVER-authoritative — render `aria-pressed={@theme == "light"}` / `== "dark"` / `== "auto"` from an `@theme` assign. Thread the theme from shell mount: shell must learn the current theme (session value or LiveView connect param) at mount, assign it, and pass it down to theme_picker (add an `attr :theme` to theme_picker and pass it from shell). Keep the existing `select_theme/1` `JS.set_attribute` chain as progressive enhancement ONLY — it is no longer the source of truth. This is a real wiring task (shell mount → assign → component attr), not a render tweak.
    2. live_indicator: drop the `tabindex="0"` (dead tab stop on a non-interactive `<p>`); add `role="status"` + `aria-live="polite"` + `aria-atomic="true"`. Keep the decorative span `aria-hidden="true"`.
    3. shell `<main>` (~L45): add `id="rindle-admin-main"` + `tabindex="-1"`. Add a skip-link as the FIRST focusable child of shell (`href="#rindle-admin-main"`, visually-hidden-until-focused — the CSS for it was authored in P1). Add a persistent ASSERTIVE `role="alert"` region inside shell that is present at mount and INITIALLY EMPTY (for async run-failure/action-error banners). The POLITE region is `live_indicator` (fixed in step 2); the assertive region is net-new shell markup.
    4. error_state: add `role="alert"`.
    Do NOT change `status_chip` (it stays a non-focusable `<span>` with visible text and NO role — adding role="status" would spam on patch, §D). Do NOT touch microcopy strings here (that is P3, §F) — keep current copy verbatim except where a role/attr is added.
  </action>
  <verify>
    <automated>mix test test/brandbook/admin_design_system_validation_test.exs && mix test test/rindle/admin 2>/dev/null; mix compile 2>&1 | grep -iv "Mox\|test/support" | grep -i "error" || true</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n 'aria-pressed={@theme' lib/rindle/admin/components.ex` matches (server-driven, not a hard-coded string).
    - `grep -n 'role="status"' lib/rindle/admin/components.ex` matches AND `live_indicator` no longer contains `tabindex="0"` (`grep -A6 "def live_indicator" lib/rindle/admin/components.ex` shows no `tabindex`).
    - `grep -n 'id="rindle-admin-main"' lib/rindle/admin/components.ex` and `grep -n 'tabindex="-1"' lib/rindle/admin/components.ex` both match.
    - `grep -n 'href="#rindle-admin-main"' lib/rindle/admin/components.ex` matches (skip-link).
    - `grep -c 'role="alert"' lib/rindle/admin/components.ex` ≥ 2 (persistent assertive shell region + error_state).
    - Module compiles; existing admin tests still pass.
  </acceptance_criteria>
  <done>theme_picker emits server-owned aria-pressed via @theme threaded from shell mount; live_indicator is a polite live region with no dead tabindex; shell has a skip-link + identified focusable main + a persistent empty assertive alert region; error_state is role=alert. status_chip unchanged. No microcopy changes.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Introduce the shared modal/1 + confirm_dialog/1 overlay primitive (focus_wrap, server-assign-driven inert)</name>
  <read_first>
    - lib/rindle/admin/components.ex (alias Phoenix.LiveView.JS at L6; select_theme/1 ~L209-213 for the JS-command chaining idiom)
    - lib/rindle/admin/live/actions_live.ex (the inline confirm panels ~L609-779 being replaced — the anti-pattern: no trap, no ESC, no return-focus. Read for the open/close event names and confirm-input shape the dialog must support; actual rewiring happens in P3.)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-UI-SPEC.md §D (overlay focus contract) + §F (confirmation pattern "{Verb} this {noun}?", no "!")
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-RESEARCH.md (§ "Phoenix.Component.focus_wrap" + "JS.transition" + "inert + aria-hidden reset-on-reconnect" — VERIFIED LV 1.1.30 idioms; prefer server-assign-driven inert; dialog needs permanent visible border because programmatic focus may not trigger :focus-visible)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-CONTEXT.md (D-98-11)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-PATTERNS.md (modal/confirm_dialog pattern — lean on focus_wrap/push_focus/pop_focus + select_theme JS chaining, NO copied analog)
  </read_first>
  <action>
    Add `modal/1` and `confirm_dialog/1` function components to `components.ex`. Use `Phoenix.Component.focus_wrap` (NOT a hand-rolled keydown trap) wrapping the dialog content; require an `id` attr; declare slots for title and body and an actions slot. Render `role="dialog"` for informational and `role="alertdialog"` for destructive/confirm (`confirm_dialog/1`), plus `aria-modal="true"` + `aria-labelledby` pointing at the title element id. ESC closes via `phx-window-keydown` + `phx-key="escape"`. Build the open/close commands as chained `Phoenix.LiveView.JS` (same idiom as `select_theme/1`): open does `JS.push_focus()` |> `JS.focus_first(to: "#<dialog-id>")` (and shows the dialog node); close does `JS.pop_focus()` (and hides). For motion, use `JS.transition` with `:time` EQUAL to the transition token duration (300ms) the P1 CSS authored — the node is held that long; reduced-motion users wait but see no animation (acceptable, RESEARCH A2). CRITICAL inert/aria-hidden (D-98-11): toggle `inert` AND `aria-hidden` on `main`+`nav` while the dialog is open. Make this SERVER-ASSIGN-DRIVEN — i.e. the dialog open/close state lives in a LiveView assign and the shell/main/nav render `inert`/`aria-hidden` conditionally off that assign — so a LiveView dead-render/reconnect re-renders the CORRECT state and never leaves `main` inert (the critical landmine). Give the dialog a permanent visible border / `:focus` ring (the CSS rule was authored in P1) since a programmatically-focused container may not trigger `:focus-visible`. Confirm body/heading copy follows §F shape ("{Verb} this {noun}?", plain consequence sentence, no "!") — but the per-surface confirm strings are wired in P3; here provide the primitive with slots, not hard-coded surface copy.
    Do NOT wire any surface to the dialog here — surfaces adopt it in P3 (actions_live confirm flows). P2a only ships the primitive.
  </action>
  <verify>
    <automated>mix compile 2>&1 | grep -iv "Mox\|test/support" | grep -i "error" || true ; mix test test/brandbook/admin_design_system_validation_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n "def modal(" lib/rindle/admin/components.ex` and `grep -n "def confirm_dialog(" lib/rindle/admin/components.ex` both match.
    - `grep -n "focus_wrap" lib/rindle/admin/components.ex` matches (no hand-rolled `phx-keydown` Tab trap — `grep -i "Tab" lib/rindle/admin/components.ex` should show no manual tab-cycling logic).
    - `grep -E 'role="(dialog|alertdialog)"' lib/rindle/admin/components.ex` matches; `grep 'aria-modal="true"' lib/rindle/admin/components.ex` matches; `grep "aria-labelledby" lib/rindle/admin/components.ex` matches.
    - `grep -n 'phx-key="escape"' lib/rindle/admin/components.ex` matches.
    - `grep -n "push_focus\|pop_focus\|focus_first" lib/rindle/admin/components.ex` matches (framework focus stack, not hand-stashed id).
    - `grep -n "inert" lib/rindle/admin/components.ex` matches AND it is rendered conditionally off an assign (not solely toggled by client JS) — the shell/main/nav inert/aria-hidden is server-assign-driven.
    - Module compiles; ExUnit static gate green.
  </acceptance_criteria>
  <done>modal/1 + confirm_dialog/1 exist using focus_wrap with role/aria-modal/aria-labelledby, ESC close, push/pop focus, JS.transition timed to the token, and server-assign-driven inert+aria-hidden on main+nav that survives reconnect. No surface wired yet.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client keyboard/AT → LiveView UI state | Focus, ESC, Tab, screen-reader virtual cursor interact with the dialog trap and live regions; a stuck `inert` makes the whole console non-interactive |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-98-02a-01 | Denial of Service | `main` left `inert` after dialog close fails or after reconnect (whole console non-interactive) | mitigate | Server-assign-driven inert/aria-hidden so a re-render restores correct state; D-98-11 critical landmine; P4 Playwright proves reset-on-close + reset-on-reconnect |
| T-98-02a-02 | Spoofing | theme_picker aria-pressed desyncs from real theme (JS-only) misrepresenting state to AT | mitigate | Server-owned aria-pressed via @theme assign (D-98-07); JS.set_attribute demoted to progressive enhancement |
| T-98-02a-03 | Information Disclosure | Assertive live region announcing more than a summarized message (row-level spam / leaking detail) | accept | §D limits the region to a single summarized message ("Run 1f2 failed"); region is empty at mount; no PII in summaries |
| T-98-02a-SC | Tampering | npm/node package installs | mitigate | N/A — zero new packages this phase (focus_wrap is in the already-pinned phoenix_live_view 1.1.30 optional dep) |
</threat_model>

<verification>
- ExUnit static gate green (no CSS touched here → no drift; P1's CSS already shipped).
- All five §D primitive fixes present in dead markup (grep over components.ex).
- Overlay primitive uses focus_wrap + framework focus stack + server-assign-driven inert.
- The dialog inert reset-on-close + reset-on-reconnect is a NON-INFERABLE Playwright backstop proven in P4 (D-98-11, VALIDATION backstop 4) — not provable by this plan's static gate.
</verification>

<success_criteria>
- All §D primitive a11y bugs fixed centrally in components.ex; theme_picker aria-pressed server-owned; live_indicator polite region without dead tabindex; skip-link + identified main; persistent assertive region; error_state role=alert.
- modal/1 + confirm_dialog/1 exist (focus_wrap, role/aria-modal/aria-labelledby, ESC, push/pop focus, server-assign-driven inert) — unused by surfaces until P3.
- Module compiles; ExUnit gate green.
</success_criteria>

<output>
Create `.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-02a-SUMMARY.md` when done.
</output>
