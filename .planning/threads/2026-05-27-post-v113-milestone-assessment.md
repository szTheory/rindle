# Post-v1.13 Milestone Assessment (v1.14+ boundary)

Date: 2026-05-27
Status: resolved

## Framing

Rindle is a Phoenix/Ecto-native **media lifecycle** library. Post-v1.13, "done enough"
means a serious SaaS team can complete core flows from Hex + guides without spelunking
internals — including aborting abandoned Mux direct uploads.

**Confidence:** High on shipped capabilities (`lib/`, tests, 14 guides). Planning drift
fixed in this pass: JTBD-MAP previously claimed `cancel_direct_upload` was planning-only;
v1.13 shipped it in `lib/rindle/streaming.ex`.

## Done estimate

**~95%** — band **90–95% near-done / diminishing returns soon**.

Rubric: T0–T2 JTBD cleared (v1.0–v1.11); v1.12 fixed support-truth/planning hygiene;
v1.13 closed Mux direct-upload cancel. Remaining delta is **IMPORTANT-BUT-NARROW (T3)**
or **LONG-TAIL POLISH** — not foundational.

## v1.14 recommendation

**Charter selected:** `v1.14 Bulk Owner-Erasure Orchestration` (LIFE-05).

Extends shipped v1.10 single-owner facade (`preview_owner_erasure/2`, `erase_owner/2`)
with batch preview/execute or mix task. Policy-first; no force-delete bundled; no admin UI.

If no adopter/compliance pull exists, the honest alternative is maintenance-only (patch
releases) — but assessment + milestone planning proceed with bulk orchestration as the
highest-leverage remaining wedge.

## Ranked wedges (v1.14+ only when demanded)

| Rank | Wedge | Type | Done enough |
|------|-------|------|-------------|
| 1 | Admin/bulk owner-erasure orchestration (LIFE-05) | IMPORTANT-BUT-NARROW | Batch preview/execute or mix task; policy first |
| 2 | Force-delete shared assets | IMPORTANT-BUT-NARROW | Explicit opt-in destructive policy + docs |
| 3 | Second streaming provider | IMPORTANT-BUT-NARROW | One adapter + doctor; explicit demand only |
| 4 | Signed dynamic image transforms (job 33) | LONG-TAIL POLISH | Only on explicit pull |
| 5 | EXIF privacy stripping (job 34) | LONG-TAIL POLISH | Opt-in control on originals |
| 6 | Richer uploader UI abstractions | LONG-TAIL POLISH | Beyond `allow_tus_upload/4` |

**Shipped since post-v112 assessment:** `cancel_direct_upload/1` (v1.13) — no longer a gap.

## Do not build (default)

- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Generic uploader component library
- Platform scope (DRM, HLS platform, unsigned dynamic transforms)
- Force-delete bundled into bulk erasure milestone
- Second streaming provider speculatively "to finish the abstraction"

## Verdict

**Finish the last important wedges on demand — mostly stop proactive feature work.**

Core JTBD for stated mission is shipped. v1.14 bulk orchestration is the correct narrow
milestone if GDPR/compliance scale is the pull. Otherwise patch releases only.

## Evidence pointers

- v1.13 audit: `.planning/milestones/v1.13-MILESTONE-AUDIT.md`
- JTBD anchor v1.13: `.planning/JTBD-MAP.md` (32/36 jobs ✅)
- `cancel_direct_upload`: `lib/rindle/streaming.ex`, `Rindle.Streaming.Provider.Mux`
- Owner erasure: `lib/rindle/internal/owner_erasure.ex`, `preview_owner_erasure/2`
- Deferred LIFE-05: `.planning/milestones/v1.13-REQUIREMENTS.md` Future Requirements

## Shift-left note

Global `~/.gsd/defaults.json` already has `text_mode: true` and
`research_before_questions: true`. Project `.planning/config.json` already has
`milestone_boundary.assessment_thread`, `regenerate_jtbd_on_ship`, `prefer_repo_inspection`.
No quality-gate changes recommended for bulk erasure milestone.

## Supersedes

- Post-v1.12 assessment: `.planning/threads/2026-05-27-post-v112-milestone-assessment.md`
  (v1.13 cancel wedge is now shipped; bulk erasure is #1 remaining)
