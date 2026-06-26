# Phase 101: daisyUI Retirement [Track B] - Context

**Gathered:** 2026-06-18 (assumptions mode + 3 parallel `gsd-advisor-researcher` subagents)
**Status:** Ready for planning

<domain>
## Phase Boundary

Track B (COHORT-05). This is the **retirement/teardown** phase that Phases 99 and 100
deliberately deferred. Phases 99 (the small-7 pages) and 100 (`/upload`) already migrated all
8 routed Cohort inner pages class-by-class onto the hand-authored token-only `.ck-*` design
system (`examples/adoption_demo/priv/static/assets/cohort.css` — vanilla CSS, NO Tailwind, NO
build step, must pass the brace-depth literal-hex scanner). Phase 101 removes the **leftover
daisyUI/Tailwind scaffold** so the demo is grep-clean, then deletes `default.css` (a 2590-line
pre-built daisyUI/Tailwind v4 dump) and its `<link>`.

**What this phase owns (the only remaining daisyUI in the rendered demo):**
1. The `Layouts.app` Tailwind wrapper (`layouts.ex:40-41` — `<main class="px-4 py-8 sm:px-6
   lg:px-8"><div class="mx-auto max-w-3xl space-y-4">`).
2. `CoreComponents.flash`/`flash_group` (`core_components.ex:56-86` — daisyUI `toast`/`alert`/
   `alert-info`/`alert-error` + `hero-*` icons), which renders on **all 8 inner pages** via
   `Layouts.app`.
3. The unrouted generator dead code (`page_controller.ex` + `page_html.ex` + `home.html.heex`).
4. The `default.css` `<link>` (`root.html.heex:9`) + the `default.css` file itself.
5. Promoting the daisyUI-retirement ExUnit gate from per-page to demo-wide + source/file
   assertions.

**This is teardown + ONE small token-only CSS addition (`.ck-flash`/`.ck-alert`) + inline-SVG
icon swap, NOT construction.** Zero new deps. No `tokens.json` / token-VALUE edits.

**Out of scope (deferred):** warn→fail flip of the Cohort polish gate + VIS-* re-converge /
idempotency / cross-surface visual matrix / milestone audit → **Phase 102 (VIS-01..04)**; any
`cohort.css` token-VALUE or `tokens.json` change (e.g. adding `--ck-info-surface`); the admin
(`rindle-admin`) surfaces (deliberately separate but coherent — D-94-05/06). Optional pixel
baselines → later milestone.
</domain>

<decisions>
## Implementation Decisions

### Area A — Generator dead code & the hero-icon dependency (researched, HIGH confidence)

- **D-101-01:** **DELETE** the unrouted Phoenix `--no-tailwind` generator landing page:
  `examples/adoption_demo/lib/adoption_demo_web/controllers/page_controller.ex`,
  `.../page_html.ex`, and `.../page_html/home.html.heex`. They are provably dead — `router.ex:23`
  routes `/` to `LaunchpadLive`, and a repo-wide grep finds no reference to `PageController`/
  `PageHTML` outside their own definitions. `home.html.heex` (~201 lines of daisyUI utilities:
  `base-200`, `rounded-box`, `badge badge-warning`, `text-base-content/70`) is the single biggest
  source of utility-class grep hits (~19). Migrating dead code is cargo-cult; excluding it from
  the scan hides rather than removes. **Delete, don't migrate, don't exclude.**
- **D-101-02:** **Rename** the mis-named `test/.../controllers/page_controller_test.exs` →
  `LaunchpadLiveTest` (it already asserts against `LaunchpadLive` at `/`, never invokes
  `PageController.home/2`, so deletion of the controller breaks no test). Cosmetic tidy, not a
  blocker.
