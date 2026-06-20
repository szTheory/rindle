# Phase 94: Foundation — Token Pipeline CI Gate & New Token Categories - Context

**Gathered:** 2026-06-14 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

The token→CSS pipeline is gated in CI and carries the new token categories the uplift
needs, so all later visual work is idempotent and drift-proof. **This phase blocks
everything** in v1.19.

In scope (PIPE-01, PIPE-02, VIS-01 groundwork):
- A merge-blocking `brandbook-tokens` CI job: regenerate → contrast → gallery-check →
  `git diff --exit-code`.
- New token categories added to `tokens.json` + the `.mjs` **admin** generators: motion
  presets, a semantic dark elevation/shadow ladder, fluid type + space scales with named
  breakpoints, and differentiated semantic dark status surfaces.
- Generalize `admin-polish.js` to target any root selector, ready for both surfaces.

Out of scope (deferred): any actual visual/component work; authoring Cohort's `.ck-*`
dark/elevation/motion CSS (that is Phase 96 / Track B B1); tuning the *values* of the
fluid `clamp()` tuples and dark-status hexes (that is `/gsd:ui-phase 94` design judgment).
</domain>

<decisions>
## Implementation Decisions

### CI Gate — the `brandbook-tokens` job

- **D-94-01:** Add a **new standalone top-level job** `brandbook-tokens` to
  `.github/workflows/ci.yml`, `needs: [quality, optional-dependencies]` like the other
  proof lanes (`proof`, `contract`, `cohort-demo-smoke`, `adoption-demo-e2e`). Do **not**
  fold it into an existing lane — the brandbook pipeline is pure Node/Playwright and shares
  no Elixir/Postgres/MinIO/ffmpeg setup. Reuse the existing Node-20 `setup-node@v4` pattern
  (`ci.yml:467`, `696`).
- **D-94-02:** The job runs, in order: `tokens-build.mjs` → `admin-css-build.mjs` →
  `admin-contrast.mjs` → `admin-gallery-check.mjs` → **sync the second CSS copy** →
  `git diff --exit-code`. Install Playwright chromium / `npm ci` in
  `examples/adoption_demo` first, because `admin-gallery-check.mjs:14-15` resolves
  `playwright` via that package's `createRequire` (otherwise the gate red-herrings on
  "Cannot find module 'playwright'", not drift).
