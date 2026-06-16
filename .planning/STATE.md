---
gsd_state_version: 1.0
milestone: v1.19
milestone_name: Design-System Stress-Test
status: executing
last_updated: "2026-06-16T02:30:27.873Z"
last_activity: 2026-06-16 -- Phase 95 execution started
progress:
  total_phases: 32
  completed_phases: 12
  total_plans: 44
  completed_plans: 45
  percent: 38
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-14)

**Core value:** Media, made durable.
**Current focus:** Phase 95 — admin-level-1-component-audit-track-a

## Current Position

Phase: 95 (admin-level-1-component-audit-track-a) — EXECUTING
Plan: 1 of 3
Status: Executing Phase 95
Last activity: 2026-06-16 -- Phase 95 execution started

## Current Milestone

**v1.19 Design-System Stress-Test** (SEED-002) — maintainer-pull **quality** milestone; likely
ships as hex **0.3.x**. Elevate the whole design system to an award-winning bar — fractally and
**without regressions** — across the mountable admin/operator console **and** the Cohort demo's
inner pages, in service of real user flows.

- **Two tracks on a hardened pipeline:** Track A (admin DS: component → meta-component → page) and
  Track B (Cohort restyle: `.ck-*` component layer + net-new dark/reduced-motion contract →
  page-by-page migration → daisyUI retirement). Parallel after the Phase 94 foundation;
  re-converge in Phase 102.

- **Near-zero new deps:** extend `tokens.json → .mjs → rindle-admin.css` (admin) + hand-authored
  `cohort.css`/`CohortComponents` (demo). No Tailwind in `rindle`, no JS animation lib, no SaaS
  visual-regression, no Storybook.

- **Proof (resolved):** the deterministic `admin-polish.js` computed-style gate (generalized over
  admin + Cohort) is the **single merge-blocking** visual gate; golden-PNG pixel baselines are
  optional / non-blocking only.

- **Roadmap:** `.planning/ROADMAP.md` phases 94–102
- **Requirements:** `.planning/REQUIREMENTS.md` (PIPE-01/02, UPLIFT-01..08, COHORT-01..06,
  VIS-01..04 — 20 reqs)

> ⚠️ **Opens over an un-closed v1.18.** v1.18 Admin Console & Adoption Lab is held at
> `status: tech_debt` pending maintainer HUMAN-UAT sign-off (Phases 90/91/92). Deliberate,
> recorded maintainer scope move (2026-06-14). Close via `/gsd-complete-milestone v1.18` once
> UAT is signed off.

## Next Step

**Discuss Phase 95.** Phase 94 is verified and complete; the next phase is Track A's
admin Level-1 component audit. Start with `/gsd-discuss-phase 95` so the component/state matrix
is grounded before planning.

## Accumulated Context

- **v1.19 build order (research-locked, repo-verified):** Foundation (94) → parallel Track A
  (95 admin L1 → 97 admin L2 → 98 admin L3+motion/mobile/a11y/IA/microcopy) + Track B (96 Cohort
  component layer + dark/reduced-motion → 99 small-7 page migrations → 100 /upload migration →
  101 daisyUI retirement) → re-converge (102 matrix + idempotency + audit). Level 1→2→3 is a hard
  intra-track dependency; pages compose only from finished primitives.

- **The structural prerequisite is closed:** Phase 94's `brandbook-tokens` job gates the
  `.mjs` token→CSS pipeline, and branch protection now requires that check.

- **Two design systems stay separate but coherent:** `rindle-admin` (`.rindle-admin-*` BEM,
  generated, host-Tailwind-independent) and `cohort.css` (`.ck-*`, hand-authored, emerald brand)
  share vocabulary but **never** a stylesheet, token file, or build step. Generated
  `rindle-admin.css` is never hand-edited (generator is the only writer).

- **Migration discipline:** class-by-class, never element-by-element; preserve every
  `id`/`data-testid`/`phx-hook` as a frozen behavior contract; run behavior e2e per page; delete
  `default.css` only once grep is clean (Phase 101).

- **Cohort net-new work:** `cohort.css` has **no** dark `[data-theme]` contract and **no**
  `prefers-reduced-motion` block today — both authored in Phase 96.

- **Anti-features (hard no):** metrics/charting dashboard, dark-by-inversion, color-only status,
  animate-everything, generating `cohort.css` from `tokens.json`, adding Tailwind/JS-anim-lib to
  `rindle`, golden-PNG as a merge blocker.

### Carried from v1.18 (tech_debt — HUMAN-UAT pending)

