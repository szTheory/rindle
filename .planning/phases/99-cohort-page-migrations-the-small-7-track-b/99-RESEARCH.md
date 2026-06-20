# Phase 99: Cohort Page Migrations (the small 7) [Track B] — Research

**Researched:** 2026-06-18
**Domain:** Phoenix LiveView 1.1 design-system migration — porting 7 daisyUI/Tailwind inner pages onto the hand-authored `.ck-*` Cohort DS (`cohort.css` + `CohortComponents`), class-by-class, with frozen DOM contracts and a per-page polish/screenshot gate.
**Confidence:** HIGH

## Summary

This is the **Track-B twin of the already-shipped Phase 98** Track-A (admin) migration. The pattern is proven and locked: Phase 96 built the `.ck-*` primitive layer (`cohort_components.ex` + hand-authored `cohort.css`, the dark `[data-theme]` + `prefers-reduced-motion` contract, the `data-ck-root` polish seam) and proved it at `/styleguide`; Phase 98 migrated the six admin surfaces onto a `page/1` scaffold, class-by-class, preserving every `data-*` hook, and gated each on ExUnit static + Playwright computed-style. Phase 99 adapts that proven recipe to the 7 small Cohort inner pages. **Do not invent a new pattern — mirror 98 in the Cohort idiom.**

The decisive structural fact discovered by reading every file: the 7 pages render through `Layouts.app/1` (`components/layouts.ex`), which already emits `cohort_nav`/`cohort_footer` but wraps page content in a **daisyUI Tailwind `<main class="px-4 py-8 …"><div class="mx-auto max-w-3xl space-y-4">` shell with NO `.ck` root** — so today none of the 7 pages carry `.ck` / `data-ck-root` / `data-theme`, which means the cohort focus-visible ring, the reduced-motion block, box-sizing, and the polish gate's `[data-ck-root]` seam **do not reach any of these pages at all**. The root layout (`root.html.heex`) already links `default.css` (daisyUI) AND `cohort.css` globally, so the `.ck-*` rules are available; what's missing is the per-page `.ck` wrapper that scopes them. Establishing that wrapper for all 7 pages is the heart of this migration.

