# v1.12 Milestone Assessment & Selection

Date: 2026-05-27
Status: resolved

## Framing

Rindle is a Phoenix/Ecto-native **media lifecycle** library (post-upload durability). "Done"
for this repo means a serious SaaS team can install from Hex, run `mix rindle.doctor`, wire
profiles, and complete core flows without hand-rolling lifecycle glue.

**Confidence:** High on shipped code/tests/guides. Lower on JTBD/MILESTONES sequencing until
v1.12 hygiene lands (JTBD was anchored at v1.7; MILESTONES.md lacked v1.11).

## Done estimate

**~93%** — band **90–95% near-done / diminishing returns soon**.

Rubric: core JTBD coverage strong; docs/onboarding good but planning drift risk; operator/diagnostic
surfaces shipped; proof/CI honest (generated-app lanes, parity gates, milestone audits).

## Adopter coverage (summary)

| Area | Status |
|------|--------|
| Presign/multipart/GCS resumable/tus ingest | Well-served |
| Phoenix LiveView tus + Mux direct upload | Well-served |
| Image/AV processing, signed delivery | Well-served |
| Mux streaming + webhooks | Well-served |
| Owner/account erasure facade | Well-served (v1.10) |
| Ops (doctor, runtime_status, maintenance) | Well-served |
| Cancel Mux direct upload | Gap — deferred, not in lib/ |
| Admin/bulk erasure, force-delete | Deferred / policy gap |
| Second streaming provider, tus 2.0, JS client | Out of scope or demand-only |

## v1.12 selection

**Milestone:** `v1.12 Adopter Truth & Maintenance Hygiene`

**Goal:** Align planning artifacts, JTBD frontier, public moduledocs, and API-surface tests
with shipped v1.11 reality — **no new capability requirements**.

**Why now:** Wrong planning truth (JTBD still ranks tus/Mux-direct/erasure as next) and stale
lib moduledocs ("Phase 37 deferred") waste tokens and invite overbuilding. Hygiene is the
highest-leverage work at ~93% done.

## Ranked wedges for v1.13+ (after v1.12)

| Rank | Wedge | Done enough | Notes |
|------|-------|-------------|-------|
| 1 | `cancel_direct_upload/1` | API + Mux adapter + test + guide | Only named Mux control hole; demand-driven |
| 2 | Admin/bulk owner-erasure orchestration | Batch/preview or mix task | High blast radius |
| 3 | Force-delete shared assets | Opt-in destructive policy | Policy decision first |
| 4 | Richer uploader UI abstractions | Beyond `allow_tus_upload/4` | Convenience only |
| 5 | Second streaming provider | One adapter + doctor | Explicit adopter demand only |

## Do not build (default)

- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Generic uploader component library
- Platform scope (DRM, HLS platform, unsigned dynamic transforms)

## Verdict

**Finish v1.12 hygiene, then mostly stop proactive feature work.** Go quiet until concrete
demand for `cancel_direct_upload/1` or lifecycle orchestration.

## Evidence pointers

- Shipped tus protocol: phases 57–59, `v1.11-MILESTONE-AUDIT.md`
- Owner erasure: phases 53–55, `preview_owner_erasure/2`, `erase_owner/2`
- Browser→Mux: `lib/rindle/streaming.ex`, v1.8 phase 45
- Planning drift noted: `JTBD-MAP.md` anchor v1.7 (fixed in v1.12 Phase 60)
- `cancel_direct_upload`: grep shows planning-only, zero lib/ matches

## Graduation candidates

- **Parity triple-lock:** guide + `phoenix_tus_truth_parity_test` + install-smoke tus lane —
  consider `.planning/METHODOLOGY.md` note for future proof phases.

## Supersedes

- `.planning/threads/2026-05-25-next-milestone-ordering.md` (v1.9-era wedge order; v1.10/v1.11 shipped)
