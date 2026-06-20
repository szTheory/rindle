# Phase 100: Cohort `/upload` Migration (all tabs) [Track B] — Research

**Researched:** 2026-06-18
**Domain:** Phoenix LiveView 1.1 design-system migration — porting the heaviest inner page (`upload_live.ex`, 6 tabs, 4 `phx-hook` upload flows + 2 `live_file_input`) onto the hand-authored `.ck-*` Cohort DS, class-by-class, preserving a frozen DOM contract; the Track-B twin of the already-shipped Phase 99.
**Confidence:** HIGH

## Summary

This is **composition + class-swap + frozen-contract preservation, NOT construction.** Every primitive (`ck_page/1`, `.ck-tabs__tab`/`.ck-tabs__list`, `.ck-output`, `.ck-error`, `.ck-input`, `.ck-btn`/`--primary`, `.ck-help`, the `ck_icon(:warning)` markup), the warn-mode polish harness (`assertCohortPagePolish`), and the ExUnit frozen-contract/daisyUI-retirement module already exist, are token-clean, dark/light-correct, and were proven against `/styleguide` + the 7 small pages in Phase 99. CONTEXT.md locks decisions D-100-01..08 at HIGH confidence; **this research confirms every one against the live codebase** and surfaces the corrections/landmines the planner needs.

The decisive structural fact (verified by reading `upload_live.ex` in full): today `/upload` renders `<Layouts.app flash={@flash} page_title={@page_title}>` (NO `nav`, line 48) wrapping a bare `<h1 class="text-2xl">`, a daisyUI `tabs tabs-boxed` strip (`:54-61`) of `<.link patch>` tabs, and six `:if={@tab == …}` single-panel renders (`:63-136`) full of `font-mono text-sm` status `<p>`s, a `text-red-600` tus error, bare file `<input>`s + two `<.live_file_input>`, three `<button>`s (one carrying `phx-hook="MultipartUpload"`, two `type=submit`), and a `tab_class/2` helper (`:473`) emitting `tab px-3 py-1 rounded border [bg-gray-200]`. None of it carries `.ck` / `data-ck-root` / `data-theme`, so the focus-visible ring, reduced-motion block, box-sizing, and the polish gate's `[data-ck-root]` seam do not reach `/upload` at all. Establishing the `.ck` shell (by composing the existing UNUSED `ck_page/1`, exactly as `ops_live.ex` and `dashboard_live.ex` do) and swapping the body classes onto existing `.ck-*` primitives is the entire phase.

**Primary recommendation:** Mirror the proven Phase 99 recipe one-to-one on `/upload`: compose `ck_page/1` inside the untouched `Layouts.app` (now `nav={:upload}`), restyle the routed tab strip as `.ck-tabs__list` of `.ck-tabs__tab ck-tab` links with `aria-current="page"` (delete `tab_class/2`), add the ONE token-only `.ck-tabs__tab[aria-current="page"]` CSS rule, class-swap the six panels onto `.ck-output`/`.ck-error`/`.ck-input`/`.ck-btn`/`.ck-help` preserving every id/testid/hook byte-for-byte, and extend (never fork) the two Phase-99 harnesses to prove `/upload` as six `?tab=`-driven variants. **Zero new deps, zero new components, exactly one tiny token-only CSS rule.**

<user_constraints>
## User Constraints (from 100-CONTEXT.md)

### Locked Decisions
- **D-100-01:** `/upload` gets its `.ck` shell by **composing the existing `ck_page/1` scaffold** (built UNUSED in Phase 99-01) — NOT a `Layouts.app` `ck`-mode, NOT a bespoke inline shell, NOT a new scaffold variant. Mechanics: `import AdoptionDemoWeb.CohortComponents`; `assign(:theme, "light")` in `mount/2` (server-owned, no localStorage); wrap the body in `<Layouts.app … nav={:upload}>` → `<.ck_page eyebrow=… title=… lede=… theme={@theme}>` → existing body. **`Layouts.app` is UNTOUCHED** (daisyUI `<main>`/`<link>` retirement is strictly Phase 101).
- **D-100-02a:** **Pass `nav={:upload}`** (today `/upload` does not set it) so `cohort_nav` highlights the active section.
- **D-100-02b:** The member line `<strong id="upload-member-name" data-testid="upload-member-name">{@member.name}</strong>` is **load-bearing — keep it byte-for-byte** as a `.ck` line inside `:inner_block` (or a `.ck-hero__lede` sibling).
- **D-100-03:** **Keep the server-driven URL-`patch` tab model.** Restyle the tab links onto `.ck-*`; do **NOT** adopt the `ck_tabs/1` client widget and do **NOT** add `role=tab`/`role=tablist`. (Routed tabs that change the URL = navigation → links + `aria-current`, never `role=tablist`.)
- **D-100-04:** There is **no standalone styled `.ck-tab` selector** — `.ck-tab` is empty, a polish-gate `interactiveSelector` hook only; all tab styling lives on **`.ck-tabs__tab`**. Apply `class="ck-tabs__tab ck-tab"` to the existing `<.link>`, wrap the strip in `<div class="ck-tabs__list" role="navigation" aria-label="Upload strategy">`, mark the active link `aria-current={@current == @tab && "page"}` (navigation-correct), and **delete `tab_class/2`**. Keep every `data-testid="upload-tab-#{tab}"` and the `<div :if={@tab == …}>` single-panel render byte-for-byte.
- **D-100-05:** **One tiny token-only CSS rule** (the single new CSS): add `.ck-tabs__tab[aria-current="page"]` mirroring the existing `[aria-selected="true"]` rule (color/weight/border-bottom-color via tokens only). May be consolidated as `.ck-tabs__tab[aria-selected="true"], .ck-tabs__tab[aria-current="page"]`.
- **D-100-06:** Class-only swap with **ZERO new `.ck-*` rules** beyond D-100-05. Preserve byte-for-byte every panel/status `id`+`data-testid`, the 4 `phx-hook`s, the 2 `<.live_file_input>`, the 2 `<.form phx-change/phx-submit>`, all file `<input>` attrs, the 3 `<button>`s, `tus-upload-error`, `image-upload-asset-id`, `mux-streaming-url`. Mapping (see Per-Element Class Map below).
- **D-100-07:** **Extend (never fork)** both Phase-99 harnesses; prove `/upload` as **SIX `?tab=`-driven variants** in each gate + **one dark case** on the image tab.
- **D-100-08:** Header microcopy — eyebrow `Upload lab`; title `Every Rindle upload path, live.`; lede (see CONTEXT); optional tab-label tightenings.

### Claude's Discretion
Exact `surface:` strings, the `aria-label` wording, whether to consolidate the `aria-current`/`aria-selected` selectors, the precise icon SVG reused for `.ck-error` (use `ck_icon(%{name: :warning})`), the per-tab `for`-comprehension layout in the ExUnit test, and whether to additionally assert a `data-theme` marker on the light cases — all resolvable during planning, provided the locked decisions hold, the frozen DOM contract is preserved, and **no `cohort.css` token VALUE / `tokens.json` / `admin-polish.js` is edited.**

### Deferred Ideas (OUT OF SCOPE)
- daisyUI `<link>`/`default.css` retirement + the `Layouts.app` daisyUI `<main>` wrapper → **Phase 101 (COHORT-05)**.
- warn→fail flip of the polish gate + VIS-* re-converge / idempotency / cross-surface audit → **Phase 102**.
- Any `cohort.css` token-VALUE or `tokens.json` change; the admin (`rindle-admin`) surfaces.
- Higher-value upload UX (drag-and-drop, live percent/byte progress bar, per-entry preview/cancel, human-readable status microcopy) — all require DOM/behavior change, out of class-only scope → future ticket.
- Optional non-blocking pixel-baseline screenshots → later milestone work.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COHORT-02 | `/upload` (all tabs) restyled onto the Cohort DS (`cohort.css` + `cohort_components.ex`), migrated class-by-class, every `id`/`data-testid`/`phx-hook` (incl. `PresignedPut`, `MultipartUpload`, `Copy`) preserved, behavior e2e green across tabs, a light/dark polish case covering the upload surface. | The Per-Element Class Map + the `ck_page` composition precedent (`ops_live.ex`/`dashboard_live.ex`) + the extend-not-fork harness plan below cover it. All target `.ck-*` primitives EXIST and are verified present in `cohort.css`. One token-only `.ck-tabs__tab[aria-current="page"]` rule is the sole new CSS. |
</phase_requirements>

