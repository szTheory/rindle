# Phase 98: Admin Level-3 Page Composition + Motion / Mobile / A11y / IA / Microcopy - Pattern Map

**Mapped:** 2026-06-18
**Files analyzed:** 14 new/modified
**Analogs found:** 14 / 14 (every new artifact has a same-file or same-role analog — this is a polish pass over an existing system, not greenfield)

> Read alongside `98-CONTEXT.md` (D-98-01..16) and `98-UI-SPEC.md` (§A–§F merge-gates). Every
> file path below is absolute-from-repo-root. The generated-CSS boundary (D-98-12) means CSS is
> authored ONLY in `brandbook/src/admin-css-build.mjs` — never hand-edit either `rindle-admin.css`.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/admin/components.ex` → new `page/1` scaffold | component (function component) | request-response (render) | `shell/1`, `table/1`, `empty_state/1`, `error_state/1` (same file) | exact (same file, same idiom) |
| `lib/rindle/admin/components.ex` → new `modal/1`+`confirm_dialog/1` | component (overlay primitive) | event-driven (open/close + focus) | inline confirm panel in `actions_live.ex:609-779`; `select_theme/1` JS chaining `components.ex:209-213` | role-match (no existing overlay primitive) |
| `lib/rindle/admin/components.ex` → §D primitive fixes (theme_picker, live_indicator, table, skip-link, alert region) | component | request-response (render) | the same five primitives in `components.ex` | exact |
| `brandbook/src/admin-css-build.mjs` → scaffold grid / two-pane / motion / mobile-first / focus-visible / skip-link CSS | config (generator template strings) | transform (tokens → CSS) | the co-located `@media (max-width:760px)` block (~L946), `:focus-visible` block (~L927-942), `.rindle-admin-shell` grid (~L111-121) | exact (same generator, same idiom) |
| `brandbook/src/admin-css-build.mjs` → `requiredTokenUses` + `requiredSelectors` guards | config (fail-closed self-check) | transform | existing `requiredSelectors`/`requiredMetaSelectors`/`requiredTokenUses` arrays (~L989-1054) | exact |
| `lib/rindle/admin/queries.ex` → new run-detail function (D-98-09) | service (query) | CRUD (read + redact) | `asset_detail/1` (~L78-94), `upload_session_detail/1` (~L124-148) | exact |
| `lib/rindle/admin/router.ex` → new `variants-jobs/:id` `:show` route | route | request-response | `/assets/:id` (L97), `/upload-sessions/:id` (L100-104) | exact |
| `lib/rindle/admin/live/home_live.ex` → triage-home rebuild | controller (LiveView) | request-response (render off assigns) | `assets_live.ex` render + `home_live.ex` current structure | role-match (replacing `inspect/1` anti-pattern) |
| `lib/rindle/admin/live/assets_live.ex` → migrate onto `page/1` + caption/scope | controller (LiveView) | request-response | its own current `<table>` markup (L109-141) | exact (self-migration) |
| `lib/rindle/admin/live/upload_sessions_live.ex` → migrate onto `page/1` | controller (LiveView) | request-response | `assets_live.ex` migration | exact |
| `lib/rindle/admin/live/variants_jobs_live.ex` → migrate + `:show` + microcopy | controller (LiveView) | request-response | `assets_live.ex` `handle_params(%{"id"=>id})` detail render (L29-96) | exact |
| `lib/rindle/admin/live/runtime_doctor_live.ex` → migrate onto `page/1` | controller (LiveView) | request-response | `assets_live.ex` migration | exact |
| `lib/rindle/admin/live/actions_live.ex` → migrate + confirm→`confirm_dialog` + microcopy | controller (LiveView) | event-driven (confirm flows) | its own inline confirm panels (L609-779) | exact (self-migration) |
| `test/brandbook/admin_design_system_validation_test.exs` → new ExUnit clauses | test | static substring/regenerate scan | DS-01 (L40-100), ADMIN-02 (L204-256), `run_node/1` (L258-274), `assert_generated_clean/1` (L276-288) | exact |
| `examples/adoption_demo/e2e/support/admin-polish.js` → new sub-assertions | test (computed-style) | event-driven (per-state) | `assertFocusVisibleTokens` (L319), `assertTargetSizes` (L291), `freezeMotion` (L63), `assertAdminPolish` runner (L574) | exact |
| `examples/adoption_demo/e2e/admin-screenshots.spec.js` → bump `toHaveLength(22)` | test (orchestration) | event-driven | `expectedScreenshots`+`toHaveLength(22)` (L39-62, L146) | exact |

---

## Pattern Assignments

### `lib/rindle/admin/components.ex` — new `page/1` scaffold (component, request-response) — D-98-01

**Analog:** `shell/1` (L23-57) for `attr`/`slot`/`render_slot` idiom; `empty_state`/`error_state` (L123-143) for `:state` fallbacks; `table/1` (L172-178) for the bare-wrapper convention `page/1` must SUPERSEDE.

**`attr`/`slot` declaration idiom** (every component declares attrs immediately above the `def`):
```elixir
attr(:active, :string, required: true)
attr(:base_path, :string, default: "/admin/rindle")
attr(:title, :string, required: true)
slot(:inner_block, required: true)

