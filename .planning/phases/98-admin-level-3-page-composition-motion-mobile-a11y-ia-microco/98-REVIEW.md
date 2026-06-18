---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
reviewed: 2026-06-18T00:00:00Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - brandbook/admin-gallery/index.html
  - brandbook/src/admin-css-build.mjs
  - brandbook/tokens/rindle-admin.css
  - lib/rindle/admin/components.ex
  - lib/rindle/admin/live/actions_live.ex
  - lib/rindle/admin/live/assets_live.ex
  - lib/rindle/admin/live/home_live.ex
  - lib/rindle/admin/live/runtime_doctor_live.ex
  - lib/rindle/admin/live/upload_sessions_live.ex
  - lib/rindle/admin/live/variants_jobs_live.ex
  - lib/rindle/admin/queries.ex
  - lib/rindle/admin/router.ex
  - priv/static/rindle_admin/rindle-admin.css
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 98: Code Review Report

**Reviewed:** 2026-06-18T00:00:00Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 98 layers Level-3 page composition, motion, responsive behavior, and an
overlay/focus contract onto the mountable Rindle Admin console. The generated CSS
regenerates byte-identical from `admin-css-build.mjs` (no generator drift), the two
CSS artifacts are identical, the gallery is self-consistent, and `mix compile
--warnings-as-errors` passes clean.

The central new abstraction — the `modal`/`confirm_dialog` overlay primitive with
its documented `show_modal`/`hide_modal` focus contract (push_focus → focus_first →
pop_focus, plus server-assign-driven `inert`/`aria-hidden`) — is implemented
correctly in `variants_jobs_live.ex` but is **bypassed** in `actions_live.ex`, the
one surface that hosts the most consequential flow (GDPR owner/batch erasure). That
is the most material finding. The remaining issues are a latent structural
inconsistency in the Doctor error model, two cosmetic label/state mismatches on the
Overview health chips, and a stray window-keydown listener on a permanently-mounted
hidden dialog.

No critical (data-loss / security / guaranteed-crash) defects were found. The
erasure flow is gated server-side by a typed confirmation string regardless of the
focus issue, and the router keeps its production auth fail-closed validation intact.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Erasure confirm dialogs bypass the documented focus contract

**File:** `lib/rindle/admin/live/actions_live.ex:429-481`, `502-521` (and `lib/rindle/admin/components.ex:256-422`)
**Issue:** The owner- and batch-erasure `confirm_dialog`s are shown purely from the
server assign — `render_action_overlay/2` renders them with `show={true}` once
`action_state == :preview`, and the trigger is the plain `preview_owner_erasure` /
`preview_batch_erasure` form submit. Neither `show_modal/2` nor any
`JS.push_focus()` / `JS.focus_first` is ever chained on the open path, and the
`:on_cancel` is a bare `JS.push("change_owner_erasure")` with no `hide_modal`. The
`confirm_dialog` moduledoc (components.ex:256-289) explicitly documents that the
primitive exists *because* it stashes the trigger, moves focus into the
`focus_wrap`, and returns focus on close.

Consequences in the erasure flow specifically:
- On open, focus is never moved into the `role="alertdialog"` — keyboard and
  screen-reader users land on a modal with focus stranded in the (now `inert`)
  `<main>` behind it. `focus_wrap` only traps Tab *after* focus is inside, so the
  trap never engages.
- ESC / backdrop click invoke `hide_modal(@on_cancel, @id)` which calls
  `JS.pop_focus()`, but `push_focus()` was never called, so focus return is a
  no-op — focus is left wherever it happened to be.

`variants_jobs_live.ex:133` correctly chains `show_modal("regenerate-variants") |>
JS.push("open_regenerate")` and its cancel/confirm buttons chain `hide_modal(...)`.
The actions surface should follow the same pattern.

