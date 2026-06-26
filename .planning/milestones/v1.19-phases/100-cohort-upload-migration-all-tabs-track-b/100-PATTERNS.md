# Phase 100: Cohort `/upload` Migration (all tabs) [Track B] - Pattern Map

**Mapped:** 2026-06-18
**Files analyzed:** 4 (all MODIFIED — zero new files, zero new deps, zero new components)
**Analogs found:** 4 / 4 (every file has an in-repo, in-phase-99 proven analog)

> This is a frozen-contract CSS class-swap migration — the Track-B twin of Phase 99 applied to the
> one heavy page (`/upload`, 6 tabs) deliberately held back. Every primitive, scaffold, and gate
> already exists and is proven. **The planner/executor's job is to MIRROR the analogs below,
> preserving every `id`/`data-testid`/`phx-hook` byte-for-byte.** The two most error-prone artifacts
> — the ExUnit per-tab `for`-comprehension and the Playwright per-tab `test(...)` loop — have
> their exact shapes pinned in Pattern Assignment 3 and 4.

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex` | LiveView (view+render) | request-response (URL `?tab=` patch) + file-I/O (4 hooks, 2 live_file_input) | `ops_live.ex` + `dashboard_live.ex` | exact (same `ck_page` composition idiom) |
| `examples/adoption_demo/priv/static/assets/cohort.css` | config (hand-authored stylesheet) | transform (one token-only rule) | `.ck-tabs__tab[aria-selected="true"]` rule (`cohort.css:942`) | exact (same selector family, same file) |
| `examples/adoption_demo/e2e/cohort-pages.spec.js` | test (Playwright polish) | request-response (route-driven computed-style probe) | the existing `/dashboard`/`/ops` `test(...)` entries (`:76-167`) | exact (reuses exported `assertCohortPagePolish` unchanged) |
| `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` | test (ExUnit static contract) | transform (render → substring grep) | the existing per-page tests + `assert_frozen_contract/2`/`assert_daisyui_retired/1` (`:122-391`) | exact (reuses shared helpers; extends `@retired_daisyui_classes`) |

## Pattern Assignments

### 1. `upload_live.ex` (LiveView, request-response + file-I/O)

**Analog:** `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` (the cleanest `ck_page`
composition) + `dashboard_live.ex` (proves the `nav=` path + the testid-on-explicit-element idiom).

**A. Imports + theme assign** — mirror `ops_live.ex:1-25`:
```elixir
defmodule AdoptionDemoWeb.OpsLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents      # <- ADD this line to upload_live.ex (line ~2)
  ...
  def mount(_params, _session, socket) do
    ...
    {:ok, assign(socket, page_title: "...", theme: "light", ...)}   # <- ADD theme: "light"
```
For `upload_live.ex`: keep the existing `|> assign(...)` pipeline (`upload_live.ex:17-32`) and add
`|> assign(:theme, "light")` to it. Add `import AdoptionDemoWeb.CohortComponents` after the `use`.

**B. `ck_page` composition shell** — replace the bare `<Layouts.app>` body (`upload_live.ex:48-52`)
with the `ops_live.ex:30-35,89-91` wrap. Note `Layouts.app` is UNTOUCHED; only add `nav={:upload}`:
```elixir
<Layouts.app flash={@flash} page_title={@page_title} nav={:upload}>
  <.ck_page
    eyebrow="Upload lab"
    title="Every Rindle upload path, live."
    lede="Six ingest flows against real MinIO — presigned PUT, tus resume, multipart, LiveView server upload, AV variants, and Mux streaming. Pick a tab to run one end to end; the data is seeded, the uploads are real."
    theme={@theme}
  >
    <%!-- member line + tab strip + 6 panels go here --%>
  </.ck_page>