## CONTEXT Validation — Canonical Refs Verified Against Live Code

> Every `<canonical_refs>` line reference in CONTEXT.md was checked against the current files. **All accurate.** Drift/correction notes are flagged explicitly below.

| CONTEXT claim | Verified? | Evidence |
|---|---|---|
| `upload_live.ex` tab strip `:54-61` | ✅ | `<div class="tabs tabs-boxed mt-4 flex flex-wrap gap-2">` + 6 `<.tab_link>` at `:54-61` |
| `tab_link/1` `:146` | ✅ | `defp tab_link(assigns)` at `:146`; renders `<.link patch={~p"/upload?member_id=#{@member.id}&tab=#{@tab}"} class={tab_class(@current,@tab)} data-testid={"upload-tab-#{@tab}"}>` |
| `tab_class/2` `:473` (to delete) | ✅ | `defp tab_class(current, tab)` at `:473-476`, emits `"tab px-3 py-1 rounded border"` (+ `" bg-gray-200"` when active) |
| 6 panels `:if` `:63-136` | ✅ | image `:63`, tus `:78`, video `:90`, multipart `:102`, liveview `:112`, mux `:123` |
| `handle_params`/`?tab=` `:38-43` | ✅ | `handle_params` reads `params["tab"]` at `:38-43`; `mount` reads it at `:14-22` |
| `load_member!(nil)` fallback | ✅ | `:469` — `Accounts.list_members() |> List.first()` (member-less `?tab=` URLs render) |
| `Layouts.app` NO `nav` today | ✅ | `:48` `<Layouts.app flash={@flash} page_title={@page_title}>` — no `nav` attr |
| `cohort.css` `--ck-maxw: 64rem` `:108` | ✅ | exact, `:108` |
| tabs block `:912-957`, NO standalone `.ck-tab` | ✅ | `.ck-tabs`/`.ck-tabs__list`/`.ck-tabs__tab`/`[aria-selected="true"]`/`[aria-disabled]`/`__panel:focus-visible` at `:912-957`. **No `.ck-tab` selector exists anywhere** (D-100-04 confirmed) |
| `.ck-output` `:461` | ✅ | exact, `:461-471`; `white-space: pre` + `overflow-x: auto` (see Mux-URL caveat) |
| `.ck-input`/`.ck-btn`/`.ck-btn--primary`/`.ck-help`/`.ck-error` exist | ✅ | `.ck-btn` `:326`, `--primary` `:352`, `.ck-input` `:860`, `.ck-help` `:893`, `.ck-error` `:898` |
| `ck_page/1` UNUSED scaffold | ✅ | `cohort_components.ex:78`, attrs `:title`(req)/`:eyebrow`/`:lede`/`:theme`(default `"light"`, `values: ~w(light dark)`)/`:rest`; renders `.ck` + `data-ck-root` + `data-theme` + `.ck__wrap` + `.ck-hero` |
| `ck_button/1` link-only (Pitfall 4) | ✅ | `:100` renders `<.link>` — cannot carry `phx-hook`/`type=submit` |
| `ck_field`/`ck_icon` error idiom | ✅ | `ck_field` `:436` renders `<p class="ck-error" role="alert">{ck_icon(%{name: :warning})} …</p>` at `:450-451`; `ck_icon(%{name: :warning})` defined `:606` |
| `Layouts.app` `nav={:upload}` support | ✅ | `layouts.ex:32` `attr :nav` doc lists `:upload`; `cohort_nav` (`cohort_components.ex:24`) already wires `aria-current={@active == :upload && "page"}` on the Upload link |
| `cohort-pages.spec.js` exports `assertCohortPagePolish` + warn-mode `reportPolish` + `interactiveSelectors` (incl. `.ck-tab`) | ✅ | `:25` `interactiveSelectors = [".ck-btn", ".ck-tab", ".ck-input", ".ck-select"]`; `:48` helper; `:64` exports |
| `cohort_migration_contract_test.exs` exports `assert_frozen_contract/2`, `assert_daisyui_retired/1`, `render_route/2`, `page_body/1` | ✅ | all present `:47-100`; `@retired_daisyui_classes` `:32-41` |
| `tus-resume.spec.js` uses `?tab=tus` deep link | ✅ | `e2e/tus-resume.spec.js:6` `page.goto("/upload?tab=tus")` — load-bearing; do NOT break the `?tab=` patch (D-100-03 rationale) |
| `ops_live.ex`/`dashboard_live.ex` `ck_page` composition precedent | ✅ | both `import AdoptionDemoWeb.CohortComponents`, `assign(theme: "light")` in mount, `<Layouts.app …>` → `<.ck_page … theme={@theme}>` → body. `dashboard` passes `nav={:app}` proving the `nav` path |

**No drift found in any line reference.** Three corrections/landmines surfaced (below): the dark-case mechanism, the daisyUI-retirement list needs new entries, and the Mux-URL `white-space: pre`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `.ck` page shell (root, theme, wrap, focus-visible, reduced-motion, box-sizing) | `ck_page/1` (composed; EXISTS) | `cohort.css` `.ck`/`.ck__wrap` base rules (EXIST) | Today only `Layouts.app`'s daisyUI `<main>` wraps `/upload`; the `.ck` shell must be (re)introduced per-LiveView (D-96-05) — by composing `ck_page`, exactly as ops/dashboard do |
| Server-owned theme (`data-theme`) | `UploadLive.mount` `assign(:theme, "light")` → `ck_page` attr | client (none — no localStorage) | Deterministic for e2e; mirrors ops/dashboard |
| Routed tab navigation (URL `?tab=` patch) | `UploadLive` `<.link patch>` + `handle_params` (UNCHANGED behavior; classes only) | `cohort.css` `.ck-tabs__list`/`.ck-tabs__tab` + the one new `[aria-current]` rule | URL-addressable, shareable, back-button-correct → links + `aria-current`, NOT `role=tablist` (D-100-03/04) |
| Upload flows (4 `phx-hook`, 2 `live_file_input`, 2 forms, status/error UX) | `UploadLive` handlers + JS hooks (UNCHANGED — frozen contract) | `cohort.css` `.ck-input`/`.ck-btn`/`.ck-output`/`.ck-error`/`.ck-help` | Class-only swap; every id/testid/hook/submit preserved byte-for-byte |
| Page chrome (nav + footer) | `Layouts.app` (`cohort_nav`/`cohort_footer` — already `.ck-*`) | — | Already migrated; pass `nav={:upload}` for active-state. Untouched otherwise |
| Per-tab polish/contrast gate | Playwright `cohort-pages.spec.js` calling `assertCohortPagePolish` over `[data-ck-root]` | `admin-polish.js` (reused UNCHANGED, D-96-06) | Warn mode this phase; 6 per-tab cases + 1 dark |
| Frozen-contract preservation proof | ExUnit `cohort_migration_contract_test.exs` (`render_route` grep) + 6 behavior specs | — | id/testid/hook survival + daisyUI retirement; behavior specs are the runtime backstop |

## Standard Stack

### Core (all already present — this phase installs ZERO new packages)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | 1.1.30 `[VERIFIED: examples/adoption_demo/mix.lock, Phase 99]` | `UploadLive` is a LiveView; `live_file_input`, `allow_upload`, `consume_uploaded_entries`, `attr`/`slot` | Already the demo's render layer |
| `AdoptionDemoWeb.CohortComponents` | in-repo | `ck_page/1` to compose; `ck_icon(:warning)` for the error icon | Built + proven Phases 96/99 |
| `cohort.css` (hand-authored, vendored) | in-repo | `.ck-*` stylesheet; light/dark tokens, motion, focus | Built Phase 96; already linked globally in `root.html.heex` |
| `@playwright/test` | existing `adoption-demo-e2e` lane | Per-tab polish cases + the 6 behavior specs | The lane is already merge-blocking and boots `mix phx.server` + seeds + MinIO |

