---
gsd_state_version: 1.0
milestone: demand-gated-pause
milestone_name: Demand-gated pause
status: between-milestones
last_updated: "2026-05-28T14:00:00.000Z"
last_activity: 2026-05-28
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-27)

**Core value:** Media, made durable.
**Current focus:** Demand-gated pause — maintenance and issue-driven work only

## Current Position

Phase: Not started (no feature phases)
Plan: —
Status: Demand-gated pause — formalized 2026-05-27
Last activity: 2026-05-28 — LIFE-06 prep (batch opts fix), libvips docs, RP tag fix pending

## Current Milestone

**Demand-gated pause** — no versioned feature milestone (v1.18+ reserved for demand signals).

- **Last shipped:** v1.17 Adopter-Confidence Hygiene (Phases 78–80, 2026-05-27)
- **Assessment thread:** `.planning/threads/2026-05-27-post-v117-milestone-assessment.md`
- **LIFE-06 prep:** `.planning/threads/LIFE-06-prep.md` (no charter until compliance ticket)
- **Path-to-done:** `.planning/threads/2026-05-27-path-to-done-roadmap.md`
- **Requirements:** `.planning/REQUIREMENTS.md` (pause posture + demand gates)

## Next Step

**Issue-driven maintenance only** — patch/minor releases, bugs, docs drift.

**When demand arrives:** `/gsd-new-milestone` with LIFE-06 (compliance) or STREAM-10 (named adopter) signal.

**Do not run** `/gsd-plan-phase` until a feature milestone with phases exists.

## Accumulated Context

- Rindle is roughly **94–96%** done for its stated mission (90–95% near-done band).
- Post-v117 assessment (repo-verified) reaffirms demand-gated pause as default next step.
- v1.17 closed residual assessment drift and recorded Credo/Dialyzer advisory policy (CI-04).
- v1.16 closed v1.15 audit gaps (proof CI lane, TusPlug doc lock, planning truth).
- LIFE-06 and STREAM-10 remain demand-gated for v1.18+ feature milestone.
- Default `mix coveralls` is merge-blocking per `ci.yml` (source of truth).

- **Closed (2026-05-28):** user_flows roadmap + Find-your-job tus row; PR `install_smoke.sh image` already merge-blocking.
- **Closed (2026-05-28):** batch erasure opts propagation (`run_batch_owner_erasure/3` forwards per-owner opts).

- **Do not** reopen tus protocol, Mux surfaces, or owner-erasure semantics without demand signal.
- **Do not** add force-delete, second provider, or new public API without compliance/adopter charter.

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

Last session: 2026-05-28T14:00:00.000Z