</Layouts.app>
```
`ck_page/1` signature (`cohort_components.ex:71-91`): `attr :title` (required), `:eyebrow`/`:lede`
(default nil), `:theme` (default `"light"`, `values: ~w(light dark)`). It emits the `.ck` div with
`data-ck-root` + `data-theme={@theme}` + `.ck__wrap` + `.ck-hero` — the polish-gate root for free.

**C. Member line testid on an explicit element** — `ck_page`'s `<h1>` cannot carry a testid, so the
load-bearing member line goes inside `:inner_block` as a `.ck-hero__lede` sibling, exactly as
`dashboard_live.ex:26` did with its title testid:
```elixir
# dashboard_live.ex:26 precedent (a testid on a .ck-hero__lede sibling, since the h1 can't carry one)
<p class="ck-hero__lede" data-testid="cohort-dashboard-title">...</p>
```
For `/upload` — keep the `<strong id=.. data-testid=..>` byte-for-byte (D-100-02b), wrapped in a
`.ck-hero__lede` line:
```elixir
<p class="ck-hero__lede">
  Member: <strong id="upload-member-name" data-testid="upload-member-name">{@member.name}</strong>
</p>
```

**D. Routed tab strip + `tab_link/1`** — restyle in place (D-100-03/04). Today
(`upload_live.ex:54-61, 146-156`):
```elixir
<div class="tabs tabs-boxed mt-4 flex flex-wrap gap-2">
  <.tab_link member={@member} tab="image" current={@tab} label="Image presigned PUT" />
  ...
</div>
# tab_link/1:
<.link patch={~p"/upload?member_id=#{@member.id}&tab=#{@tab}"} class={tab_class(@current, @tab)} data-testid={"upload-tab-#{@tab}"}>
  {@label}
</.link>
```
Restyle to:
```elixir
<div class="ck-tabs__list" role="navigation" aria-label="Upload strategy">
  <.tab_link member={@member} tab="image" current={@tab} label="Image (presigned PUT)" />
  ... (6 tabs; labels are display-only, D-100-08)
</div>
# tab_link/1 (KEEP the patch URL + data-testid byte-for-byte; swap class; add aria-current):
<.link
  patch={~p"/upload?member_id=#{@member.id}&tab=#{@tab}"}
  class="ck-tabs__tab ck-tab"
  aria-current={@current == @tab && "page"}
  data-testid={"upload-tab-#{@tab}"}
>
  {@label}
</.link>
```
Then **DELETE `defp tab_class/2` entirely** (`upload_live.ex:473-476`). `ck-tabs__tab` carries the
visuals/44px/focus ring; `ck-tab` (empty selector) keeps the polish gate's `interactiveSelector`
finding the element. `aria-current` (NOT `aria-selected`) is the navigation-correct cue.

**E. tus error → `.ck-error` + warning icon + `role="alert"`** — mirror `ck_field`'s error markup
(`cohort_components.ex:450-453`):
```elixir
<p :if={@errors != []} class="ck-error" id={@error_id} role="alert">
  {ck_icon(%{name: :warning})}
  <span>{Enum.join(@errors, " ")}</span>
</p>
```
`ck_icon/1` is **`defp`** (private). Minimal-scope path (RESEARCH A2 — recommended): copy the
warning SVG inline from `cohort_components.ex:606-624`. Apply to the tus error
(`upload_live.ex:81-83`), preserving `id="tus-upload-error"`, `data-testid`, `:if={@tus_error}`:
```elixir
<p :if={@tus_error} id="tus-upload-error" class="ck-error" role="alert" data-testid="tus-upload-error">
  <svg class="ck-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor"
       stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <path d="M10.3 3.7 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.7a2 2 0 0 0-3.4 0Z" />
    <path d="M12 9v4" /><path d="M12 17h.01" />
  </svg>
  <span>{@tus_error}</span>
</p>
```

**F. Status `<pre>`/`<p>` → `.ck-output`** — mirror `ops_live.ex:55-56,86-87` (the proven
status/debug surface):
```elixir
<pre :if={@doctor_output} id="doctor-output" class="ck-output" data-testid="doctor-output">{@doctor_output}</pre>
```
For `/upload`: swap each `class="font-mono text-sm"` status line (`upload_live.ex:65,80,92,104,114,125`)
to `class="ck-output"`, keeping every `id="X-upload-status"` + `data-testid`. Same for
`mux-streaming-url` (`:133-135`, drop `text-xs break-all` → `.ck-output`; scroll-not-wrap is
accepted per the Mux-URL caveat).

**G. Hook/submit `<button>` → `.ck-btn ck-btn--primary` on the EXISTING button** — mirror
`ops_live.ex:37-44` (a `phx-click` button keeping its id/testid/handler, class only swapped):
```elixir
<button id="run-doctor-button" phx-click="run_doctor" class="ck-btn ck-btn--primary" data-testid="run-doctor-button">
  Run doctor