- **D-101-03:** **Inline the 3 needed hero icons as token-only `<svg>`.** The hero glyphs
  (`hero-information-circle`, `hero-exclamation-circle`, `hero-x-mark`) are defined **inside
  `default.css`** (`:1458-1560`, `--hero-*: url(data:image/svg+xml…)` + `mask`/`-webkit-mask`
  rules); `CoreComponents.icon/1` renders a glyphless `<span class={[@name, @class]}>` that
  depends entirely on them. Flash uses all 3 and renders on every page — so **deleting
  `default.css` breaks flash icons site-wide unless the icons are inlined first.** Inline them as
  plain `<svg viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">` directly in the
  flash (and the `core_components.ex` error helper), exactly mirroring the private
  `ck_icon`/`task_icon`/`cast_icon` inline-SVG idiom already in `cohort_components.ex`. Do **NOT**
  add a `mask:`/`data:` hero rule to `cohort.css` (re-imports the very pattern being retired) and
  do **NOT** drop icons (a11y/polish regression). Icon inherits color via `currentColor`. **This
  inlining is a hard prerequisite for the `default.css` deletion and must land in the same atomic
  change/PR.**

### Area B — Flash/alert primitive + the Layouts wrapper (researched, HIGH confidence)

- **D-101-04:** **Add a token-only `.ck-flash` + `.ck-alert` family to `cohort.css`** (the only
  net-new CSS this phase — every value a `var(--ck-*)`, passes the literal scanner, no
  `tokens.json` edit). Shape: `.ck-flash` = fixed top-end toast container (`position:fixed; top/
  right: var(--ck-*); z-index:50` above `.ck-nav`'s 20; `width:min(24rem, calc(100vw - …))`);
  `.ck-alert` = `--ck-surface` ground + `1px var(--ck-border)` + a **colored 3px left-border
  accent** (`--_accent`, default `--ck-info`) + `--ck-radius` + `--ck-shadow-lg`;
  `.ck-alert--info { --_accent: var(--ck-info) }`, `.ck-alert--error { --_accent:
  var(--ck-quarantine) }`; `.ck-alert__icon/__body/__title/__msg`; `.ck-alert__dismiss` =
  44px min target with negative margin to preserve hit area (D-96-22). Entrance reuses the
  existing `ck-rise` keyframe (`cohort.css:1032`) gated on
  `@media (prefers-reduced-motion: no-preference)`. The colored-ground-via-left-border approach
  mirrors the existing `.ck-stat` accent pattern (`cohort.css:745-760`) and **sidesteps the one
  token gap** (Cohort has `--ck-info`/`--ck-quarantine` foreground tokens but no per-state
  *surface* token like brandbook's `--rindle-status-*-surface`) without any token-value edit.
- **D-101-05:** **Wrap the rendered flash in a `.ck` element** (`class="ck ck-flash"`). Flash
  currently renders **outside any `.ck` root** (in `Layouts.app` after `</main>`), so the
  `:focus-visible` ring and the reduced-motion `.ck *` clamp (D-96-13) do not reach it unless it
  lives under `.ck`. Wrapping fixes both for free.
- **D-101-06:** **Keep the Phoenix 1.8 `flash`/`flash_group` contract; swap only the class layer.**
  Preserve `attr :kind`/`:flash`/`:title`/`:rest`, the `Phoenix.Flash.get` slot fallback, the
  JS click-to-dismiss, and the outer `flash_group` `aria-live="polite"` wrapper. Do NOT
  restructure markup toward a different shape (Phoenix 1.8 flash *is* the modern convention —
  only its daisyUI classes are non-idiomatic).
- **D-101-07:** **A11y contract (split by kind):** `:info` → `role="status"` + `aria-live=
  "polite"`; `:error` → `role="alert"` + `aria-live="assertive"` (WCAG 4.1.3; today both use
  `role="alert"` — split so info does not interrupt). **No auto-dismiss timer** (WCAG 2.2.1 — manual
  dismiss only; matches Phoenix's own click-to-dismiss). Flash never steals focus. Non-color
  state cue = icon + colored left-border (+ optional kind label), never color alone (D-96-15).
  Dismiss button: 44px target, real `aria-label` ("Close notification"), inherited
  `:focus-visible` ring.
- **D-101-08:** **Microcopy posture** (developer-adopter persona): terse, factual, no
  exclamation/emoji. Info confirms ("Upload complete"); error states the failure + the actionable
  next step where the upload domain provides one ("Upload failed — resume from the last chunk").
  Titles optional; default to title-less single-line for routine confirmations.
- **D-101-09:** **Delete the `Layouts.app` Tailwind wrapper.** Remove `<main class="px-4 py-8
  sm:px-6 lg:px-8">` and the inner `<div class="mx-auto max-w-3xl space-y-4">` (`layouts.ex:
  40-41`); render `{render_slot(@inner_block)}` directly (a bare `<main>` is fine), and re-home
  `<.cohort_footer />` + `<.flash_group />` as direct children of `app/1`. Every routed page
  nests `<Layouts.app>` → `<.ck_page>` → `.ck__wrap` (`cohort.css:211`, 64rem max-width +
  responsive `clamp()` padding), so the Tailwind wrapper is redundant *and* conflicting (it capped
  content at 48rem, narrower than the design's 64rem column, and nested padding inside padding).
  No page renders `Layouts.app` content without `ck_page` (styleguide/launchpad build their own
  `.ck` shell), so removal regresses nothing — and it removes the last Tailwind utilities from the
  layout, clearing the path to delete `default.css`.

### Area C — Proof gate promotion + irreversible-teardown ordering (researched, HIGH confidence)

- **D-101-10:** **One layered retirement gate, implemented entirely inside the existing
  `test/adoption_demo_web/live/cohort_migration_contract_test.exs`** so it runs in the
  merge-blocking `adoption-demo-unit` lane (`mix test`) — NO new CI tooling, NO raw shell
  `rg 'btn'` step (that bare-substring shape is exactly the Phase-100 contract-test defect).
  Three layers:
  1. **Widen the render scan demo-wide** — stop slicing `assert_daisyui_retired/1` through
     `page_body/1` (the `[data-ck-root]` scope that explicitly excluded `Layouts.app` "until
     Phase 101", `:30-31`), so the scan covers the full composed page including the layout
     wrapper. Add the now-in-scope wrapper literals to `@retired_daisyui_classes`:
     `~s(class="px-4 py-8)`, `"mx-auto max-w-3xl"`, `"space-y-4"`.
  2. **Add a source+file test** — the decisive half. `File.read!` `layouts.ex`,
     `core_components.ex`, and `root.html.heex` and `refute` the **conditionally-rendered** flash
     daisyUI literals that a clean page render never contains (so a render-only scan
     false-greens): `~s(class="toast)`, `"toast-top"`, `"alert-info"`, `"alert-error"`,
     `~s(class="alert)`, `"btn-primary"`, `"btn-soft"`. Plus `refute File.read!(root.html.heex)
     =~ "default.css"` (criterion 2a) and `refute File.exists?(.../assets/default.css)`
     (criterion 2b).
  3. **Anchor every literal to the `class="…` attribute boundary** (never the bare utility word)
     so `.ck-btn`/`.ck-tab`/`.ck-tabs`/`.ck-grid` are not substring-matched — the shipped list
     already does this for the tab classes; every added literal must follow the same rule.
  The gate is a **forward-only idempotency ratchet** (asserts absence; once green stays green,
  only fails when a banned token reappears) — satisfying the milestone's "only moves quality
  forward" posture. Per milestone proof posture the **static/source gate is the merge-blocking
  proof**; the Playwright polish lane is the no-regression backstop (stays warn-mode; warn→fail
  is Phase 102).
- **D-101-11:** **Teardown ordering (destructive step last, behind a green grep):**
  1. Migrate the leftover daisyUI markup off the rendered pages first — retire `CoreComponents.
     flash`/`flash_group` to `.ck-*` (D-101-04..08, incl. inline-SVG icons D-101-03) and delete
     the `Layouts.app` wrapper (D-101-09); delete the generator dead code (D-101-01/02). This
     makes the grep clean.
  2. Promote the gate (D-101-10) in the same wave, then remove the `<link phx-track-static …
     href={~p"/assets/default.css"} />` line from `root.html.heex:9` (criterion 2a).
  3. **`git rm examples/adoption_demo/priv/static/assets/default.css` LAST** (criterion 2 —
     "delete only after grep clean") — it is a committed static asset with **no build pipeline to
     chase** (no esbuild/tailwind step regenerates it; `app.css` is empty); the file's own header
     (`:1-3`) self-authorizes deletion. Land it with the `refute File.exists?` assertion.
  4. Run the screenshot/behavior lane as the criterion-3 safety net — `adoption-demo-e2e`
     (`cohort-pages.spec.js` polish over all 8 pages incl. 6 `/upload` tabs + dark, plus the
     behavior specs image/video/multipart/liveview/mux-streaming/tus-resume) confirms no page
     regressed to unstyled once `default.css` is gone.

### Claude's Discretion

Per `minimal_decisive` calibration, resolvable during planning provided the locked decisions
hold: exact `--ck-*` token names used inside `.ck-flash`/`.ck-alert` (verify against
`cohort.css` token blocks), whether to add a visible kind label vs icon-only, the precise inline
SVG path data for the 3 glyphs, whether the gate's source-read uses a per-file helper or a flat
list, the exact `surface:` string if a flash polish case is added, and whether to consolidate the
`.ck-alert--info`/`--error` selectors. No `cohort.css` token VALUE / `tokens.json` /
`admin-polish.js` edit; the frozen DOM contracts and behavior specs stay green.

### Folded Todos

No matching pending todos (`todo.match-phase 101` → 0 matches).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 101 boundary (COHORT-05, ~line 433); Phase 102 deferral
- `.planning/REQUIREMENTS.md` — COHORT-05 (the sole requirement this phase owns, lines 74-76)
- `.planning/STATE.md` — v1.19 position; two-DS separation note; the Phase-100 over-broad-substring
  contract-test defect lesson
- `.planning/METHODOLOGY.md` — Repo-Truth Evidence Ladder, Idiomatic-Elixir-Least-Surprise,
  Narrow-Then-Escalate, Research-First, Automate-UAT-shift-left lenses
- `.planning/phases/100-cohort-upload-migration-all-tabs-track-b/100-CONTEXT.md` — the immediate
  predecessor; its `<deferred>` section names exactly what Phase 101 owns (`default.css` `<link>`,
  `Layouts.app` daisyUI `<main>`); D-100-04 (`.ck-tab` is an empty hook → over-broad-substring risk)
- `.planning/phases/99-cohort-page-migrations-the-small-7-track-b/99-RESEARCH.md` — the proven
  migration recipe, Pitfalls 1-6 (esp. Pitfall 6 = the completeness/retirement gate), the
  Validation Architecture / Nyquist decisive-test split
- `.planning/phases/99-cohort-page-migrations-the-small-7-track-b/99-01-SUMMARY.md` — what the
  `cohort_migration_contract_test.exs` harness + `cohort-pages.spec.js` shipped as ("extend never fork")
- `.planning/phases/96-cohort-component-layer-dark-reduced-motion-contract-track-b/96-CONTEXT.md` —
  the binding inherited contract: D-96-05 (`.ck`+`data-ck-root` per-LiveView, never `<body>`),
  D-96-09/20 (hand-authored token-only CSS, literal scanner), D-96-13 (reduced-motion scoped to
  `.ck *`), D-96-15 (error = icon+message, never color-only), D-96-21 (dark via `emulateMedia`),
  D-96-22 (interaction-state matrix; 44px target; `:focus-visible`), D-96-23 (`--ck-muted` readable)
- `.planning/phases/94-foundation-token-pipeline-ci-gate-new-token-categories/94-CONTEXT.md` —
  D-94-05/06 (cohort.css hand-authored, separate build; Cohort ≠ rindle-admin)
- `examples/adoption_demo/lib/adoption_demo_web/components/core_components.ex` — `flash/1` (`:56-86`,
  the daisyUI `toast`/`alert*` + `<.icon hero-*>` to retire), error helper (`~:305-312`),
  `icon/1` (`~:448-452`, the glyphless span dependent on default.css hero rules)
- `examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex` — `app/1` (`:36-49`; delete the
  `<main>`/`<div>` wrapper; re-home footer + flash_group), `flash_group/1`
- `examples/adoption_demo/lib/adoption_demo_web/components/layouts/root.html.heex` — the `default.css`
  `<link>` to remove (`:9`); app.css + cohort.css links stay
- `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex` — `ck_page/1` (`:78`,
  owns `.ck__wrap`), the private `ck_icon`/`task_icon`/`cast_icon` inline-SVG idiom to mirror for flash
- `examples/adoption_demo/lib/adoption_demo_web/router.ex` — `/` → `LaunchpadLive` (`:23`, proves the
  generator landing is dead)
- `examples/adoption_demo/lib/adoption_demo_web/controllers/page_controller.ex` + `page_html.ex` +
  `page_html/home.html.heex` — the dead generator code to delete
- `examples/adoption_demo/test/adoption_demo_web/controllers/page_controller_test.exs` — mis-named;
  already tests `LaunchpadLive` → rename to `LaunchpadLiveTest`
- `examples/adoption_demo/priv/static/assets/default.css` — the daisyUI/Tailwind v4 dump to delete
  (`:1-3` self-authorizing header; hero rules `:1458-1560`); `app.css` is empty (no build step)
- `examples/adoption_demo/priv/static/assets/cohort.css` — token blocks (`:43-191`), `.ck__wrap`
  (`:211`, 64rem + clamp padding), `.ck-error`/`.ck-icon` (`~:898-910`), `.ck-stat` left-border accent
  (`:745-760`), `ck-rise` keyframe (`:1032`), reduced-motion block (`~:1025-1055`) — where `.ck-flash`/
  `.ck-alert` is added (token-only)
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` — the gate to
  promote: `@retired_daisyui_classes`, `assert_daisyui_retired/1`, `render_route/2`, `page_body/1`
  (`:18-21,30-48,98-104`; the Phase-101 placeholder comment lives here)
- `examples/adoption_demo/e2e/cohort-pages.spec.js` — warn-mode polish lane (criterion-3 net; unchanged)
- `examples/adoption_demo/e2e/{image-upload,video-upload,multipart-upload,liveview-upload,mux-streaming,tus-resume}.spec.js`
  — behavior specs (the frozen-contract backstop; confirm green post-teardown)
- `.github/workflows/ci.yml` — `adoption-demo-unit` (`mix test`, merge-blocking, `~:558-629`) and
  `adoption-demo-e2e` (Playwright, `~:649-760`) lanes
- `brandbook/brand.css` + `brandbook/tokens/tokens.css` — the LIVE brand source of truth (supersedes
  stale parts of `prompts/rindle-brand-book.md`); `--rindle-status-*-surface` (`~:76-79`) shows the
  per-state surface tokens Cohort lacks (noted-not-fixed)
- `prompts/phoenix-media-uploads-lib-deep-research.md` — upload-domain UX (flash reports upload
  success/error; informs microcopy)
- `prompts/gsd-rindle-elixir-oss-dna.md` — OSS posture / clean-adopter-example DNA
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (nearly everything this phase needs already exists)
- `ck_page/1` / `.ck__wrap` (`cohort.css:211`, 64rem + clamp padding) — already owns content
  width/padding on all 8 pages, making the `Layouts.app` Tailwind wrapper redundant.
- Existing tokens for the flash: `--ck-info`, `--ck-quarantine`, `--ck-surface`, `--ck-border`,
  `--ck-ink`, `--ck-muted`, `--ck-faint`, `--ck-radius`, `--ck-shadow-lg`, spacing scale,
  `ck-rise` keyframe, the `.ck *` reduced-motion clamp, the `.ck :focus-visible` ring.
- `.ck-stat` left-border accent pattern (`cohort.css:745-760`) — the precedent the `.ck-alert`
  colored accent mirrors (sidesteps the missing per-state surface token).
- `ck_icon`/`task_icon`/`cast_icon` private inline-SVG clauses (`cohort_components.ex`) — the
  idiom to mirror for the 3 inlined flash icons.
- `assert_daisyui_retired/1` + `render_route/2` + `@retired_daisyui_classes`
  (`cohort_migration_contract_test.exs`) — the gate to promote (extend, never fork).
- `cohort-pages.spec.js` warn-mode polish lane + the 6 behavior specs — the criterion-3 net.

### Established Patterns
- `cohort.css` is hand-authored vanilla CSS (D-94-05/06); any new rule is hand-written, token-only,
  must pass the brace-depth literal scanner. NO generator, NO `tokens.json` / token-VALUE edit.
- `data-ck-root`/reduced-motion/focus-ring live on the per-LiveView `.ck` div, never `<body>`
  (D-96-05/13) — hence the flash must be wrapped in `.ck` to inherit them.
- daisyUI styling for the whole demo comes ONLY from `default.css` (app.css empty, no build step);
  removing it un-styles whatever still uses daisyUI classes/hero icons — hence the migrate-first,
  delete-last ordering.
- Retirement-scan literals are anchored to the `class="…` attribute boundary to avoid matching the
  DS's own `.ck-btn`/`.ck-tab`/`.ck-tabs`/`.ck-grid` (the Phase-100 over-broad-substring defect).

### Integration Points
- `core_components.ex`: flash → `.ck ck-flash` + `.ck-alert*`, inline-SVG icons, split a11y; error
  helper → inline-SVG icon.
- `layouts.ex` `app/1`: delete the `<main>`/`<div>` wrapper; re-home `cohort_footer` + `flash_group`.
- `cohort.css`: add the token-only `.ck-flash`/`.ck-alert` family (the only net-new CSS).
- `root.html.heex`: remove the `default.css` `<link>` (`:9`).
- `cohort_migration_contract_test.exs`: widen scan demo-wide + add source/file `refute`s.
- Delete: `page_controller.ex`, `page_html.ex`, `home.html.heex`, `priv/static/assets/default.css`;
  rename `page_controller_test.exs` → `LaunchpadLiveTest`.
</code_context>

<specifics>
## Specific Ideas

- The Cohort persona is a **developer-adopter evaluating the upload library** — the demo's
  credibility rests on containing only reachable, intentional code (delete the dead generator
  landing; don't leave adopters guessing which home page is load-bearing).
- Flash/toast is the demo's notification surface for upload success/error — it must be accessible
  (icon+label not color-alone, split `status`/`alert` semantics, no timing trap), reduced-motion
  aware, and correct in light/dark/system, matching the bar set for the migrated pages.
- The destructive `default.css` deletion is sequenced last behind a green source grep, with the
  screenshot/behavior lane as the net — never a red-in-between state.

</specifics>

<deferred>
## Deferred Ideas

- **Per-state surface tokens** (`--ck-info-surface`/`--ck-quarantine-surface` mirrored from
  brandbook's `--rindle-status-*-surface`) for a tinted alert ground — NOT needed for criterion 3
  (the left-border-accent-over-`--ck-surface` pattern covers it) and forbidden by this phase's
  no-token-value-edit scope. Future polish ticket if desired.
- warn→fail flip of the Cohort polish gate + VIS-* re-converge / idempotency / cross-surface visual
  matrix / milestone audit → **Phase 102 (VIS-01..04)**.
- Higher-value upload UX (drag-drop, live progress bar, per-entry thumbnails, humanized status
  microcopy) — out of scope, carried from Phase 100's deferred list.
- Optional non-blocking pixel-baseline screenshots → later milestone.

### Reviewed Todos (not folded)
None — `todo.match-phase 101` returned 0 matches.
</deferred>