def shell(assigns) do
  assigns = assign(assigns, :surfaces, surface_links(assigns.base_path))
  ~H"""
  ...
  """
end
```
For `page/1` declare (per UI-SPEC §A / D-98-01): `slot :summary`, `slot :filters`, `slot :work, required: true`, `slot :aside`, `slot :actions`, `attr :state, :atom, default: :ok`. Render slots in canonical DOM order with `render_slot/1`. The `:state` attr drives the existing empty/error/loading fallbacks so pages never re-implement them.

**State-fallback markup to reuse verbatim** (from `empty_state`/`error_state`, L123-143):
```elixir
def empty_state(assigns) do
  ~H"""
  <section class="rindle-admin-empty-state" data-rindle-admin-empty-state data-rindle-admin-state="empty">
    <h2 class="rindle-admin-empty-state__title">{@heading}</h2>
    <p>{@body}</p>
  </section>
  """
end
```
`page/1`'s `:state` branches should call these existing primitives, not duplicate the markup.

**Data hooks:** every primitive carries `data-rindle-admin-*` attributes (`data-rindle-admin-root`, `data-rindle-admin-surface`, `data-rindle-admin-empty-state`, `data-rindle-admin-state`). The scaffold root needs a `data-rindle-admin-*` seam so both test homes can target it.

**Grid is NOT inline** — the scaffold's `display:grid`/`grid-template-columns` lives in `admin-css-build.mjs` (see CSS section), authored against the scaffold's class selector (`.rindle-admin-shell` is the precedent at generator L111-121). Surface modules must NOT carry page-local grid (§A Composition gate).

---

### `lib/rindle/admin/components.ex` — new `modal/1` + `confirm_dialog/1` (overlay primitive) — D-98-11

**Analog (anti-pattern being replaced):** the inline confirm panels in `actions_live.ex:609-779` — `<div class="rindle-admin-action-panel">` with `<input data-rindle-admin-confirm-input>` and a submit button, NO focus trap, NO ESC, NO return-focus. There is no existing overlay/dialog/focus-wrap analog — this is net-new chrome.

**Closest JS-command analog** (`select_theme/1`, `components.ex:209-213`) for chaining `Phoenix.LiveView.JS` commands and how `JS` is aliased:
```elixir
alias Phoenix.LiveView.JS   # already at components.ex:6

defp select_theme(theme) when theme in ["light", "dark", "auto"] do
  JS.set_attribute({"data-theme", theme}, to: "[data-rindle-admin-root]")
  |> JS.set_attribute({"aria-pressed", "false"}, to: "[data-rindle-admin-theme]")
  |> JS.set_attribute({"aria-pressed", "true"}, to: ~s([data-rindle-admin-theme="#{theme}"]))
