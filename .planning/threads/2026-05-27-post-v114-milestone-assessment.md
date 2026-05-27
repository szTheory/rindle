# Post-v1.14 Milestone Assessment (v1.15+ boundary)

Date: 2026-05-27
Status: resolved

## Framing

Rindle is a Phoenix/Ecto-native **media lifecycle** library. Post-v1.14, "done enough"
means a serious SaaS team can complete core flows from Hex + guides without spelunking
internals — including multi-owner GDPR/compliance erasure orchestration.

**Confidence:** High on shipped capabilities (`lib/`, tests, 14 guides). Medium on exact
done-% point estimate (95% vs 96% drift across planning artifacts).

## Done estimate

**~94–96%** — band **90–95% near-done / diminishing returns soon**.

Rubric: T0–T2 JTBD cleared (v1.0–v1.11); v1.12 fixed support-truth/planning hygiene;
v1.13 closed Mux direct-upload cancel; v1.14 closed bulk owner-erasure orchestration.
Remaining delta is **IMPORTANT-BUT-NARROW (T3)** or **LONG-TAIL POLISH** — not foundational.

## v1.14 result (shipped)

**Charter delivered:** `v1.14 Bulk Owner-Erasure Orchestration` (LIFE-05).

Batch `preview_batch_owner_erasure/2` / `erase_batch_owner_erasure/2`, operator CLI
`mix rindle.batch_owner_erasure`, PROOF-05 hermetic matrix, TRUTH-03 guide/docs parity.
8/8 requirements validated across Phases 67–70.

Bulk orchestration is **no longer a gap** — it was the last proactive T3 wedge.

## Ranked wedges (v1.15+ only when demanded)

| Rank | Wedge | Type | Done enough |
|------|-------|------|-------------|
| 1 | Maintenance / proof honesty | IMPORTANT-BUT-NARROW | JTBD regen post-v1.14; `batch_owner_failed` mix E2E; optional Nyquist on 68–70; CI lane severity decision |
| 2 | Force-delete shared assets (LIFE-06) | IMPORTANT-BUT-NARROW | Explicit opt-in only; preview collateral damage; never default; separate milestone |
| 3 | Second streaming provider (STREAM-10) | IMPORTANT-BUT-NARROW | One adapter + doctor; explicit adopter demand only |
| 4 | Signed dynamic image transforms (job 33) | LONG-TAIL POLISH | Explicit pull only |
| 5 | EXIF/GPS privacy stripping (job 34) | LONG-TAIL POLISH | Opt-in control on originals |

## Recommended next milestone

**Default: v1.15 Maintenance & Proof Honesty** — no new public feature surface unless
concrete compliance pull exists.

**Conditional upgrade: v1.15 Force-Delete Shared Assets (LIFE-06)** — only if legal/compliance
requires destroying blobs that still have surviving attachments from other owners.

## Do not build (default)

- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Generic uploader component library
- Platform scope (DRM, HLS platform, admin UI, CDN replacement)
- Second streaming provider speculatively "to finish the abstraction"
- Force-delete bundled into maintenance or any other milestone without explicit charter

## Open concerns

### CI proof honesty

Several high-signal CI lanes use `continue-on-error: true` in `.github/workflows/ci.yml`
(package-consumer, adopter, contract, dialyzer). Green main may overstate optional-path
and package-consumer readiness. Release workflow can bypass CI gate on timeout/failure.

**Decision needed:** Should any of these lanes become merge-blocking? High-impact — not
auto-applied.

### Maintenance tech debt (non-blocking)

- Mix `batch_owner_failed` partial report + exit 1 — no E2E task test (Phase 69 audit)
- Nyquist partial on phases 68–70 (`nyquist_compliant: false`) — optional `/gsd-validate-phase`
- Batch aggregate `retained_shared_assets` uses flat_map without asset_id dedupe — intentional;
  proofs use `>= 1` assertions

## Verdict

**Finish the last important wedges on demand — mostly stop proactive feature work.**

Core JTBD for stated mission is shipped. v1.15 default is maintenance-only. Force-delete
is the single feature milestone worth opening if compliance pull materializes.

## Evidence pointers

- v1.14 audit: `.planning/milestones/v1.14-MILESTONE-AUDIT.md`
- JTBD anchor v1.14: `.planning/JTBD-MAP.md` (job 38 batch erasure)
- Batch erasure: `lib/rindle.ex`, `lib/rindle/internal/owner_erasure.ex`
- Force-delete absence: `OwnerErasure.execute/2` ignores opts; no force-purge path
- Deferred LIFE-06: `.planning/milestones/v1.14-REQUIREMENTS.md` Future Requirements

## Supersedes

- Post-v1.13 assessment: `.planning/threads/2026-05-27-post-v113-milestone-assessment.md`
  (v1.14 bulk orchestration is now shipped; maintenance is #1 remaining wedge)