- v1.18 milestone-close gated on HUMAN-UAT sign-off for phases 90/91/92 (90 destructive-action UX,
  91 logo+lifecycle display, 92 screenshot-review matrix). Audit status: `tech_debt` until signed
  off; archival commit was reset away on `main`, so v1.18 reqs/roadmap remain inline (demoted, not
  archived). Close via `/gsd-complete-milestone v1.18`.

- **v1.18 surfaces are the substrate v1.19 polishes:** token-generated `rindle-admin` CSS,
  mountable console (`Rindle.Admin.Router.rindle_admin/2`), `Rindle.Admin.Queries`, deterministic
  `adoption-demo-e2e` Playwright lane (`admin-polish.js` + 22-PNG matrix), Cohort demo with full
  lifecycle-state seeds + audio/document profiles.

- **b1.0 brand system** in `brandbook/` (Confluence e1 logo, tokens with WCAG gate, HTML brand
  book) is the token source of truth for `rindle-admin`.

- **Do not** reopen tus protocol, Mux surfaces, owner-erasure semantics, or any console lifecycle
  / write path beyond the v1.18 surface — v1.19 is DS quality only.

- **Do not** add force-delete (LIFE-06) or a second provider (STREAM-10) — demand-gated, v1.20+.
- Default `mix coveralls` and `adoption-demo-e2e` are merge-blocking per `ci.yml` (source of truth).

## Decisions

- v1.19 proof strategy: deterministic computed-style `admin-polish.js` gate is the SINGLE
  merge-blocking visual gate (generalized over admin + Cohort); golden-PNG `toHaveScreenshot()`
  baselines stay optional / non-blocking (never merge-blocking until proven CI-stable).

- v1.19 keeps the two design systems separate (no shared stylesheet/token file/build step);
  coherence enforced by shared vocabulary + parallel gallery/contrast gate, not a shared file.

- v1.19 collapses the research's Cohort B1+B2 (Level-1 + Level-2 `.ck-*` layers) into a single
  Phase 96 anchored on COHORT-06, keeping a clean 1:1 requirement→phase mapping; the small-7 page
  migrations (Phase 99) and `/upload` (Phase 100) compose those finished primitives.

<details>
<summary>v1.18 phase-88..93 implementation decisions (carried, collapsed)</summary>

- 88: `rindle-admin` is vanilla generated CSS, no runtime UI dep / host asset-pipeline dep; gallery
  is static generated HTML linking only `../tokens/rindle-admin.css`; review screenshots gitignored.

- 89: production mounts require non-empty `:on_mount` or explicit `auth_guarded?: true`; packaged
  static assets are byte-identical to `brandbook/tokens/rindle-admin.css` (brandbook generators are
  source of truth); admin read composition lives in `Rindle.Admin.Queries` (7 `/1` query fns +
  `actions_directory/0`), not the public facade; `phoenix_live_view` optional, compile-away proven
  in a dedicated CI matrix job.

- 90: owner/batch erasure + non-destructive ops (variant regen, lifecycle repair, quarantine
  triage) implemented within `ActionsLive` with strict typed confirmation.

- 91: Cohort logo = `logo_opt2.svg`; console mounted at `/admin` via `allow_unauthenticated?: true`
  (demo only).

- 92: shared CommonJS admin helper inside the existing `adoption_demo` Playwright harness; only
  semantic `data-rindle-admin-*` selectors in shipped admin source; live screenshot artifacts under
  ignored Playwright `test-results` with an exact 22-file PNG contract; screenshot polish fixed at
  the brandbook generator source (CSS kept byte-identical across brandbook/priv).

- 93: TRUTH-07 docs parity CI-locked in `docs_parity_test.exs`; JTBD T4 admin-UI exclusion reversed
  (shipped job 39 cites `rindle_admin/2`); v1.18 traceability closed 19/19; milestone audit recorded
  at `status: tech_debt` pending HUMAN-UAT.

</details>

