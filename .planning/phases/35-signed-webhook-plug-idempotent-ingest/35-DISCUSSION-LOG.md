# Phase 35 Discussion Log

**Date:** 2026-05-06
**Mode:** Research-driven one-shot (no interactive questions). Per `STATE.md`
Decision-Making Preference and the user feedback memo
`memory/feedback_research_driven_one_shot.md`: planner / executor decide
by default; escalate only for VERY impactful items (semver / public-API /
security / cost / scope-shift). Phase 35 had no such items — every
decision either inherits from the candidate memo and Phase 34 CONTEXT or
falls inside the bounds the user already locked.

## Process

1. **Loaded prior context:** PROJECT.md, REQUIREMENTS.md, STATE.md, Phase 34
   CONTEXT.md, candidate memo `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md`.
2. **Scouted existing code** for Phase 35-relevant seams:
   `lib/rindle/streaming/provider/mux.ex` (`verify_webhook/3` shipped),
   `lib/rindle/streaming/provider/mux/event.ex` (normalizer shipped),
   `lib/rindle/delivery/local_plug.ex` (existing Plug pattern),
   `lib/rindle/workers/process_variant.ex` (PubSub broadcast pattern),
   `lib/rindle/workers/mux_ingest_variant.ex` (worker shape),
   `lib/rindle/domain/provider_asset_fsm.ex` (FSM contract),
   `lib/rindle/ops/runtime_status.ex` (extension target),
   `lib/mix/tasks/rindle.runtime_status.ex` (Mix wrapper).
3. **Spawned three parallel research subagents:**
   - **A** — Mountable Plug + raw-body cache shape; Stripe.WebhookPlug
     peer comparison; init opt validation; failure-mode coverage.
   - **B** — `IngestProviderWebhook` Oban worker contract; race handling
     (webhook-before-row); FSM concurrency; PubSub topic+payload; telemetry
     namespace split; `runtime_status --provider-stuck` extension.
   - **C** — Mux event catalog (full 2026 set with v1.6 disposition);
     test signing helper; fixture payload templates; replay-attack test
     pattern; `Event.normalize/1` upload-event branch.
4. **Synthesized findings** into a single coherent decision set with
   merged D-XX numbering.

## Key Findings (Folded Into CONTEXT.md)

### Surprises / Course Corrections

- **`Event.normalize/1` mis-attributes `data.id` for `video.upload.asset_created`**
  — Mux ships `data.id` as the UPLOAD-id (NOT the asset-id) for this event.
  The current generic branch silently corrupts `provider_asset_id` for
  Phase 37's direct-creator-uploads. Phase 35 lands the typed branch as
  forward-compat (D-29) — pure forward-compat with zero v1.6 runtime impact.
  This was the most important silent footgun the research surfaced.

- **`Rindle.Streaming.Provider.@type provider_event` extends with optional
  `upload_id` field** (D-30). Additive Phase 33 typespec extension; no
  callback shape change.

- **The Plug's `secrets:` resolver supports four shapes** (`[binary()]` /
  `{:system, env}` / `{:application, app, keys}` / 0-arity fn) — D-02. The
  candidate memo only mentioned `{:system, ...}` but the Phase 34 production
  config posture is `{:application, ...}` (resolved env vars stored in
  Application config). Supporting both is cheap; canonical adopter usage
  is `{:application, ...}`.

- **`405 Method Not Allowed` for non-POST**, deliberately diverging from
  Stripe's `400` (D-04). Avoids GET-health-check confusion and is HTTP-correct.

- **`503 Service Unavailable` for Oban DB failure during enqueue**, NOT
  `500` (D-15). Mux retries non-2xx; 503 is the correct semantic for
  "transient downstream, please retry."

- **`500 server_misconfigured` for missing body-reader assign + empty
  read_body fallback** (D-16). Adopter wiring bug, not a malformed
  webhook. Surface clearly, don't 400.

- **Worker telemetry uses a NEW namespace** `:processed | :ignored |
  :exception` distinct from Plug's `:verified | :rejected | :secret_used`
  (D-26). Operators see both signals: edge verification AND queue drain.

- **Two-topic PubSub broadcast** mirrors `process_variant.ex:478`:
  `"rindle:provider_asset:#{asset_id}"` AND `"rindle:asset:#{asset_id}"`,
  keyed on `MediaAsset.id` (D-31). Phase 37's LiveView extension is then
  a one-line addition to `live_view.ex:209-211`'s `topic_for/2` table.

- **Race-snooze for missing `media_provider_assets` row** is the locked
  posture (D-21): `5/15/45/90s` over 4 attempts then cancel. Phase 35 is
  the only Rindle worker using `{:snooze, n}`; documented in worker
  `@moduledoc`.

- **Mux event DROP set returns `200 OK`, NOT `204`** (D-28). Mux historically
  has quirks with 204 interpreted as "no acknowledgment." Telemetry emits
  `kind: :dropped` so operators see the events.

- **`Mux.Webhooks.TestUtils.generate_signature/2`** is a public SDK helper
  Rindle adopts for happy-path tests (D-34); wrapped in
  `Rindle.Test.MuxWebhookFixtures.sign_header/3` only to add the `:timestamp`
  override needed for replay-attack tests.

### Decisions Locked (Summary; full text in CONTEXT.md `<decisions>`)

46 decisions locked across 9 categories:
- Mountable Plug shape (D-01..D-05)
- Raw-body cache (D-06..D-10)
- Verification, enqueue, response (D-11..D-17)
- Worker contract (D-18..D-26)
- Mux event dispatch + DROP table (D-27..D-28)
- `Event.normalize/1` upload-event branch + typespec extension (D-29..D-30)
- PubSub broadcast contract (D-31..D-33)
- Test surface (D-34..D-38)
- `runtime_status --provider-stuck` extension (D-39..D-41)
- Configuration (no new env vars) (D-42)
- Module layout (D-43..D-44)
- Documentation (Phase 35 inline-only; Phase 36 owns guide) (D-45)
- Decision-Making Preference reinforcement (D-46)

Plus Claude's Discretion items (planner/executor decide autonomously)
documented at end of `<decisions>`.

## Items Not Discussed (No Escalation Triggered)

The user preference says escalate only for: public API / module / function
renames touching the published surface; semver-affecting changes; deletion
of git history or hex versions; secret/auth scope changes; cost-bearing
infra; milestone/scope reshape.

Phase 35 had no such items:
- New public modules (`WebhookPlug`, `WebhookBodyReader`,
  `IngestProviderWebhook`) — REQUIRED by ROADMAP.md (MUX-09..14); shape
  locked by candidate memo §5.3 + §7.
- `provider_event` typespec extension — additive optional field, not a
  rename or breaking change.
- `verify_webhook/3` callback contract — UNCHANGED (D-17). Provider-internal
  telemetry is additive, not a behaviour change.
- All other decisions are implementation specifics within already-bounded
  surface area.

## Deferred Ideas

(Captured in CONTEXT.md `<deferred>` section.) Most notable:
- `:provider_asset_created` PubSub broadcast → Phase 37
- `Rindle.LiveView.subscribe(:provider_asset, id)` → Phase 37
- `Rindle.Streaming.Provider.Mux.create_direct_upload/2` → Phase 37
- Configurable webhook body-size limit → v1.7+
- Pending-event sidecar table for race → rejected (snooze is the locked posture)
- Re-verify signature in worker → rejected (Plug is the trust boundary)

## Next Step

`/gsd-plan-phase 35` to produce the 4-plan PLAN.md from this CONTEXT.md.
