---
gsd_state_version: 1.0
milestone: v1.18
milestone_name: Admin Console & Adoption Lab
status: executing
last_updated: "2026-06-11T18:10:23.402Z"
last_activity: 2026-06-11 -- Phase 87 planning complete
progress:
  total_phases: 23
  completed_phases: 4
  total_plans: 12
  completed_plans: 12
  percent: 17
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-10)

**Core value:** Media, made durable.
**Current focus:** Phase 87 — docker & demo dx
console, Cohort demo evolution, deterministic E2E, Docker DX

## Current Position

Phase: 87
Plan: Not started
Status: Ready to execute
Last activity: 2026-06-11 -- Phase 87 planning complete

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

**Phase 87 plan** — use the captured Docker & Demo DX context, then research → plan →
execute → verify. Cost checkpoint offered before each heavy execute.

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

Last session: 2026-06-11T17:35:04.706Z
Stopped at: Phase 87 UI-SPEC approved
(release-please 0.2.0 PR from brand feat: commits expected on origin — merge to release brand)

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 86 P01 | 10 min | 2 tasks | 2 files |
| Phase 86 P02 | 2 min | 2 tasks | 2 files |
| Phase 86 P03 | 2 min | 3 tasks | 3 files |
