# Phase 100: Cohort `/upload` Migration (all tabs) [Track B] - Context

**Gathered:** 2026-06-18 (assumptions mode + 4 parallel `gsd-advisor-researcher` subagents)
**Status:** Ready for planning

<domain>
## Phase Boundary

Track B (COHORT-02). Migrate the Cohort demo's `/upload` page (`examples/adoption_demo`,
`upload_live.ex`, 484 lines, 6 tabs, the heaviest `PresignedPut`/`PresignedVideoPut`/
`MultipartUpload`/`PresignedMuxPut` + `live_file_input` hooks) onto the hand-authored `.ck-*`
Cohort design system — **class-by-class, preserving a frozen DOM contract**. This is the
**Track-B twin of Phase 99** (the small-7 migration) applied to the one page deliberately held
back; the recipe, scaffold, primitives, and proof harnesses already exist and are proven.

This is **composition + class-swap + frozen-contract preservation, NOT construction.** Zero new
deps, zero new components, exactly ONE tiny token-only CSS rule (the `aria-current` tab cue).

**Out of scope (deferred):** removing the daisyUI `<link>`/`default.css` and the `Layouts.app`
daisyUI `<main>` wrapper → **Phase 101 (COHORT-05)**; warn→fail flip of the polish gate + VIS-*
re-converge / idempotency / cross-surface audit → **Phase 102**; any `cohort.css` token-VALUE or
`tokens.json` change; the admin (`rindle-admin`) surfaces. Cohort and `rindle-admin` stay
**deliberately separate but coherent** — shared vocabulary, never a shared file or build step
(D-94-05/06).
</domain>

<decisions>
## Implementation Decisions

### Page Shell (Area 1 — researched, HIGH confidence)

- **D-100-01:** `/upload` gets its `.ck` shell by **composing the existing `ck_page/1` scaffold**
  (built in Phase 99 `99-01`, shipped intentionally UNUSED), exactly as the 7 small pages and
  `/ops` do — NOT a `Layouts.app` `ck`-mode, NOT a bespoke inline shell, NOT a new scaffold
  variant. Mechanics: `import AdoptionDemoWeb.CohortComponents`; add `assign(:theme, "light")` in
  `mount/2` (server-owned theme, D-96-07/16 — no `localStorage`); wrap the page body in
  `<Layouts.app flash={@flash} page_title={...} nav={:upload}>` → `<.ck_page eyebrow=… title=…
  lede=… theme={@theme}>` → existing body. **`Layouts.app` is untouched** (no responsibility
  bleed; daisyUI `<main>`/`<link>` retirement is strictly Phase 101). `ck_page` emits
  `data-ck-root` + server `data-theme` on the `.ck` div (D-96-05), so the polish-gate seam
  (Phase 99 Pitfall 5), `:focus-visible`, reduced-motion, and box-sizing all reach `/upload` for
  free. `ck_page`'s `.ck__wrap` is `--ck-maxw: 64rem` (1024px) — wider than today's `max-w-3xl`
  (768px), a strict improvement for the 6-tab strip.
- **D-100-02a:** **Pass `nav={:upload}`** (today `/upload` does not set it) so `cohort_nav`
  highlights the active section — a free wayfinding/a11y win (`cohort_nav` already supports
  `active={:upload}`).
- **D-100-02b:** The member line value `<strong id="upload-member-name"
  data-testid="upload-member-name">{@member.name}</strong>` is **load-bearing — keep it
  byte-for-byte** as a `.ck` line inside `:inner_block` (or a `.ck-hero__lede` sibling), the same
  way `/dashboard` put `data-testid="cohort-dashboard-title"` on an explicit element because
  `ck_page`'s `:title` `<h1>` cannot carry a testid.

### Tab Navigation — THE decisive call (Area 2 — researched, HIGH confidence; corrects the draft assumption)

