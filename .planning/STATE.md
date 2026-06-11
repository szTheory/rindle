---
gsd_state_version: 1.0
milestone: v1.18
milestone_name: Admin Console & Adoption Lab
status: ready_to_plan
last_updated: 2026-06-11T21:57:28.512Z
last_activity: 2026-06-11
progress:
  total_phases: 23
  completed_phases: 6
  total_plans: 18
  completed_plans: 18
  percent: 26
stopped_at: Phase 88 complete (3/3) — ready to discuss Phase 89
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-11)

**Core value:** Media, made durable.
**Current focus:** Phase 89 — console read surfaces
console, Cohort demo evolution, deterministic E2E, Docker DX

## Current Position

Phase: 89
Plan: Not started
Status: Ready to plan
Last activity: 2026-06-11

## Current Milestone

**v1.18 Admin Console & Adoption Lab** — ships as hex **0.3.0** (after 0.2.0 brand release).

- **Charter decisions:** D-v1.18-01 console in `rindle` package, mountable
  Oban-Web/LiveDashboard-style, self-contained assets; D-v1.18-02 hex 0.3.0 after 0.2.0;
  D-v1.18-03 keep Cohort, extend (audio + documents + full state-space seeds).

- **Scope reversal recorded:** JTBD T4 "admin UI" exclusion and the `lib/rindle.ex`
  facade "no admin UI" promise are deliberately reversed; TRUTH-07 closes docs parity.

- **Pause override:** PAUSE-03 amended; LIFE-06/STREAM-10 stay demand-gated → v1.19+.
- **Roadmap:** `.planning/ROADMAP.md` phases 86–93
- **Requirements:** `.planning/REQUIREMENTS.md` (ADMIN-01..06, DS-01..03, DEMO-01..03,
  E2E-01..02, DX-01..03, PRIN-01, TRUTH-07)

## Next Step

**Phase 88 verification** — review the completed admin design-system kit before Phase 89
consumes the generated CSS, static gallery, and operating guide.

**Manual brand follow-ups (one-time, carried over):**

1. GitHub repo Settings → Social preview → upload `brandbook/assets/social/github-social-preview.png`
2. Optional: set `brandbook/assets/logo/avatar-512.png` as repo/org avatar
3. HexDocs logo/favicon go live with the next Hex publish (0.2.0 release PR)

## Accumulated Context

- Rindle is roughly **94–96%** done for its stated mission (90–95% near-done band).
- Post-v117 assessment (repo-verified) reaffirms demand-gated pause as default next step.
- v1.17 closed residual assessment drift and recorded Credo/Dialyzer advisory policy (CI-04).
- v1.16 closed v1.15 audit gaps (proof CI lane, TusPlug doc lock, planning truth).
- LIFE-06 and STREAM-10 remain demand-gated for v1.18+ feature milestone.
- Default `mix coveralls` is merge-blocking per `ci.yml` (source of truth).

- **Closed (2026-05-28):** user_flows roadmap + Find-your-job tus row; PR `install_smoke.sh image` already merge-blocking.
- **Closed (2026-05-28):** batch erasure opts propagation (`run_batch_owner_erasure/3` forwards per-owner opts).
- **Closed (2026-05-29):** Adoption Evidence E2E Lab — Cohort persona (members, lessons, posts), 12 Playwright specs (11 merge-blocking + GCS skip), proof matrix drift gate, optional Docker preview (`scripts/demo/up.sh`).

- **Do not** reopen tus protocol, Mux surfaces, or owner-erasure semantics without demand signal.
- **Do not** add force-delete or a second provider without compliance/adopter charter (v1.19+).
- **v1.18 new-API boundary:** the only new public surface is the mountable console
  (router macro + mount config); operational queries stay in `Rindle.Admin.Queries`,
  console actions reuse existing facade capabilities — no new lifecycle semantics.

- **b1.0 shipped (2026-06-10):** committed brand system in `brandbook/` — Confluence e1
  logo (user-selected), tokens with 38/38 WCAG gate, self-contained HTML brand book,
  README/HexDocs/social integration. Regenerate assets via `brandbook/src/*.mjs`; the
  tokens are the source of truth. `examples/adoption_demo` still carries the Phoenix
  firebird placeholder logo — re-theme deferred (D-b1.0-01). "rindle" name-collision
  risk recorded as human-review-only (D-b1.0-03).

- **Phase 88 Plan 01 complete (2026-06-11):** `brandbook/src/admin-css-build.mjs`
  regenerates `brandbook/tokens/rindle-admin.css` from brand tokens with namespaced
  `.rindle-admin-*` BEM selectors, dark/auto theme scopes, motion-token usage, and parity
  checks. `brandbook/src/admin-contrast.mjs` validates 38/38 console component pairs.

- **Phase 88 Plan 02 complete (2026-06-11):** `brandbook/src/admin-gallery.mjs`
  regenerates a deterministic static Rindle Admin gallery with stable component/state
  selectors, `data-theme="light|dark|auto"` controls, and owner-erasure typed
  confirmation fixtures. `brandbook/src/admin-gallery-check.mjs` verifies the theme
  picker and confirmation behavior in Playwright and writes seven ignored screenshot
  review artifacts.

- **Phase 88 Plan 03 complete (2026-06-11):** `guides/admin_design_system.md`
  documents the design-system operating contract, package boundary, exact generation
  commands, forbidden dependencies, and Phase 89 ownership. Human gallery review reported
  a blocking anchor-navigation issue; `brandbook/src/admin-gallery.mjs` now emits matching
  surface section ids and `brandbook/src/admin-gallery-check.mjs` verifies `#assets`
  file deep links plus nav-click movement.

## Decisions

- 88-01 kept `rindle-admin` as vanilla generated CSS with no runtime UI dependency or host
  asset-pipeline dependency.

- 88-01 checks skeleton contrast through visible border boundaries rather than low-emphasis
  fill gradients.

- 88-02 kept the gallery as static generated HTML that links only
  `../tokens/rindle-admin.css`.

- 88-02 kept review screenshots ignored by default through
  `brandbook/admin-gallery/.gitignore`.

- 88-03 kept Phase 88 assets under `brandbook/` and documented that Phase 89 owns
  `priv/static/rindle_admin` serving.

- 88-03 resolved the gallery review issue by making each surface nav item target a
  generated section id instead of adding runtime routing.

## Blockers/Concerns

- None.

## Deferred Items

| Category | Item | Status |
|----------|------|--------|
| lifecycle | Force-delete policy (LIFE-06) | demand-gated (v1.18+ on compliance ticket) |
| streaming | Second provider (Cloudflare/Bunny) | demand-gated (v1.18+ on named adopter) |
| tus | IETF RUFH / tus 2.0 | deferred |
| tus | GCS-as-tus-backend / R2-native tus proxying | out of scope |
| tus | Rindle-owned standalone tus JS client package | out of scope |
| tus | Richer reusable uploader abstractions | deferred |
| polish | Signed dynamic image transforms (TRANS-01 / job 33) | deferred |
| polish | EXIF privacy stripping (PRIV-01 / job 34) | deferred |

## Session Continuity

Last session: 2026-06-11T21:29:41.661Z
Stopped at: Completed 88-03-PLAN.md; ready for Phase 88 verification
Resume file: None

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