end
```
Build the open/close commands the same way (chained `JS.*`). Per RESEARCH (verified LV 1.1.30): use `Phoenix.Component.focus_wrap` (NOT a hand-rolled keydown trap), `JS.push_focus()`+`JS.focus_first(to: "#dialog")` on open, `JS.pop_focus()` on close, ESC via `phx-window-keydown phx-key="escape"`, and toggle `inert`+`aria-hidden` on `main`+`nav`. **Critical (D-98-11):** prefer server-assign-driven inert so a LiveView reconnect/dead-render re-renders correct state — never leave `main` inert.

**Confirm body/heading copy** comes from UI-SPEC §F (locked `"{Verb} this {noun}?"` shape, no "!"). `role="alertdialog"` for destructive confirms, `role="dialog"` otherwise; `aria-modal="true"` + `aria-labelledby`→title.

---

### `lib/rindle/admin/components.ex` — §D primitive a11y fixes (D-98-07)

**Analogs = the primitives themselves** (single-touch, all six surfaces inherit):

`theme_picker` (L59-67) — today hard-codes `aria-pressed` and flips via `JS.set_attribute` (client-only). Make server-authoritative: `aria-pressed={@theme == "light"}` etc., shell learns theme at mount and passes it down. Keep `JS.set_attribute` as progressive enhancement.

`live_indicator` (L71-78) — currently:
```elixir
<p class="rindle-admin-toast rindle-admin-toast--info" data-rindle-admin-live-indicator tabindex="0">
  <span aria-hidden="true">!</span>
  <span>{@copy}</span>
</p>
```
Fix: drop `tabindex="0"` (dead tab stop on non-interactive `<p>`); add `role="status"` + `aria-live="polite"` + `aria-atomic="true"`.

`table/1` (L172-178) — bare wrapper; caption/`<thead>`/`scope` fix rides the per-surface migration (D-98-08), not a standalone pass.

`shell/1` `<main>` (L45) — add `id="rindle-admin-main"` + `tabindex="-1"`, add skip-link as FIRST focusable child, add a persistent ASSERTIVE `role="alert"` region (empty at mount).

`error_state` (L134-143) — add `role="alert"`.

---

### `brandbook/src/admin-css-build.mjs` — new generated-CSS blocks (config/transform) — D-98-12..15

**Analog:** the co-located `@media (max-width:760px)` block (~L946-968, the SPEC's "L1087") and the `:focus-visible` block (L927-942) and the `.rindle-admin-shell` grid (L111-121). All CSS is a single growing `css` template string written once at L986 (`writeFileSync(adminCssPath, css)`), then byte-mirrored by `sync-admin-css.mjs`.

**Token-consuming selector idiom** (everything references `var(--rindle-*)`, never literals except media-query breakpoints):
```css
.rindle-admin-shell {
  display: grid;
  grid-template-columns: minmax(220px, 260px) minmax(0, 1fr);
  gap: var(--rindle-space-6);
  background: var(--rindle-surface);
  transition: background-color var(--rindle-motion-transition) var(--rindle-motion-easing-standard), color var(--rindle-motion-transition) var(--rindle-motion-easing-standard);
}
```
Note the EXISTING transition already enumerates exact properties (no `transition:all`) — Phase 98 motion blocks must do the same (§B gate).

**`:focus-visible` block to extend** (L927-942) — append any NEW interactive selectors (disclosure button, sort-th control, stacked-row tap target) to this comma list AND to `requiredSelectors`:
```css
.rindle-admin-button:focus-visible,
... ,
.rindle-admin-toast:focus-visible {
  outline: var(--rindle-focus-width) solid var(--rindle-focus-ring);
  outline-offset: var(--rindle-focus-offset);
}
```

**Media-query idiom + D-98-15 two-stop comment** — the existing block uses `max-width:760px` (desktop-first). D-98-12/14 convert it mobile-first and add two NEVER-CONFLATED `min-width` blocks:
```css
/* collapse point anchored on --rindle-bp-md (760px); literal because CSS media
   conditions cannot read custom properties */
