---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
reviewed: 2026-06-18T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - brandbook/src/admin-css-build.mjs
  - lib/rindle/admin/components.ex
  - lib/rindle/admin/live/actions_live.ex
  - lib/rindle/admin/live/assets_live.ex
  - lib/rindle/admin/live/home_live.ex
  - lib/rindle/admin/live/runtime_doctor_live.ex
  - lib/rindle/admin/live/upload_sessions_live.ex
  - lib/rindle/admin/live/variants_jobs_live.ex
  - lib/rindle/admin/queries.ex
  - lib/rindle/admin/router.ex
findings:
  critical: 3
  warning: 6
  info: 4
  total: 13
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-06-18
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 98 builds the Level-3 admin page composition layer (scaffold, motion, mobile, a11y, IA, microcopy) on top of an in-package Phoenix LiveView admin console plus the brandbook generated-CSS build script. The router/queries auth and redaction parity hold up well: `variant_run_detail/1`, `asset_detail/1`, and `upload_session_detail/1` all funnel through the same redacted row builders (`redacted_session_uri/1`, `redacted_provider_id/1`), the `:show` routes cast every id through `Ecto.UUID.cast/1` before any query, and the static-asset plug fails closed on the `tokens.json` `:deny` sentinel.

However, this phase ships three correctness BLOCKERs that defeat its own headline goals:

1. **The "Needs attention" problems-first IA never fires** — the whole point of D-98-10 — because it reads count buckets with string keys against an atom-keyed counts map.
2. **The modal/confirm-dialog focus contract inerts itself** — `@dialog_open` sets `inert` on `<main>`, but every modal is rendered *inside* `<main>`, so the dialog and its destructive-confirmation inputs become non-interactive the instant they open. This blocks owner erasure, batch erasure, and variant regeneration.
3. **The overlay primitive has no CSS at all** — `.rindle-admin-overlay` / `.rindle-admin-overlay__backdrop` are referenced by the components but never emitted by the generator, so dialogs render inline with no positioning, no backdrop, and no z-index.

Together, finding 2 + 3 mean the entire shared modal grammar (the central D-98-11 deliverable) is non-functional, and finding 1 means the home surface silently hides every actionable problem.

## Critical Issues

### CR-01: "Needs attention" task-list and all variant/asset count chips read string keys against an atom-keyed counts map (problems-first IA silently dead)

**File:** `lib/rindle/admin/live/home_live.ex:107-147`, `lib/rindle/admin/live/variants_jobs_live.ex:140-148, 335`
**Issue:** `Rindle.Ops.RuntimeStatus` builds every state-count map via `count_map/1`, which does `String.to_atom(state)` (`lib/rindle/ops/runtime_status.ex:609-613`). The counts map therefore has **atom** keys (`:failed`, `:quarantined`, `:expired`, ...) plus the atom `:total`. But the new code reads them with **string** keys:

- `home_live.ex` `needs_attention/2` reads `count_value(model, [:counts, :variants, "failed"])`, `"stale"`, `count_value(model, [:counts, :assets, "quarantined"])`, `count_value(model, [:counts, :upload_sessions, "expired"])`, and `count_value(model, [:counts, :provider_assets, "orphaned"])` (`orphan_count/1`).
- `variants_jobs_live.ex` summary `metadata_list` reads `count_value(@model, "failed")`, `"cancelled"`, `"stale"`, `"missing"`, `"queued"`, `"processing"`.

`get_in(model, [:counts, :variants, "failed"])` and `Map.get(counts, "failed", 0)` never match `:failed`, so `problem/3` always receives the `nil`/`0` fallback and returns `nil`. The result: **the Needs-attention list is permanently empty** ("Nothing needs attention" renders even when assets are quarantined / runs are failing), and the Processing summary counters always read 0. This defeats the D-98-10 problems-first IA — the central goal of this phase's home surface.