- [Phase ?]: Phase 94: token CSS pipeline gets a single committed sync mechanism (brandbook/src/sync-admin-css.mjs) mirroring generator output to the shipped priv copy; sync is a discrete invokable step (not folded into admin-css-build.mjs) so the Plan 04 CI gate calls it in D-94-02 order. Drift-free baseline established (stale dark text-on-brand corrected to #101417).
- [Phase ?]: Phase 94 Plan 02: admin-polish.js generalized over { root, interactiveSelectors } with admin defaults (D-94-07: no auto-detection — root always explicit). admin-screenshots spec byte-for-byte unchanged is the backward-compat acceptance test; the seam Phase 102 uses to run the same computed-style gate over Cohort ([data-ck-root] / .ck-*).
- [Phase ?]: Phase 94 Plan 03: four new token categories wired into tokens.json + admin generators via the 3-touchpoint pattern (source object -> emit loop -> parity registration). diagram kept out of MOTION_TOKENS (only the 3 new easings join, each consumed by a rule); elevation hexes placed in color.raw so both deref and WCAG resolve() find them; differentiated dark status surfaces are a tokens.json value change with no .map() edit. admin-contrast 44/44, base 47/47, both CSS copies byte-identical.
- [Phase ?]: Phase 94 Plan 04: standalone merge-blocking brandbook-tokens CI job lands (PIPE-01) — regen -> WCAG contrast -> gallery proof -> sync-admin-css -> tree-wide git diff --exit-code; closes the un-gated token->CSS pipeline gap. Surfaced + fixed stale committed tokens.css (Plan 03 ran admin-css-build but not the base tokens-build); the gate now lands on an empty-diff tree.

## Blockers/Concerns

- v1.18 milestone-close gated on HUMAN-UAT sign-off for phases 90/91/92. Audit status: tech_debt
  until signed off. v1.19 proceeds in parallel by recorded maintainer decision.

## Deferred Items

| Category | Item | Status |
|----------|------|--------|
| lifecycle | Force-delete policy (LIFE-06) | demand-gated (v1.20+ on compliance ticket) |
| streaming | Second provider (Cloudflare/Bunny) | demand-gated (v1.20+ on named adopter) |
| tus | IETF RUFH / tus 2.0 | deferred |
| tus | GCS-as-tus-backend / R2-native tus proxying | out of scope |
| tus | Rindle-owned standalone tus JS client package | out of scope |
| tus | Richer reusable uploader abstractions | deferred |
| polish | Signed dynamic image transforms (TRANS-01 / job 33) | deferred |
| polish | EXIF privacy stripping (PRIV-01 / job 34) | deferred |
| v1.19 | Pixel-baseline `toHaveScreenshot()` as merge-blocker | non-blocking only until CI-stable (Phase 102 optional) |

## Session Continuity

Last session: 2026-06-15T21:40:50.478Z
Stopped at: Phase 95 context gathered (assumptions mode)
Resume file: .planning/phases/95-admin-level-1-component-audit-track-a/95-CONTEXT.md

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 86 P01 | 10 min | 2 tasks | 2 files |
| Phase 86 P02 | 2 min | 2 tasks | 2 files |
| Phase 86 P03 | 2 min | 3 tasks | 3 files |
| Phase 87 P01 | 8 min | 2 tasks | 2 files |
| Phase 87 P02 | 2 min | 2 tasks | 1 files |
| Phase 87 P03 | 3 min | 2 tasks | 2 files |
| Phase 88 P01 | 7 min | 2 tasks | 4 files |
| Phase 88 P02 | 6 min | 2 tasks | 4 files |
| Phase 88 P03 | 12 min | 2 tasks | 6 files |
| Phase 89 P01 | 6 min | 2 tasks | 3 files |
| Phase 89 P02 | 5 min | 2 tasks | 8 files |
| Phase 89 P03 | 7 min | 2 tasks | 3 files |
| Phase 89 P04 | 16 min | 2 tasks | 9 files |
| Phase 89 P05 | 8 min | 2 tasks | 5 files |
| Phase 89 P06 | 9 min | 2 tasks | 5 files |
| Phase 89 P07 | 7 min | 2 tasks | 4 files |
| Phase 90 P01 | 10 min | 3 tasks | 3 files |
| Phase 90 P02 | 15 min | 3 tasks | 3 files |
| Phase 91 P01 | 2 min | 3 tasks | 4 files |
| Phase 91 P02 | 5 min | 2 tasks | 3 files |
| Phase 91 P03 | 5 min | 2 tasks | 2 files |
| Phase 92 P01 | 5 min | 2 tasks | 6 files |
| Phase 92 P02 | 70 min | 2 tasks | 10 files |
| Phase 92 P04 | 25 min | 2 tasks | 5 files |
| Phase 92 P05 | 8min | 2 tasks | 7 files |
| Phase 93 P01 | 2min | 3 tasks | 4 files |
| Phase 93 P02 | 6min | 2 tasks | 2 files |
| Phase 93 P03 | 4min | 2 tasks | 3 files |
| Phase 93 P04 | 12min | 3 tasks | 6 files |
| Phase 94 P01 | 7min | 2 tasks | 2 files |
| Phase 94 P02 | 6 min | 1 tasks | 1 files |
| Phase 94 P03 | 5min | 2 tasks | 6 files |
| Phase 94 P04 | 4min | 1 tasks | 2 files |
| Phase 94 P05 | 6min | 2 tasks | 3 files |