</button>
```
Apply to `multipart-upload-button` (KEEP `phx-hook="MultipartUpload"`, `upload_live.ex:107-109`) and
the two `type="submit"` buttons (`:86,119`). **NEVER** `ck_button/1` — it renders `<.link href>`
(`cohort_components.ex:100-104`) and silently drops the hook/submit (Pitfall A).

**H. File inputs → `.ck-input`; descriptions + `image-upload-asset-id` → `.ck-help`** — add the
class to each bare `<input type="file" ... phx-hook=...>` (`:66-72,93-99,126-132`) and to each
`<.live_file_input>` (`:85,118`), preserving every attr. Description `<p class="text-sm">` and
`image-upload-asset-id` (`:73-75`) → `.ck-help`. Drop `mt-6 space-y-3` from the 6 `<div :if>` panel
wrappers (keep the `:if={@tab == "X"}` + `id`/`data-testid`).

> **Frozen contract (the hard constraint):** the 6 behavior specs key off testids/ids/hooks, not
> classes. Every `id`, `data-testid`, `phx-hook` (`PresignedPut`/`PresignedVideoPut`/`PresignedMuxPut`/
> `MultipartUpload`), `phx-change`/`phx-submit`, the 2 `<.form>`, the 2 `<.live_file_input>`, the
> `<div :if>` single-panel render, and the `?tab=` patch URL must survive byte-for-byte.

---

### 2. `cohort.css` (config, transform — ONE token-only rule, D-100-05)

**Analog:** the existing `.ck-tabs__tab[aria-selected="true"]` rule, **same file, `cohort.css:942-947`:**
```css
.ck-tabs__tab[aria-selected="true"] {
  /* non-color cue: underline + weight, in addition to color (D-96-17) */
  color: var(--ck-ink);
  font-weight: 700;
  border-bottom-color: var(--ck-brand);
}
```
**Add the navigation-correct `aria-current` cue** by consolidating the selectors (recommended — the
cue is defined once):
```css
.ck-tabs__tab[aria-selected="true"],
.ck-tabs__tab[aria-current="page"] {
  /* non-color cue: underline + weight, in addition to color (D-96-17/22) */
  color: var(--ck-ink);
  font-weight: 700;
  border-bottom-color: var(--ck-brand);
}
```
Place inside the existing tabs block (`:912-957`). **Token-only** (every value `var(--ck-*)`) — no
hex/rgb/named-color/raw-measure literal in the rule body, so it passes the brace-depth literal
scanner (D-96-09/20). **No new `--ck-*` token, no `tokens.json`, no generator.** Re-run
`node brandbook/src/cohort-contrast.mjs` as the sanity gate (stays green — no new token/pair).

---

### 3. `cohort_migration_contract_test.exs` (test, ExUnit static contract) — the per-tab `for`-comprehension

**Analog:** the existing per-page tests (`:122-391`) calling the shared helpers `assert_frozen_contract/2`
+ `assert_daisyui_retired/1` + `render_route/2`. The single-page tests (e.g. `/ops` `:182-211`) show
the exact shape; `/upload` differs only in wrapping a 6-entry `for` over `?tab=`.

**STEP 1 — extend `@retired_daisyui_classes`** (`:32-41`, Pitfall E). The existing list:
```elixir
@retired_daisyui_classes [
  ~s(class="btn"), "text-2xl", "text-lg", "bg-gray-", "list-disc", "opacity-80",
  "space-y-", "font-mono text-sm"
]
```
Add the `/upload`-specific strings NOT yet covered (mechanical, low-risk):
```elixir
  "tabs",          # catches "tabs tabs-boxed"
  "text-red-600",  # the old tus error color-only class
  ~s( tab ),       # the standalone "tab " token from the deleted tab_class/2
  "break-all"      # the old mux-streaming-url class
  # (consider "flex flex-wrap")