**Fix:** Chain the focus commands onto the preview triggers and the cancel path, e.g.:
```elixir
# on the preview submit button, in addition to phx-submit="preview_owner_erasure",
# open the overlay with focus management once the server flips to :preview:
phx-click={show_modal("owner-erasure-confirm")}
# and route the dialog's on_cancel through hide_modal so the trigger is restored:
on_cancel={hide_modal(JS.push("change_owner_erasure"), "owner-erasure-confirm")}
```
Because visibility is server-assign driven (`show={true}` in `:preview`), issue
`JS.push_focus()` + `JS.focus_first(to: "#...-content")` from the preview-submit
click and route cancel/ESC through `hide_modal/2` so the trigger is stashed and
restored symmetrically with the variants surface.

### WR-02: `empty_model/0` omits `runtime_checks`, inconsistent with `runtime_findings/1`

**File:** `lib/rindle/admin/live/runtime_doctor_live.ex:138-149` (vs. `157-162`)
**Issue:** `runtime_findings/1` reads `runtime_status.runtime_checks.findings`
(line 161), but `empty_model/0`'s `runtime_status` map defines only `assets`,
`variants`, `upload_sessions`, and `provider_assets` — no `runtime_checks` key. The
real `RuntimeStatus.runtime_status/1` report *does* include `runtime_checks`
(confirmed in `lib/rindle/ops/runtime_status.ex:51`), so the fallback model is
structurally narrower than the contract its own render function consumes.

This does not crash today only by accident of sequencing: at mount `empty_model` is
assigned and then `load()` runs synchronously, replacing it with either the real
model (`error?: false`) or `empty_model` paired with `error?: true` (which routes
`page` to the `:error` branch and never renders the `:work` slot). If any future
caller renders the `:work` slot while `model == empty_model()` and `error? == false`
— e.g. a refactor that defers `load()`, or an added intermediate `:loading` model —
`runtime_findings/1` raises `KeyError: key :runtime_checks not found`. The fallback
shape should not silently diverge from the shape `render/1` requires.

**Fix:** Add the missing key so the fallback is a true subset of the real report:
```elixir
runtime_status: %{
  runtime_checks: %{counts: %{}, findings: []},
  assets: %{counts: %{}},
  variants: %{counts: %{}, findings: []},
  upload_sessions: %{counts: %{}, findings: []},
  provider_assets: %{counts: %{}, findings: []}
}
```

### WR-03: Permanently-mounted hidden dialog leaves a global ESC listener attached

**File:** `lib/rindle/admin/components.ex:299-308`, `351-360`; `lib/rindle/admin/live/variants_jobs_live.ex:227-253`
**Issue:** `modal/1` and `confirm_dialog/1` put `phx-window-keydown={hide_modal(...)}`
+ `phx-key="escape"` on the outer overlay element, which is hidden via
`style="display: none;"` when `@show` is false rather than removed from the DOM.
`phx-window-keydown` binds to `window`, so the listener fires regardless of the
element's display. In `variants_jobs_live.ex` the `regenerate-variants`
`confirm_dialog` is rendered unconditionally (`show={@dialog_open}`), so when the
dialog is closed, pressing Escape anywhere on the page (e.g. while typing in a
filter field) still fires `hide_modal(...) |> JS.push("close_regenerate")`. The
effect is benign today (`close_regenerate` just re-asserts `dialog_open: false`, and
`pop_focus` with nothing stashed is a no-op), but it is a latent surprise: the page
swallows Escape globally and round-trips a spurious server event on every Escape
press. `actions_live.ex` is unaffected because its dialogs are only rendered in the
`:preview` state.

**Fix:** Gate the keydown binding on visibility, or only mount the dialog element
when open. Either render the overlay element conditionally (`:if={@show}`) so the
window listener exists only while open, or scope Escape handling to the
focus-trapped dialog container (focus is inside it once WR-01 is honored) instead of
a global `phx-window-keydown`.

### WR-04: Health chip label/state can contradict each other on Overview