@media (max-width: 760px) {
  .rindle-admin-shell { grid-template-columns: 1fr; }
  ...
}
@media (prefers-reduced-motion: reduce) {
  .rindle-admin-shell, ..., .rindle-admin-skeleton {
    transition-duration: 0ms; animation: none; transform: none;
  }
}
```
Author: `min-width:760` = SHELL sidebar `minmax(220px,260px) minmax(0,1fr)` ONLY; `min-width:1024` = `:aside` two-pane `minmax(0,1fr) minmax(320px,380px)` ONLY (D-98-15). Add a CSS comment marking 760 shell-only / 1024 :aside-only. Stacked-table: at <760 flip `table`/`tr`/`td` to `display:block` + `td::before { content: attr(data-label); }` (the reduced-motion block above is the template idiom for a property-collapse rule).

---

### `brandbook/src/admin-css-build.mjs` — fail-closed guards (D-98-13)

**Analog:** `requiredSelectors` (L989-1026), `requiredMetaSelectors` (L1030-1043), `requiredTokenUses` (L1046-1054). Each is a flat array `for`-checked against `written` (L1056-1060); a miss pushes to `missing` and `process.exit(1)`.
```js
const requiredTokenUses = [
  'var(--rindle-surface)', 'var(--rindle-text)', 'var(--rindle-focus-width)', ...
];
for (const token of requiredTokenUses) if (!written.includes(token)) missing.push(token);
```
Guard-1: add `'var(--rindle-shadow-card)'` to `requiredTokenUses` (confirmed ABSENT today — RESEARCH L294). Guard-2: add the new Phase-98 structural selectors (scaffold root, two-pane region, disclosure button, stacked-table `::before`) to `requiredSelectors`/`requiredMetaSelectors`.

---

### `lib/rindle/admin/queries.ex` — new run-detail function (service, CRUD) — D-98-09

**Analog:** `asset_detail/1` (L78-94) and `upload_session_detail/1` (L124-148).

**Detail-query idiom** (`with`-pipeline, UUID cast, `{:ok, map}` / `{:error, :not_found}`, `generated_at` stamp, redacted sub-rows):
```elixir
def upload_session_detail(session_id) when is_binary(session_id) do
  with {:ok, session_id} <- Ecto.UUID.cast(session_id),
       query = from(...),
       {session, profile} <- Config.repo().one(query) do
    {:ok, %{generated_at: DateTime.utc_now(), upload_session: upload_session_row(session, profile), asset: asset_detail_row(session.asset_id)}}
  else
    nil -> {:error, :not_found}
    :error -> {:error, :not_found}
  end
end
```

**Redaction parity** (module attrs + `defp` helpers, L23-24, L492-552):
```elixir
@redacted_session_uri "Redacted by Rindle Admin"
@redacted_provider_id "Provider identifier redacted"

defp redacted_provider_id(provider_asset_id) do
  case MediaProviderAsset.redact_id(provider_asset_id) do
    {:ok, redacted} -> redacted
    _redacted -> @redacted_provider_id
  end