```

**STEP 2 — add ONE `/upload` test with a 6-entry per-tab `for` comprehension.** Mirror the
shared-helper idiom from the `/ops` test, wrapped in the `for tab <- ~w(...)` loop (exact shape from
RESEARCH Code Examples; this is the most error-prone artifact to author from scratch):
```elixir
# --- Plan: /upload per-tab frozen-contract + daisyUI-retirement (all 6 tabs) ---
# load_member!(nil) falls back to the first seeded member, so ?tab=X renders with no id.
# tus-upload-error / image-upload-asset-id / mux-streaming-url render only under their :if
# (after a handler fires) — DO NOT assert them statically; the behavior specs are their backstop.
test "/upload preserves its frozen contract and retires daisyUI across all tabs", %{conn: conn} do
  for tab <- ~w(image tus video multipart liveview mux) do
    html = render_route(conn, ~p"/upload?tab=#{tab}")

    # always-present (every tab): the member line + all 6 tab links + the .ck shell
    assert_frozen_contract(html, [
      ~s(data-testid="upload-member-name"),
      ~s(id="upload-member-name"),
      ~s(data-testid="upload-tab-image"),
      ~s(data-testid="upload-tab-tus"),
      ~s(data-testid="upload-tab-video"),
      ~s(data-testid="upload-tab-multipart"),
      ~s(data-testid="upload-tab-liveview"),
      ~s(data-testid="upload-tab-mux")
    ])

    # active-panel selectors per tab (only the :if-rendered panel is in the DOM)
    assert_frozen_contract(html, panel_contract(tab))

    assert_daisyui_retired(html)
  end
end

# planner: a small per-tab map → selector list. Suggested contents (each tab's id/testid/hook/form):
defp panel_contract("image"),
  do: [~s(id="image-upload-panel"), ~s(data-testid="image-upload-status"),
       ~s(id="image-file-input"), ~s(phx-hook="PresignedPut")]
defp panel_contract("tus"),
  do: [~s(id="tus-upload-panel"), ~s(data-testid="tus-upload-status"), ~s(id="tus-form"),
       ~s(phx-submit="save_tus"), ~s(id="tus-submit")]
defp panel_contract("video"),
  do: [~s(id="video-upload-panel"), ~s(data-testid="video-upload-status"),
       ~s(id="video-file-input"), ~s(phx-hook="PresignedVideoPut")]
defp panel_contract("multipart"),
  do: [~s(id="multipart-upload-panel"), ~s(data-testid="multipart-upload-status"),
       ~s(id="multipart-upload-button"), ~s(phx-hook="MultipartUpload")]
defp panel_contract("liveview"),
  do: [~s(id="liveview-upload-panel"), ~s(data-testid="liveview-upload-status"),
       ~s(id="liveview-form"), ~s(phx-submit="save_liveview"), ~s(id="liveview-submit")]
defp panel_contract("mux"),
  do: [~s(id="mux-upload-panel"), ~s(data-testid="mux-upload-status"),
       ~s(id="mux-file-input"), ~s(phx-hook="PresignedMuxPut")]
```
> `assert_frozen_contract/2` (`:71-84`) already asserts `data-ck-root` is present and refutes `raw(`.
> `assert_daisyui_retired/1` (`:91-100`) scopes its scan to the `page_body/1` `data-ck-root` subtree,
> so `Layouts.app`'s own `space-y-4` chrome never false-positives. Reuse both UNCHANGED.

---

### 4. `cohort-pages.spec.js` (test, Playwright polish) — the per-tab `test(...)` loop + 1 dark case

**Analog:** the existing `/dashboard`/`/ops` entries (`:76-83`) calling the exported
`assertCohortPagePolish(page, {route, surface})`. The helper (`:48-62`) is reused UNCHANGED (D-96-06):
it `goto`s, waits for the LiveSocket, asserts `[data-ck-root]` visibility FIRST (Pitfall D guard),
then runs `assertAdminPolish` over `[data-ck-root]`/`.ck-*` in warn mode.
```javascript
// existing single-route precedent (cohort-pages.spec.js:82-84):
test("/ops renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await assertCohortPagePolish(page, { route: "/ops", surface: "ops-cohort" });
});
```

**Add 6 per-tab cases via a `for` loop + 1 dark case** (exact shape from RESEARCH Code Examples):
```javascript
// /upload migrated onto ck_page/1 — prove all 6 tabs via the deterministic ?tab= URL.
// load_member!(nil) falls back to the first seeded member, so no id is needed.
for (const tab of ["image", "tus", "video", "multipart", "liveview", "mux"]) {
  test(`/upload?tab=${tab} renders on the Cohort DS (polish, warn mode)`, async ({ page }) => {
    await assertCohortPagePolish(page, {
      route: `/upload?tab=${tab}`,
      surface: `upload-${tab}-cohort`,
    });
  });
}