- **D-100-03:** **Keep the server-driven URL-`patch` tab model.** The 6 tabs are
  `<.link patch={~p"/upload?...&tab=#{tab}"}>` and only the active panel renders via
  `:if={@tab == ...}`. Restyle the tab links onto `.ck-*`; do **NOT** adopt the `ck_tabs/1`
  client widget and do **NOT** add `role=tab`/`role=tablist`.
  - **Why not `ck_tabs/1`:** it is the in-page WAI-ARIA APG primitive (`role=tab`, roving
    `tabindex`, all panels in one DOM, `phx-hook="Tabs"`, `phx-click` server event — built for the
    *different* in-page case, D-96-17). Adopting it would (1) force a DOM restructure (all 6
    panels rendered + JS-hidden) violating the class-only / `:if` single-panel contract; (2)
    replace `<.link patch>` URL nav with events, breaking the `?tab=` patch **and** the
    `tus-resume.spec.js` `?tab=tus` deep link; (3) regress a11y for a genuinely-routed surface;
    (4) impose arrow-key-only nav on a developer audience that expects linkable/shareable tab
    URLs.
  - **Ecosystem consensus (researched):** when activating a "tab" changes the URL/route it is
    **navigation → links with `aria-current`, never `role=tablist`** (WAI-ARIA APG, Inclusive
    Components, GitHub/Stripe/gov.uk precedent). Forcing `role=tab` onto routed nav hides the tabs
    from the screen-reader links list, removes Tab-key access, and breaks back-button mental
    models.
- **D-100-04:** **CRITICAL correction to the original draft** — there is **no standalone styled
  `.ck-tab` selector** in `cohort.css`; `.ck-tab` is an *empty* class used only as a polish-gate
  `interactiveSelector` hook. All tab styling lives on **`.ck-tabs__tab`**. So apply
  `class="ck-tabs__tab ck-tab"` to the existing `<.link>` (the `ck-tab` token keeps the polish
  gate finding the element; `ck-tabs__tab` carries the visuals + 44px target + focus ring), wrap
  the strip in `<div class="ck-tabs__list" role="navigation" aria-label="Upload strategy">`, mark
  the active link with **`aria-current={@current == @tab && "page"}`** (navigation-correct), and
  **delete `tab_class/2`**. Keep every `data-testid="upload-tab-#{tab}"` and the `<div :if={@tab
  == ...}>` single-panel render byte-for-byte. (This is the Cohort analog of Phase 99 Pitfall 4 —
  `ck_button` is link-only → put the class on the existing element — but note `.ck-btn` is fully
  styled whereas `.ck-tab` is empty, hence `.ck-tabs__tab` is the styling carrier.)
- **D-100-05:** **One tiny token-only CSS rule is required** (the single new CSS in this phase):
  because the selected state is correctly `aria-current="page"` (not `aria-selected`), add to
  `cohort.css`, mirroring the existing `.ck-tabs__tab[aria-selected="true"]` rule and token-only
  (no hex/rgb outside token blocks — D-96-09/20, passes the literal scanner):
  ```css
  .ck-tabs__tab[aria-current="page"] {
    color: var(--ck-ink);
    font-weight: 700;
    border-bottom-color: var(--ck-brand);
  }
  ```
  (May be consolidated as `.ck-tabs__tab[aria-selected="true"], .ck-tabs__tab[aria-current="page"]`.)
  This carries the non-color selected cue (underline + weight), satisfying D-96-22. Within the
  Phase 99 "one tiny token-only rule" allowance (the `.ck-output` precedent).

### Panel Bodies, Hooks, Status/Error UX (Area 3 — researched, HIGH confidence)

- **D-100-06:** Class-only swap with **ZERO new `.ck-*` rules** (every element maps to an existing
  primitive). Preserve byte-for-byte every panel/status `id`+`data-testid`, the 4 `phx-hook`s, the
  2 `<.live_file_input>`, the 2 `<.form phx-change/phx-submit>`, all file `<input>` attrs, the 3
  `<button>`s, `tus-upload-error`, `image-upload-asset-id`, `mux-streaming-url`. Mapping:
  - Status `<p class="font-mono text-sm">` (`*-upload-status`) → **`.ck-output`** (the existing
    token-only mono code/debug surface; status is open-ended system output incl. `error: <reason>`
    — NOT a `badge`/enum pill).
  - tus error `<p class="text-red-600">` (`tus-upload-error`) → **`.ck-error`** + inline warning
    icon (mirror the `ck_field` icon markup) + **`role="alert"`**. This fixes a color-only error
    violation (D-96-15) and makes the message announced. Keep `id`/`data-testid`/`:if={@tus_error}`.
  - File inputs (bare `<input type=file>` + `<.live_file_input>`) → **`.ck-input`** (gives 44px
    min-height, token border, hover/`:focus-visible`, dark/light parity; ZERO new CSS; no hook
    risk).
  - Buttons carrying hooks/submit (`multipart-upload-button` `phx-hook="MultipartUpload"`, the 2
    `type=submit`) → **`.ck-btn ck-btn--primary` on the EXISTING `<button>`** — **never** the
    link-only `ck_button/1` (Pitfall 4: it renders `<.link href>` and would silently drop the hook
    / submit semantics).
  - `mux-streaming-url` `<p class="text-xs break-all">` → `.ck-output` (URL = system output;
    `overflow-x:auto` handles length). Planner caveat: if wrapping is preferred over scroll for the
    long Mux URL, keep a minimal token wrapper instead — not worth a new rule.
  - Description `<p class="text-sm">` and `image-upload-asset-id` → `.ck-help` (token muted
    secondary text) for DS consistency.
  - Retire panel-wrapper daisyUI utilities (`mt-6 space-y-3`, etc.) onto `.ck`-scoped spacing.

