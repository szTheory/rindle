# Post-v1.12 Milestone Assessment (v1.13+ boundary)

Date: 2026-05-27
Status: resolved

## Framing

Rindle is a Phoenix/Ecto-native **media lifecycle** library. Post-v1.12, "done enough"
means planning truth matches shipped code and a serious SaaS team can complete core flows
from Hex + guides without spelunking internals.

**Confidence:** High. v1.12 closed JTBD/MILESTONES/moduledoc drift. Fresh proof run:
58 tests (api_surface_boundary + phoenix_tus_truth_parity + tus_plug) green.

## Done estimate

**~94%** — band **90–95% near-done / diminishing returns soon**.

Rubric: T0–T2 JTBD cleared (v1.0–v1.11); v1.12 fixed support-truth/planning hygiene;
remaining delta is **IMPORTANT-BUT-NARROW** (T3 demand-driven) not foundational.

## v1.13 recommendation

**Do not open a proactive v1.13 milestone.** Enter maintenance / demand-driven mode.

If concrete adopter demand appears, the first capability wedge is
`cancel_direct_upload/1` (Mux-only, narrow surface).

## Ranked wedges (v1.13+ only when demanded)

| Rank | Wedge | Type | Done enough |
|------|-------|------|-------------|
| 1 | `cancel_direct_upload/1` | IMPORTANT-BUT-NARROW | Public API + Mux adapter + test + guide note |
| 2 | Admin/bulk owner-erasure orchestration | IMPORTANT-BUT-NARROW | Batch preview/execute or mix task; policy first |
| 3 | Force-delete shared assets | IMPORTANT-BUT-NARROW | Explicit opt-in destructive policy + docs |
| 4 | Signed dynamic image transforms (job 33) | LONG-TAIL POLISH | Only on explicit pull |
| 5 | EXIF privacy stripping (job 34) | LONG-TAIL POLISH | Opt-in control on originals |
| 6 | Second streaming provider | IMPORTANT-BUT-NARROW | One adapter + doctor; explicit demand only |
| 7 | Richer uploader UI abstractions | LONG-TAIL POLISH | Beyond `allow_tus_upload/4` |

## Do not build (default)

- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Generic uploader component library
- Platform scope (DRM, HLS platform, unsigned dynamic transforms)

## Verdict

**Mostly stop proactive feature work.** Ship patch releases for bugs/deps only until
concrete demand for `cancel_direct_upload/1` or lifecycle orchestration.

## Evidence pointers

- v1.12 audit: `.planning/milestones/v1.12-MILESTONE-AUDIT.md`
- JTBD anchor v1.11: `.planning/JTBD-MAP.md` (32/36 jobs ✅)
- `cancel_direct_upload`: planning-only (zero `lib/` matches)
- Install-smoke tus: `tmp/install_smoke_tus_last_run.json` (extensions proved)
- Owner erasure: `Rindle.preview_owner_erasure/2`, `erase_owner/2` in `lib/rindle.ex`

## Supersedes

- Pre-ship v1.12 selection: `.planning/threads/2026-05-27-v112-milestone-assessment.md`
  (v1.12 is now shipped; this thread is the active v1.13+ boundary)