- **D-94-03:** The gate **must regenerate-and-diff BOTH committed CSS copies** —
  `brandbook/tokens/rindle-admin.css` (written by the generator) **and** the
  package-shipped `priv/static/rindle_admin/rindle-admin.css`, which is mirrored **by hand
  today** (no script copies it; it's listed in `mix.exs:279`). Make the copy a committed
  script/step (e.g. a `sync_admin_css` step or `.mjs` write) so it is the single mechanism,
  then diff it. Diffing only the brandbook copy would let the shipped package CSS drift
  silently — the exact failure this phase exists to kill (PITFALL #6).
- **D-94-04:** All three generated artifacts must be regenerated before the diff so the
  check is honest: `tokens.css` (`tokens-build.mjs:59`), `rindle-admin.css`
  (`admin-css-build.mjs:571`), and the gallery `index.html` (`admin-gallery.mjs:519`).

### Scope Boundary — admin-only in 94; Cohort categories land in Phase 96

- **D-94-05:** Phase 94 emits the new categories into `tokens.json` + the `.mjs` **admin**
  generators + widened `CONSOLE_CONTRAST_PAIRS` **only**. It does **not** author Cohort's
  versions. The ROADMAP success-criterion "flowing to both `rindle-admin` and `cohort`" is
  satisfied by **parallel hand-authoring in Phase 96 (Track B B1)**, never a shared build
  step. (`cohort.css` is hand-authored, no `.mjs` generator — ARCHITECTURE.md:111 locked
  "Do NOT generate `cohort.css` from `tokens.json`".)
- **D-94-06:** Phase 94 may at most *seed shape* — document the parallel `--ck-*` token
  vocabulary so Phase 96 has a coherence/parity reference — but writes **no** `cohort.css`.
  The two design systems share vocabulary, never a stylesheet, token file, or build step.

### Polish Generalization, Token Shape & Idempotency

- **D-94-07:** Generalize `admin-polish.js` by threading `root` + `interactiveSelectors`
  as **parameters** through `assertAdminPolish(page, { viewport, surface, root,
  interactiveSelectors })`, defaulting to today's `[data-rindle-admin-root]` /
  `.rindle-admin-*` set so the existing admin spec passes unchanged. Cohort later passes
  `[data-ck-root]` / `.ck-*`. **No auto-detection** of the root (a page mounting both
  surfaces would match both). The spec already passes a per-call `{viewport, surface}`
  options object — adding keys is the established seam (`admin-screenshots.spec.js:79`).
- **D-94-08:** New token categories plug into `tokens.json` as **new top-level objects**
  (`elevation`, extended `motion`, fluid `typography`/`spacing` steps,
  `color.semantic.{light,dark}` differentiated status surfaces). Each gets a matching emit
  loop in `admin-css-build.mjs` **and** a new entry in the `exact()` / `requiredTokenUses`
  parity arrays (and `MOTION_TOKENS` in `admin-design-system-data.mjs:44` for motion).
  Emitting a category without adding it to the parity arrays lets the generator self-check
  pass while the artifact silently omits it.
- **D-94-09:** Token *shape* is locked (values deferred to `/gsd:ui-phase 94`): fluid
  `clamp()` on **display sizes only** (hero/h1/h2/h3); `body`/`small`/`code` stay fixed-px
  for table scannability; dark status surfaces **stop collapsing** to `dark-surface`
  (`tokens.json:99-104` confirms they collapse today); elevation is a **surface-tint
  ladder**, not heavier shadow.
- **D-94-10:** `git diff --exit-code` after a single regen is **sufficient** as the
  idempotency anchor — no separate double-run check required. Generators are deterministic
  (pure `Object.entries` iteration; `exact()` array-equality parity is the named anchor,
  STACK.md:33). If a future generator introduces ordering nondeterminism (`Set` /
  `Date.now()` / `Map`), that breaks this assumption and a cheap `regen; regen; git diff`
  belt-and-suspenders becomes warranted.

### Claude's Discretion

Routine job-step naming, the exact filename of the CSS-sync script, the parameter object
key names beyond `root`/`interactiveSelectors`, and where the `--ck-*` vocabulary
reference is documented may be resolved during planning — provided they do not alter the
public package artifact set, the merge-blocking gate semantics, the locked separate-build-
step boundary, or the `data-theme` theme contract.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/research/v1.19/SUMMARY.md` — reconciled visual-proof decision + build order
- `.planning/research/v1.19/STACK.md` — `exact()` parity = idempotency anchor; near-zero new deps
- `.planning/research/v1.19/ARCHITECTURE.md` — token plug-in path (lines 158-179);
  locked "do NOT generate `cohort.css`" (line 111)
- `.planning/research/v1.19/PITFALLS.md` — #2 idempotency thrash, #6 token-pipeline drift
- `.planning/research/v1.19/FEATURES.md` — dark-mode-done-right; fluid-on-display anti-feature
- `brandbook/tokens/tokens.json` — single source of truth; new categories added here first
- `brandbook/src/admin-css-build.mjs` — generator + `exact()` parity + `requiredTokenUses`
- `brandbook/src/admin-design-system-data.mjs` — `MOTION_TOKENS`, contrast-pair data
- `brandbook/src/admin-contrast.mjs`, `brandbook/src/admin-gallery.mjs`,
  `brandbook/src/admin-gallery-check.mjs`, `brandbook/src/tokens-build.mjs`
- `.github/workflows/ci.yml` — proof-lane convention; brandbook NOT gated today
- `e2e/support/admin-polish.js`, `e2e/playwright.config.js`, `e2e/admin-screenshots.spec.js`
- `examples/adoption_demo/priv/static/assets/cohort.css` — hand-authored `.ck-*`; `clamp()` ref
- `priv/static/rindle_admin/rindle-admin.css` — the second, hand-mirrored CSS copy
- `.planning/phases/88-admin-design-system-ui-kit/88-CONTEXT.md` — locked DS decisions (D-88-*)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The full `.mjs` token→CSS pipeline (`tokens-build.mjs`, `admin-css-build.mjs`,
  `admin-contrast.mjs`, `admin-gallery.mjs`/`admin-gallery-check.mjs`,
  `admin-design-system-data.mjs`) — extend, do not replace.
- `admin-polish.js` deterministic computed-style gate + `freezeMotion` — generalize via
  parameters; it is already surface-agnostic in its WCAG utils.
- The CI proof-lane convention (`needs: [quality, optional-dependencies]`, `setup-node@v4`).

### Established Patterns
- Generator is the only writer; `exact()` array-equality parity refuses drift (the
  idempotency anchor). New categories must be registered in the parity arrays.
- Per-call options object (`{viewport, surface}`) is the spec's extension seam.
- Two design systems separate but coherent: `rindle-admin` (generated, BEM) vs `cohort`
  (hand-authored, `.ck-*`) — never a shared file/build.

### Integration Points
- New CI job added to `.github/workflows/ci.yml`.
- New token categories added to `tokens.json` and emitted by `admin-css-build.mjs`.
- The hand-mirrored `priv/static/rindle_admin/rindle-admin.css` copy must be brought under
  the generator/sync mechanism so the gate covers the shipped artifact.
</code_context>

<specifics>
## Specific Ideas

- Fluid type: `clamp()` mirrors Cohort's existing `--ck-step-*` display approach
  (`cohort.css:71-76`) but applied to admin display sizes only.
- Dark status surfaces currently collapse to a single `dark-surface` (`tokens.json:99-104`)
  — differentiate per status, with new dark contrast pairs added to the WCAG gate.
- Elevation as a 4-level surface-tint ramp (not shadow), per FEATURES dark-mode-done-right.
</specifics>

<deferred>
## Deferred Ideas

- **Cohort's `.ck-*` dark `[data-theme]` + `prefers-reduced-motion` + elevation/motion
  authoring** → Phase 96 (Track B B1). Net-new, hand-authored, no prior art in `cohort.css`.
- **Exact `clamp()` min/preferred/max tuples + named breakpoint set** → `/gsd:ui-phase 94`
  (design judgment with the contrast gate in the loop). Only the shape is locked here.
- **Specific differentiated dark-status hex values + the 4-level elevation tint ramp** →
  `/gsd:ui-phase 94`, validated by extending the dark contrast pairs.
- **Optional non-blocking pixel-baseline `toHaveScreenshot()`** → later milestone work;
  research locked it as optional/assistive, never merge-blocking until proven stable.

### Reviewed Todos (not folded)
None — no pending todos matched Phase 94 scope.
</deferred>