### Proof / Validation (Area 4 — researched, HIGH confidence)

- **D-100-07:** **Extend (never fork)** both Phase-99 harnesses. Prove `/upload` as **SIX variants**
  in each gate, driven by the deterministic `?tab=` URL (not a client tab-click — that's the
  behavior specs' job; Nyquist decisive-test split):
  - **Playwright polish (`e2e/cohort-pages.spec.js`):** 6 flat `test(...)` cases, one per tab,
    each calling the already-exported `assertCohortPagePolish(page, {route: "/upload?tab=X",
    surface: "upload-X-cohort"})` (warn mode, `[data-ck-root]` guard, reuses `assertAdminPolish`
    UNCHANGED — D-96-06; `load_member!(nil)` falls back to first seeded member). **+1 dark case** on
    the image tab via `emulateMedia({colorScheme:"dark"})` applied **after** `goto` (D-96-21).
  - **ExUnit (`test/.../cohort_migration_contract_test.exs`):** ONE test with a 6-entry per-tab
    `for` comprehension rendering `~p"/upload?tab=#{tab}"` and calling the unchanged
    `assert_frozen_contract/2` (each panel's selector set + the always-present `upload-member-name`
    + 6 `upload-tab-#{tab}` links + `data-ck-root` + refute `raw(`) and `assert_daisyui_retired/1`
    (the Pitfall-6 completeness gate — catches stray `btn`/`tabs`/`text-2xl`/`font-mono`/
    `text-red-600`/`space-y-`).
  - **The 6 existing behavior specs** (`{image,video,multipart,liveview,mux,tus}-*.spec.js`) stay
    UNCHANGED and remain the behavior backstop; confirm green post-migration (class-only swap; they
    key on testids/ids, not classes).
  - Theme: default light via the `ck_page` scaffold attr (no per-page toggle); dark proven once
    (image tab). **No new screenshot infra** — warn-mode polish is the gate this phase; pixel
    baselines stay deferred to Phase 102.

### Microcopy (Area 1/2/3 — researched; display-only, safe — labels not under test)

- **D-100-08:** `/upload` header (developer-adopter JTBD = "show me this works, and how"):
  - eyebrow: `Upload lab`
  - title: `Every Rindle upload path, live.`
  - lede: `Six ingest flows against real MinIO — presigned PUT, tus resume, multipart, LiveView
    server upload, AV variants, and Mux streaming. Pick a tab to run one end to end; the data is
    seeded, the uploads are real.`
  - Tab labels (display-only tightenings, optional but recommended): `Image (presigned PUT)`,
    `Tus (resumable)`, `Video (AV variants)`; keep `Multipart`, `LiveView upload`, `Mux streaming`.

### Claude's Discretion

Per `minimal_decisive` calibration: exact `surface:` strings, the `aria-label` wording, whether to
consolidate the `aria-current`/`aria-selected` selectors, the precise icon SVG reused for
`.ck-error`, the per-tab `for`-comprehension layout in the ExUnit test, and whether to additionally
assert a `data-theme` marker on the light cases — all resolvable during planning, provided the
locked decisions above hold, the frozen DOM contract is preserved, and no `cohort.css` token VALUE
/ `tokens.json` / `admin-polish.js` is edited.

### Folded Todos

No matching pending todos (`todo.match-phase 100` → 0 matches).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 100 boundary (COHORT-02); Track B build order; Phase 101/102 deferral
- `.planning/REQUIREMENTS.md` — COHORT-02 (the sole requirement this phase owns)
- `.planning/STATE.md` — v1.19 position; two-DS separation note
- `.planning/METHODOLOGY.md` — Narrow-Then-Escalate / Idiomatic-Elixir-Least-Surprise / Repo-Truth / Research-First lenses
- `.planning/phases/99-cohort-page-migrations-the-small-7-track-b/99-RESEARCH.md` — the PROVEN recipe
  (the per-page class-map idiom, Pitfalls 1–6, the Validation Architecture / Nyquist decisive-test
  split). Phase 100 mirrors this one-to-one on `/upload`.
- `.planning/phases/99-cohort-page-migrations-the-small-7-track-b/99-01-SUMMARY.md` — what `ck_page/1`,
  `.ck-output`, `cohort-pages.spec.js`, and `cohort_migration_contract_test.exs` actually shipped as
- `.planning/phases/96-cohort-component-layer-dark-reduced-motion-contract-track-b/96-CONTEXT.md` —
  the binding inherited contract: D-96-05 (`.ck`+`data-ck-root` per-LiveView, never `<body>`),
  D-96-06 (`assertAdminPolish` reused unchanged, warn mode), D-96-07/16 (server-state theme, no
  localStorage), D-96-09/20 (hand-authored token-only CSS, literal scanner), D-96-15 (`.ck-input`
  FormField + aria; error = icon+message never color-only), D-96-17 (the `ck_tabs/1` in-page tabs
  primitive — NOT for routed tabs), D-96-22 (interaction-state matrix; selected = aria + non-color
  mark), D-96-23 (`--ck-muted` readable / `--ck-faint` decorative)
- `.planning/phases/94-foundation-token-pipeline-ci-gate-new-token-categories/94-CONTEXT.md` —
  D-94-05/06 (cohort.css hand-authored, separate build), D-94-07 (`admin-polish.js` `{root,
  interactiveSelectors}` seam)
- `examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex` — the migration target. Tab strip
  `:54-61`, `tab_link/1` `:146`, `tab_class/2` `:473` (to delete), 6 panels `:if` `:63-136`,
  `handle_params`/`?tab=` `:38-43`, `load_member!(nil)` fallback `:469`, status assigns + `@tus_error`
- `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` + `dashboard_live.ex` — the exact
  `ck_page` composition precedents to mirror
- `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex` — `ck_page/1` (`:78`,
  the scaffold to compose), `ck_tabs/1` (`:558`, the in-page primitive to AVOID for routed tabs),
  `ck_button/1` (link-only — Pitfall 4), `badge/1`, `ck_field`/`ck_detail` (icon/error markup to mirror)
- `examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex` — `Layouts.app/1` (UNTOUCHED;
  `cohort_nav active={:upload}` support)
- `examples/adoption_demo/priv/static/assets/cohort.css` — `--ck-maxw: 64rem` (`:108`); the tabs block
  `.ck-tabs`/`.ck-tabs__list`/`.ck-tabs__tab`/`[aria-selected="true"]` (`:912-957`, **no standalone
  `.ck-tab`**); `.ck-output` (`:461`); `.ck-error`/`.ck-input`/`.ck-btn`/`.ck-help` rules + tokens
- `examples/adoption_demo/e2e/cohort-pages.spec.js` — the warn-mode polish harness to EXTEND
  (`assertCohortPagePolish`, `reportPolish`, `interactiveSelectors` incl. `.ck-tab`)
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` — the ExUnit
  frozen-contract / daisyUI-retirement harness to EXTEND (`assert_frozen_contract/2`,
  `assert_daisyui_retired/1`, `render_route/2`, `page_body/1`)
- `examples/adoption_demo/e2e/{image-upload,video-upload,multipart-upload,liveview-upload,mux-streaming,tus-resume}.spec.js`
  — the 6 behavior specs (the frozen-contract backstop; unchanged). `tus-resume` uses the
  `?tab=tus` deep link
- `examples/adoption_demo/e2e/support/admin-polish.js` — `assertAdminPolish({root,
  interactiveSelectors})` (do NOT edit — D-96-06)
- `prompts/phoenix-media-uploads-lib-deep-research.md` — upload-domain UX research (status/progress/
  error best practices; informs the deferred-ideas list)
- `brandbook/brand.css` + `brandbook/tokens/` — the LIVE brand source of truth (supersedes any older
  brandbook reference in `prompts/rindle-brand-book.md`)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (everything this phase needs already exists)
- `ck_page/1` scaffold (`cohort_components.ex:78`) — the `.ck` shell + `data-ck-root` + server
  `data-theme` + `.ck__wrap` + `.ck-hero` header. Built UNUSED in Phase 99 for exactly this family.
- `.ck-tabs__tab` (+ `.ck-tabs__list`) styling, `.ck-output`, `.ck-error`, `.ck-input`,
  `.ck-btn`/`--primary`, `.ck-help` — all exist, token-only, dark/light-correct, scanner-clean.
- `assertCohortPagePolish(page,{route,surface})` (`cohort-pages.spec.js`) — URL-driven warn-mode
  polish runner reusing `assertAdminPolish` unchanged; just add `test(...)` entries.
- `assert_frozen_contract/2` + `assert_daisyui_retired/1` + `render_route/2`
  (`cohort_migration_contract_test.exs`) — the static ExUnit gate; just add a `/upload` test.
- `load_member!(nil)` fallback → member-less `?tab=` URLs render (the polish gate needs no seeded id).

### Established Patterns
- `cohort.css` is hand-authored vanilla CSS (D-94-05/06) — any new rule is hand-written, token-only,
  must pass the brace-depth literal scanner. NO generator, NO `tokens.json` edit.
- Theme is server state (`assign(:theme)`); `data-ck-root`/`data-theme` live on the per-LiveView `.ck`
  div, never `<body>` (D-96-05).
- Routed tabs (URL-addressable) = links + `aria-current="page"`; in-page tabs = `ck_tabs/1`
  `role=tab` widget. `/upload` is the routed case.
- Mechanical proof preferred: per-tab computed-style polish (warn mode) + static `render_to_string`
  frozen-contract greps over subjective screenshot review.

### Integration Points
- `upload_live.ex`: import CohortComponents; `mount` `assign(:theme,"light")`; wrap body in
  `Layouts.app nav={:upload}` + `ck_page`; restyle tab strip (`.ck-tabs__list`/`.ck-tabs__tab ck-tab`
  + `aria-current`, delete `tab_class/2`); class-swap the 6 panels.
- `cohort.css`: add the ONE `.ck-tabs__tab[aria-current="page"]` token-only rule.
- `cohort-pages.spec.js`: 6 per-tab polish cases + 1 dark case.
- `cohort_migration_contract_test.exs`: 1 `/upload` per-tab frozen-contract + daisyUI-retirement test.
</code_context>

<specifics>
## Specific Ideas

- The `/upload` page is a developer-facing **guided tour of Rindle's upload strategies** — the JTBD is
  "let me try each upload mode and see it work (and bookmark/share the one that broke)." The
  URL-addressable tab links directly serve the shareable-deep-link expectation; the `.ck-output`
  status line is the "I can see it working" affordance.
- Error states must pair an icon/label, never color-alone (D-96-15) — the tus error gains the warning
  icon + `role="alert"`.
- Every interactive `.ck-*` control ships a token-backed `:focus-visible` ring (inherited from `.ck`),
  44px min target, and is correct in light/dark/system with no hover/focus weirdness.
</specifics>

<deferred>
## Deferred Ideas

- **Higher-value upload UX (require DOM/behavior change — out of class-only scope, worth a future
  ticket):** drag-and-drop dropzone affordance; live percent/byte progress bar (LiveView
  `entry.progress` is already computed but collapsed to the word "uploading"); per-entry preview
  thumbnails / cancel buttons; human-readable status microcopy ("Requesting upload URL…",
  "Verifying…", "Attached ✓") replacing the terse engineering tokens.
- daisyUI/Tailwind scaffold retirement (`default.css` `<link>` + the `Layouts.app` daisyUI `<main>`)
  → **Phase 101 (COHORT-05)**.
- warn→fail flip of the Cohort polish gate + VIS-* re-converge / idempotency / cross-surface audit →
  **Phase 102**.
- Optional non-blocking pixel-baseline screenshots → later milestone work.

### Reviewed Todos (not folded)
None — `todo.match-phase 100` returned 0 matches.
</deferred>