**File:** `lib/rindle/admin/live/home_live.ex:188`, `205-209`
**Issue:** `storage_state/1` returns `"warning"` when `doctor.failed > 0`, but
`storage_label/1` is a constant that always returns `"Storage reachable"`. Likewise
`lifecycle_label/1` always returns `"Lifecycle events flowing"` even when
`lifecycle_state/1` resolves to `"info"` (no variants and no upload sessions, i.e.
nothing is flowing). The result is a chip that renders a warning/neutral color with
copy asserting the opposite ("Storage reachable" beside a warning chip; "Lifecycle
events flowing" beside an info chip when nothing is flowing). On the operator's
problems-first Overview this is actively misleading rather than merely cosmetic.

**Fix:** Make each label a function of the same signal that drives its state, e.g.:
```elixir
defp storage_label(model) do
  if (get_in(model, [:doctor, :failed]) || 0) > 0,
    do: "Storage checks failing",
    else: "Storage reachable"
end

defp lifecycle_label(model) do
  case lifecycle_state(model) do
    "ready" -> "Lifecycle events flowing"
    _ -> "No lifecycle events yet"
  end
end
```

## Info

### IN-01: Confirmation prompt echoes untrimmed owner type/id

**File:** `lib/rindle/admin/live/actions_live.ex:72-88`, `101`, `446`
**Issue:** `preview_owner_erasure` stores the raw (untrimmed) `type`/`id` form
values into `action_data`, and both the displayed confirmation prompt (`ERASE
{@action_data.type}:{@action_data.id}`) and the `expected` string in
`execute_owner_erasure` (`"ERASE #{type}:#{id}"`) use those raw values, so they stay
in sync and the gate still works. But `parse_owner/2` trims before resolving the
module, so an operator who enters `" User "` is asked to type a confirmation string
with embedded leading/trailing spaces (`ERASE  User : 42 `), which is awkward and
easy to mistype. Trim `type`/`id` before storing them in `action_data` so the
displayed/expected confirmation string is the canonical (trimmed) form.

### IN-02: `finding_label/1` has no fallback clause

**File:** `lib/rindle/admin/live/runtime_doctor_live.ex:164-165`
**Issue:** `finding_label/1` pattern-matches only `%{class: class}` and
`%{state: state}`. A finding map carrying neither key would raise
`FunctionClauseError` during render. In practice `summarize_findings` always emits a
`:class`, so this is low-risk, but a defensive trailing clause (`defp
finding_label(_), do: "finding"`) would make render robust to upstream shape changes.

### IN-03: `home_live` health chips repeat the same `doctor.failed` signal

**File:** `lib/rindle/admin/live/home_live.ex:190-209`
**Issue:** Both `doctor_state/1` and `storage_state/1` derive entirely from
`doctor.failed > 0`, so the "Doctor checks" and "Storage" chips are perfectly
correlated and never disagree — the storage chip carries no independent
information. This is a modeling smell on the problems-first dashboard (two chips
implying two signals where there is one). If storage reachability has a distinct
Doctor check id, key the storage chip off that specific check rather than the
aggregate failure count.

### IN-04: Duplicated visually-hidden recipe in generated CSS

**File:** `brandbook/src/admin-css-build.mjs:1087-1095` and `1170-1179`
**Issue:** The `.rindle-admin-visually-hidden` utility and the stacked-table
`thead` hide block emit the identical clip / clip-path / 1px recipe twice. The
generator comment at 1082-1086 acknowledges this ("authored once here so any
element can opt into accessible-but-invisible"), yet the `thead` rule re-inlines the
same declarations instead of reusing the utility. Not a correctness defect, but a
maintenance hazard: a future change to the visually-hidden recipe must be made in
two places or the table-hide will silently drift. Factor the shared declarations
into one emitter so both consumers stay in lockstep.

---

_Reviewed: 2026-06-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
