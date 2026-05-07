---
gsd_state_version: 1.0
milestone: v1.6
milestone_name: Provider Boundary + Mux
status: ready_for_planning
stopped_at: Phase 35 context gathered (46 decisions locked across mountable Plug, raw-body cache, worker contract, Mux event dispatch, PubSub broadcast, test signing, runtime_status extension)
last_updated: "2026-05-06T21:00:00.000Z"
last_activity: 2026-05-06 -- Phase 35 CONTEXT.md committed (d6cfa5f); research-driven one-shot, three parallel subagents (Plug shape / worker contract / Mux event surface); surfaced silent data-corruption fix for Phase 37 (D-29 Event.normalize/1 typed branch for video.upload.asset_created — data.id is upload-id, not asset-id)
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 17
  completed_plans: 8
  percent: 47
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-06)

**Core value:** Media, made durable.
**Current focus:** v1.6 Provider Boundary + Mux — productize
`Rindle.Streaming.Provider` as a real adapter contract and ship Mux as the
single reference streaming adapter without expanding into a video platform.

## Current Position

Phase: 35 — Signed-Webhook Plug + Idempotent Ingest (context gathered)
Plan: TBD — `/gsd-plan-phase 35`
Status: Ready for planning — Phase 35 CONTEXT.md committed
Last activity: 2026-05-06 -- Phase 35 context gathered; 46 decisions locked; ready for `/gsd-plan-phase 35` to produce the 4-plan PLAN.md per ROADMAP.md plan-count guidance

## Recent Completion

- Last completed milestone: `v1.5 Adopter Hardening & Lifecycle Repair`
- Scope: Phases 29-32, 14 plans
- Audit status: passed on 2026-05-06
- Archive files:
  - `.planning/milestones/v1.5-ROADMAP.md`
  - `.planning/milestones/v1.5-REQUIREMENTS.md`
  - `.planning/milestones/v1.5-MILESTONE-AUDIT.md`
  - `.planning/milestones/v1.4-ROADMAP.md`
  - `.planning/milestones/v1.4-REQUIREMENTS.md`
  - `.planning/milestones/v1.4-MILESTONE-AUDIT.md`

## Pending Todos

- Plan Phase 35: Signed-Webhook Plug + Idempotent Ingest (`MUX-09..14`) —
  `/gsd-plan-phase 35`. CONTEXT.md committed; 4-plan target per ROADMAP.md
  guidance (highest-fidelity v1.6 phase: raw-body cache, multi-secret
  rotation, replay protection, idempotency).

- Phase 34 follow-ups (advisory, not blocking ship):
  - 9 Warning + 3 Info findings in `34-REVIEW.md` — auto-fix via
    `/gsd-code-review 34 --fix --all` or defer to v1.7 polish.

- Preserve GCS resumable uploads (`.planning/research/v1.6-CANDIDATE-GCS.md`)
  and tus (`.planning/research/v1.6-CANDIDATE-TUS.md`) as locked candidate
  scope for v1.7+.

## Blockers/Concerns

- None. v1.4/v1.5 phase-directory reconciliation completed in commit b09b1c9
  (archived to `.planning/milestones/v1.4-phases/` and `v1.5-phases/`).

## Decision-Making Preference

- Downstream agents should front-load research, prefer coherent one-shot
  recommendations, and decide by default.

- Escalate only for very impactful decisions such as public semver reshapes,
  destructive or irreversible operations, security/compliance boundaries, or
  similarly high-blast-radius tradeoffs.

## Session Continuity

Last session: Phase 35 context gathered (research-driven one-shot, no
interview turns); 46 decisions locked. Three parallel research subagents:
(A) mountable Plug + raw-body cache pattern (Stripe.WebhookPlug peer
comparison, body_reader MFA, init opt validation), (B) IngestProviderWebhook
worker contract (race-snooze for missing row, FSM concurrency, two-topic
PubSub broadcast, telemetry namespace split, runtime_status --provider-stuck
extension), (C) Mux event catalog (full 2026 set with v1.6 disposition;
DROP table; HMAC test signing via Mux.Webhooks.TestUtils.generate_signature/2;
fixture payloads). Surfaced silent data-corruption fix for Phase 37:
Event.normalize/1 mis-attributes data.id for video.upload.asset_created
(data.id is upload-id; asset-id lives in data.asset_id) — Phase 35 lands
the typed branch as forward-compat (D-29).

Stopped at: Phase 35 CONTEXT.md + DISCUSSION-LOG.md committed (d6cfa5f)
Resume file: .planning/phases/35-signed-webhook-plug-idempotent-ingest/35-CONTEXT.md

**Last Completed Milestone:** v1.5 (Phases 29-32) — archived 2026-05-06

**Next Step:** `/gsd-plan-phase 35`
