# Architecture Research

**Domain:** Design-system uplift on an existing token→CSS pipeline + two Phoenix UI surfaces (admin console + Cohort demo)
**Researched:** 2026-06-14
**Confidence:** HIGH (all integration points read from live repo: `brandbook/src/*.mjs`, `tokens.json`, `rindle-admin.css`, `cohort.css`, `cohort_components.ex`, the Playwright matrix + `admin-polish.js` gate, and `ci.yml`)

> This is an integration-and-build-order map for a SUBSEQUENT (quality-uplift) milestone, not greenfield architecture. It documents how to thread new design tokens through the existing generators and how to sequence a fractal audit so quality compounds idempotently. It does NOT re-propose the token pipeline or the console architecture — those are shipped and treated as fixed substrate.

---

## Standard Architecture

### The two design systems and how they relate (today, verified)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  SOURCE OF TRUTH                                                               │
│  brandbook/tokens/tokens.json   ← the ONLY hand-edited token file (admin DS)   │
└───────────────┬───────────────────────────────────────────────────────────────┘
                │  node brandbook/src/*.mjs  (manual local pipeline, NOT in CI)
   ┌────────────┴───────────────┬──────────────────────────┬────────────────────┐
   ▼                            ▼                          ▼                     ▼
admin-css-build.mjs       admin-contrast.mjs        admin-gallery.mjs    tokens-build.mjs
 + admin-design-          (WCAG gate over            + admin-gallery-      (→ tokens.css,
   system-data.mjs          CONSOLE_CONTRAST_           check.mjs            brand book site)
 (component contract)       PAIRS)                    (living gallery)
   ▼                                                   ▼
brandbook/tokens/rindle-admin.css  ──copied──▶  priv/static/rindle_admin/rindle-admin.css
 (.rindle-admin-* BEM,                            (ships INSIDE the rindle hex package;
  data-theme light/dark/auto,                      served by Rindle.Admin.Router mount)
  motion + reduced-motion)

┌──────────────────────────────────────────────────────────────────────────────┐
│  COHORT DEMO DS  (separate, hand-authored, NOT generated from tokens.json)     │
│  examples/adoption_demo/priv/static/assets/cohort.css   (.ck-* BEM)            │
│    - own --ck-* tokens, own emerald brand (#059669)                            │
│    - dark mode via CSS-native @media (prefers-color-scheme) — NO theme picker  │
│    - paired with CohortComponents (cohort_components.ex)                        │
│    - linked from root.html.heex alongside legacy default.css (daisyUI dump)     │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Two systems, deliberately separate, must stay coherent not merged** (locked decision, PROJECT.md "Console CSS = BEM ... Cohort keeps its own"). `rindle-admin` is a shipped library artifact that must be host-Tailwind-independent; `cohort.css` is demo-local and may evolve freely. They share a visual language (lifecycle status palette, Atkinson/JetBrains fonts, pill radius vocabulary, materialization-not-entertainment motion ethos) but DO NOT share a stylesheet, a token file, or a build step.

### Three facts that shape every recommendation below

1. **The `.mjs` pipeline is not gated in CI.** `grep brandbook .github/workflows/ci.yml` → nothing. `admin-css-build.mjs`, `admin-contrast.mjs`, and `admin-gallery-check.mjs` are run by hand; their outputs (`rindle-admin.css`, gallery HTML, screenshots) are committed. The only CI proof that the admin DS renders correctly is the Playwright `adoption-demo-e2e` lane via the demo. **Gap: token edits can land with no automated regen/contrast/parity check.** Closing this is a milestone task, not an assumption.

2. **The Cohort demo was generated `--no-tailwind`.** `default.css` is a *static, pre-built* Tailwind v4 + daisyUI dump (header: "even as you selected --no-tailwind ... You can safely remove the whole file"). There is **no Tailwind/daisyUI build step to remove** — "daisyUI removal" means deleting `btn`/`tabs`/`tabs-boxed` classes and the raw Tailwind utility classes (`text-2xl`, `mt-6`, `list-disc`, `bg-gray-100`, …) that the inner pages reference, then dropping the `default.css` `<link>`. Inner-page utility usage is small and countable (≈25 distinct classes, dominated by `text-sm`, `font-semibold`, `mt-6`).

3. **The Playwright proof is computed-style assertions, not pixel baselines.** `admin-polish.js` ports WCAG math and asserts clipped text, contrast, 44px targets, overlap, and stable dimensions on the live rendered state, then captures a screenshot for the human record. This is the flakiness-resistant model (no golden-PNG diffing) and the pattern to extend to Cohort.

### Component responsibilities (for the uplift)

| Component | Responsibility | Implementation today / change |
|-----------|----------------|-------------------------------|
| `tokens.json` | Single source of truth for admin DS tokens | Hand-edit. New categories (elevation, motion presets, responsive type/space) are added HERE first |
| `admin-design-system-data.mjs` | The component/contract manifest (`COMPONENTS`, `MOTION_TOKENS`, `STATUS_STATES`, `CONSOLE_CONTRAST_PAIRS`) | Hand-edit. New component or contrast pair is registered here; `admin-css-build.mjs` `exact()` asserts the arrays match |
| `admin-css-build.mjs` | Emits `rindle-admin.css` + self-verifies required selectors/scopes/motion-uses | Extend emit loops for new token categories; extend `requiredSelectors`/`requiredTokenUses` parity list |
| `admin-contrast.mjs` | WCAG gate over `CONSOLE_CONTRAST_PAIRS` | Add pairs for new surfaces/states; run in CI (new) |
| `admin-gallery.mjs` + `-check.mjs` | Living component reference + screenshot capture | Keep in sync; this IS the admin gallery — extend, do not fork |
| `cohort.css` | Hand-authored Cohort DS (`.ck-*`) | Extend with inner-page component classes; keep `--ck-*` token block as its local SoT |
| `cohort_components.ex` | Phoenix function components consuming `.ck-*` | Add inner-page components (tables, stat tiles, forms, tabs, detail blocks); inner LiveViews migrate onto these |
| `admin-polish.js` | Deterministic visual gate inside e2e | Generalize selectors so it runs over Cohort surfaces too; add Cohort screenshot cases |

---

## Recommended Project Structure

Files the milestone touches (new vs modified made explicit):

```
brandbook/
├── tokens/
│   ├── tokens.json                      # MODIFY: add elevation, motion-preset, responsive
│   │                                    #   type/space, semantic dark-mode token categories
│   └── rindle-admin.css                 # REGENERATE (artifact; never hand-edit)
├── src/
│   ├── admin-design-system-data.mjs     # MODIFY: register new components + contrast pairs
│   ├── admin-css-build.mjs              # MODIFY: emit new token categories + parity asserts
│   ├── admin-contrast.mjs              # MODIFY: widen pair coverage
│   ├── admin-gallery.mjs / -check.mjs   # MODIFY: new component states in living gallery
│   └── cohort-tokens-check.mjs          # NEW (optional): lint .ck-* token coverage / contrast
├── admin-gallery/index.html             # REGENERATE (living reference)
└── cohort-gallery/index.html            # NEW (optional): living Cohort component reference

examples/adoption_demo/
├── priv/static/assets/
│   ├── cohort.css                       # MODIFY: add inner-page component classes
│   └── default.css                      # DELETE at end (daisyUI dump) once no page links it
├── lib/adoption_demo_web/
│   ├── components/
│   │   ├── cohort_components.ex          # MODIFY: add inner-page components
│   │   └── layouts/root.html.heex        # MODIFY: drop default.css <link> (final step)
│   └── live/
│       ├── dashboard_live.ex             # MIGRATE onto .ck-* + CohortComponents
│       ├── upload_live.ex                # MIGRATE (largest, 484 lines, tabs)
│       ├── ops_live.ex                   # MIGRATE
│       └── {member,lesson,post,media,account}_live.ex  # MIGRATE
└── e2e/
    ├── support/admin-polish.js          # MODIFY: parameterize for Cohort surfaces
    ├── admin-screenshots.spec.js        # MODIFY: extend matrix (admin states)
    └── cohort-screenshots.spec.js       # NEW: Cohort light/dark inner-page matrix

.github/workflows/ci.yml                 # MODIFY: NEW brandbook-tokens job (regen+contrast+parity)
```

### Structure rationale

- **All admin token changes start in `tokens.json` + `admin-design-system-data.mjs`.** The generator self-tests via `exact()` array equality, so a new component is a two-file edit that the build refuses to drift from. This is the idempotency anchor — re-running the build is a no-op when source and artifact agree.
- **Cohort keeps its `--ck-*` token block as its own local SoT.** Do NOT generate `cohort.css` from `tokens.json`; the brand colors differ (emerald vs deep-current) and coupling them would re-introduce the host-independence problem the locked decision avoids. Coherence is enforced by *shared vocabulary and a parallel gallery/gate*, not a shared file.
- **`default.css` deletion is the LAST step**, gated on grep proving no template/page references daisyUI/utility classes — otherwise pages regress to unstyled.

---

## Architectural Patterns

### Pattern 1: Fractal audit as a three-level, idempotent workflow

**What:** Audit and uplift at three levels of abstraction, lowest first, so each level builds on a settled foundation. Each level has a defined output location and a re-runnable gate.

```
LEVEL 1 — Component (atom)
  unit:    one component × all states (default/hover/focus/active/disabled/loading/empty/error)
           × light/dark/auto × mobile/desktop
  admin output:  rindle-admin.css class + modifier; registered in admin-design-system-data.mjs;
                 rendered in admin-gallery/index.html
  cohort output: .ck-* class; CohortComponents function; rendered in cohort-gallery (new)
  gate:    contrast pair(s) added to CONSOLE_CONTRAST_PAIRS / .ck contrast list;
           admin-css-build parity selector list; admin-polish target/clip/contrast checks

LEVEL 2 — Meta-component (group / molecule)
  unit:    toolbar, table+filter, action panel, detail drill, stat row — composed from Level 1
  output:  a gallery section showing the group as a unit; for Cohort, a CohortComponents
           composite (e.g. <.ck_table>, <.ck_toolbar>)
  gate:    rhythm/overlap/no-horizontal-scroll assertions in admin-polish (extended to Cohort);
           visual cohesion reviewed in the gallery

LEVEL 3 — Page composition
  unit:    a full route (/admin/rindle/assets, /dashboard, /upload?tab=…)
  output:  the LiveView itself, assembled only from Level 1+2 primitives
  gate:    the Playwright screenshot matrix capture for that surface + admin-polish on the
           live page; per-page JTBD microcopy tied to guides/user_flows.md persona
```

**When to use:** Always, in this order. A page (Level 3) must never introduce a one-off style — if it needs something, that something is promoted to a Level 1/2 primitive first. This is what makes the milestone *compound* instead of accreting page-local hacks.

**Idempotency mechanism (the no-regression guarantee):** Quality lives in the *generated artifact + gates*, not in prose. Re-running the audit on an already-uplifted surface:
- regenerates identical CSS (source==artifact → `admin-css-build` is a no-op diff),
- re-passes the same contrast/parity/polish gates,
- so "moving quality forward" means *adding* a state/component/pair, never reformatting settled output.
The `admin-polish.js` `POLISH_EXEMPTIONS` map (ships empty, each entry is a justified reviewable code change) is the controlled escape hatch — a regression can only be *explicitly* exempted, never silently.

**Trade-offs:** Bottom-up discipline is slower to first visible page but eliminates rework; a page built before its primitives exist would be audited twice.

### Pattern 2: Token category extension threading

**What:** Adding a new token category (motion presets, elevation/shadow scale, responsive type/space, semantic dark tokens) follows one fixed path through the admin generator.

```
1. tokens.json:                 add the category object (e.g. "elevation": {...}) or extend
                                 existing ("motion", "shadow", "spacing", semantic.dark)
2. admin-css-build.mjs:         add an emit loop  →  --rindle-<cat>-<key>: <value>;
                                 (dereference {refs} via existing deref())
3. admin-css-build.mjs parity:  add the new var to requiredTokenUses / requiredSelectors
4. admin-design-system-data.mjs: if it gates a component contract, add to the relevant array
                                 (admin-css-build exact() will fail loudly on drift)
5. admin-contrast.mjs:          if color-bearing, add CONSOLE_CONTRAST_PAIRS entries
6. consume in the .rindle-admin-* component CSS via var(--rindle-<cat>-<key>)
```

**Concrete per-category guidance (admin DS):**

| New category | tokens.json shape | Notes |
|--------------|-------------------|-------|
| **Motion presets** | extend existing `motion` (press/popover/toast/transition/diagram/easing already exist) | Add semantic *named* transitions (e.g. `enter`, `exit`, `emphasis`) mapping to durations+easing à la Emil Kowalski; `MOTION_TOKENS` array + `requiredMotionUses` already enforce usage. `prefers-reduced-motion` block already exists — extend it for any new animated component |
| **Elevation/shadow** | promote `shadow.card` to a scale (`shadow.raised`, `shadow.overlay`, `shadow.sunken`) | Currently a single `--rindle-shadow-card`. Dark theme needs its own shadow values (light shadows vanish on dark) — add under `semantic.dark` consumption or a `shadow.dark.*` block |
| **Responsive type/space** | add `clamp()`-based fluid steps OR keep fixed + add breakpoint multipliers | Admin currently ships fixed px scale + one `@media (max-width:760px)` block. Cohort already uses `clamp()` (`--ck-step-hero`). Recommend mirroring Cohort's fluid approach for admin display sizes only; keep body/label fixed for table scannability (per 88-UI-SPEC) |
| **Semantic dark-mode tokens** | extend `color.semantic.dark` | The structure already exists and is emitted to `[data-theme="dark"]` + `[data-theme="auto"]@media`. Status *surface* tokens currently collapse to `dark-surface` for all states — a real uplift differentiates them (tinted dark status surfaces) and adds contrast pairs |

**Cohort parallel:** same idea, but the loop is hand-authored in `cohort.css`'s `:root` / `@media (prefers-color-scheme: dark)` blocks (already present). No `.mjs` generator — extend the existing `--ck-*` token blocks directly.

### Pattern 3: Incremental, flow-safe daisyUI retirement (page-by-page)

**What:** Migrate one inner LiveView at a time onto `.ck-*` + `CohortComponents`, keeping its e2e flow green throughout, and only delete `default.css` once nothing references it.

```
Per page (idempotent, reversible per-commit):
  a. Inventory: grep the page for btn/tabs/tabs-boxed + raw Tailwind utilities
  b. Promote-or-reuse: for each visual need, use an existing .ck-* / CohortComponents
     primitive; if missing, BUILD IT AT LEVEL 1 FIRST (Pattern 1), don't inline
  c. Swap markup: replace utility classes with .ck-* classes / <.ck_*> components.
     CRITICAL: preserve every data-testid and id — the e2e specs key off them
     (e.g. data-testid="cohort-dashboard-title", member-row-#{email}, nav-upload)
  d. Verify flow: run the page's existing Playwright spec (smoke/image-upload/
     ops-surfaces/replace-detach/etc.) — must stay green
  e. Add a screenshot case to cohort-screenshots.spec.js + run admin-polish over it
  f. Commit. Page is now migrated; default.css link still present (harmless).

Final step (once ALL pages migrated):
  - grep the whole demo for daisyUI/utility classes → must be empty (or only inside
    core_components.ex if any path still uses it)
  - remove the default.css <link> from root.html.heex; delete default.css
  - one screenshot/polish pass confirms no page regressed to unstyled
```

**Why safe:** Each page is independent; `default.css` staying linked during migration means a half-migrated page still renders. The `data-testid` preservation rule means functional e2e (the actual upload/erase/ops flows) never breaks — the seed/fixture data and event handlers are untouched; only presentation classes change. Reversible: any single page's migration commit can be reverted without touching others.

**Trade-offs:** `upload_live.ex` (484 lines, multiple tabs) is the heavy page and should be its own phase or split by tab. The other seven pages are 45–113 lines and are quick.

### Pattern 4: Deterministic visual proof loop (analyze → fix), no golden PNGs

**What:** Extend the existing `admin-polish.js` computed-style gate to cover Cohort, run it inside the same merge-blocking `adoption-demo-e2e` lane, and use its *aggregated offender report* as the analyze→fix worklist.

```
capture(page, theme, surface):
  selectTheme → freezeMotion → assertPolish(clip, contrast, target≥44px,
                overlap, stable-dims, no-horizontal-scroll) → screenshot(fullPage)
assertPolish RETURNS all offenders (never throws mid-check) → one error lists every
  violation per state → one CI run = full worklist. Fix → re-run → green.
```

**Flakiness control (already designed in, keep it):**
- `freezeMotion` injects `transition:none!important;animation:none!important` so computed-style reads settle (no mid-tween muddy-gray false contrast fails).
- `page.screenshot({ animations: "disabled" })` for the human-record PNG.
- Tolerances are explicit constants (`CLIP_TOLERANCE`, `OVERLAP_TOLERANCE`, `CONTRAST_SLACK`, `SUBPIXEL_TOLERANCE`).
- New/noisy checks ship in *warn mode* for one green cycle (`OVERLAP_ENFORCED = false`) then flip to hard fail.
- `workers:1`, `fullyParallel:false` already — deterministic ordering.

**Why not pixel-diff baselines:** Golden-PNG visual regression is flaky across font-rendering/OS/headless-chromium versions and would fight the cross-platform CI (this repo already fought ffmpeg/setup-action flakiness). Computed-style assertions are deterministic and *explain* the failure. Recommend NOT introducing `toHaveScreenshot()` baselines; keep the polish-gate model. The committed screenshots remain a human review artifact, not a CI assertion.

### Pattern 5: Living gallery stays in sync via generation, not duplication

**What:** The admin gallery (`admin-gallery/index.html`) is *generated* from the same `admin-design-system-data.mjs` contract that drives the CSS, and `admin-gallery-check.mjs` re-runs `admin-css-build.mjs` + `admin-gallery.mjs` before checking — so the gallery can never drift from the shipped CSS.

**Recommendation for Cohort:** add a parallel **generated** `cohort-gallery/index.html` driven from a small `cohort-design-system-data.mjs` manifest (component list + states), OR — lower effort, still in-sync — render the gallery as a Phoenix route inside the demo (`/styleguide`) that imports the *real* `CohortComponents`, so it is the live components by construction. The Phoenix-route approach is recommended: zero duplication, the gallery IS the components, and the Playwright matrix can screenshot it like any other surface. Place admin gallery where it is (brandbook, shipped reference); place Cohort gallery as a demo route (`/styleguide`, dev/test only).

**Trade-off:** A demo-route gallery isn't a static shippable artifact like the brandbook one — acceptable because Cohort is the demo, not the shipped library.

---

## Data Flow

### Token → CSS → rendered surface (admin)

```
edit tokens.json
   ↓  node admin-css-build.mjs   (self-parity: selectors, scopes, motion, token-uses)
rindle-admin.css  ──┬─▶ brandbook/admin-gallery (node admin-gallery.mjs → -check.mjs → screenshots)
                    └─▶ copy → priv/static/rindle_admin/rindle-admin.css
                              ↓  Rindle.Admin.Router mount serves it
                        /admin/rindle (LiveViews) rendered in demo
                              ↓  Playwright adoption-demo-e2e
                        admin-polish.js gate + 22-PNG matrix
```

### Token → CSS → rendered surface (Cohort)

```
edit cohort.css :root / @media(dark) + add CohortComponents function
   ↓  (no generator)
cohort.css served via root.html.heex
   ↓  inner LiveViews use .ck-* / <.ck_*>
/dashboard, /upload, /ops, … rendered
   ↓  Playwright adoption-demo-e2e
cohort-screenshots.spec.js + (generalized) admin-polish gate
```

### Key data flows

1. **Idempotent regen:** `tokens.json` unchanged ⇒ `admin-css-build` emits byte-identical CSS ⇒ git diff empty ⇒ no-op. A CI `brandbook-tokens` job that regenerates and `git diff --exit-code`s the artifact makes drift a hard failure.
2. **Flow-preserving migration:** inner LiveView event handlers + seed data are untouched; only class strings + `data-testid`-bearing wrappers change ⇒ functional e2e specs stay green while presentation moves to `.ck-*`.

---

## Suggested Phase Decomposition (phases 94+)

Two tracks. **Track A (admin DS uplift)** and **Track B (Cohort restyle)** are largely independent after a shared foundation phase, so they can parallelize. Within each track, fractal order (Level 1 → 2 → 3) is a hard dependency.

```
Phase 94  FOUNDATION — token categories + CI gate            [BLOCKS everything]
  - tokens.json: add elevation scale, motion presets, responsive display steps,
    differentiated dark status surfaces
  - admin-css-build.mjs + admin-design-system-data.mjs: emit + parity for new cats
  - admin-contrast.mjs: widen CONSOLE_CONTRAST_PAIRS
  - NEW ci.yml job `brandbook-tokens`: run admin-css-build + admin-contrast +
    admin-gallery-check + git diff --exit-code (closes the un-gated-pipeline gap)
  - Generalize admin-polish.js selectors so it can target any root (admin or .ck)
  → idempotency + no-regression infrastructure exists before any visual work

────────── after 94, Track A and Track B run in PARALLEL ──────────

TRACK A — Admin/operator DS (primary)            TRACK B — Cohort restyle
Phase A1 (95)  Level-1 component audit            Phase B1 (96)  Cohort Level-1 components
  every rindle-admin-* component × all              + cohort-gallery route (/styleguide)
  states × light/dark/auto/mobile;                  build .ck-* table/stat/form/tabs/
  fix contrast+polish; extend gallery               detail primitives + CohortComponents
Phase A2 (97)  Level-2 meta-components            Phase B2 (98)  Cohort meta-components
  toolbars, table+filter, action panels,            composed .ck groups; rhythm gates
  detail drills; rhythm/overlap gates
Phase A3 (99)  Level-3 page composition           Phase B3 (100) Page migrations (small 7)
  all six admin surfaces; per-surface JTBD          dashboard, ops, member, lesson,
  microcopy; full matrix + polish                   post, media, account → .ck-*
                                                  Phase B4 (101) upload_live migration
                                                    (484 lines, tabs) — its own phase
                                                  Phase B5 (102) daisyUI retirement
                                                    grep-clean → drop default.css link →
                                                    delete default.css → polish pass

────────── re-converge ──────────

Phase 103  PROOF & MATRIX EXTENSION + MILESTONE AUDIT
  - cohort-screenshots.spec.js merged into matrix; admin-polish enforced (flip warn→fail)
  - full light/dark matrix green for admin + Cohort in adoption-demo-e2e
  - mobile-first responsive verified at all breakpoints
  - milestone audit / requirements traceability / docs parity
```

### Dependencies & parallelization

- **94 blocks all** (token categories + CI gate + polish generalization are the substrate).
- **Track A and Track B are independent** after 94 — different files (`rindle-admin.css`/brandbook vs `cohort.css`/demo), different surfaces. Run concurrently.
- **Within each track, Level 1 → 2 → 3 is strict** (Pattern 1): pages may only use primitives that exist.
- **B5 (daisyUI retirement) depends on B1–B4 all done** (grep must be clean before deleting `default.css`).
- **103 depends on both tracks** (re-convergence: the matrix and polish gate now cover everything).
- `upload_live.ex` isolated into its own phase (B4) because it is 4× the size of any other page and tab-structured.

### What can be deferred / escalation triggers

- A `cohort-design-system-data.mjs` *generated static* gallery is optional; the `/styleguide` Phoenix route is the recommended, lower-cost in-sync alternative.
- Any proposal to *merge* the two stylesheets, generate `cohort.css` from `tokens.json`, or add a runtime UI dependency (icon package, daisyUI rebuild, shadcn/Radix) is a recorded high-blast-radius boundary (88-UI-SPEC Registry Safety, PROOF decision) → **escalate**.

---

## Scaling Considerations

Not a runtime-scale concern; "scale" here is *audit surface growth*.

| Scale | Adjustment |
|-------|-----------|
| Current (11 admin components, 6 surfaces, 9 inner Cohort pages) | The two-file-edit + parity-assert model holds; manual gallery regen is fine |
| If component count doubles | The `exact()` array-equality contract still scales; consider data-driving gallery sections fully from the manifest so adding a component is a one-line manifest edit |
| If a third surface/theme appears (e.g. high-contrast) | Add a `data-theme` scope in `admin-css-build` emit + a contrast-pair theme dimension; `CONSOLE_CONTRAST_PAIRS` already carries a `theme` field |

### Scaling priorities

1. **First bottleneck: un-gated pipeline** → Phase 94's `brandbook-tokens` CI job. Without it, every later phase risks silent artifact drift.
2. **Second bottleneck: matrix runtime** → the Playwright matrix is `workers:1` serial; adding all Cohort surfaces lengthens it. Keep captures lean (only states that exercise a real gate), not a combinatorial explosion.

---

## Anti-Patterns

### Anti-Pattern 1: Hand-editing `rindle-admin.css`

**What people do:** Tweak the generated `rindle-admin.css` directly to fix a visual issue.
**Why it's wrong:** The file header says "do not edit by hand"; the next `admin-css-build` run overwrites it, silently reverting the fix and breaking idempotency.
**Do this instead:** Edit `tokens.json` (+ `admin-design-system-data.mjs` if contract) and regenerate.

### Anti-Pattern 2: Page-local one-off styles (skipping the fractal order)

**What people do:** Style a Level-3 page directly with bespoke classes/utilities because "it's just this page."
**Why it's wrong:** Quality stops compounding; the next audit pass finds N divergent one-offs instead of N usages of one primitive. Breaks idempotency (re-run wants to reformat).
**Do this instead:** Promote the need to a Level-1/2 primitive first, then compose the page from primitives only.

### Anti-Pattern 3: Generating `cohort.css` from `tokens.json` (coupling the two DSs)

**What people do:** "Unify" by driving Cohort from the admin token file.
**Why it's wrong:** Different brand (emerald vs deep-current), and it re-introduces a build-step/host-coupling the locked decision deliberately avoided for the *shipped* library. High blast radius.
**Do this instead:** Keep `--ck-*` as Cohort's local SoT; enforce coherence via shared vocabulary + a parallel gallery/contrast gate, not a shared file.

### Anti-Pattern 4: Golden-PNG visual regression baselines

**What people do:** Add `toHaveScreenshot()` pixel diffing for "real" visual regression.
**Why it's wrong:** Flaky across font/OS/chromium versions on CI (this repo already paid the flaky-action tax); failures don't explain themselves.
**Do this instead:** Extend the computed-style `admin-polish.js` gate (deterministic, self-explaining); keep PNGs as human-review artifacts only.

### Anti-Pattern 5: Deleting `default.css` before the demo is grep-clean

**What people do:** Remove the daisyUI dump early to "clean up."
**Why it's wrong:** Any not-yet-migrated page or `core_components.ex` path regresses to unstyled, breaking the demo mid-milestone.
**Do this instead:** Delete it as the final B5 step, gated on a clean grep for daisyUI/utility classes.

### Anti-Pattern 6: Changing `data-testid`/`id` during a restyle

**What people do:** Rename or drop test hooks while swapping classes.
**Why it's wrong:** The functional e2e specs (upload, erase, ops, replace-detach) key off them; the flow breaks even though the page "looks done."
**Do this instead:** Treat `data-testid`/`id` as a frozen contract during migration; only class strings change.

---

## Integration Points

### Pipeline / tooling

| Integration | Pattern | Notes |
|-------------|---------|-------|
| `tokens.json` → `rindle-admin.css` | `node admin-css-build.mjs`, self-parity asserts | Add emit loops + parity entries per new category |
| `rindle-admin.css` → shipped package | copy to `priv/static/rindle_admin/` | Served by `Rindle.Admin.Router` mount; keep copy step (or script it) so artifact and shipped asset match |
| `tokens.json` → contrast gate | `node admin-contrast.mjs` over `CONSOLE_CONTRAST_PAIRS` | Make it CI-blocking in Phase 94 |
| gallery sync | `admin-gallery-check.mjs` re-runs build+gallery before check | Cannot drift; mirror for Cohort via `/styleguide` route |
| **NEW** CI `brandbook-tokens` job | regen + contrast + gallery-check + `git diff --exit-code` | Closes the only structural gap (pipeline un-gated today) |

### Phoenix surfaces

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `rindle-admin.css` ↔ Cohort `cohort.css` | none (BEM namespace isolation: `.rindle-admin-*` vs `.ck-*`) | Must stay non-leaking (88-UI-SPEC); coherence via shared vocabulary only |
| inner LiveViews ↔ `CohortComponents` | function components consuming `.ck-*` | Migration target; preserve `data-testid`/`id` |
| LiveViews ↔ `default.css` | legacy `<link>` + utility classes | Retire last (B5) |
| demo ↔ Playwright e2e | `adoption-demo-e2e` lane (merge-blocking) | Extend with `cohort-screenshots.spec.js` + generalized `admin-polish.js`; keep `workers:1`, `freezeMotion` |
| LiveViews ↔ `guides/user_flows.md` personas | microcopy ties to JTBD per surface | Level-3 audit deliverable per page |

---

## Sources

- `brandbook/tokens/tokens.json`, `brandbook/tokens/rindle-admin.css` — token SoT + generated artifact (read)
- `brandbook/src/admin-css-build.mjs`, `admin-design-system-data.mjs`, `admin-contrast.mjs`, `admin-gallery.mjs`, `admin-gallery-check.mjs` — generation pipeline (read) — HIGH
- `examples/adoption_demo/priv/static/assets/cohort.css`, `lib/.../components/cohort_components.ex`, `layouts.ex`, `layouts/root.html.heex` — Cohort DS (read) — HIGH
- `examples/adoption_demo/priv/static/assets/default.css` header — confirms `--no-tailwind` static daisyUI dump, removable — HIGH
- `examples/adoption_demo/lib/.../live/{dashboard,member,...}_live.ex` — inner-page utility inventory (read) — HIGH
- `examples/adoption_demo/e2e/admin-screenshots.spec.js`, `support/admin-polish.js`, `playwright.config.js`, `global-setup.js` — proof loop (read) — HIGH
- `.github/workflows/ci.yml`, `scripts/ci/{adoption_demo_e2e,cohort_demo_smoke}.sh` — CI wiring; confirms brandbook pipeline NOT gated — HIGH
- `.planning/phases/88-admin-design-system-ui-kit/88-UI-SPEC.md` — DS contract, registry-safety boundary, 6-pillar conventions — HIGH
- `.planning/PROJECT.md` (v1.19 charter, locked DS decisions), `.planning/seeds/SEED-002-*.md` — scope + method — HIGH

---
*Architecture research for: design-system uplift integration + build order (v1.19)*
*Researched: 2026-06-14*