(Note: `:total` is read with the atom `:total` and works; that's why the totals block looks fine and masks the bug.)

**Fix:** Read the buckets with atom keys (the counts map is atom-keyed):
```elixir
# home_live.ex
problem(count_value(model, [:counts, :variants, :failed]), "failed processing runs", ...)
problem(count_value(model, [:counts, :assets, :quarantined]), "quarantined assets", ...)
problem(count_value(model, [:counts, :upload_sessions, :expired]), "expired upload sessions", ...)
# orphan_count/1
count_value(model, [:counts, :provider_assets, :orphaned]) + ...

# variants_jobs_live.ex
{"failed", count_value(@model, :failed)},
{"cancelled", count_value(@model, :cancelled)}, ...
```
Add a test asserting a quarantined asset / failed run produces a non-empty `data-rindle-admin-needs-attention` list, since the symptom is a silent empty state. (Also confirm the variant DB enum actually has `:stale`/`:missing` states — those are finding-class names, not `MediaVariant.state` values, so they may need to come from `counts`-derived findings rather than `counts` directly.)

### CR-02: `@dialog_open` inerts `<main>`, but every modal/confirm dialog is rendered inside `<main>` — opening a dialog disables the dialog itself

**File:** `lib/rindle/admin/components.ex:70-84` (shell `inert`), `lib/rindle/admin/live/variants_jobs_live.ex:121,150-174`, `lib/rindle/admin/live/actions_live.ex:333,452-485,514-538`
**Issue:** `shell/1` applies `inert={@dialog_open}` and `aria-hidden` to `<main>` (and `<nav>`). The documented contract (D-98-11) is that the modal sits *outside* the inerted region so focus can move into it. But all three dialog call-sites render the dialog **inside** the `<main>` content:

- `variants_jobs_live.ex`: the `<.confirm_dialog id="regenerate-variants">` is inside the `<:summary>` slot of `<.page>`, which renders inside `<main>`. When `confirm_regenerate` opens it, `dialog_open=true` inerts `<main>` → the dialog (a descendant of `<main>`) and its "Regenerate variants" / "Cancel" buttons become inert and unclickable.
- `actions_live.ex`: `dialog_open={@action_state == :preview}` and the owner-erasure `<.confirm_dialog>` (lines 459-482) is rendered inside the `:work` slot → inside `<main>`. Opening it inerts the confirmation `<input name="confirmation">` and the "Erase owner" submit, so the typed-confirmation gate can never be satisfied.

`inert` disables the element **and all descendants**, so a modal nested under the inerted `<main>` is non-interactive precisely when shown. The shared modal grammar is the headline D-98-11 deliverable and it is non-functional for all three flows (owner erasure, batch erasure path via CR-03, variant regeneration).

**Fix:** Render the dialog outside the inerted `<main>`/`<nav>` (e.g. as a sibling in `shell/1`, or hoist the overlay to the shell root via a slot), or stop inerting the subtree that contains the live modal. The simplest structural fix is to give `shell/1` a dedicated `:overlay` slot rendered as a sibling of `<main>` and move each surface's `confirm_dialog` into it.

### CR-03: `actions_live` sets `dialog_open` true during batch-erasure preview, but batch preview renders an inline form (no modal) — the entire confirmation form is inerted with no overlay to host it

**File:** `lib/rindle/admin/live/actions_live.ex:333,514-538`
**Issue:** The shell receives `dialog_open={@action_state == :preview}` — true for *both* owner and batch erasure previews. Owner erasure preview renders a `confirm_dialog` (still broken per CR-02), but **batch erasure preview (`render_batch_erasure_state(%{action_state: :preview})`) renders a plain inline `<form>`**, not a modal/overlay. So when batch preview is active:
- `<main>` is inerted and `aria-hidden="true"`.
- The batch confirmation form (`name="confirmation"`, "Erase owners" submit) lives inside that inerted `<main>`.
- There is no overlay element outside `<main>` to receive focus.

Result: batch erasure can never be confirmed (the form is inert), and the whole surface is announced as `aria-hidden` to assistive tech with no dialog to compensate. This is both a functional dead-end and an a11y regression.

**Fix:** Either route batch preview through the same `confirm_dialog` primitive (and fix CR-02 so dialogs live outside `<main>`), or stop setting `dialog_open` for the inline batch-preview state. Do not drive `inert` from a state that has no corresponding modal.

## Warnings

### WR-01: Overlay/backdrop CSS is never generated — dialogs have no positioning, backdrop, or z-index

**File:** `brandbook/src/admin-css-build.mjs` (whole generator), referenced by `lib/rindle/admin/components.ex:288-322,340-376`
**Issue:** `modal/1` and `confirm_dialog/1` emit `class="rindle-admin-overlay"` and `class="rindle-admin-overlay__backdrop"`, but the generator emits **no** `.rindle-admin-overlay` or `.rindle-admin-overlay__backdrop` rule (`grep` confirms 0 occurrences in the generated CSS and in the generator's `requiredSelectors`). The only visibility control is the inline `style={unless @show, do: "display: none;"}`. When shown, the overlay has no `position: fixed`, no centering, no dimmed backdrop, and no `z-index`, so the dialog renders inline in document flow underneath/within the page rather than as a true modal. Combined with CR-02 this makes the modal grammar visually broken as well as non-interactive.

**Fix:** Author `.rindle-admin-overlay` (fixed, full-viewport, flex-centered, high z-index) and `.rindle-admin-overlay__backdrop` (absolute inset-0, semi-opaque surface) in the Phase-98 section of `admin-css-build.mjs`, and add both to `requiredSelectors` so the parity self-check fails closed if they go missing again.

### WR-02: `.rindle-admin-target-min` is used as a class on ~30 elements but only exists as a custom property — the class is a silent no-op

**File:** `brandbook/src/admin-css-build.mjs:89` (only `--rindle-admin-target-min` is emitted), referenced as a class in `components.ex:45,112-114,169,203` and every LiveView button/link (e.g. `assets_live.ex:133`, `home_live.ex:48`, `actions_live.ex:446`)
**Issue:** The markup applies `class="... rindle-admin-target-min"` expecting a 44px hit-area, but the generator only defines the custom property `--rindle-admin-target-min: 44px;` — there is no `.rindle-admin-target-min { min-height: ... }` rule. Most carriers (`.rindle-admin-button`, `.rindle-admin-theme-picker__option`) already set `min-height` independently, so the visible result is usually fine, but the **skip link** (`components.ex:45`, `.rindle-admin-skip-link` has no min-height of its own) and any future bare element relying on this class will fail the 44px touch-target requirement that this phase is supposed to guarantee.

**Fix:** Emit a real utility rule and assert it in `requiredSelectors`:
```css
.rindle-admin-target-min { min-height: var(--rindle-admin-target-min); min-width: var(--rindle-admin-target-min); }
```

### WR-03: `runtime_doctor_live` `empty_model/0` omits `runtime_checks`, so `runtime_findings/1` would crash if ever rendered on the error/empty model

**File:** `lib/rindle/admin/live/runtime_doctor_live.ex:138-149,157-162`
**Issue:** `runtime_findings/1` evaluates `runtime_status.runtime_checks.findings`, but `empty_model/0`'s `runtime_status` map has no `:runtime_checks` key. Today this is not triggerable because `empty_model` is only assigned when `error?: true`, and `<.page state={:error}>` renders `error_state` instead of the `:work` slot that calls `runtime_findings/1`. It is a latent KeyError landmine: any future change that renders `:work` with the empty model (e.g. a loading state, or removing the error short-circuit) will crash with `key :runtime_checks not found`.

**Fix:** Add `runtime_checks: %{counts: %{}, findings: []}` to `empty_model/0`'s `runtime_status` so the shape matches `Rindle.Ops.RuntimeStatus` output.

### WR-04: `confirm_regenerate` swallows the real error and fabricates a fake receipt (`errors: 1`)

**File:** `lib/rindle/admin/live/variants_jobs_live.ex:44-55`
**Issue:** On `{:error, _}` from `regenerate_variants/1`, the handler synthesizes `%{enqueued: 0, skipped: 0, errors: 1}` and then renders "Variant regeneration queued. ... Errors: 1" with `live_status: "Variant regeneration queued."`. The operator is told the regeneration was *queued* and shown a fabricated count of exactly 1 error regardless of the actual failure (which could be a total refusal affecting hundreds of variants). This is misleading operational reporting for a maintenance action.

**Fix:** On error, set an error banner / `action_error`-style assign and a truthful `live_status` ("Variant regeneration failed."), and do not present a fake success-shaped receipt. Surface the real reason (redacted as needed).

### WR-05: `dialog_open` is not reset to false on `handle_params`/navigation, so a stale-open modal can persist across detail navigation

**File:** `lib/rindle/admin/live/variants_jobs_live.ex:57-69`
**Issue:** `handle_params` (both `:show` and index clauses) reassigns `filters`/`detail`/loads data but never resets `dialog_open`. If the regenerate dialog is open (`dialog_open: true`) and the user follows a deep link or filter `live_patch`, `handle_params` fires without clearing `dialog_open`, leaving `<main>` inert (CR-02) on the freshly navigated page with no visible dialog. The detail render clause (`render(%{detail: %{run: _run}})`) doesn't even pass `dialog_open` to the shell, so the index→detail transition can strand inert state inconsistently.

**Fix:** Reset `dialog_open: false` in `handle_params` (both clauses), and pass `dialog_open` consistently to `shell/1` in every render clause.

### WR-06: Home "Recent activity" / "Recent lifecycle activity" actually renders diagnostic recommendations, not lifecycle events

**File:** `lib/rindle/admin/live/home_live.ex:66-76,149-161`
**Issue:** The section is headed "Recent activity" with the empty copy "No recent lifecycle activity recorded," but `recent_activity/1` maps over `model.recommendations` (Doctor/diagnostic recommendations), humanizing `recommendation.class` as the "title". Recommendations are not a time-ordered activity feed; `Enum.take(5)` takes the first five recommendations in whatever order `build_recommendations` produced, not the most recent lifecycle events. The microcopy promises a lifecycle activity log this phase emphasizes (§F) but renders something semantically different, which will mislead operators triaging "what just happened."

**Fix:** Either rename the section to reflect that it shows current diagnostic recommendations, or back it with an actual recent-events source ordered by timestamp. At minimum align the heading/empty copy with what is rendered.

## Info

### IN-01: `finding_label/1` second clause is unreachable dead code

**File:** `lib/rindle/admin/live/runtime_doctor_live.ex:164-165`
**Issue:** `finding_label(%{class: class})` matches first; all findings produced by `RuntimeStatus` carry `:class`, so `finding_label(%{state: state})` is never reached.
**Fix:** Remove the dead clause, or document why a class-less finding shape is expected.

### IN-02: Duplicate `@impl true` annotations on multi-clause `handle_event`

**File:** `lib/rindle/admin/live/actions_live.ex:31,49,71,90,125,147,166` (and similar)
**Issue:** `@impl true` is repeated before several `handle_event` clauses of the same callback; only the first is needed and the compiler warns on redundant `@impl`. Cosmetic but produces warning noise.
**Fix:** Keep a single `@impl true` before the first clause of each callback group.

### IN-03: `error_state/1` reuses `.rindle-admin-empty-state` class with an error data-attr

**File:** `lib/rindle/admin/components.ex:197-206`
**Issue:** `error_state/1` renders `class="rindle-admin-empty-state"` while carrying `data-rindle-admin-error-state`. The visual error styling lives only on the `[data-rindle-admin-error-state]` attribute selector, so the element simultaneously matches the empty-state class rule and the error attribute rule. It works due to attribute-selector specificity, but mixing the empty-state class onto the error component is confusing and fragile if the empty-state rule changes.
**Fix:** Use a dedicated `.rindle-admin-error-state` class (or no class, relying solely on the attribute) so the two states don't share a class name.

### IN-04: `format_value/1` renders arbitrary terms via `to_string/1`, which will raise for non-`String.Chars` values

**File:** `lib/rindle/admin/components.ex:472-476`
**Issue:** The catch-all `def format_value(value), do: to_string(value)` will raise `Protocol.UnprotocolError`/`ArgumentError` for maps, lists, tuples, or PIDs. Current callers feed scalars (ids, states, integers, datetimes), so it's safe today, but `metadata_list`/`detail_table` are generic and a future caller passing a map (e.g. `playback_ids`) would crash the render.
**Fix:** Add a defensive clause for non-`String.Chars` terms: `def format_value(value), do: inspect(value)` as the final fallback (or guard the generic table inputs).

---

_Reviewed: 2026-06-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
