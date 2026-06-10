---
gsd_state_version: 1.0
milestone: b1.0
milestone_name: Brand Foundations
status: active
last_updated: "2026-06-10T15:59:29.000Z"
last_activity: 2026-06-10
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 11
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-10)

**Core value:** Media, made durable.
**Current focus:** b1.0 Brand Foundations (non-feature brand track); feature pause remains active

## Current Position

Phase: 81 of 81–85 (Brand Audit & Direction Lock)
Plan: 81-01 pending
Status: b1.0 opened 2026-06-10 — brand track, zero `lib/` changes
Last activity: 2026-06-10 — b1.0 charter committed (phases 81–85, BRAND-01..08)

## Current Milestone

**b1.0 Brand Foundations** — non-feature brand track (phases 81–85). The demand-gated
pause for feature work remains active; v1.18+ stays reserved for LIFE-06/STREAM-10.

- **Charter:** pressure-test `prompts/rindle-brand-book.md` seed → user-selected logo
  system → verified design tokens → self-contained HTML brand book in `brandbook/` →
  README/HexDocs/social integration
- **Last shipped:** v1.17 Adopter-Confidence Hygiene (Phases 78–80, 2026-05-27)
- **Assessment thread:** `.planning/threads/2026-05-27-post-v117-milestone-assessment.md`
- **Requirements:** `.planning/REQUIREMENTS.md` (BRAND-01..08 + pause posture)

## Next Step

Execute Phase 81 (brand audit + direction lock), then Phase 82 logo candidates with the
**user-selection checkpoint** (hard gate — never auto-pick the logo).

**When feature demand arrives:** `/gsd-new-milestone` with LIFE-06 (compliance) or STREAM-10 (named adopter) signal.

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
- **Do not** add force-delete, second provider, or new public API without compliance/adopter charter.

- **b1.0 brand track (2026-06-10):** `examples/adoption_demo/priv/static/images/logo.svg`
  is the Phoenix Framework bird logo (placeholder, Phoenix orange `#FD4F00`) — not a Rindle
  mark; resolution recorded in Phase 81. Brand work touches `brandbook/`, `mix.exs` docs()
  config, and README only — never `lib/`. User logo constraints: no container shapes behind
  marks, tight logotype, no subtitle on main lockup, ≥2 integrated typemark candidates.

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

Last session: 2026-06-10T15:59:29.000Z
Stopped at: b1.0 Brand Foundations opened; Phase 81 next