end
```
The new run-detail must return one run's `error_reason`/attempt/worker with the same redaction discipline.

---

### `lib/rindle/admin/router.ex` — new `variants-jobs/:id` `:show` route — D-98-09

**Analog:** the `:show` routes inside `live_session` (L95-109):
```elixir
live(Path.join(path, "/assets/:id"), Rindle.Admin.Live.AssetsLive, :show)
live(Path.join(path, "/upload-sessions/:id"), Rindle.Admin.Live.UploadSessionsLive, :show)
```
Add immediately after the existing `variants-jobs` index (L106):
```elixir
live(Path.join(path, "/variants-jobs/:id"), Rindle.Admin.Live.VariantsJobsLive, :show)
```
Same module, `:show` action — no auth/macro change (the mount-validation macro at L58-111 is untouched).

---

### `lib/rindle/admin/live/*_live.ex` — six surface migrations onto `page/1` (controller) — D-98-02

**Best analog for the detail `:show` pattern:** `assets_live.ex` (the only surface with BOTH index and detail). Its `handle_params` split is exactly what `variants_jobs_live.ex` must gain (D-98-09):
```elixir
def handle_params(%{"id" => id}, _uri, socket), do: {:noreply, load_detail(socket, id)}
def handle_params(params, _uri, socket) do
  filters = take_filters(params, ~w(state profile kind))
  {:noreply, socket |> assign(filters: filters, detail: nil) |> load_list()}
end
```
And its two `render/1` clauses (detail-match head `render(%{detail: %{asset: _}} = assigns)` at L55 vs list head at L98).

**Current hand-rolled table markup being migrated** (`assets_live.ex:109-136`) — this whole `<table class="rindle-admin-table">` block moves INTO the scaffold `:work` slot; each `<td>` gains `data-label="State"` etc. (D-98-08) so §C's stacked-card CSS drives off the same markup:
```elixir
<table class="rindle-admin-table">
  <thead class="rindle-admin-table__head">
    <tr><th class="rindle-admin-table__cell" scope="col">State</th>...</tr>
  </thead>
  <tbody>
    <tr :for={asset <- @model.rows} class="rindle-admin-table__row" data-rindle-admin-row="asset">
      <td class="rindle-admin-table__cell"><.status_chip state={asset.state} label={asset.state} /></td>
      ...
    </tr>
  </tbody>
</table>
```
Add `<caption>` (visually-hidden ok) + `scope="row"` on the row-header cell during this migration. **One atomic commit per surface** (D-98-02 / gov.uk "never half-broken").

**PubSub re-render idiom to PRESERVE** (D-98-16 — no streams). Every surface (`home_live.ex:26`, `assets_live.ex:43-52`, `variants_jobs_live.ex:38`):
```elixir
def handle_info({:rindle_event, _event_type, _payload}, socket) do
  {:noreply, socket |> assign(:live_status, "Updated just now") |> load_list()}
end
```
Keep `load`/`load_list` into assigns + `:for` comprehension — do NOT introduce `phx-update="stream"`.

**`home_live.ex` triage rebuild (D-98-10):** replace the `inspect/1` anti-pattern (L56 `{inspect(recommendation)}`) with a GDS task-list of deep-link `<a href>`s off `Queries.home_status/1` (already returns `recommendations`+`counts`). Deep-links are pure `<a>` using the existing `admin_path/2` helper (`components.ex:186-194`), e.g. `admin_path(@admin_base_path, "variants-jobs?state=failed")` — NO new routes (D-98-10). DOM order: needs-attention → system-health → recent activity → vanity totals last (§E gate).

**`actions_live.ex` (D-98-10/F):** distribute the "Actions" verb-bucket; replace the inline confirm panels (L609-779) with the new `confirm_dialog/1`; apply §F microcopy fixes ("Regenerate Variants"→"Regenerate variants" L779, "Confirm broad regeneration" L773).

**`variants_jobs_live.ex` (D-98-09/F):** replace the borrowed `assets/#{...}` detail link (L104-110) with the new `variants-jobs/#{id}` route; add the `:show` render clause; replace L121 long diagnostic copy.

---

### `test/brandbook/admin_design_system_validation_test.exs` — new ExUnit clauses (test, static)

**Analog:** DS-01 (L40-100), ADMIN-02 (L204-256). Static gate idioms:

**Substring/selector presence over generated CSS** (DS-01, L50-78):
```elixir
css = read!("brandbook/tokens/rindle-admin.css")
for selector <- [".rindle-admin-shell", ".rindle-admin-table__row", ...] do
  assert css =~ selector
end
```
Add the new Phase-98 selectors (scaffold root, two-pane, disclosure, stacked `::before`, `data-label`) to this list — these are the UNCONDITIONAL §A/§B clauses (D-98-05).

**Regenerate-then-diff (drift gate)** (L99, L258-288):
```elixir
output = run_node("brandbook/src/admin-css-build.mjs")
assert output =~ "parity OK"
assert_generated_clean(["brandbook/tokens/rindle-admin.css"])
```
`run_node/1` shells to `node`; `assert_generated_clean/1` is `git diff --exit-code`.

**Source-scan over surfaces / `render_to_string` grep** — for §D DOM structure (caption/scope, `live_indicator role`, skip-link, server-rendered `aria-pressed`), §E nav order + deep-link hrefs, §F microcopy denylist + off-voice replacements. These are STATIC (D-98-05/06): assert over `render_to_string` of the surface or substring over the source file. `aria-pressed` MUST be asserted in dead/server-rendered markup (D-98-06 — a live read can't prove server-ownership). Contrast stays here too (`admin-contrast.mjs`, 58/58 — DS-03 L125-127, do NOT re-derive in browser).

**Forbidden-dependency regex over `@implementation_files`** (ADMIN-02, L241-250) — `admin-polish.js` is in that list, so new e2e checks must avoid Tailwind/daisy/etc. literals.

---

### `examples/adoption_demo/e2e/support/admin-polish.js` — new computed-style sub-assertions (test)

**Analog:** `assertFocusVisibleTokens` (L319-395), `assertTargetSizes` (L291-314), `freezeMotion` (L63-72).

**Offender-returning contract** (NEVER throw — return an array; `assertAdminPolish` L588-596 aggregates and throws once):
```js
async function assertTargetSizes(page, interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS) {
  return page.locator(interactiveSelectors.join(",")).evaluateAll((els, { MIN, TOL }) => {
    const out = [];
    for (const el of els) {
      const s = getComputedStyle(el);
      if (s.display === "none" || s.visibility === "hidden") continue;
      const r = el.getBoundingClientRect();
      if (r.width < MIN - TOL || r.height < MIN - TOL) out.push(`${el.tagName.toLowerCase()} ${r.width}x${r.height} < ${MIN}`);
    }
    return out;
  }, { MIN: MIN_TARGET_PX, TOL: SUBPIXEL_TOLERANCE });
}
```
New conditional clauses (D-98-05 Playwright home): responsive `display` flip at 759/761 + 1023/1025, `:focus-visible`-vs-pointer negative, dialog-open `inert`/`aria-hidden`, two-pane track count at safe-inside literal (≈900px, the §A↔§C band backstop), `::before content:attr(data-label)` resolution, reduced-motion `transitionDuration === "0s"`.

**Registration:** add each to the `assertAdminPolish` runner (L598-607 `run(...)` calls) and the `module.exports` (L625-641), against the default `[data-rindle-admin-root]` / `DEFAULT_INTERACTIVE_SELECTORS` seam (L21, L33) — do NOT generalize over Cohort (Phase 102).

**Pitfall (RESEARCH Pitfall 6):** `freezeMotion` (L63, injected by `assertAdminPolish` L583) sets `transition:none !important` — the reduced-motion `0s` assertion must run un-frozen or via `page.emulateMedia({ reducedMotion: "reduce" })` reading `transitionDuration` directly. Add new interactive selectors to `DEFAULT_INTERACTIVE_SELECTORS` so `assertFocusVisibleTokens`/`assertTargetSizes` cover them.

---

### `examples/adoption_demo/e2e/admin-screenshots.spec.js` — bump `toHaveLength` (test)

**Analog:** `expectedScreenshots` (L39-62, 22 entries) + `toHaveLength(22)` (L146) + `desktopCases`/`mobileCases` arrays (L18-37). Per D-98-06, net-new e2e STATES bump both `expectedScreenshots` and the literal IN LOCKSTEP (as 97-04 bumped 10→18). Many new checks (focus-visible, dialog-open, reduced-motion) can RIDE existing captures rather than adding screenshot states — count only distinct net-new viewport/theme/interaction states (planner discretion, RESEARCH Open Question 1).

---

## Shared Patterns

### `data-rindle-admin-*` selector seam
**Source:** `components.ex` (every primitive) + `admin-polish.js:21` `DEFAULT_ROOT = "[data-rindle-admin-root]"`
**Apply to:** the new `page/1` scaffold root, `modal/confirm_dialog`, and every new e2e check. Both test homes target these data attributes. Keep new e2e checks admin-root-only (the lane is already hard-fail; Phase-102 `{root, interactiveSelectors}` generalization must stay intact).

### `Phoenix.LiveView.JS` command chaining
**Source:** `components.ex:6` (`alias Phoenix.LiveView.JS`) + `select_theme/1` (L209-213)
**Apply to:** `modal/confirm_dialog` open/close commands, motion `JS.transition`/`JS.toggle` wiring. Chain with `|>`. `:time` on `JS.transition` MUST equal the CSS duration token (RESEARCH).

### Query result + redaction contract
**Source:** `queries.ex` `{:ok, %{generated_at: ...}}` / `{:error, :not_found}`, `@redacted_*` attrs (L23-24, L492-552)
**Apply to:** the new run-detail function. LiveViews pattern-match `{:ok, model}` / `{:error, reason}` into assigns (`assets_live.ex:167-183`).

### PubSub full re-render (NO streams)
**Source:** `handle_info({:rindle_event, _, _}, socket)` in every `*_live.ex`; `Support.subscribe_admin_lifecycle/1`
**Apply to:** all six migrated surfaces. D-98-16: keep `load`/`load_list` + `:for`; §B "stream row insert/remove" is N/A.

### Generated-CSS-only authoring + drift gate
**Source:** `admin-css-build.mjs` (single `css` string → `writeFileSync`) → `sync-admin-css.mjs` byte-mirror → DS-01 `assert_generated_clean` + ADMIN-02 byte-equality (`test:254-255`)
**Apply to:** ALL new selectors. NEVER hand-edit `brandbook/tokens/rindle-admin.css` or `priv/static/rindle_admin/rindle-admin.css` (D-98-12/14).

### Offender-returning e2e sub-assertion
**Source:** `admin-polish.js` (`assertFocusVisibleTokens`/`assertTargetSizes` return arrays; `assertAdminPolish` L588 aggregates)
**Apply to:** every new computed-style check. Never throw inside the check; return `offenders` and register in the runner + exports.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | — | — | Every Phase-98 artifact has a same-file or same-role analog. The closest-to-novel is `modal/1`/`confirm_dialog/1` (no existing overlay primitive — only the inline-panel anti-pattern in `actions_live.ex:609-779`); for it, lean on RESEARCH's verified `focus_wrap`/`JS.push_focus`/`pop_focus` idioms + the `select_theme/1` JS-chaining pattern, NOT a copied analog. |

---

## Metadata

**Analog search scope:** `lib/rindle/admin/` (components, queries, router, live/*), `brandbook/src/`, `test/brandbook/`, `examples/adoption_demo/e2e/`
**Files scanned:** components.ex, queries.ex, router.ex, home_live.ex, assets_live.ex, variants_jobs_live.ex, actions_live.ex (grep), admin-css-build.mjs (targeted L110-144, L920-1070), admin_design_system_validation_test.exs (full), admin-polish.js (targeted L21-95, L291-395, L574-641), admin-screenshots.spec.js (full)
**Pattern extraction date:** 2026-06-18