// +1 dark case on the image tab. SEE Pitfall F (the one CONTEXT-mechanism correction):
// emulateMedia({colorScheme:"dark"}) ALONE will NOT flip the theme — ck_page always emits an
// explicit data-theme="light", which is authoritative over the @media fallback. Drive the dark
// case via a SERVER ?theme=dark assign (requires the upload_live.ex change in note below).
test("/upload?tab=image renders on the Cohort DS in dark (polish, warn mode)", async ({ page }) => {
  await assertCohortPagePolish(page, {
    route: "/upload?tab=image&theme=dark",
    surface: "upload-image-dark-cohort",
  });
});
```
> `interactiveSelectors` (`:25` — already includes `.ck-tab`) and `reportPolish` (`:30-40`) are
> reused unchanged. Do NOT inline a bypass of the `[data-ck-root]` guard (Pitfall D).

## Shared Patterns

### `ck_page/1` composition (applies to: `upload_live.ex`)
**Source:** `cohort_components.ex:71-91` (scaffold); `ops_live.ex:30-91` + `dashboard_live.ex:24-25`
(usage). Compose inside the UNTOUCHED `Layouts.app` (`nav={:upload}`); server theme via
`assign(:theme, "light")`. The scaffold emits `data-ck-root` + `data-theme` on the `.ck` div, giving
`/upload` the polish-gate seam, focus-visible ring, reduced-motion block, and box-sizing for free.

### Class-on-existing-element (applies to: `upload_live.ex` buttons, inputs, status, error)
**Source:** `ops_live.ex:37-56` (buttons + `.ck-output`); `ck_field` error markup
`cohort_components.ex:450-453`; `ck_icon(:warning)` SVG `cohort_components.ex:606-624`.
**Rule:** swap the class string only; keep the element, its `id`/`data-testid`/`phx-*`/`type` intact.
Never substitute a component (`ck_button`/`ck_tabs`) that would restructure the DOM or drop a hook.

### Extend-not-fork the gates (applies to: both test files)
**Source:** `cohort_migration_contract_test.exs:71-100` (`assert_frozen_contract`/`assert_daisyui_retired`/
`page_body`); `cohort-pages.spec.js:48-64` (`assertCohortPagePolish` + exports). Reuse the shared
helpers UNCHANGED; add new `test(...)` entries only. `admin-polish.js` is NOT edited (D-96-06).

## Dark-Case Server-Theme Note (the one CONTEXT-mechanism correction — RESEARCH Pitfall F / Open Q1)

The dark polish case requires a server-driven `data-theme="dark"`. Recommended option (RESEARCH
option 1): add a validated `?theme=dark` param read in `upload_live.ex` `mount`/`handle_params` so the
existing `assign(:theme, ...)` can become `"dark"`, falling back to `"light"` for any other value
(the `ck_page` `:theme` attr already enforces `values: ~w(light dark)`). This is a tiny,
server-state-consistent addition (D-96-07/16) that actually proves the upload surface in dark — and
is the only option satisfying COHORT-02's "light/dark covers the upload surface" wording. The
planner should flag this as the single place CONTEXT's stated mechanism (`emulateMedia` alone) is
corrected. (`handle_params` reads `params["tab"]` today at `upload_live.ex:38-43`; the `theme` read
follows the same idiom.)

## No Analog Found

None. Every file in scope has an exact, in-repo, Phase-99-proven analog. Zero files fall back to
RESEARCH-only patterns.

## Metadata

**Analog search scope:** `examples/adoption_demo/lib/adoption_demo_web/live/`,
`examples/adoption_demo/lib/adoption_demo_web/components/`, `examples/adoption_demo/e2e/`,
`examples/adoption_demo/test/adoption_demo_web/live/`, `examples/adoption_demo/priv/static/assets/`.
**Files read (analogs):** `upload_live.ex` (target), `ops_live.ex`, `dashboard_live.ex` (excerpt),
`cohort_components.ex` (excerpts: `ck_page`, `ck_field`, `ck_icon`), `cohort.css` (tabs block
`:908-957`), `cohort_migration_contract_test.exs`, `cohort-pages.spec.js`.
**Pattern extraction date:** 2026-06-18
