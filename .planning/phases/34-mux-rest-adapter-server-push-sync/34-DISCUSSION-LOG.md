# Phase 34 Discussion Log

**Date:** 2026-05-06
**Mode:** Research-driven one-shot (per `STATE.md` Decision-Making Preference
and user feedback memo `memory/feedback_research_driven_one_shot.md`).

This phase did NOT use the standard interview-style 4-questions-per-area
flow. Per the user's durable preference, the discussion ran as:

1. Load full prior context (PROJECT.md, REQUIREMENTS.md, STATE.md,
   33-CONTEXT.md, candidate memo).
2. Scout existing code for patterns and reusable assets.
3. Spin up two parallel research subagents on the two genuinely-uncertain
   areas (Mux SDK 3.2.x exact surface; Oban patterns + optional-dep
   guards + test strategy).
4. Synthesize a coherent locked recommendation set into 34-CONTEXT.md
   (43 numbered decisions D-01..D-43).
5. No AskUserQuestion turns — none of the decisions met the escalation
   threshold (semver-significant public API reshape, destructive ops,
   security/compliance boundary, irreversible infra, scope shift).

---

## Areas analyzed

### Area 1 — Optional dep posture for `:mux` and `:jose`

**Pre-existing lock (memo §3 + REQ MUX-01):** `optional: true` for both;
adopter pays zero transitive cost when streaming not configured.

**Gray area resolved by research:** the *guard pattern* — wrap entire
adapter module in `if Code.ensure_loaded?(Mux.Video.Assets) do ... end`,
mirroring `lib/rindle/live_view.ex:1`. Locked as D-31..D-33.

### Area 2 — Mux SDK 3.2.x exact API surface

**Two memo corrections surfaced from the SDK's source on GitHub:**
- `Mux.Video.Assets.create/2` params use `playback_policy` (singular,
  string list `["signed"]`), not `playback_policies` (plural, atom list).
  Locked as D-04.
- `Mux.Token.sign/2` is **deprecated**; `Mux.Token.sign_playback_id/2` is
  the current export. Default `:expiration` is 7 days — must pass
  explicitly. Locked as D-06..D-09.

### Area 3 — Worker design (`MuxIngestVariant`, `MuxSyncProviderAsset`)

**Pre-existing lock (memo §7):** queue, max_attempts, unique constraints,
timeouts. Phase 34 mirrors `process_variant.ex:244-275` for atomic-promote.

**Gray area resolved by research (memo addition):** the periodic-poll
enqueuer was unspecified in the memo. Research locked the **coordinator +
per-row** pattern: `Rindle.Workers.MuxSyncCoordinator` is cron-driven and
fans out per-row `Rindle.Workers.MuxSyncProviderAsset` jobs. Mirrors
existing `cleanup_orphans.ex` / `abort_incomplete_uploads.ex`. Locked as
D-21..D-25.

### Area 4 — Webhook callback shape (signature only; routing in Phase 35)

**Memo correction surfaced:** `Mux.Webhooks.verify_header/4` accepts a
**single secret string**, not a list. Multi-secret rotation must loop in
the caller. Locked as D-10..D-12.

### Area 5 — Test strategy for Tesla-based SDK calls

**Choice locked:** Mox + thin behaviour wrapper
(`Rindle.Streaming.Provider.Mux.Client`) + `ClientMock` registered in
`test/support/mocks.ex`. Mirrors existing repo convention
(`Rindle.StorageMock`, `Rindle.ProcessorMock`). Rejected alternatives:
Tesla.Mock (process-locality issues with Oban worker process), Bypass
(Mux SDK base URL hard-coded), ExVCR (replay drift). Locked as
D-34..D-38.

### Area 6 — Telemetry shape and security invariant 14

**Pre-existing lock (memo §8.4 + Phase 33's invariant 14):** event
families, measurements, metadata. Phase 34 enforces last-4-char redaction
of `provider_asset_id` at every emit, reusing the helper from the schema
Inspect impl. Locked as D-26..D-28.

### Area 7 — Configuration

**Pre-existing lock (memo §8.6):** five env vars + three optional
tunables under `config :rindle, Rindle.Streaming.Provider.Mux`. No
caching; read at call site. Locked as D-29, D-30.

### Area 8 — Documentation touch

**Locked minimal:** `@moduledoc` blocks + CHANGELOG only. Phase 36 owns
`guides/streaming_providers.md`, `Rindle.Profile.Presets.MuxWeb`, README
updates. Locked as D-41, D-42.

---

## Items deliberately NOT escalated

The following are interesting trade-offs that some reviewers might want
to lock interactively, but per the user's research-driven preference and
the escalation threshold (very high blast radius only), they were locked
under "Claude's Discretion" or by research-default:

- Internal sub-module file layout (`provider/mux.ex` vs `mux/*.ex`
  folder) — D-39 expresses a recommendation; planner may consolidate
- Coordinator worker name — `Rindle.Workers.MuxSyncCoordinator` chosen
  over `Rindle.Workers.Mux.PollPending` for naming-pattern consistency
  with existing `Rindle.Workers.MuxIngestVariant`,
  `Rindle.Workers.MuxSyncProviderAsset`
- Whether to cache the JOSE PEM parse in `:persistent_term` — D-09
  defers to v1.7 (premature optimization for v1.6); planner may
  revisit if benchmarks show p99 > 10ms
- `mp4_support` + `max_resolution_tier` defaults inside the adapter —
  locked as `"standard"` and `"1080p"` per Mux's own production
  defaults (D-04); not exposed in the DSL (memo §5.2 forbids raw
  provider knobs)

## Items folded from prior context

- Phase 33 contract — the entire `Rindle.Streaming.Provider` behaviour
  callback set, schema, FSM, dispatch rule, error vocabulary. Phase 34
  consumes verbatim; no re-relitigation.
- Security invariant 14 (provider id redaction) — added v1.6 in PROJECT.md.
- AV-03-10 atomic-promote pattern — locked v1.4; Phase 34 mirrors it.
- Adopter-owned Oban supervision posture — locked v1.0+ across the
  codebase; Phase 34 honors it.

## Items deferred (captured for v1.7+ or later phase)

See `<deferred>` section of 34-CONTEXT.md for the full list. Highlights:

- `create_direct_upload/2` impl (Phase 37 / v1.7)
- Webhook plug + raw-body cache (Phase 35)
- `mix rindle.doctor` streaming validation (Phase 36)
- `Rindle.Profile.Presets.MuxWeb` + onboarding guide (Phase 36)
- JOSE PEM caching, webhook replay tooling, configurable telemetry
  redaction, `cancel_provider_ingest/1` (v1.7+)
- DASH support, second provider (v1.7+)

---

*Discussion mode: research-driven one-shot.*
*Subagents spawned: 2 (Mux SDK surface verification; Oban patterns +
optional-dep guards + test strategy).*
*Decisions locked: 43 (D-01..D-43).*
*AskUserQuestion turns: 0.*
