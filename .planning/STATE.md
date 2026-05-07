---
gsd_state_version: 1.0
milestone: v1.6
milestone_name: Provider Boundary + Mux
status: Awaiting next milestone
stopped_at: Phase 36 context gathered (assumptions mode)
last_updated: "2026-05-07T14:38:23.494Z"
last_activity: 2026-05-07 — Milestone v1.6 completed and archived
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 15
  completed_plans: 15
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-06)

**Core value:** Media, made durable.
**Current focus:** Phase 36 — public-dx-onboarding-ci-proof
`Rindle.Streaming.Provider` as a real adapter contract and ship Mux as the
single reference streaming adapter without expanding into a video platform.

## Current Position

Phase: Milestone v1.6 complete
Plan: —
Status: Awaiting next milestone
Last activity: 2026-05-07 — Milestone v1.6 completed and archived

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

- Execute Phase 35: Signed-Webhook Plug + Idempotent Ingest (`MUX-09..14`) —
  `/gsd-execute-phase 35`. 4 plans committed across 2 waves; recommended
  to `/clear` first for a fresh context window since Plan 02 has
  cross-plan dependencies on 35-01 and 35-03.

- **Cut hex release at v1.6 milestone close (after Phase 36 ships +
  `/gsd-complete-milestone v1.6`).** Last release `rindle-v0.1.4` was
  2026-04-29; since then v1.3 + v1.4 + v1.5 + v1.6 phases 33-34 all
  shipped (109 conventional `feat:`/`fix:` commits, 0 BREAKING). Wait
  for v1.6 close because Phase 35 (webhook plug) is what makes the
  Mux story end-to-end and Phase 36 ships the documented onboarding
  lane (`MuxWeb` preset, `mix rindle.doctor` streaming smoke,
  `guides/streaming_providers.md`, package-consumer `mux-enabled` CI
  lane). Release-please will auto-bump `0.1.4 → 0.2.0` (minor — no
  breaking changes). Trigger via the existing `release-please-config.json`
  pipeline; verify post-publish via `mix hex.publish docs` reachability
  probe (v1.3 surface). Add v1.4/v1.5/v1.6 highlights to the release
  body when the release-please PR opens.

- Phase 34 follow-ups (advisory, not blocking ship):
  - 9 Warning + 3 Info findings in `34-REVIEW.md` — auto-fix via
    `/gsd-code-review 34 --fix --all` or defer to v1.7 polish.

- Preserve GCS resumable uploads (`.planning/research/v1.6-CANDIDATE-GCS.md`)
  and tus (`.planning/research/v1.6-CANDIDATE-TUS.md`) as locked candidate
  scope for v1.7+.

## Blockers/Concerns

- None. v1.4/v1.5 phase-directory reconciliation completed in commit b09b1c9
  (archived to `.planning/milestones/v1.4-phases/` and `v1.5-phases/`).

## Deferred Items

Items acknowledged and deferred at v1.6 milestone close on 2026-05-07:

| Category | Item | Status |
|----------|------|--------|
| uat | Phase 36 — `bash scripts/install_smoke.sh mux` cassette PR run | pending (CI-only by Plan 03 design) |
| uat | Phase 36 — `mux-soak` real-Mux lane against `streaming`-labelled PR | pending (requires 5 GitHub Secrets) |
| uat | Phase 36 — HexDocs publish wire (`mix docs` rendering of MuxWeb + streaming_providers.md) | pending (post-publish observable) |
| uat | Phase 36 — Fork-secret leak boundary on `streaming`-labelled fork PR | pending (GitHub fork secret semantics) |
| uat | Phase 36 — `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` in spawned Phoenix project | pending (CI package-consumer step only) |
| code-review | Phase 34 — 9 Warning + 3 Info findings in `34-REVIEW.md` | deferred to v1.7 polish |
| code-review | Phase 35 — 6 Warning + 7 Info findings (advisory) | deferred to v1.7 polish |

Phase 36 verifier passed 5/5 must-haves at artifact-and-wiring level; the
5 UAT items above are CI-time observables by design (Plan 03 SUMMARY
explicitly defers them to the package-consumer CI step).

Phase 36 code-review findings — **all 12 already resolved before close**
(commits `8b291c1` CR-01, `744755e` CR-02, `12dfd0f` CR-03, `a1e5e94`–`c901124`
WR-01..WR-10). REVIEW.md `status: fixes_applied`. No Phase 36 review
deferral remains.

## Decision-Making Preference

- Downstream agents should front-load research, prefer coherent one-shot
  recommendations, and decide by default.

- Escalate only for very impactful decisions such as public semver reshapes,
  destructive or irreversible operations, security/compliance boundaries, or
  similarly high-blast-radius tradeoffs.

## Session Continuity

Last session: 2026-05-07T10:59:07.090Z
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

Stopped at: Phase 36 context gathered (assumptions mode)
Resume file: .planning/phases/36-public-dx-onboarding-ci-proof/36-CONTEXT.md

**Last Completed Milestone:** v1.5 (Phases 29-32) — archived 2026-05-06

**Next Step:** `/gsd-plan-phase 35`

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
