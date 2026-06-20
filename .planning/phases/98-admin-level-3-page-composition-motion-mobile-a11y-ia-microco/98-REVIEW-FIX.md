---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
fixed_at: 2026-06-18T00:00:00Z
review_path: .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 3
skipped: 1
status: partial
---

# Phase 98: Code Review Fix Report

**Fixed at:** 2026-06-18T00:00:00Z
**Source review:** .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01..WR-04; Info findings IN-01..IN-04 out of scope)
- Fixed: 3
- Skipped: 1

All fixes were applied in an isolated git worktree and verified with
`mix compile --warnings-as-errors`, which compiled the `rindle` app cleanly
(the only typing note emitted is in the third-party `sweet_xml` dependency,
not in any modified file, and it did not abort the build).

## Fixed Issues

### WR-02: `empty_model/0` omits `runtime_checks`, inconsistent with `runtime_findings/1`

**Files modified:** `lib/rindle/admin/live/runtime_doctor_live.ex`
**Commit:** e218f9b
**Applied fix:** Added `runtime_checks: %{counts: %{}, findings: []}` as the first
key of the `runtime_status` map in `empty_model/0` so the fallback model is a true
subset of the real `RuntimeStatus.runtime_status/1` report. `runtime_findings/1`
reads `runtime_status.runtime_checks.findings`; the fallback now carries that key,
removing the latent `KeyError` if the `:work` slot is ever rendered against the
fallback model. Verbatim shape from the review's Fix suggestion.

### WR-03: Permanently-mounted hidden dialog leaves a global ESC listener attached

**Files modified:** `lib/rindle/admin/components.ex`
**Commit:** c2cd9a8
**Applied fix:** In both `modal/1` and `confirm_dialog/1`, gated the overlay's
`phx-window-keydown` and `phx-key="escape"` bindings on `@show`
(`phx-window-keydown={if @show, do: hide_modal(@on_cancel, @id)}` and
`phx-key={if @show, do: "escape"}`). The overlay element stays mounted (so the
existing `JS.show`/`JS.hide` transitions and server-assign-driven `display: none`
contract are untouched), but the global `window` keydown listener now exists only
while the dialog is open. This eliminates the latent "Escape anywhere swallows the
key and round-trips a spurious server event" behaviour on the always-mounted
`regenerate-variants` dialog without altering the documented inert/visibility
contract. Chose the minimal attribute-gating option over the review's alternative
`:if={@show}` full-conditional-render suggestion, because conditionally removing the
whole overlay from the DOM would change the show/hide transition contract the
moduledoc relies on.

### WR-04: Health chip label/state can contradict each other on Overview

**Files modified:** `lib/rindle/admin/live/home_live.ex`
**Commit:** 31c6caa
**Applied fix:** Replaced the two constant label functions with signal-derived ones:
`lifecycle_label/1` now switches on `lifecycle_state/1` ("Lifecycle events flowing"
for `"ready"`, "No lifecycle events yet" otherwise), and `storage_label/1` now
returns "Storage checks failing" when `doctor.failed > 0` (the same signal
`storage_state/1` keys off) and "Storage reachable" otherwise. Labels can no longer
contradict their chip colour. Matches the review's Fix suggestion, keyed to the
exact return values of the existing `*_state/1` functions.

## Skipped Issues

### WR-01: Erasure confirm dialogs bypass the documented focus contract

**File:** `lib/rindle/admin/live/actions_live.ex:429-481`, `502-521` (and `lib/rindle/admin/components.ex:256-422`)
**Reason:** skipped — fix as specified cannot be applied without risking behaviour
regressions; flagged for human implementation.

The review's suggested fix (chain `show_modal("owner-erasure-confirm")` /
`JS.push_focus()` / `JS.focus_first(to: "#...-content")` onto the preview-submit
trigger) does not work for this surface as written, and the framework-correct
alternative cannot be applied safely through the shared primitive. Details:

- **The actions dialog is rendered conditionally by a server round-trip, not opened
  by a client click.** `render_action_overlay/2` only emits the `confirm_dialog`
  element once the server flips `action_state` to `:preview` (the result of the
  `preview_owner_erasure` / `preview_batch_erasure` form submit). At the moment the
  preview-submit button is clicked, `#owner-erasure-confirm` (and its
  `-content` focus_wrap) does **not yet exist in the DOM**. A
  `JS.focus_first(to: "#owner-erasure-confirm-content")` chained onto that click
  fires before the server render and silently no-ops. This is structurally unlike
  `variants_jobs_live.ex`, where the dialog is always mounted (`show={@dialog_open}`)
  and opened by a client-side button (`open_regenerate`), so `show_modal` legitimately
  chains onto the click.

- **`JS.push_focus()` on the preview-submit click would stash a button that the
  server then destroys.** The `:input` panel (and its preview-submit button) is
  replaced when the state flips to `:preview`, so the stashed trigger reference is
  gone; the later `JS.pop_focus()` in `hide_modal` would have nothing valid to
  restore focus to.

- **The correct mechanism — `phx-mounted={JS.focus_first(...)}` on the dialog — cannot
  be added to the shared primitive without regressing the variants surface.** The
  variants dialog is permanently mounted, so a blanket `phx-mounted` focus move on
  `confirm_dialog`'s `focus_wrap` would fire on initial page load (dialog closed) and
  pull focus into a hidden dialog. Distinguishing "conditionally-rendered (actions)"
  from "always-mounted (variants)" requires a primitive API change beyond the scope of
  a single review-fix, and even an actions-local `phx-mounted` would move focus *in*
  but still could not reliably restore focus *out* to the original trigger (destroyed
  by the re-render).

Because WR-01 is the most material finding (GDPR owner/batch erasure focus
management) and an incorrect speculative change here could break keyboard/screen-
reader behaviour or the server-side typed-confirmation gate, it is left for human
implementation per the fixer's risk guidance. Note: the server-side typed-confirmation
gate that actually protects the erasure flow is unaffected and remains intact; this is
an accessibility focus-management gap, not a data-safety defect.

---

_Fixed: 2026-06-18T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