**Primary recommendation:** Add a single `ck_page/1` scaffold to `cohort_components.ex` (the Cohort analog of Phase 98's `page/1`) that renders the `.ck` shell + `data-ck-root` + server-owned `data-theme` + `.ck__wrap` + a canonical `:title`/`:lede`/`:inner_block` slot grammar, and migrate each of the 7 pages to compose it + existing `.ck-*` primitives. Rationale: all 7 pages need the **identical** `.ck` wrapper and the page-level shell is currently in `Layouts.app` (shared, not per-page like Phase 98) — a scaffold centralizes the one piece that must be byte-identical across 7 pages while keeping each page's body a thin composition of existing primitives. The pages are too small (45–113 lines) to justify per-page bespoke shells, and a scaffold prevents 7 copies of the `.ck`/`data-ck-root`/`data-theme` boilerplate drifting. **Only ONE genuinely new primitive may be needed** (a key/value "fact row" list for member/lesson/post/media metadata) — and `ck_detail/1` already covers it, so likely **zero** new primitives.

<user_constraints>
## User Constraints (from phase brief + inherited Phase 96/98 CONTEXT)

> Phase 99 has no `99-CONTEXT.md` yet (this RESEARCH precedes discuss-phase). Constraints below are copied from the phase brief and the binding inherited decisions in `96-CONTEXT.md` (D-96-*) and `98-CONTEXT.md` (D-98-*) that this phase must honor.

### Locked Decisions (from the phase brief)
- **Class-by-class migration, NOT element-by-element.** Swap the daisyUI/Tailwind utility classes on each existing element for the target `.ck-*` class/component; do NOT restructure the DOM.
- **Preserve every `id` / `data-testid` / `phx-hook` / `phx-click` / `phx-submit` byte-for-byte** as a frozen contract. The existing behavior e2e specs depend on these selectors and must stay green.
- **Do NOT remove the `default.css` / daisyUI `<link>`** from `root.html.heex` — daisyUI retirement is deferred to **Phase 101 (COHORT-05)**. Scope is restyle-onto-`.ck-*` only.
- **`/upload` is NOT in scope** — that is Phase 100 (COHORT-02).
- This is the **`examples/adoption_demo`** app (a demo/adoption surface), NOT the core Rindle library.
- Each migrated page's existing behavior e2e specs stay green, AND a Cohort screenshot/polish case is added per page.

### Inherited Decisions that bind this phase (from Phase 96)
- **D-96-05:** The `.ck` shell + `data-ck-root` + `data-theme` seam is rendered **per-LiveView on the `.ck` div, never on `<body>`** in `root.html.heex`. A body-level root would scoop daisyUI inner chrome into the polish query and weaken the gate.
- **D-96-06:** The polish gate reuses `assertAdminPolish(page, { root, interactiveSelectors })` **UNCHANGED** (D-94-07 seam) against `[data-ck-root]` / `.ck-*`. Do NOT edit `admin-polish.js` to special-case Cohort. The gate runs in **WARN/report mode this phase** (warn→fail is Phase 102).
- **D-96-07/16:** Theme is **server state** (`assign(:theme)` + `phx-click` setting `data-theme` on the per-LiveView `.ck` shell). No `localStorage`. Stable `data-ck-*` test markers are emitted SEPARATE from BEM styling classes; assert on the markers, never on `.ck-*` styling classes.
- **D-96-09:** New `.ck-*` selectors/components follow the existing conventions exactly (`attr`/`slot` enums, inline `currentColor` SVG via `defp *_icon`, BEM `.ck-root__el--mod`, `--_local` custom props). Every new selector stays `.ck`-scoped so it inherits reduced-motion / `:focus-visible` / box-sizing and is visible to the polish gate.
- **D-94-05/06:** Cohort and `rindle-admin` share **vocabulary, never a file/build step**. `cohort.css` is **hand-authored vanilla CSS** — there is NO generator (`.mjs`) and it is NOT in `tokens.json`. (This is the opposite of Phase 98's generated-CSS pipeline — see Pitfall 1.)
- **D-96-23:** Readable secondary text uses `--ck-muted` (passes AA 4.5 both themes); `--ck-faint` is decorative/3:1 only. No `--ck-*` color values change.

### Claude's Discretion
- The exact scaffold name (`ck_page/1` proposed), its slot grammar, helper/function names, gallery grouping of the new per-page screenshot cases, assertion wording, and whether a tiny new `.ck-*` class is warranted for any single page — provided the locked decisions above hold and the frozen DOM contract is preserved.

### Deferred Ideas (OUT OF SCOPE)
- Removing `default.css` / daisyUI retirement from inner pages → **Phase 101 (COHORT-05)**.
- `/upload` restyle → **Phase 100 (COHORT-02)**.
- Warn→fail flip of the Cohort polish gate + VIS-* cross-surface re-converge / idempotency → **Phase 102**.
- Any change to `cohort.css` token VALUES, `tokens.json`, or the admin (`rindle-admin`) surfaces.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COHORT-01 | `/dashboard` restyled onto the Cohort DS (`cohort.css` + `cohort_components.ex`) | Per-page class map below; `ck_page` scaffold + `ck-section`/`ck_table`/`ck_detail`/`badge`/`ck_button`/`task_grid`/`task_card` cover it |
| COHORT-03 | `/ops` restyled onto the Cohort DS | Class map below; `ck_page` + `ck_button` + `ck-section`; `<pre>` output panels keep ids/testids, gain a `.ck-*` surface class |
| COHORT-04 | member / lesson / post / media / account pages restyled and consistent | Class maps below; all five compose `ck_page` + `ck_detail`/`ck-section`/`ck_button`/`badge`; no new primitive needed |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `.ck` page shell (root, theme, wrap, focus-visible, reduced-motion, box-sizing) | `cohort_components.ex` (new `ck_page/1` scaffold) | `cohort.css` (`.ck`, `.ck__wrap`, `.ck :focus-visible`, reduce block — all EXIST) | Today only `Layouts.app`'s daisyUI `<main>` wraps these pages; the `.ck` shell must be (re)introduced per-page (D-96-05) |
| Server-owned theme (`data-theme`) | LiveView `mount`/`assign(:theme)` → `ck_page` attr | client (none — no localStorage, D-96-16) | Deterministic for e2e; mirrors `StyleguideLive` |
| Page body composition (cards, tables, detail lists, buttons, badges) | `cohort_components.ex` primitives (`ck_table`, `ck_detail`, `badge`, `ck_button`, `task_grid`/`task_card`, `ck-section`) | per-page HEEx | All exist from Phase 96; pages compose, don't author |
| Page chrome (nav + footer) | `Layouts.app` (`cohort_nav`/`cohort_footer` — already `.ck-*`) | — | Already migrated; only the `<main>`/wrapper between nav and footer is daisyUI today |
| Behavior (phx-click handlers, uploads, erasure, sort) | LiveView modules (UNCHANGED) | — | Frozen contract — handlers + ids + testids preserved byte-for-byte |
| Per-page polish/contrast gate | Playwright `cohort-*.spec.js` calling `assertAdminPolish` over `[data-ck-root]` | `admin-polish.js` (reused unchanged) | D-96-06 seam; warn mode this phase |
| Frozen-contract preservation proof | ExUnit (`render_to_string` grep) + e2e regression specs | — | id/testid/hook survival + daisyUI-class retirement scan |

## Standard Stack

### Core (all already present — this phase installs ZERO new packages)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | 1.1.30 `[VERIFIED: examples/adoption_demo/mix.lock]` | The 7 pages are LiveViews; `attr`/`slot`/`render_slot` for `ck_page/1` | Already the demo's render layer |
| `AdoptionDemoWeb.CohortComponents` | in-repo | The `.ck-*` function components to compose | Built + proven in Phase 96 |
| `cohort.css` (hand-authored, vendored) | in-repo, 1038 lines | The `.ck-*` stylesheet, light/dark tokens, motion, focus | Built in Phase 96; already linked globally in `root.html.heex` |
| `@playwright/test` | existing lane | Per-page polish/screenshot cases | The `adoption-demo-e2e` lane is already merge-blocking |

### Supporting (existing, reused)
| Asset | Purpose | When to Use |
|-------|---------|-------------|
| `assertAdminPolish` / `assertReadableContrast` (`e2e/support/admin-polish.js`) | Computed-style polish + rendered-contrast over a root | Per-page polish case, reused UNCHANGED with `root: "[data-ck-root]"` (D-96-06) |
| `support/cohort.js` (`MEMBERS`, `memberRow`, `memberId`) | Member/email → id lookup from `/dashboard` rows | Per-page specs that navigate via a dashboard member row |
| `support/liveview.js` (`waitForLiveSocket`) | Await LiveView connect before asserting | Every per-page spec |
| `brandbook/src/cohort-contrast.mjs` + `cohort-design-system-data.mjs` | Token-pair contrast + parity + literal gate (node, runs in `adoption-demo-e2e` lane before browser) | No change needed unless a NEW `--ck-*` token/pair is introduced (it should not be) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ck_page/1` scaffold | Per-page inline `.ck` shell (the Phase-98 surfaces each rendered their own shell) | 7 copies of `.ck`/`data-ck-root`/`data-theme`/`.ck__wrap` boilerplate that must stay byte-identical → drift risk; rejected (see Open Question 1) |
| `ck_page/1` scaffold | Move the `.ck` shell into `Layouts.app` for these routes | `Layouts.app` is shared with `/upload` (Phase 100, out of scope) and currently renders the daisyUI `<main>`; touching it risks scope creep into 100 and a half-migrated layout. A page-level scaffold keeps 99 self-contained. (Planner may instead add a `nav`/`ck`-mode flag to `Layouts.app` — discuss in CONTEXT.) |
| `ck_detail/1` for metadata rows | A net-new `.ck-fact`/`.ck-kv` primitive | `ck_detail/1` is already a real `<dl><dt><dd>` with an empty state — covers member/lesson/post/media/account metadata; a new primitive is unjustified |

**Installation:** None. `mix deps.get` unchanged; no `npm install`; no `tokens.json` edit; no new `.mjs`.

**Version verification:**
```bash
grep -n "phoenix_live_view" /Users/jon/projects/rindle/examples/adoption_demo/mix.lock   # 1.1.30
```

## Package Legitimacy Audit

> **N/A — this phase installs ZERO external packages.** It composes existing in-repo components (`CohortComponents`), an existing hand-authored stylesheet (`cohort.css`), and existing test harness modules. No npm/hex/PyPI dependency is added. (`@playwright/test`, `phoenix_live_view`, and the `cohort-*.mjs` gates are pre-existing and were vetted in Phases 94/96.)

## Architecture Patterns

### System Architecture Diagram

```
                         root.html.heex  (UNCHANGED — links default.css + cohort.css globally)
                                   │  <body>{@inner_content}</body>
                                   ▼
   ┌────────────────────────── Layouts.app/1 ──────────────────────────┐
   │  <.cohort_nav active={@nav}/>      ← already .ck-*                  │
   │  <main class="px-4 py-8 …">        ← daisyUI TODAY  ◀── the gap     │
   │    <div class="mx-auto max-w-3xl space-y-4">                       │
   │       {render_slot(@inner_block)}  ← each page's body              │
   │    <.cohort_footer/>               ← already .ck-*                 │
   └────────────────────────────────────────────────────────────────────┘
                                   │
        per-page render/1 (TODAY: bare <h1 class="text-2xl">… daisyUI)
                                   │  MIGRATE ▼
   ┌──────────────────── <.ck_page title=… theme={@theme}> ────────────┐
   │  <div class="ck" data-ck-root data-theme={@theme}>   ← NEW shell   │
   │    <div class="ck__wrap">                                          │
   │      <header>…title/lede…</header>                                 │
   │      <section class="ck-section" data-ck-section="…">              │
   │         compose: ck_table / ck_detail / badge / ck_button /        │
   │                  task_grid+task_card  (all EXIST, Phase 96)        │
   │         ── every id / data-testid / phx-* PRESERVED byte-for-byte ─│
   └────────────────────────────────────────────────────────────────────┘
                                   │
            polish gate: assertAdminPolish(page,{root:"[data-ck-root]", …})  (warn mode)
            behavior gate: existing rendering/replace-detach/owner-erasure/ops specs stay green
```

> **Open layout question for the planner / CONTEXT:** the `.ck` shell can be introduced either (a) by a `ck_page/1` scaffold rendered as the page body inside the existing `Layouts.app` `<main>` (simplest, self-contained — but the daisyUI `<main>` wrapper still surrounds it until Phase 101), or (b) by teaching `Layouts.app` a `ck`-mode that drops the daisyUI `<main>` for these routes. (a) is recommended for scope safety; the daisyUI `<main>` padding is cosmetic and harmless under the `.ck` shell, and its `<link>` removal is explicitly Phase 101. **Confirm in discuss-phase.**

### Pattern 1: `ck_page/1` scaffold (the Cohort analog of Phase 98 `page/1`)
**What:** A single function component in `cohort_components.ex` that renders the `.ck` shell, `data-ck-root`, server-owned `data-theme`, `.ck__wrap`, and a canonical header (`:title`, optional `:lede`/eyebrow) + `:inner_block` for page sections. Mirrors Phase 98 `page/1` (slots in canonical DOM order) but in Cohort's flat-function idiom (D-96-09/14).
**When to use:** Every one of the 7 pages wraps its body in it.
**Example (idiom grounded in `hero/1` + `StyleguideLive` shell at `styleguide_live.ex:86`):**
```elixir
# Source: cohort_components.ex hero/1 (L44-59) + styleguide_live.ex:86 shell
attr :title, :string, required: true
attr :eyebrow, :string, default: nil
attr :lede, :string, default: nil
attr :theme, :string, default: "light", values: ~w(light dark)
attr :rest, :global
slot :inner_block, required: true

def ck_page(assigns) do
  ~H"""
  <div class="ck" data-ck-root data-theme={@theme} {@rest}>
    <div class="ck__wrap">
      <header class="ck-hero">
        <span :if={@eyebrow} class="ck-eyebrow">{@eyebrow}</span>
        <h1 class="ck-hero__title">{@title}</h1>
        <p :if={@lede} class="ck-hero__lede">{@lede}</p>
      </header>
      {render_slot(@inner_block)}
    </div>
  </div>
  """
end
```
(Theme toggle is optional per-page; the styleguide adds an interactive toggle, but inner pages may simply default `theme: "light"` from `mount`. If a toggle is wanted, mirror `StyleguideLive`'s `set_theme` event — server state, D-96-07.)

### Pattern 2: Class-by-class swap (NOT element-by-element)
**What:** For each existing element, replace the daisyUI/Tailwind class string with the `.ck-*` equivalent; keep the element, its `id`, `data-testid`, `phx-*`, and tree position.
**Example (`/ops` button, `ops_live.ex:32`):**
```elixir
# BEFORE (daisyUI)
<button id="run-doctor-button" phx-click="run_doctor" class="btn" data-testid="run-doctor-button">Run doctor</button>
# AFTER (.ck-*) — same id, testid, phx-click; only class changes
<button id="run-doctor-button" phx-click="run_doctor" class="ck-btn ck-btn--primary" data-testid="run-doctor-button">Run doctor</button>
```
> Note: `ck_button/1` renders an `<a>` (it takes `:href`), so the *interactive `<button phx-click>`* elements on ops/member/account use the bare `.ck-btn` class on the existing `<button>`, NOT the `ck_button` component (which is link-only). This preserves `phx-click`. Use `ck_button/1` only where the original was a `<.link>`/`<a>`.

### Pattern 3: `<pre>` debug-output panels (ops/account)
**What:** ops/account render `<pre id=… class="bg-gray-100 text-xs">` raw `inspect/1` output. Keep the `<pre>`, id, testid, and `:if`; replace the daisyUI `bg-gray-100` with a `.ck`-scoped surface class. `cohort.css` has `--ck-code-bg`/`--ck-code-ink` tokens; the planner adds a small `.ck-output`/`.ck-pre` rule (D-96-09/20 — hand-authored, token-only, no literals outside token blocks) OR reuses an existing code surface if present. This is the **one place a tiny new `.ck-*` rule is plausibly needed** — keep it token-only.

### Anti-Patterns to Avoid
- **Element-by-element rewrite:** restructuring `<ul><li>` member lists into `ck_table` rows changes the DOM and breaks `data-testid="member-row-…"` / `id="member-#{id}"`. Migrate the *classes*, keep the `<li>` structure (or wrap the existing structure in `ck-section`). The dashboard member list's per-row `id`/`testid` and nested links are a frozen contract.
- **Authoring a CSS generator:** `cohort.css` is hand-authored (D-94-05/06) — do NOT introduce an `.mjs` build or hand-edit a "generated" file. (This is the inverse of Phase 98; see Pitfall 1.)
- **Putting `data-ck-root` on `<body>`:** D-96-05 — it must be per-page on the `.ck` div.
- **Editing `admin-polish.js` for Cohort:** D-96-06 — reuse unchanged with the `{root, interactiveSelectors}` params.

### Recommended Per-Page Class Map (the core planning artifact)

> Class-by-class. "Keep" = element/id/testid/hook unchanged; only the class string changes. All `.ck-*` targets EXIST in `cohort.css` today (verified via the selector inventory) unless marked NEW.

#### `/dashboard` (`dashboard_live.ex`, ~104 lines) — COHORT-01
| Current element / class | Target | Frozen contract to preserve |
|---|---|---|
| `<h1 class="text-2xl font-semibold" data-testid="cohort-dashboard-title">` | `ck_page` `:title` (or `.ck-hero__title`) | `data-testid="cohort-dashboard-title"` |
| `<p class="text-sm opacity-80">` lede + `<code>` | `.ck-hero__lede` + `--ck-code-*` styled `<code>` | — |
| `<section id="demo-members" data-testid="demo-members">` + `<h2 class="text-lg font-semibold mt-6">` | `.ck-section` + `.ck-section__title` | `id="demo-members"`, `data-testid="demo-members"` |
| `<ul class="list-disc pl-5 space-y-2">` + `<li id="member-#{id}" data-testid="member-row-#{email}">` | `.ck`-scoped list (keep `<ul>/<li>` structure; restyle) | **every** `id="member-#{id}"`, `data-testid="member-row-#{email}"`, nested `data-testid="member-avatar-link"`/`member-no-avatar`/`member-upload-link`/`member-delete-link` |
| courses/posts/assets `<section id="demo-courses|demo-posts|demo-assets">` lists + `lesson-link-#{id}`/`post-link-#{id}` links | `.ck-section` + restyle lists | `id=`/`data-testid=` on each section + `data-testid="lesson-link-#{id}"`, `data-testid="post-link-#{id}"` |
| `<nav class="flex gap-4 mt-8 text-sm">` with `nav-upload`/`nav-ops` `underline` links | `.ck`-scoped nav row; links via `ck_button variant="quiet"` or `.ck` link | `data-testid="nav-upload"`, `data-testid="nav-ops"` |

#### `/ops` (`ops_live.ex`, ~105 lines) — COHORT-03
| Current | Target | Frozen contract |
|---|---|---|
| `<h1>`/`<p>` header | `ck_page` `:title`/`:lede` | — |
| `<button id="run-doctor-button" class="btn" …>` / `run-runtime-status-button` | `.ck-btn ck-btn--primary` on existing `<button>` | `id`, `data-testid`, `phx-click="run_doctor"`/`"run_runtime_status"` |
| `<pre id="doctor-output" class="… bg-gray-100 text-xs …" data-testid="doctor-output">` / `runtime-status-output` | `.ck-output` (NEW token-only rule) keep `<pre>` | `id`, `data-testid`, `:if={@doctor_output}` |
| `<section id="batch-erasure" data-testid="batch-erasure-section">` + `<h2>` | `.ck-section` | `id`, `data-testid` |
| `batch-member-#{email}` spans, `preview-batch-button`/`execute-batch-button` `btn`, `batch-preview`/`batch-result` `<pre>` | `.ck-btn` on buttons; `.ck-output` on `<pre>`; keep spans | all `id`/`data-testid` + `phx-click="preview_batch"`/`"execute_batch"` |

#### `/members/:id` (`member_live.ex`, ~113 lines) — COHORT-04
| Current | Target | Frozen contract |
|---|---|---|
| `<h1 data-testid="member-profile-title">` + `<p class="text-sm">` | `ck_page` `:title` + `:lede`/`.ck-hero__lede` | `data-testid="member-profile-title"` |
| `<section id="member-avatar" data-testid="member-avatar-section">` | `.ck-section` | `id`, `data-testid` |
| `picture_tag` wrapper `id="member-picture-tag"` + `member-avatar-state` `<p>` | keep wrapper; `ck_detail` or `.ck`-scoped text for state | `id="member-picture-tag"`, `data-testid="member-picture-tag"`, `member-avatar-state`, `member-no-avatar` |
| `<section id="replace-detach" data-testid="replace-detach-section">` + `replace-status` `<p class="font-mono">` | `.ck-section` + `--ck-code`/mono `.ck` text | `id`, `data-testid`, `replace-status` |
| `<button id="replace-avatar-button" class="btn" …>` / `detach-avatar-button` | `.ck-btn` on existing `<button>` | `id`, `data-testid`, `phx-click="replace_avatar"`/`"detach_avatar"` |

#### `/lessons/:id` (`lesson_live.ex`, ~72 lines) — COHORT-04
| Current | Target | Frozen contract |
|---|---|---|
| `<h1 data-testid="lesson-title">` + course `<p>` | `ck_page` title/lede | `data-testid="lesson-title"` |
| `<section id="lesson-video" data-testid="lesson-video-section">` | `.ck-section` | `id`, `data-testid` |
| `video_tag` wrapper `id="lesson-video-tag"` + `lesson-asset-state`/`lesson-streaming-url`/`lesson-no-video` | keep wrapper; `.ck` text/`ck_detail` for state | `id="lesson-video-tag"`, all four `data-testid`s |
| `<section id="lesson-variants" data-testid="lesson-variants">` + `<ul><li id="variant-#{name}" data-testid="variant-#{name}">` | `.ck-section`; restyle list OR `ck_table` only if DOM-safe (prefer keep `<ul>` to preserve ids) | `id`, `data-testid` on section + **every** `variant-#{name}` id/testid |

#### `/posts/:id` (`post_live.ex`, ~45 lines) — COHORT-04
| Current | Target | Frozen contract |
|---|---|---|
| `<h1 data-testid="post-title">` + `By …` + body `<p>` | `ck_page` title + `.ck` body text | `data-testid="post-title"` |
| `<section id="post-image" data-testid="post-image-section">` | `.ck-section` | `id`, `data-testid` |
| `post-picture-tag` wrapper / `post-no-image` | keep | `data-testid="post-picture-tag"`, `post-no-image` |

#### `/media/:id` (`media_live.ex`, ~57 lines) — COHORT-04
| Current | Target | Frozen contract |
|---|---|---|
| `<h1>` "Media detail" | `ck_page` `:title` | — |
| `<dl class="text-sm space-y-1"><dt class="inline">…<dd id="media-id" data-testid="media-id">` etc. | **`ck_detail/1`** (real `<dl><dt><dd>`) — but `ck_detail` generates its own `<dd>`; to preserve `id`/`data-testid` on the value, either pass them through `ck_detail`'s `:item` slot content or restyle the existing `<dl>` with `.ck-detail` classes. **Prefer restyling the existing `<dl>`** to keep `media-id`/`media-state`/`media-delivery-url` exactly. | `id="media-id"`+`data-testid`, `media-state`, `media-delivery-url` |
| `<section id="media-variants" data-testid="media-variants">` + variant `<ul><li id="variant-#{name}">` | `.ck-section`; keep `<ul>` | `id`, `data-testid`, `variant-#{name}` ids |
| `media-alex-profile-link` `<.link class="underline">` | `ck_button variant="quiet"` or `.ck` link | `data-testid="media-alex-profile-link"` |

#### `/account/:member_id/delete` (`account_live.ex`, ~55 lines) — COHORT-04
| Current | Target | Frozen contract |
|---|---|---|
| `<h1>` "Owner erasure demo" + `erasure-member-name` `<p>` | `ck_page` title + `.ck` text | `data-testid="erasure-member-name"` |
| `preview-erasure-button`/`execute-erasure-button` `class="btn"` | `.ck-btn` (execute likely `ck-btn--primary`) on existing `<button>` | `id`, `data-testid`, `phx-click="preview"`/`"execute"` |
| `erasure-preview`/`erasure-result` `<pre class="bg-gray-100 text-xs">` | `.ck-output` (NEW token-only) keep `<pre>` | `id`, `data-testid`, `:if` |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Page shell (root, theme, focus ring, reduced-motion, box-sizing) | A bespoke `<div class="ck">` per page | `ck_page/1` scaffold (one place) | 7 byte-identical shells drift; the `.ck` base rules already exist in `cohort.css` |
| Key/value metadata blocks (media/member/lesson facts) | A new `.ck-fact` primitive | `ck_detail/1` (existing real `<dl>`) or restyle existing `<dl>` with `.ck-detail` | Already shipped + contrast-gated in Phase 96 |
| Status pills (asset/variant state) | Inline colored spans | `badge/1` (`ready|processing|quarantine|info`) | Color+label pairing already enforced (D-96 status rule) |
| Theme toggle / persistence | localStorage / JS | server `assign(:theme)` + `phx-click` (D-96-07/16) | Deterministic e2e; matches `StyleguideLive` |
| Polish/contrast assertions | New computed-style checks | `assertAdminPolish` / `assertReadableContrast` reused unchanged (D-96-06) | The seam is already parameterized; do not fork |

**Key insight:** Phase 96 + 98 already built and proved every primitive and every gate. Phase 99 is **composition + class-swap + frozen-contract preservation**, not construction. The only plausible net-new CSS is one token-only `.ck-output`/`.ck-pre` rule for the `<pre>` debug panels on ops/account.

## Runtime State Inventory

> Not a rename/migration-of-stored-state phase, but this IS a string/markup migration with a frozen-contract dimension, so the analogous inventory is the **DOM-contract** inventory (the ids/testids/hooks that downstream e2e specs read). These are NOT in a database — they are in the LiveView source and the e2e specs.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — `/styleguide` and these pages render off seeded demo data via context functions; no DS string is a DB key | none |
| Live service config | None | none |
| OS-registered state | None | none |
| Secrets/env vars | None | none |
| Frozen DOM contract (the real "runtime state" here) | Every `id` / `data-testid` / `phx-click` / `phx-submit` / `phx-hook` on the 7 pages (enumerated per-page above) — read by `rendering.spec.js`, `replace-detach.spec.js`, `owner-erasure.spec.js`, `batch-erasure.spec.js`, `ops-surfaces.spec.js`, `image-upload.spec.js`, `liveview-upload.spec.js`, `multipart-upload.spec.js`, `mux-streaming.spec.js`, `video-upload.spec.js`, `replace-detach.spec.js` + `support/cohort.js` (reads `id="member-#{id}"` and `data-testid="member-row-#{email}"`) | **Code-edit (class-only):** swap classes, preserve every attribute byte-for-byte. **Verification:** ExUnit `render_to_string` grep that each attribute still exists + regression run of all behavior specs. The `phx-hook="Copy"`/`"Tabs"` hooks live in `CohortComponents` (not these pages) and are untouched. |

**The canonical question — after the migration, what still reads the old markup?** The Playwright behavior specs and `support/cohort.js`. They key off `data-testid`/`id`, NOT class names, so a class-only swap is safe **iff** no `id`/`testid`/`phx-*` is dropped or renamed and no element is restructured out of existence. That is the single hardest constraint of this phase.

## Common Pitfalls

### Pitfall 1: Treating `cohort.css` like the admin generated-CSS pipeline
**What goes wrong:** A planner who pattern-matches Phase 98 too hard adds an `.mjs` generator, a `requiredSelectors` self-check, or hand-edits a "generated" file.
**Why:** `cohort.css` is **hand-authored vanilla CSS** (D-94-05/06) — header comment: *"Hand-authored, vendored (no build step)."* There is NO generator. The drift gate is the `cohort-contrast.mjs` **parity check** (D-96-18: pair values byte-equal the `:root`/`[data-theme]` block) + the brace-depth **literal scanner** (D-96-20), not a regenerate-diff.
**How to avoid:** Any new `.ck-*` rule (e.g. `.ck-output`) is hand-written directly in `cohort.css`, token-only (no hex/rgb outside `:root`/`[data-theme]`), and must pass the literal scanner. No build step, no `tokens.json` edit.
**Warning sign:** a plan task that says "run the cohort CSS generator" or "regenerate cohort.css."

### Pitfall 2: Element-by-element restructure breaking a frozen testid
**What goes wrong:** Converting the dashboard member `<ul><li>` or the lesson/media variant `<ul><li id="variant-…">` into a `ck_table` drops the per-`<li>` `id`/`data-testid`, breaking `rendering.spec.js`, `replace-detach.spec.js`, and `support/cohort.js`'s `memberId` (which reads `id="member-#{id}"`).
**Why:** the brief locks class-by-class, not element-by-element.
**How to avoid:** keep the `<ul>/<li>`/`<dl>` structure; restyle with `.ck`-scoped classes inside `.ck-section`. Use `ck_table`/`ck_detail` ONLY where you can preserve the exact ids/testids (or skip them for the list-shaped data and just restyle).
**Warning sign:** a diff that removes an `id=`/`data-testid=` or changes the element type under one.

### Pitfall 3: `data-ck-root` placement and theme determinism
**What goes wrong:** Putting `data-ck-root` on `<body>` (D-96-05 violation) scoops daisyUI inner chrome into the polish query; or a client-side theme toggle makes e2e flaky.
**How to avoid:** `data-ck-root` + `data-theme` on the per-page `.ck` div via `ck_page`; theme is server `assign(:theme)` (D-96-07/16).
**Warning sign:** `data-ck-root` in `root.html.heex`, or `localStorage` in the theme path.

### Pitfall 4: `ck_button/1` is link-only — it cannot carry `phx-click`
**What goes wrong:** Replacing a `<button phx-click="run_doctor">` with `<.ck_button>` drops the `phx-click` handler (ck_button renders `<.link href>`), silently breaking ops/account/member buttons.
**How to avoid:** put the bare `.ck-btn`/`.ck-btn--primary` class on the EXISTING `<button>`; use `ck_button/1` only where the source was an `<a>`/`<.link>`.
**Warning sign:** a `phx-click` button replaced by `<.ck_button>`.

### Pitfall 5: Polish gate runs but the page has no `[data-ck-root]`
**What goes wrong:** A per-page spec calls `assertAdminPolish(page, {root:"[data-ck-root]"})` but the migrated page never rendered the `.ck` shell → the locator finds nothing and the gate vacuously passes (or errors).
**How to avoid:** the per-page spec must first assert `await expect(page.locator("[data-ck-root]")).toBeVisible()` (as `cohort-styleguide.spec.js` implicitly relies on). The `ck_page` scaffold guarantees the root.
**Warning sign:** a polish case with no root-visibility assertion.

### Pitfall 6: daisyUI class still present after migration (incomplete swap)
**What goes wrong:** A page keeps stray `class="btn"`/`text-2xl`/`bg-gray-100`/`list-disc` Tailwind utilities, so it's half-migrated and the VIS audit (Phase 102) later flags it.
**How to avoid:** add a **daisyUI-class-retirement scan** to the Validation Architecture (below): grep each migrated page's `render_to_string` (or source) for the known daisyUI/Tailwind utility classes and assert ZERO remain — EXCEPT the `Layouts.app` `<main>` wrapper which is explicitly Phase 101. Scope the scan to the page bodies, not the shared layout.
**Warning sign:** a migrated page that still matches `\bbtn\b`, `text-2xl`, `bg-gray-`, `list-disc`, `opacity-80`, `space-y-`, `flex gap-`.

## Code Examples

### Per-page polish/screenshot case (mirror `cohort-styleguide.spec.js`)
```javascript
// Source: examples/adoption_demo/e2e/cohort-styleguide.spec.js (Phase 96) + D-96-06
const { test, expect } = require("@playwright/test");
const { assertAdminPolish } = require("./support/admin-polish");
const { waitForLiveSocket } = require("./support/liveview");

const interactiveSelectors = [".ck-btn", ".ck-tab", ".ck-input", ".ck-select"];

test("/ops renders on the Cohort DS (polish, warn mode)", async ({ page }) => {
  await page.goto("/ops");
  await waitForLiveSocket(page);
  await expect(page.locator("[data-ck-root]")).toBeVisible();   // Pitfall 5 guard
  await assertAdminPolish(page, {
    viewport: "desktop", surface: "ops-cohort",
    root: "[data-ck-root]", interactiveSelectors,
  }).catch((e) => { /* warn mode this phase (D-96-06); re-throw on harness crash */
    if (e instanceof ReferenceError || e instanceof TypeError) throw e;
    console.warn(`[cohort-ops] polish offenders:\n  ${e.message}`);
  });
});
```

### Frozen-contract ExUnit assertion (id/testid survival via `render_to_string`)
```elixir
# Idiom mirrors Phase 98's render_to_string greps over migrated surfaces.
test "ops page preserves the frozen DOM contract after the Cohort migration" do
  html = render_to_string(AdoptionDemoWeb.OpsLive, ...)   # or live render
  for sel <- ~w(run-doctor-button run-runtime-status-button doctor-output
                runtime-status-output batch-erasure-section preview-batch-button
                execute-batch-button batch-preview batch-result) do
    assert html =~ ~s(data-testid="#{sel}")
  end
  assert html =~ ~s(phx-click="run_doctor")
  assert html =~ ~s(data-ck-root)        # the new .ck shell is present
  refute html =~ ~s(class="btn")          # daisyUI retired from the body
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inner pages on daisyUI/Tailwind utilities, no `.ck` shell | `.ck-*` Cohort DS via `ck_page` + primitives | this phase (99) | The 7 pages join the DS Track-A already joined in 98 |
| Per-surface bespoke shell (Phase 98 admin surfaces) | `ck_page/1` scaffold (recommended) | this phase | Centralizes the one byte-identical-across-pages concern |
| daisyUI `<link>` still loaded | daisyUI `<link>` still loaded (kept) | Phase 101 removes it | This phase is restyle-only; both stylesheets coexist (`.ck-*` scoping prevents collision) |

**Deprecated/outdated:** none. No package or API changes; all `.ck-*` primitives and the polish seam are current (Phase 96, this milestone).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A `ck_page/1` scaffold is the right call vs. per-page shells | Patterns / Open Q1 | LOW — both work; scaffold reduces drift. Planner/maintainer may prefer teaching `Layouts.app` a `ck`-mode instead. Confirm in CONTEXT. |
| A2 | Zero new `.ck-*` primitives needed; at most one token-only `.ck-output` rule for `<pre>` panels | Don't Hand-Roll / Pattern 3 | LOW — `ck_detail`/`badge`/`ck_table` cover the rest; the `<pre>` rule is a minor hand-authored addition gated by the literal scanner |
| A3 | A class-only swap preserves all behavior specs as long as ids/testids/hooks survive | Runtime State Inventory | MEDIUM — specs key on testid/id (verified by reading them), but any spec that asserts on text content or layout (e.g. `rendering.spec.js` uses `getByRole("link", {name})`) must keep link text + roles. Verify link accessible names survive the restyle. |
| A4 | The daisyUI `<main>` wrapper in `Layouts.app` is harmless to leave until Phase 101 | Architecture diagram | LOW — `.ck` shell sets its own background/padding; cosmetic double-padding at most. Confirm visually in the per-page screenshot case. |

## Open Questions

1. **`ck_page/1` scaffold vs. `Layouts.app` `ck`-mode vs. per-page shell.** (The single most impactful planning decision.)
   - What we know: all 7 pages need the identical `.ck`+`data-ck-root`+`data-theme`+`.ck__wrap` shell; today none have it (the shell is the daisyUI `<main>` in `Layouts.app`). Phase 98 used per-surface shells; Phase 96's `StyleguideLive`/`LaunchpadLive` each render their own `.ck` div.
   - What's unclear: whether to centralize in a new `ck_page/1` component, teach `Layouts.app` a mode, or render per-page.
   - Recommendation: **`ck_page/1` scaffold** (self-contained, scope-safe, drift-proof) rendered as the page body inside the existing `Layouts.app`. Resolve in discuss-phase.

2. **Theme toggle on inner pages — yes or default-light?**
   - What we know: `StyleguideLive` has an interactive toggle; inner pages may not need one.
   - Recommendation: default `theme: "light"` from `mount` (server state, D-96-07); add a toggle only if the per-page screenshot case must prove dark. The polish gate can drive dark via the scaffold attr or `emulateMedia`. Confirm in CONTEXT.

3. **Per-page screenshot/polish pattern — one shared spec vs. per-page specs?**
   - What we know: `cohort-styleguide.spec.js` is one spec; admin used `admin-screenshots.spec.js` with an enumerated `expectedScreenshots` + `toHaveLength(N)` lockstep.
   - Recommendation: a single `cohort-pages.spec.js` (or extend per existing behavior spec) that loops the 7 routes calling `assertAdminPolish` over `[data-ck-root]` in warn mode, PLUS a screenshot per page if a `cohort-screenshots.spec.js` is wanted (mirror admin's enumerated-array + `toHaveLength` lockstep). Planner discretion (mirrors Phase 98 Open Question 1). Confirm in CONTEXT.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `phoenix_live_view` | the 7 LiveViews + `ck_page` | ✓ | 1.1.30 `[VERIFIED: mix.lock]` | none |
| `@playwright/test` + seeded Phoenix server | per-page polish/screenshot + behavior regression | ✓ (existing `adoption-demo-e2e` lane boots `mix phx.server` with seeds) | — | none |
| `node` | `cohort-contrast.mjs` token-pair/parity/literal gate | ✓ (runs in the lane before browser, Phase 96) | — | none (only re-runs if a new token/pair lands — it should not) |
| `cohort.css` + `CohortComponents` | the restyle target | ✓ (Phase 96 shipped; linked globally in `root.html.heex`) | in-repo | none |

**No new external dependencies introduced this phase.** No `mix deps.get`, no `npm install`, no `tokens.json` change.

## Validation Architecture

> **HIGHEST-PRIORITY SECTION (Nyquist gate).** Each phase success criterion is decomposed into clauses, each assigned its proving HOME using the Phase-98 decisive test: *does proving it require the cascade/viewport/theme to resolve, or a real LiveView render?* If a static substring/source scan fully proves it → ExUnit / node. If it needs a real browser/computed-style or a real behavior flow → Playwright. `workflow.nyquist_validation` is not disabled in `.planning/config.json`, so this section is REQUIRED.

### Test Framework
| Property | Value |
|----------|-------|
| Behavior + computed-style framework | Playwright (`@playwright/test`), Chromium-only, in the existing **`adoption-demo-e2e`** lane (boots `mix phx.server` + seeds; already merge-blocking) |
| Config file | `examples/adoption_demo/playwright.config.js` |
| Static markup framework | ExUnit (`render_to_string` / live render greps for frozen-contract survival + daisyUI retirement) — Phase-98 idiom |
| Token/literal gate | `node brandbook/src/cohort-contrast.mjs` (only re-relevant if a new `--ck-*` token/pair lands) |
| Quick run command | `cd examples/adoption_demo && npx playwright test e2e/<page>.spec.js` |
| Full suite command | the `adoption-demo-e2e` CI lane (`npx playwright test` after seed/serve) |

### Success Criterion 1 → "7 pages restyled onto cohort.css + CohortComponents, visually consistent"
| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| Each of the 7 pages renders a `[data-ck-root]` `.ck` shell | ExUnit (`render_to_string =~ "data-ck-root"`) + Playwright (`expect(locator("[data-ck-root]")).toBeVisible()`) | Static markup proves authored; live proves it actually mounts |
| Each page's interactive `.ck-*` controls pass the polish gate (focus-ring tokens, 44px targets, contrast) in BOTH themes | **Playwright** `assertAdminPolish(page,{root:"[data-ck-root]", interactiveSelectors})` (warn mode, D-96-06) | Focus-visible ring, target size, effective-bg contrast only resolve at runtime |
| Reduced-motion: `.ck-reveal`/animated `.ck-*` resolve to motionless final state under `emulateMedia({reducedMotion:'reduce'})` | **Playwright** (probe BEFORE `freezeMotion`, per D-96-21 / Pitfall 6) | `@media` must fire; computed read |
| Dark theme renders distinct tokens (no daisyUI bleed) | **Playwright** (`assertReadableContrast` over `[data-ck-root]` in dark) | Cascade/compositing only visible at runtime |
| Token-pair contrast unchanged (no new failing pair) | node `cohort-contrast.mjs` | Source-hex full-float; only if a new token lands |
| Visual consistency / per-page screenshot reference | **Playwright** screenshot case per page (warn/report this phase; pixel baselines deferred to 102) | Visual reference is a rendered artifact |

### Success Criterion 2 → "class-by-class, every id/data-testid/phx-hook frozen"
| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| Every enumerated `id` / `data-testid` survives on each page | **ExUnit** (`render_to_string` grep per page, asserting each frozen selector from the per-page class map) | Static markup — the cheapest, most exhaustive proof |
| Every `phx-click`/`phx-submit` handler attribute survives | **ExUnit** (grep `phx-click="…"`) | Static markup |
| `phx-hook="Copy"`/`"Tabs"` untouched | N/A (live in `CohortComponents`, not these pages) | Not modified this phase |
| daisyUI/Tailwind utility classes RETIRED from each page body | **ExUnit** (`refute` the known daisyUI class set in each page's `render_to_string`, scoped to the body, excluding the `Layouts.app` `<main>` which is Phase 101) | Static negative scan (Pitfall 6); the daisyUI-class-retirement check |
| No element restructured out of existence under a frozen id | **Playwright** behavior regression (below) is the backstop | Only a real flow proves the element still functions, not just exists |

### Success Criterion 3 → "behavior e2e stays green + a Cohort polish/screenshot case per page"
| Existing behavior spec | Covers page(s) | Must stay green |
|---|---|---|
| `ops-surfaces.spec.js` | `/ops` (doctor + runtime output) | ✓ |
| `batch-erasure.spec.js` | `/ops` batch | ✓ |
| `rendering.spec.js` | `/dashboard` → `/lessons/:id`, `/members/:id` (picture/video tags, `getByRole("link",{name})`) | ✓ — verify link accessible names survive (A3) |
| `replace-detach.spec.js` | `/dashboard` → `/members/:id` (replace/detach buttons + `replace-status`) | ✓ |
| `owner-erasure.spec.js` | `/dashboard` → `/account/:id/delete` (preview/execute erasure) | ✓ |
| `image-upload.spec.js`, `liveview-upload.spec.js`, `multipart-upload.spec.js`, `mux-streaming.spec.js`, `video-upload.spec.js` | navigate via `/dashboard` member rows (`support/cohort.js` reads `member-row-#{email}` + `id="member-#{id}"`) | ✓ — the dashboard member-row id/testid contract is load-bearing for these |
| **NEW: per-page polish case** | all 7 | added — `assertAdminPolish` over `[data-ck-root]` (warn mode) |
| **NEW (optional): per-page screenshot** | all 7 | mirror admin `expectedScreenshots` + `toHaveLength(N)` lockstep if a `cohort-screenshots.spec.js` is adopted (Open Q3) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COHORT-01 | `/dashboard` on `.ck-*`, contract frozen | polish + behavior + ExUnit grep | `npx playwright test e2e/rendering.spec.js e2e/replace-detach.spec.js` + new dashboard polish case | ✅ behavior specs exist / ❌ Wave 0: dashboard polish case + ExUnit grep |
| COHORT-03 | `/ops` on `.ck-*`, contract frozen | polish + behavior + ExUnit grep | `npx playwright test e2e/ops-surfaces.spec.js e2e/batch-erasure.spec.js` + new ops polish case | ✅ behavior / ❌ Wave 0: ops polish case + grep |
| COHORT-04 | member/lesson/post/media/account on `.ck-*` | polish + behavior + ExUnit grep | `npx playwright test e2e/rendering.spec.js e2e/owner-erasure.spec.js` + new per-page polish cases | ✅ behavior / ❌ Wave 0: 5 polish cases + greps |

### Sampling rate
- **Per page migration (one atomic commit per page, mirroring Phase 98 D-98-02):** that page's existing behavior spec(s) + its new polish case + the ExUnit frozen-contract grep must be green before commit.
- **Per wave merge:** full `adoption-demo-e2e` lane (all behavior specs + all 7 polish cases) + ExUnit.
- **Phase gate:** full lane green + ExUnit + `cohort-contrast.mjs` green before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `e2e/` per-page polish cases for the 7 routes (new — model on `cohort-styleguide.spec.js`), each guarding `[data-ck-root]` visibility (Pitfall 5).
- [ ] ExUnit frozen-contract + daisyUI-retirement greps per page (new — model on Phase 98 `render_to_string` idiom). The repo's ExUnit home for adoption-demo web is `examples/adoption_demo/test/` (confirm path during planning).
- [ ] `ck_page/1` scaffold in `cohort_components.ex` (new component — the Wave-0 enabler all 7 pages depend on; mirrors Phase 98 P1).
- [ ] Optional `.ck-output`/`.ck-pre` token-only rule in `cohort.css` for the `<pre>` debug panels (hand-authored; must pass the D-96-20 literal scanner).
- *(Infrastructure exists: the `adoption-demo-e2e` lane, `admin-polish.js` seam, `support/cohort.js`, and `cohort-contrast.mjs` are all present and merge-blocking today.)*

## Security Domain

> `security_enforcement` is not disabled in config; assessed below. This phase is a **presentational restyle of a demo app** with no new write paths, auth changes, or data flows (the behavior handlers are unchanged).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth touched (`/admin` already `allow_unauthenticated?: true` for preview only; not in scope) |
| V3 Session Management | no | No session change |
| V4 Access Control | no | No new routes/permissions; restyle only |
| V5 Input Validation | minimal | `account_live`/`ops_live` already validate the sort/member params upstream; this phase changes no handler. The styleguide sort-key allowlist (`@sort_keys`) is the existing pattern — preserve it if any `ck_table` sort is wired (it likely is not on these pages) |
| V6 Cryptography | no | None |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Reflected unvalidated param in markup (e.g. forged sort key) | Tampering | Existing allowlist pattern (`@sort_keys` in `StyleguideLive`); not introduced here — no new param reflection in a class-only swap |
| HEEx auto-escaping bypass | XSS | HEEx escapes interpolations by default; the migration interpolates the same values as today (member names, asset ids) — no new `raw/1` introduced. Verify no migration adds `raw/1`. |

**Net:** no new security surface. The only diligence item is "do not introduce `raw/1` or a new unvalidated param reflection during the restyle" — assert via the same ExUnit grep that proves the frozen contract.

## Sources

### Primary (HIGH confidence)
- The 7 LiveViews (read in full): `dashboard_live.ex`, `ops_live.ex`, `member_live.ex`, `lesson_live.ex`, `post_live.ex`, `media_live.ex`, `account_live.ex` — every `id`/`data-testid`/`phx-*` enumerated.
- `components/layouts.ex` (read) — `Layouts.app/1` renders `cohort_nav`/`cohort_footer` + a daisyUI `<main>`/`<div>` wrapper with NO `.ck` shell (the gap).
- `components/layouts/root.html.heex` (read) — links `app.css` + `default.css` (daisyUI) + `cohort.css` globally; `<body>` carries no `data-ck-root`.
- `components/cohort_components.ex` (read in full, 695 lines) — full `.ck-*` component inventory; `ck_button` is link-only; no `ck_page`/scaffold exists.
- `priv/static/assets/cohort.css` (read targeted + full selector inventory) — hand-authored, `.ck`/`.ck__wrap`/`.ck :focus-visible`/`.ck-section`/reduce block exist; header confirms "no build step."
- `live/styleguide_live.ex` (read) — per-LiveView `.ck` shell at `:86` (`<div class="ck" data-ck-root data-theme={@theme}>`), server theme, `data-ck-section` markers.
- `router.ex` (read) — the 7 routes in the `:browser` scope (`:25-32`); `/upload` present but out of scope.
- `e2e/cohort-styleguide.spec.js` (read in full) — the polish-case template (D-96-06 reuse, warn mode, reduced-motion-before-freeze).
- `e2e/support/admin-polish.js` (grepped signatures/exports) — `assertAdminPolish({root, interactiveSelectors})`, `assertReadableContrast`, `MIN_TARGET_PX=44`, offender-returning.
- `e2e/support/cohort.js` (read) — `memberId` reads `id="member-#{id}"`; `memberRow` reads `data-testid="member-row-#{email}"` — load-bearing dashboard contract.
- `e2e/ops-surfaces.spec.js`, `rendering.spec.js`, `replace-detach.spec.js`, `owner-erasure.spec.js`, `batch-erasure.spec.js` (read) — the behavior specs that must stay green; key off testids/ids/roles, not classes.
- `brandbook/src/cohort-contrast.mjs` + `cohort-design-system-data.mjs` (read head) — hand-authored parity/literal/contrast gate; resolves `--ck-*` from `cohort.css` directly (no `tokens.json`).
- `.planning/phases/96-*/96-CONTEXT.md` (read in full) — D-96-01..23 (the binding inherited contract).
- `.planning/phases/98-*/98-PATTERNS.md` + `98-RESEARCH.md` (read in full) — the proven Track-A pattern + Validation-Architecture idiom mirrored here.
- `examples/adoption_demo/mix.lock` — `phoenix_live_view` 1.1.30 `[VERIFIED]`.

### Secondary (MEDIUM confidence)
- `.planning/config.json` (read) — `nyquist_validation` not disabled → Validation Architecture required; `parallelization: false`.

## Metadata

**Confidence breakdown:**
- Per-page class map + frozen-contract inventory: HIGH — every page and every behavior spec read directly; ids/testids enumerated from source.
- Scaffold-vs-compose recommendation: HIGH on the facts (page sizes, shared shell, no existing `.ck` wrapper), MEDIUM on the exact mechanism (scaffold vs `Layouts.app` mode) — flagged as Open Question 1 for discuss-phase.
- Validation Architecture: HIGH — grounded in the real `adoption-demo-e2e` lane, `admin-polish.js` seam, the existing behavior specs, and the Phase-98 decisive-test idiom.
- Pitfalls: HIGH — derived from real code positions (hand-authored `cohort.css`, link-only `ck_button`, `support/cohort.js` id reads, D-96-05/06 placement rules).

**Research date:** 2026-06-18
**Valid until:** 2026-07-18 (stable; the `.ck-*` layer, the polish seam, and the behavior specs are fixed inputs from Phases 96/98).
