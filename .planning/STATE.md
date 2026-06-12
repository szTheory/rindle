---
gsd_state_version: 1.0
milestone: v1.18
milestone_name: Admin Console & Adoption Lab
status: executing
last_updated: "2026-06-12T18:53:44.939Z"
last_activity: 2026-06-12 -- Phase 90 planning complete
progress:
  total_phases: 23
  completed_phases: 7
  total_plans: 24
  completed_plans: 25
  percent: 30
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-11)

**Core value:** Media, made durable.
**Current focus:** Phase 90 — console ops actions
console, Cohort demo evolution, deterministic E2E, Docker DX

## Current Position

Phase: 90
Plan: Not started
Status: Ready to execute
Last activity: 2026-06-12 -- Phase 90 planning complete

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

**Phase 89 verification** — all seven Phase 89 plans are complete. Run
`$gsd-verify-work` for `.planning/phases/89-console-read-surfaces/` to validate
the mountable console read surfaces, live updates, package assets, and ADMIN-06
optional dependency proof as one phase.

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

- **Phase 88 verification complete (2026-06-11):** code review found and closed
  generated CSS contrast/border drift before completion. Dark status-chip surfaces,
  border color-vs-rule tokens, gallery helper borders, rendered contrast checks, and
  rendered border checks are now covered. Final review is clean; verifier passed
  automated gates after maintainer gallery approval.

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

- 89-01 requires Rindle Admin production mounts to provide non-empty `:on_mount` or explicit `auth_guarded?: true`.

- 89-01 keeps `allow_unauthenticated?: true` as a dev/test-only escape hatch and rejects it in production.

- 89-01 keeps Phoenix/LiveView and `Plug.Static` references behind the top-level optional dependency guard.
- [Phase 89]: 89-02 keeps generated admin CSS byte-identical to brandbook/tokens/rindle-admin.css and treats brandbook generators as source of truth.
- [Phase 89]: 89-02 packages only priv/static/rindle_admin, preserving the explicit priv/repo/migrations package boundary instead of broadening to all priv.
- [Phase 89]: 89-02 uses a self-contained JavaScript theme controller scoped to data-rindle-admin-root with an exact light/dark/auto allowlist.
- [Phase 89]: 89-03 keeps admin read composition in Rindle.Admin.Queries with exactly seven /1 query functions plus actions_directory/0.
- [Phase 89]: 89-03 returns UI-facing redaction copy instead of shortened provider IDs where provider identifiers would otherwise be exposed.
- [Phase 89]: 89-03 keeps actions_directory/0 read-only and disabled for Phase 90-owned operation flows.
- [Phase 89]: 89-04 keeps the first read surfaces guarded behind optional Phoenix dependencies while proving real LiveView behavior in tests.
- [Phase 89]: 89-04 uses exact packaged static asset routes so /assets/:id detail pages do not conflict with /assets/rindle-admin.css style URLs.
- [Phase 89]: 89-04 adds lazy_html only as a test dependency because Phoenix.LiveViewTest 1.1 requires it for DOM parsing.
- [Phase 89]: 89-05 keeps Variants/Jobs query-backed and renders active processing as status/count context while classified problem rows appear in findings.
- [Phase 89]: 89-05 keeps Actions strictly read-only until Phase 90 by rendering disabled metadata only and defining no mutation handle_event callbacks.
- [Phase 89]: 89-05 keeps Runtime/Doctor deterministic in LiveView tests by using explicit no-op probe and empty Oban queue config.
- [Phase 89]: 89-06 reuses Rindle.PubSub and existing upload_session/asset topics instead of adding a console-specific realtime channel.
- [Phase 89]: 89-06 keeps upload-session broadcasts redaction-safe with an explicit payload allowlist.
- [Phase 89]: 89-06 keeps console LiveViews payload-agnostic by re-querying Rindle.Admin.Queries after PubSub invalidation.
- [Phase 89]: 89-07 verifies Rindle.Admin.Router.rindle_admin/2 with macro_exported?/3 because the public router surface is a macro, not a function.
- [Phase 89]: 89-07 adds ADMIN-06 Optional Dependencies as a dedicated CI matrix job and required branch-protection check name.
- [Phase 89]: 89-07 keeps phoenix_live_view optional and adds no runtime UI framework dependency.

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

Last session: 2026-06-12T18:08:10.767Z
Stopped at: Phase 90 context gathered (assumptions mode)
Resume file: .planning/phases/90-console-ops-actions/90-CONTEXT.md

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
| Phase 89-console-read-surfaces P01 | 6 min | 2 tasks | 3 files |
| Phase 89-console-read-surfaces P02 | 5 min | 2 tasks | 8 files |
| Phase 89-console-read-surfaces P03 | 7 min | 2 tasks | 3 files |
| Phase 89-console-read-surfaces P04 | 16 min | 2 tasks | 9 files |
| Phase 89-console-read-surfaces P05 | 8 min | 2 tasks | 5 files |
| Phase 89-console-read-surfaces P06 | 9 min | 2 tasks | 5 files |
| Phase 89-console-read-surfaces P07 | 7 min | 2 tasks | 4 files |