### Supporting (existing, reused UNCHANGED)
| Asset | Purpose | When to Use |
|-------|---------|-------------|
| `assertCohortPagePolish(page, {route, surface})` (`e2e/cohort-pages.spec.js`) | warn-mode polish runner; goto → `waitForLiveSocket` → `[data-ck-root]` guard → `assertAdminPolish` reused unchanged | 6 per-tab `test(...)` entries, each `route: "/upload?tab=X"` |
| `assert_frozen_contract/2` + `assert_daisyui_retired/1` + `render_route/2` + `page_body/1` (`cohort_migration_contract_test.exs`) | static id/testid/hook survival + daisyUI retirement, scoped to the `data-ck-root` body subtree | one `/upload` test with a 6-entry per-tab `for` comprehension |
| `support/liveview.js` `waitForLiveSocket` | await LiveView connect | inside `assertCohortPagePolish` (already wired) |
| `admin-polish.js` `assertAdminPolish({root, interactiveSelectors})` | computed-style polish (focus ring, 44px target, contrast) | reused UNCHANGED via the harness (D-96-06 — do NOT edit) |
| `brandbook/src/cohort-contrast.mjs` | token-pair parity + literal scanner + contrast | re-run as a sanity gate; the new `[aria-current]` rule is token-only so it stays green (no new token/pair) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ck_page/1` composition | `Layouts.app` `ck`-mode / bespoke inline shell | Rejected by D-100-01 — composing the proven scaffold matches ops/dashboard and avoids touching `Layouts.app` (Phase 101 scope) |
| `<.link patch>` + `aria-current` tabs | `ck_tabs/1` WAI-ARIA in-page widget | Rejected by D-100-03 — `ck_tabs/1` is the in-page case (`role=tab`, all panels in DOM, `phx-hook="Tabs"`); adopting it would restructure the DOM, break the `?tab=` patch + the `tus-resume` `?tab=tus` deep link, and regress a11y for a routed surface |
| `.ck-btn` on existing `<button>` | `ck_button/1` | Rejected — `ck_button/1` renders `<.link>` and would silently drop `phx-hook="MultipartUpload"` / `type=submit` (Pitfall: link-only) |
| `.ck-output` for status | `badge/1` enum pill | Rejected — status is open-ended system output incl. `error: <reason>`, NOT an enum |

**Installation:** None. No `mix deps.get`, no `npm install`, no `tokens.json` edit, no new `.mjs`, no new component.

**Version verification:**
```bash
grep -n "phoenix_live_view" /Users/jon/projects/rindle/examples/adoption_demo/mix.lock   # 1.1.30
```

## Package Legitimacy Audit

> **N/A — this phase installs ZERO external packages.** It composes existing in-repo components (`CohortComponents`), the existing hand-authored `cohort.css`, and existing test harness modules. No npm/hex/PyPI dependency is added. (`@playwright/test`, `phoenix_live_view`, and the `cohort-contrast.mjs` gates pre-exist and were vetted in Phases 94/96/99.)

## Architecture Patterns

### System Architecture Diagram

```
            root.html.heex  (UNCHANGED — links default.css + cohort.css globally)
                              │  <body>{@inner_content}</body>
                              ▼
   ┌──────────────────── Layouts.app/1  (UNTOUCHED — Phase 101 retires the daisyUI <main>) ───────────┐
   │  <.cohort_nav active={@nav}/>   ← pass nav={:upload} (D-100-02a) → Upload link gets aria-current   │
   │  <main class="px-4 py-8 …"><div class="mx-auto max-w-3xl space-y-4">  ← daisyUI TODAY (kept)        │
   │     {render_slot(@inner_block)}                                                                     │
   │  <.cohort_footer/>                                                                                  │
   └────────────────────────────────────────────────────────────────────────────────────────────────────┘
                              │  MIGRATE the body ▼
   ┌──────── <.ck_page eyebrow="Upload lab" title="Every Rindle upload path, live." lede=… theme={@theme}> ┐
   │  <div class="ck" data-ck-root data-theme={@theme}>  ← shell (focus ring/reduce/box-sizing/polish seam)│
   │    <div class="ck__wrap">   (--ck-maxw: 64rem — wider than today's max-w-3xl)                          │
   │      <header class="ck-hero"> eyebrow / title / lede                                                   │
   │      <strong id="upload-member-name" data-testid="upload-member-name">  ← KEEP byte-for-byte (D-100-02b)│
   │                                                                                                         │
   │      <div class="ck-tabs__list" role="navigation" aria-label="Upload strategy">   ← restyled tab strip │
   │         6× <.link patch={~p"/upload?...&tab=X"} class="ck-tabs__tab ck-tab"                             │
   │                 aria-current={@current == @tab && "page"} data-testid="upload-tab-X"> (delete tab_class)│
   │                                                                                                         │
   │      <div :if={@tab == "X"} id="X-upload-panel" data-testid="X-upload-panel">  ← SINGLE-PANEL :if KEPT  │
   │         status <p> → .ck-output  | tus error <p> → .ck-error+icon+role=alert | inputs → .ck-input       │
   │         hook/submit <button> → .ck-btn ck-btn--primary (NEVER ck_button) | desc → .ck-help              │
   │         ── every id / data-testid / phx-hook / phx-change / phx-submit PRESERVED byte-for-byte ─────────│
   └──────────────────────────────────────────────────────────────────────────────────────────────────────┘
                              │
   polish gate: assertCohortPagePolish(page,{route:"/upload?tab=X", surface:"upload-X-cohort"})  (warn mode, ×6 + 1 dark)
   frozen gate: ExUnit per-tab assert_frozen_contract + assert_daisyui_retired over ~p"/upload?tab=X"
   behavior gate: image/video/multipart/liveview/mux/tus *.spec.js stay green (UNCHANGED — key on testids/ids, not classes)
```

### Pattern 1: `ck_page/1` composition (mirror `ops_live.ex:30-89` / `dashboard_live.ex:24-112`)
**What:** Import `CohortComponents`, assign `theme: "light"` in `mount`, wrap the body in `Layouts.app … nav={:upload}` → `ck_page` → existing body.
**Example (grounded in the verified ops/dashboard precedent):**
```elixir
# mount/2: add to the assign pipeline (server-owned theme, D-96-07/16)
|> assign(:theme, "light")

# render/1:
<Layouts.app flash={@flash} page_title={@page_title} nav={:upload}>
  <.ck_page
    eyebrow="Upload lab"
    title="Every Rindle upload path, live."
    lede="Six ingest flows against real MinIO — presigned PUT, tus resume, multipart, LiveView server upload, AV variants, and Mux streaming. Pick a tab to run one end to end; the data is seeded, the uploads are real."
    theme={@theme}
  >
    <p class="ck-hero__lede">
      Member: <strong id="upload-member-name" data-testid="upload-member-name">{@member.name}</strong>
    </p>
    <%!-- tab strip + 6 panels (class-swapped) --%>
  </.ck_page>
</Layouts.app>
```
> Note: `UploadLive` (`use AdoptionDemoWeb, :live_view`) gets `Layouts` via the web macro (as ops/dashboard do); add `import AdoptionDemoWeb.CohortComponents` for `ck_page` (and, if the planner inlines the error icon, `ck_icon` is private — prefer reusing the `ck_field`/`ck_detail` error markup pattern by hand, or render `ck_field` is overkill; the simplest is a literal `<p class="ck-error" role="alert">…</p>` mirroring `cohort_components.ex:450-451`, but the warning SVG itself is `ck_icon/1` which is `defp` — the planner should either (a) copy the `ck_icon(:warning)` inline SVG markup from `cohort_components.ex:606` into the panel, or (b) promote `ck_icon` to a public `attr`-ed component if reuse is wanted; option (a) keeps scope minimal and is recommended).

### Pattern 2: Routed-tab restyle (the decisive call — D-100-03/04)
**What:** Keep `<.link patch>` URL navigation; restyle as `.ck-tabs__list` of `.ck-tabs__tab ck-tab` links with `aria-current`. Delete `tab_class/2`.
**Example:**
```elixir
# strip wrapper (was: class="tabs tabs-boxed mt-4 flex flex-wrap gap-2")
<div class="ck-tabs__list" role="navigation" aria-label="Upload strategy">
  <.tab_link member={@member} tab="image" current={@tab} label="Image (presigned PUT)" />
  …
</div>

# tab_link/1 (was: class={tab_class(@current,@tab)})
defp tab_link(assigns) do
  ~H"""
  <.link
    patch={~p"/upload?member_id=#{@member.id}&tab=#{@tab}"}
    class="ck-tabs__tab ck-tab"
    aria-current={@current == @tab && "page"}
    data-testid={"upload-tab-#{@tab}"}
  >
    {@label}
  </.link>
  """
end
# DELETE defp tab_class/2 entirely.
```
> `ck-tabs__tab` carries the visuals + 44px target + focus ring; `ck-tab` (empty) keeps the polish-gate `interactiveSelector` finding the element. `aria-current` is the navigation-correct selected cue (not `aria-selected`).

### Pattern 3: The ONE new CSS rule (D-100-05) — token-only, hand-authored
**What:** Add the `aria-current` selected cue to `cohort.css`, mirroring `[aria-selected="true"]` at `:942-947`. Recommended placement: consolidate the two selectors so the cue is defined once.
```css
/* in the tabs block, replacing/extending the existing :942 rule */
.ck-tabs__tab[aria-selected="true"],
.ck-tabs__tab[aria-current="page"] {
  /* non-color cue: underline + weight, in addition to color (D-96-17/22) */
  color: var(--ck-ink);
  font-weight: 700;
  border-bottom-color: var(--ck-brand);
}
```
> Token-only (every value a `var(--ck-*)`), no hex/rgb/named-color or raw measure literal in the rule body → passes the D-96-20 brace-depth literal scanner. No new `--ck-*` token, no `tokens.json`, no generator. Re-run `node brandbook/src/cohort-contrast.mjs` as the sanity gate.

### Anti-Patterns to Avoid
- **Adopting `ck_tabs/1` for the routed strip** (D-100-03) — restructures the DOM, breaks `?tab=` + the `tus-resume` deep link, regresses a11y.
- **`ck_button/1` on a hook/submit `<button>`** (Pitfall A) — drops `phx-hook="MultipartUpload"` / `type=submit`.
- **Editing `admin-polish.js`** for Cohort (D-96-06) — reuse unchanged via the harness.
- **`data-ck-root` on `<body>`** (D-96-05) — `ck_page` already puts it on the `.ck` div; do not touch `root.html.heex`.
- **Authoring a CSS generator / editing a "generated" file** (Pitfall: `cohort.css` is hand-authored, D-94-05/06).
- **Touching `Layouts.app`'s daisyUI `<main>`/`<link>`** — Phase 101 scope.

### Per-Element Class Map (the core planning artifact — D-100-06)

> Class-by-class. "Keep" = element/id/testid/hook unchanged; only the class string changes. All `.ck-*` targets EXIST in `cohort.css` (verified). The `<div :if={@tab == …}>` single-panel render stays.

| Current element / class (line) | Target | Frozen contract to preserve |
|---|---|---|
| `<h1 class="text-2xl font-semibold">Upload lab` (`:49`) | `ck_page` `:title` (`Every Rindle upload path, live.`) + `eyebrow="Upload lab"` | — (label not under test) |
| `<p class="text-sm">Member: <strong id="upload-member-name" data-testid="upload-member-name">` (`:50-52`) | `.ck-hero__lede` line; **keep the `<strong>` byte-for-byte** | `id="upload-member-name"`, `data-testid="upload-member-name"` (D-100-02b) |
| `<div class="tabs tabs-boxed mt-4 flex flex-wrap gap-2">` (`:54`) | `<div class="ck-tabs__list" role="navigation" aria-label="Upload strategy">` | — |
| `tab_link/1` `class={tab_class(@current,@tab)}` (`:146-156`) | `class="ck-tabs__tab ck-tab"` + `aria-current={@current == @tab && "page"}`; delete `tab_class/2` (`:473`) | every `data-testid="upload-tab-#{tab}"`, the `patch` URL, the 6 labels |
| status `<p class="font-mono text-sm" id="X-upload-status" data-testid="X-upload-status">` (`:65,80,92,104,114,125`) | **`.ck-output`** (token-only mono debug surface; status incl. `error: <reason>`) | each `id`/`data-testid` |
| tus error `<p class="text-red-600 text-sm" id="tus-upload-error" data-testid="tus-upload-error">` (`:81-83`) | **`.ck-error`** + inline warning icon (copy `ck_icon(:warning)` SVG from `cohort_components.ex:606`) + **`role="alert"`** | `id="tus-upload-error"`, `data-testid`, `:if={@tus_error}` (fixes color-only violation, D-96-15) |
| bare file `<input type="file" … phx-hook="PresignedPut|PresignedVideoPut|PresignedMuxPut">` (`:66-72,93-99,126-132`) | **`.ck-input`** (44px, token border, focus-visible) | every `id`/`data-testid`/`accept`/`type=file`/`phx-hook` |
| `<.live_file_input upload={@uploads.video|post_image} data-testid=…>` (`:85,118`) | **`.ck-input`** | the `data-testid`, the `upload` binding (UNCHANGED) |
| `<.form … phx-change phx-submit>` (`:84-87,117-120`) | keep `<.form>`; restyle inner controls only | `id="tus-form"/"liveview-form"`, `phx-change`, `phx-submit` |
| `<button id="multipart-upload-button" phx-hook="MultipartUpload" class="btn">` (`:107-109`) | **`.ck-btn ck-btn--primary` on the EXISTING `<button>`** (NEVER `ck_button`) | `id`, `data-testid`, `phx-hook="MultipartUpload"` |
| `<button type="submit" id="tus-submit"/"liveview-submit">` (`:86,119`) | **`.ck-btn ck-btn--primary` on the EXISTING `<button>`** | `id`, `data-testid`, `type="submit"` |
| `<p :if={@last_asset_id} id="image-upload-asset-id" data-testid=…>` (`:73-75`) | `.ck-help` (token muted secondary text) | `id`, `data-testid`, `:if` |
| `<p class="text-xs break-all" id="mux-streaming-url" data-testid=…>` (`:133-135`) | `.ck-output` (URL = system output) — **see Mux-URL caveat below** | `id`, `data-testid`, `:if={@mux_streaming_url}` |
| description `<p class="text-sm">` per panel (`:64,79,91,103,113,124`) | `.ck-help` (muted secondary) | — |
| panel wrappers `class="mt-6 space-y-3"` (`:63,78,90,102,112,123`) | `.ck`-scoped spacing (drop daisyUI utilities; keep the `<div :if>` + `id`/`data-testid`) | each `id="X-upload-panel"`, `data-testid="X-upload-panel"`, `:if={@tab == "X"}` |

**Mux-URL caveat (D-100-06):** `.ck-output` is `white-space: pre` + `overflow-x: auto` (`cohort.css:469-470`) — the long Mux URL will horizontally scroll, NOT wrap. CONTEXT explicitly permits this ("`overflow-x:auto` handles length") and says if wrapping is preferred, keep a minimal token wrapper rather than a new rule. **Recommendation:** use `.ck-output` (scroll) — it's zero-new-CSS and consistent with the status lines. Do NOT add a new `.ck-*` rule for wrapping (out of the one-rule budget).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Page shell (root, theme, focus ring, reduced-motion, box-sizing) | A bespoke `<div class="ck">` | `ck_page/1` (compose, EXISTS) | Matches ops/dashboard; the `.ck` base rules already exist |
| Routed tab styling | A new `.ck-tab-*` ruleset / `ck_tabs/1` adoption | `.ck-tabs__list`/`.ck-tabs__tab` + the one `[aria-current]` rule | Tab visuals already exist; routed tabs = links + `aria-current` (D-100-03/04) |
| Status / debug output surface | An inline mono `<p>` style | `.ck-output` (EXISTS, token-only) | Built + scanner-clean in Phase 99 |
| Error message styling | A `text-red-*` color-only `<p>` | `.ck-error` + `ck_icon(:warning)` + `role="alert"` | Color-only fails D-96-15; icon+role makes it announced |
| File input styling | Bespoke input CSS | `.ck-input` (EXISTS) | 44px target, token border, focus-visible, dark/light parity |
| Hook/submit button | `ck_button/1` (link-only) | `.ck-btn ck-btn--primary` on the existing `<button>` | `ck_button` renders `<.link>` and drops `phx-hook`/`type=submit` |
| Polish/contrast assertions | New computed-style checks | `assertCohortPagePolish` (reuses `assertAdminPolish` unchanged) | The seam is parameterized; do not fork (D-96-06) |
| Theme toggle / persistence | localStorage / JS | server `assign(:theme, "light")` | Deterministic e2e; matches ops/dashboard (D-96-07/16) |

**Key insight:** Phases 96/99 already built and proved every primitive, the scaffold, and both gates. Phase 100 is **composition + class-swap + frozen-contract preservation on the heaviest page** — the only net-new CSS is the one token-only `[aria-current]` rule.

## Runtime State Inventory

> Not a rename/stored-state migration. The analogous inventory is the **frozen DOM contract** — the ids/testids/hooks downstream e2e specs read. These live in the LiveView source and the e2e specs, NOT in any datastore.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — `/upload` renders off seeded demo data + real MinIO uploads via context functions; no DS string is a DB key | none |
| Live service config | None — the upload flows hit MinIO/Mux via existing profiles; the migration changes no handler, profile, or config | none |
| OS-registered state | None | none |
| Secrets/env vars | None — `@secret_key_base` (`:7`) is read for tus; UNCHANGED (no rename) | none |
| Build artifacts | None — no compiled artifact carries a DS class; `cohort.css` is hand-edited, no build step | none |
| **Frozen DOM contract (the real "runtime state")** | Every `id`/`data-testid`/`phx-hook`/`phx-change`/`phx-submit` on `/upload`: the 6 `X-upload-panel` ids+testids, 6 `X-upload-status` ids+testids, 6 `upload-tab-X` testids, `upload-member-name`, the 3 file-input ids+testids + their `phx-hook`s (`PresignedPut`, `PresignedVideoPut`, `PresignedMuxPut`), `multipart-upload-button` + `phx-hook="MultipartUpload"`, the 2 `<.live_file_input>` testids, the 2 forms (`tus-form`/`liveview-form` + `phx-change`/`phx-submit`), `tus-submit`/`liveview-submit`, `tus-upload-error`, `image-upload-asset-id`, `mux-streaming-url` — read by `e2e/{image,video,multipart,liveview,mux,tus}-*.spec.js` (`tus-resume.spec.js:6` uses `?tab=tus`) | **Code-edit (class-only):** swap classes, preserve every attribute byte-for-byte. **Verification:** ExUnit per-tab `assert_frozen_contract` grep + the 6 behavior specs green. The `Copy`/`Tabs` hooks live in `CohortComponents` (not `/upload`) and are untouched |

**The canonical question — after the migration, what still reads the old markup?** The 6 Playwright behavior specs. They key off `data-testid`/`id`/`phx-hook`, NOT class names, so a class-only swap is safe **iff** no id/testid/hook is dropped/renamed and no element (especially the `<div :if>` panels, the `<button>`s, the `<.form>`s, the `<.live_file_input>`s) is restructured out of existence. That is the single hardest constraint of this phase.

## Common Pitfalls

### Pitfall A: `ck_button/1` is link-only — it drops `phx-hook`/`type=submit`
**What goes wrong:** Replacing `<button phx-hook="MultipartUpload">` or a `<button type=submit>` with `<.ck_button>` silently drops the hook/submit (ck_button renders `<.link href>`, `cohort_components.ex:100`), breaking multipart/tus/liveview uploads.
**How to avoid:** put the bare `.ck-btn ck-btn--primary` class on the EXISTING `<button>`; never wrap a hook/submit button in `ck_button`.
**Warning sign:** a `phx-hook`/`type=submit` button replaced by `<.ck_button>`.

### Pitfall B: Adopting `ck_tabs/1` for the routed strip
**What goes wrong:** Pattern-matching "tabs" to the `ck_tabs/1` WAI-ARIA widget (`role=tab`, all 6 panels in DOM, `phx-hook="Tabs"`, `phx-click` events) — restructures the DOM (violates the single-panel `:if` contract), replaces `<.link patch>` with events (breaks `?tab=` + the `tus-resume.spec.js` `?tab=tus` deep link), and regresses a11y for a routed surface.
**How to avoid:** keep `<.link patch>`; restyle onto `.ck-tabs__tab ck-tab` + `aria-current` (D-100-03/04).
**Warning sign:** `role=tablist`/`role=tab`/`phx-hook="Tabs"` appearing in `/upload`, or panels rendered all-at-once + JS-hidden.

### Pitfall C: `data-ck-root` placement / theme determinism
**What goes wrong:** `data-ck-root` on `<body>` (D-96-05 violation) scoops daisyUI chrome into the polish query; a client theme toggle makes e2e flaky.
**How to avoid:** `ck_page` already puts `data-ck-root`+`data-theme` on the `.ck` div; theme is server `assign(:theme, "light")`. Do not touch `root.html.heex`.
**Warning sign:** `data-ck-root` in `root.html.heex` or `localStorage` in the theme path.

### Pitfall D: Polish gate vacuous-pass with no `[data-ck-root]`
**What goes wrong:** a per-tab polish case runs but the page never rendered the `.ck` shell → the locator finds nothing and the gate passes vacuously.
**How to avoid:** `assertCohortPagePolish` already asserts `[data-ck-root]` visibility FIRST (`cohort-pages.spec.js:54`); composing `ck_page` guarantees the root. Keep using the shared helper (don't inline a bypass).
**Warning sign:** a polish case calling `assertAdminPolish` directly without the `[data-ck-root]` guard.

### Pitfall E: Incomplete swap — stray daisyUI class survives (extend the retirement list)
**What goes wrong:** a panel keeps `font-mono text-sm`, `text-red-600`, `tabs tabs-boxed`, the standalone `tab ` class, `text-2xl`, `mt-6 space-y-3`, or `text-xs break-all` → half-migrated, and Phase 102's VIS audit later flags it.
**How to avoid:** the existing `@retired_daisyui_classes` (`cohort_migration_contract_test.exs:32-41`) ALREADY catches `text-2xl`, `space-y-`, `font-mono text-sm`, `bg-gray-`, `text-lg`, `opacity-80`, `list-disc`, `class="btn"`. **The planner MUST extend it** to add the `/upload`-specific daisyUI strings NOT yet covered: `tabs`/`tabs-boxed`, `text-red-600`, the standalone `tab ` token (from the deleted `tab_class/2`), and `break-all` (and consider `flex flex-wrap gap-`). Then `assert_daisyui_retired/1` over each `?tab=X` body proves the swap is complete.
**Warning sign:** a migrated `/upload` body still matching `tabs`, `text-red-600`, `\btab\b`, `font-mono`, `text-2xl`, `space-y-`, `break-all`.

### Pitfall F: The dark case won't flip the theme via `emulateMedia({colorScheme:"dark"})` alone (CORRECTION to D-100-07)
**What goes wrong:** D-100-07 says "+1 dark case on the image tab via `emulateMedia({colorScheme:"dark"})`". But `ck_page` ALWAYS renders an explicit `data-theme="light"`, and the dark CSS lives under both `[data-theme="dark"]` (`cohort.css:116`) AND `@media (prefers-color-scheme: dark) { :root:not([data-theme]) }`. Because `[data-ck-root]` carries an explicit `data-theme`, the media fallback does NOT apply (proven by `cohort-styleguide.spec.js:135-160`, which documents exactly this: the explicit `[data-theme]` is authoritative over the media query). So `emulateMedia({colorScheme:"dark"})` on `/upload` will leave the rendered theme **light** — the dark case would NOT actually exercise dark tokens.
**How to avoid (planner — pick one, all within scope):**
  1. **Recommended:** drive the dark case via the server theme — add a `?theme=dark` (or reuse the `tab`/param machinery) so `mount`/`handle_params` can `assign(:theme, "dark")` for the dark polish case, then assert `[data-ck-root]` has `data-theme="dark"` and run the polish gate. This is a tiny, deterministic, server-state-consistent addition (D-96-07/16) and matches how the styleguide proves the explicit dark contract. **Caveat:** this adds a param read to `mount`/`handle_params` — validate it (`values: ~w(light dark)`, default light) to avoid reflecting an unvalidated param; the `ck_page` `theme` attr already enforces the enum, so an invalid value should fall back to `"light"`.
  2. Or follow the styleguide's documented pattern exactly: prove the **media-fallback path** as a distinct probe (assert the media query is active) while accepting the explicit `data-theme` stays light — but this does NOT prove the upload surface in dark, only that the fallback machinery exists (weaker; the styleguide already covers it globally).
  3. Or, if a per-page theme toggle is undesirable, drop the upload-specific dark case and rely on the existing global `/styleguide` dark contract proof (Phase 96) — but COHORT-02's success criterion explicitly asks for "a light/dark screenshot + polish case covers the upload surface," so option 1 is the faithful read.
**Recommendation:** option 1 (server-driven `data-theme="dark"` for the dark case) — it actually proves the upload surface in dark, stays server-state-consistent, and is the only option that satisfies the COHORT-02 light/dark wording. **Flag this in the plan as the one place CONTEXT's stated mechanism needs correcting.**
**Warning sign:** a dark case that calls `emulateMedia({colorScheme:"dark"})` and then asserts polish without first forcing `data-theme="dark"` — it silently measures the light theme.

## Code Examples

### Per-tab polish case (extend `cohort-pages.spec.js` — mirror the existing `/dashboard`/`/ops` entries)
```javascript
// Source: examples/adoption_demo/e2e/cohort-pages.spec.js (Phase 99) — reuse the exported helper UNCHANGED
const { test } = require("@playwright/test");
const { assertCohortPagePolish } = require("./cohort-pages"); // or add tests directly in cohort-pages.spec.js

for (const tab of ["image", "tus", "video", "multipart", "liveview", "mux"]) {
  test(`/upload?tab=${tab} renders on the Cohort DS (polish, warn mode)`, async ({ page }) => {
    await assertCohortPagePolish(page, {
      route: `/upload?tab=${tab}`,         // load_member!(nil) falls back to first seeded member — no id needed
      surface: `upload-${tab}-cohort`,
    });
  });
}

// + 1 dark case on the image tab (see Pitfall F — drive server data-theme="dark", do NOT rely on emulateMedia alone)
test("/upload?tab=image renders on the Cohort DS in dark (polish, warn mode)", async ({ page }) => {
  await assertCohortPagePolish(page, {
    route: "/upload?tab=image&theme=dark",  // server assigns data-theme="dark" (Pitfall F option 1)
    surface: "upload-image-dark-cohort",
  });
});
```

### Per-tab frozen-contract + daisyUI-retirement (extend `cohort_migration_contract_test.exs`)
```elixir
# Source: examples/adoption_demo/test/.../cohort_migration_contract_test.exs (Phase 99) — reuse the shared helpers
# FIRST: extend @retired_daisyui_classes with the /upload-specific strings (Pitfall E):
#   "tabs", "text-red-600", ~s( tab ), "break-all"   (and consider "flex flex-wrap")

test "/upload preserves its frozen contract and retires daisyUI across all tabs", %{conn: conn} do
  for tab <- ~w(image tus video multipart liveview mux) do
    html = render_route(conn, ~p"/upload?tab=#{tab}")

    # always-present (every tab): member line + 6 tab links + the shell
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

    # active-panel selectors per tab (only the :if-rendered panel is present)
    assert_frozen_contract(html, panel_contract(tab))   # planner: a small per-tab map → selector list

    assert_daisyui_retired(html)
  end
end
# panel_contract/1 returns e.g. for "multipart":
#   [~s(id="multipart-upload-panel"), ~s(data-testid="multipart-upload-status"),
#    ~s(id="multipart-upload-button"), ~s(phx-hook="MultipartUpload")]
# for "image": [..., ~s(phx-hook="PresignedPut"), ~s(id="image-file-input")]
# for "tus":   [..., ~s(id="tus-form"), ~s(phx-submit="save_tus"), ~s(id="tus-submit")]   (tus-upload-error only when @tus_error)
```
> Note: `tus-upload-error`, `image-upload-asset-id`, `mux-streaming-url` render only under their `:if` (after a handler fires); assert them in the behavior specs (runtime backstop) or grep them in source via the per-page acceptance, exactly as Phase 99 handled the `<pre :if=…>` panels — do NOT force their `:if` true in the static ExUnit test.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `/upload` on daisyUI/Tailwind utilities, no `.ck` shell, `tab_class/2` strings | `.ck-*` Cohort DS via `ck_page` + `.ck-tabs__tab`/`aria-current` + class-swapped panels | this phase (100) | `/upload` joins the DS the 7 small pages joined in 99 and the admin joined in 98 |
| `aria-selected` as the only tab selected cue | `aria-current="page"` for routed tabs (+ the one new CSS rule) | this phase | a11y-correct selected state for navigation; `aria-selected` stays for the in-page `ck_tabs/1` widget |
| daisyUI `<link>` + `Layouts.app` `<main>` still loaded | still loaded (kept) | Phase 101 removes them | restyle-only; both stylesheets coexist (`.ck-*` scoping prevents collision) |

**Deprecated/outdated:** none. No package or API changes; all `.ck-*` primitives, the scaffold, and the polish seam are current (Phases 96/99, this milestone).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Driving the dark case via a server `?theme=dark` assign is the faithful, in-scope way to satisfy COHORT-02's "light/dark … covers the upload surface" (vs. `emulateMedia` which leaves the explicit `data-theme="light"`) | Pitfall F | MEDIUM — the planner/user may prefer the lighter media-fallback probe (option 2) or dropping the upload-specific dark case (option 3). Confirm during planning; option 1 is recommended but is the one CONTEXT-mechanism correction. The CSS facts (explicit `[data-theme]` beats the media query) are VERIFIED via `cohort-styleguide.spec.js:135-160`. |
| A2 | Reusing the `ck_icon(:warning)` SVG by copying its markup inline (not promoting it to a public component) is the minimal way to add the warning icon to `.ck-error` | Pattern 1 note / class map | LOW — `ck_icon` is `defp` (`cohort_components.ex:606`); copying the SVG keeps scope minimal. Promoting it to public is also fine if reuse is wanted. Either way the `.ck-error`+`role="alert"` markup mirrors `ck_field` (`:450-451`). |
| A3 | Using `.ck-output` (scroll, `white-space: pre`) for the long `mux-streaming-url` is acceptable (no wrapping) | Mux-URL caveat | LOW — CONTEXT explicitly permits scroll; wrapping would need a new rule (out of the one-rule budget). Confirm visually in the mux polish case. |
| A4 | `load_member!(nil)` lets every `?tab=X` polish/contract route render without a seeded member id | harness plan | LOW — VERIFIED at `upload_live.ex:469` (`Accounts.list_members() |> List.first()`). The lane seeds members, so the fallback resolves. |

## Open Questions (RESOLVED)

1. **Dark-case mechanism (the only real open decision).** See Pitfall F / A1.
   - What we know: `ck_page` always emits explicit `data-theme`; the dark `@media` fallback does NOT apply under an explicit `[data-theme]` (verified). So `emulateMedia({colorScheme:"dark"})` alone won't prove `/upload` in dark.
   - Recommendation: drive the dark case via a validated server `?theme=dark` assign (option 1) so the surface is actually proven in dark. Resolve in planning. (All three options are within scope; option 1 is the faithful COHORT-02 read.)
   - **RESOLVED:** option 1 (server-driven `?theme=dark`, enum-validated `~w(light dark)`, default light) — implemented in 100-01 Task 2 (the `handle_params` `?theme` read) and proven by 100-02 Task 1's dark image-tab polish case (asserts `[data-ck-root][data-theme="dark"]`, with an `emulateMedia` negative guard).

2. **`@retired_daisyui_classes` extension scope.** The existing list misses `tabs`, `text-red-600`, the standalone `tab ` token, and `break-all`. Recommendation: add exactly those (+ optionally `flex flex-wrap`) before the `/upload` contract test, so the daisyUI-retirement gate is complete for this page (Pitfall E). Low risk; mechanical.
   - **RESOLVED:** add `tabs`, `text-red-600`, `~s( tab )` (the standalone `tab ` token), and `break-all` — implemented in 100-01 Task 1, before the `/upload` per-tab retirement assertion.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `phoenix_live_view` | `UploadLive` + `ck_page` | ✓ | 1.1.30 `[VERIFIED: mix.lock]` | none |
| `@playwright/test` + seeded Phoenix server + MinIO | per-tab polish + the 6 behavior specs (real uploads) | ✓ (`adoption-demo-e2e` lane boots `mix phx.server` + seeds + MinIO/Mux cassette) | — | none |
| `node` | `cohort-contrast.mjs` token-pair/parity/literal gate | ✓ (runs in the lane before browser) | — | none (re-runs only if a new token/pair lands — it should not; the new rule is token-only) |
| `cohort.css` + `CohortComponents` + `ck_page/1` + the two Phase-99 harnesses | the restyle target + the gates | ✓ (Phases 96/99 shipped; linked globally) | in-repo | none |

**No new external dependencies introduced this phase.** No `mix deps.get`, no `npm install`, no `tokens.json` change.

## Validation Architecture

> **HIGHEST-PRIORITY SECTION (Nyquist gate).** `workflow.nyquist_validation` is not disabled in `.planning/config.json`, so this section is REQUIRED. Each success criterion is decomposed into clauses, each assigned its proving HOME via the Phase-98/99 decisive test: *does proving it need the cascade/viewport/theme to resolve or a real upload flow → Playwright; or does a static substring/source scan fully prove it → ExUnit / node?* The decisive-test split mirrors Phase 99 one-to-one, driven by the deterministic `?tab=` URL (NOT a client tab-click — that's the behavior specs' job).

### Test Framework
| Property | Value |
|----------|-------|
| Behavior + computed-style framework | Playwright (`@playwright/test`), Chromium-only, in the existing **`adoption-demo-e2e`** lane (boots `mix phx.server` + seeds + MinIO/Mux; already merge-blocking) |
| Config file | `examples/adoption_demo/playwright.config.js` |
| Static markup framework | ExUnit (`render_route` / `render` grep over `cohort_migration_contract_test.exs` — the Phase-99 module, EXTENDED) |
| Token/literal gate | `node brandbook/src/cohort-contrast.mjs` (re-run as sanity; the one new rule is token-only → no new token/pair) |
| Quick run command | `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js` (polish) / `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` (frozen contract) |
| Full suite command | the `adoption-demo-e2e` CI lane (all behavior + polish specs) + `mix test` + `node brandbook/src/cohort-contrast.mjs` |

### Success Criterion 1 → "/upload + all tabs render on the `.ck-*` DS, migrated class-by-class"
| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| `/upload` (each `?tab=X`) renders a `[data-ck-root]` `.ck` shell | ExUnit (`render_route(~p"/upload?tab=X") =~ "data-ck-root"`, asserted by `assert_frozen_contract`) + Playwright (`assertCohortPagePolish` guards `[data-ck-root]` visibility) | Static proves authored; live proves it mounts |
| Each tab's interactive `.ck-*` controls pass the polish gate (focus ring, 44px targets, contrast) | **Playwright** `assertCohortPagePolish(page,{route:"/upload?tab=X", surface:"upload-X-cohort"})` (warn mode) ×6 | Focus-visible ring, target size, effective-bg contrast only resolve at runtime |
| The routed tab strip is links + `aria-current` (NOT `role=tablist`) | **ExUnit** (`assert html =~ ~s(aria-current="page")` on the active tab; `refute html =~ "role=\"tablist\""` / `role="tab"`) | Static markup is the cheapest exhaustive proof of the a11y shape |
| Dark theme renders distinct tokens on the upload surface | **Playwright** dark case on the image tab — server `data-theme="dark"` then polish (Pitfall F; assert `[data-ck-root][data-theme="dark"]`) | Cascade/compositing only visible at runtime; must force explicit dark (media query won't apply) |
| Token-pair contrast unchanged (no new failing pair) | node `cohort-contrast.mjs` | The one new rule is token-only; gate stays green |
| daisyUI/Tailwind utilities RETIRED from the `/upload` body (all tabs) | **ExUnit** `assert_daisyui_retired/1` over each `?tab=X` body (EXTEND `@retired_daisyui_classes` first — Pitfall E) | Static negative scan, scoped to the `data-ck-root` subtree |

### Success Criterion 2 → "every id/data-testid/phx-hook (incl. PresignedPut, MultipartUpload, Copy) preserved; behavior e2e stays green across tabs"
| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| Every always-present `id`/`data-testid` survives per tab (member line, 6 tab links, active panel id+status) | **ExUnit** (`assert_frozen_contract` per `?tab=X`) | Static markup — cheapest, exhaustive |
| Every `phx-hook` (`PresignedPut`/`PresignedVideoPut`/`PresignedMuxPut`/`MultipartUpload`) survives | **ExUnit** (`assert html =~ ~s(phx-hook="…")` in the relevant tab's panel) | Static markup |
| Every `phx-change`/`phx-submit` (tus + liveview forms) + `type=submit` buttons survive | **ExUnit** (grep per tab) | Static markup |
| `:if`-only selectors (`tus-upload-error`, `image-upload-asset-id`, `mux-streaming-url`) survive | **Playwright behavior specs** (render only after a handler fires — the runtime backstop; do NOT force `:if` in static ExUnit) | Only a real flow renders them |
| `phx-hook="Copy"` untouched | N/A (lives in `CohortComponents`, not `/upload`) | Not modified this phase |
| No element restructured out of existence under a frozen id (panels, buttons, forms, live_file_inputs still function) | **Playwright** behavior regression (below) | Only a real upload flow proves the element still works, not just exists |
| No `raw/1` introduced (HEEx auto-escape) | **ExUnit** (`assert_frozen_contract` already `refute html =~ "raw("`) | Static negative scan |

### Success Criterion 3 → "a light/dark screenshot + polish case covers the upload surface; the 6 behavior specs stay green"
| Existing behavior spec (UNCHANGED — frozen-contract backstop) | Covers tab | Must stay green |
|---|---|---|
| `image-upload.spec.js` | image (`PresignedPut`) | ✓ |
| `video-upload.spec.js` | video (`PresignedVideoPut` → AV variants) | ✓ |
| `multipart-upload.spec.js` | multipart (`MultipartUpload` button) | ✓ |
| `liveview-upload.spec.js` | liveview (`live_file_input` + form) | ✓ |
| `mux-streaming.spec.js` | mux (`PresignedMuxPut` → `mux-streaming-url`) | ✓ |
| `tus-resume.spec.js` (uses `?tab=tus` deep link, `:6`) | tus (`live_file_input` + form, `tus-upload-error`) | ✓ — the `?tab=tus` patch is load-bearing; do NOT break it |
| **NEW: 6 per-tab polish cases** | all 6 | added to `cohort-pages.spec.js` — `assertCohortPagePolish` over `[data-ck-root]` (warn mode) |
| **NEW: 1 dark polish case** | image (dark) | added — server `data-theme="dark"` (Pitfall F) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COHORT-02 | `/upload` all tabs on `.ck-*`, contract frozen, behavior green, light/dark polish | polish (×6 + dark) + 6 behavior specs + ExUnit per-tab frozen-contract/retirement | `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js e2e/image-upload.spec.js e2e/tus-resume.spec.js …` + `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | ✅ behavior specs + both harnesses exist / ❌ Wave 0: 6 polish cases + 1 dark + the `/upload` ExUnit test + `@retired_daisyui_classes` extension |

### Sampling rate
- **Per commit (the migration is one cohesive change to one file + one CSS rule + two harness extensions):** the ExUnit `/upload` frozen-contract test + the 6 per-tab polish cases + the relevant behavior spec(s) for any flow touched must be green.
- **Per wave merge:** full `adoption-demo-e2e` lane (all 6 behavior specs + all `/upload` polish cases) + `mix test` + `node brandbook/src/cohort-contrast.mjs`.
- **Phase gate:** full lane green + ExUnit + `cohort-contrast.mjs` green before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] 6 per-tab polish cases in `e2e/cohort-pages.spec.js` (`route: "/upload?tab=X"`, `surface: "upload-X-cohort"`) — reuse the exported `assertCohortPagePolish` (Pitfall D guard already inside it).
- [ ] 1 dark polish case on the image tab — server `data-theme="dark"` (Pitfall F option 1: add a validated `?theme=dark` read to `mount`/`handle_params`, defaulting light, enum-enforced by `ck_page`'s `theme` attr).
- [ ] 1 `/upload` per-tab `for`-comprehension test in `cohort_migration_contract_test.exs` (frozen contract + daisyUI retirement), with a small `panel_contract/1` per-tab selector map.
- [ ] EXTEND `@retired_daisyui_classes` with `tabs`, `text-red-600`, the standalone `tab ` token, `break-all` (Pitfall E) BEFORE the `/upload` retirement assertion.
- [ ] The ONE token-only `.ck-tabs__tab[aria-current="page"]` rule in `cohort.css` (D-100-05) — hand-authored, must pass the literal scanner; consolidate with the `[aria-selected="true"]` rule.
- *(Infrastructure exists: `ck_page/1`, all target `.ck-*` primitives, `cohort-pages.spec.js`, `cohort_migration_contract_test.exs`, the 6 behavior specs, `admin-polish.js`, and `cohort-contrast.mjs` are all present and merge-blocking today.)*

## Security Domain

> `security_enforcement` is not disabled in config; assessed below. This phase is a **presentational restyle of a demo app** — no new write paths, auth changes, or data flows (every upload handler is UNCHANGED).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth touched |
| V3 Session Management | no | No session change |
| V4 Access Control | no | No new routes/permissions; restyle only |
| V5 Input Validation | minimal | The only new param read is the optional `?theme=dark` for the dark case (Pitfall F option 1) — MUST be enum-validated (`values: ~w(light dark)`, default `"light"`; `ck_page`'s `theme` attr already enforces the enum, so an invalid value falls back). No other handler changes; the upload flows' validation is unchanged |
| V6 Cryptography | no | None (`@secret_key_base` read for tus is unchanged) |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Reflected unvalidated `?theme=` param in markup | Tampering / XSS | Enum-validate to `~w(light dark)` (the `ck_page` `theme` attr already does); never interpolate the raw param into a class/attr without the enum gate |
| HEEx auto-escaping bypass | XSS | HEEx escapes `{...}` by default; the migration interpolates the same values as today (member name, status, asset ids, URLs) — introduce NO `raw/1` (asserted by `assert_frozen_contract`'s `refute html =~ "raw("`) |

**Net:** no new security surface beyond the optional `?theme=dark` read, which is enum-gated by the existing `ck_page` `theme` attr. Diligence item: enum-validate the theme param and introduce no `raw/1` — both already enforced by the scaffold attr + the ExUnit grep.

## Sources

### Primary (HIGH confidence)
- `examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex` (read in full, 484 lines) — every id/testid/hook/form/submit/`:if` panel/`tab_class`/`tab_link`/`load_member!(nil)` enumerated and line-verified against CONTEXT's `<canonical_refs>`.
- `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` + `dashboard_live.ex` (grepped) — the exact `import CohortComponents` + `assign(theme: "light")` + `Layouts.app … nav={…}` → `ck_page` composition precedent (dashboard passes `nav={:app}`).
- `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex` (read targeted) — `ck_page/1` (`:78`, attrs incl. `eyebrow`); `ck_button/1` link-only (`:100`); `cohort_nav` `aria-current` for `:upload` (`:24`); `ck_field` `.ck-error`+`role="alert"`+`ck_icon(:warning)` (`:436,450-451`); `ck_icon(%{name: :warning})` `:606`.
- `examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex` (grepped) — `Layouts.app` `attr :nav` doc lists `:upload` (`:32`); `cohort_nav active={@nav}` (`:38`); UNTOUCHED.
- `examples/adoption_demo/priv/static/assets/cohort.css` (read targeted) — `--ck-maxw: 64rem` (`:108`); tabs block `:912-957` (NO standalone `.ck-tab`, `[aria-selected="true"]` `:942`); `.ck-output` `:461` (`white-space: pre`); `.ck-btn`/`--primary`/`.ck-input`/`.ck-help`/`.ck-error` (`:326/352/860/893/898`).
- `examples/adoption_demo/e2e/cohort-pages.spec.js` (read in full) — exported `assertCohortPagePolish`/`reportPolish`/`interactiveSelectors` (incl. `.ck-tab`); `[data-ck-root]` guard `:54`; existing `/dashboard`/`/ops`/`/account`/`/members`/`/lessons`/`/posts`/`/media` entries to mirror.
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` (read in full) — `assert_frozen_contract/2`/`assert_daisyui_retired/1`/`render_route/2`/`page_body/1`; `@retired_daisyui_classes` `:32-41` (missing `tabs`/`text-red-600`/`tab`/`break-all`).
- `examples/adoption_demo/e2e/tus-resume.spec.js` (grepped) — `page.goto("/upload?tab=tus")` (`:6`), the load-bearing deep link.
- `examples/adoption_demo/e2e/cohort-styleguide.spec.js` (read targeted `:135-160`) — proves explicit `[data-theme]` is authoritative over `@media (prefers-color-scheme: dark)` (the Pitfall F basis).
- `.planning/phases/99-*/99-RESEARCH.md` + `99-01-SUMMARY.md` (read in full) — the PROVEN recipe, the per-page class-map idiom, Pitfalls 1–6, the Validation-Architecture/Nyquist decisive-test split, and the four Wave-0 enablers (`ck_page`/`.ck-output`/`cohort-pages.spec.js`/contract module) this phase extends.
- `.planning/phases/100-*/100-CONTEXT.md` (read in full) — D-100-01..08 (the spec; treated as locked).

### Secondary (MEDIUM confidence)
- `.planning/config.json` (read) — `nyquist_validation` not disabled → Validation Architecture required; `parallelization: false`; `mode: yolo`; `discuss_mode: assumptions`.

## Metadata

**Confidence breakdown:**
- CONTEXT validation (every canonical-ref line + decision against live code): HIGH — all references verified accurate; three corrections surfaced (dark-case mechanism, retirement-list extension, Mux-URL `white-space: pre`).
- Per-element class map + frozen-contract inventory: HIGH — `upload_live.ex` read in full; every id/testid/hook enumerated from source; all `.ck-*` targets confirmed present in `cohort.css`.
- Composition recipe: HIGH — grounded in the verified ops/dashboard `ck_page` precedent and the proven Phase-99 Wave-0 enablers.
- Validation Architecture: HIGH — grounded in the real `adoption-demo-e2e` lane, the two existing harnesses (read in full), the 6 behavior specs, and the Phase-98/99 decisive-test idiom.
- Pitfalls: HIGH — derived from real code positions (link-only `ck_button`, explicit-`data-theme`-beats-media-query proof, the retirement-list gap, `white-space: pre` on `.ck-output`).

**Research date:** 2026-06-18
**Valid until:** 2026-07-18 (stable; the `.ck-*` layer, the scaffold, the polish seam, and the behavior specs are fixed inputs from Phases 96/99).
