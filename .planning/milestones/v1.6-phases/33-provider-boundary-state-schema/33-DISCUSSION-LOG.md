# Phase 33: Provider Boundary + State Schema - Discussion Log

**Discussion date:** 2026-05-06
**Mode:** research-driven one-shot (no interview turns)

## Mode Rationale

Per the standing project preference (`.planning/STATE.md` Decision-Making
Preference; user-memory feedback `Prefer research-driven one-shot
recommendations over interview-style discussion`), Phase 33 was discussed in
non-interview mode:

- The locked recommendation memo
  `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` already specifies every
  contract surface Phase 33 ships (behaviour signatures verbatim §4, dispatch
  rule verbatim §5.1, profile DSL verbatim §5.2, Ecto migration verbatim §6,
  error vocabulary verbatim §8.2, security invariant 14 §9).
- `.planning/PROJECT.md` cites the memo as the source of truth for v1.6.
- `.planning/REQUIREMENTS.md` STREAM-01..09 mirrors the memo line by line.
- `.planning/ROADMAP.md` Phase 33 success criteria are derived directly from
  the memo.
- No genuinely-impactful unresolved decisions remained that would warrant
  user escalation under the "VERY impactful (public API / semver / destructive
  / security / cost / scope-shift)" bar.

The single arguably-escalation-worthy item — `streaming_url/3`'s
`opts[:strict]` default of `false` (progressive fallback when no provider row
exists) — was reviewed and locked from the memo's reasoning (memo §5.1):
mixed legacy assets need gradual migration, first-adopter cohort is
greenfield anyway, and `:strict` is opt-in for adopters who want
provider-only behavior. This was logged as decision **D-20** in CONTEXT.md
without re-asking.

## Areas Reviewed (No User Turn Required)

For each area, the locked decision source is the candidate memo. Decisions
were captured in CONTEXT.md `<decisions>` directly.

### 1. Capability Vocabulary (`Rindle.Streaming.Capabilities`)

- **Source:** memo §2 STREAM-01.
- **Locked:** D-01 (mirror `Rindle.Storage.Capabilities` shape), D-02 (closed
  vocabulary: `:signed_playback`, `:public_playback`, `:webhook_ingest`,
  `:server_push_ingest`, `:direct_creator_upload`), D-03 (no
  `require_streaming/2` in Phase 33 — Phase 37).
- **No user input needed:** the vocabulary is closed and pre-locked; the
  module shape mirrors an existing Rindle module exactly.

### 2. Provider Behaviour Promotion (`Rindle.Streaming.Provider`)

- **Source:** memo §4 (verbatim @callback signatures).
- **Locked:** D-04..D-08 covering all 6 required + 1 optional callbacks,
  type aliases, return-tuple discipline, and the structural correction that
  removes `streaming_url/3` from the behaviour (it lives only on
  `Rindle.Delivery`).
- **No user input needed:** the v1.4 reserved 2-callback shim has no shipped
  implementations; redesigning the behaviour is non-breaking in adopter
  terms and the new shape is locked in the memo.

### 3. State Schema and FSM (`media_provider_assets`,
`Rindle.Domain.MediaProviderAsset`, `ProviderAssetFSM`)

- **Source:** memo §6 (verbatim migration), §2 STREAM-04, §9 invariant 14.
- **Locked:** D-09 (full column list with types and defaults), D-10 (four
  indexes including the partial unique on
  `(provider_name, provider_asset_id) WHERE provider_asset_id IS NOT NULL`),
  D-11 (additive idempotent migration via standard
  `Application.app_dir(:rindle, "priv/repo/migrations")` adopter handoff),
  D-12 (file paths mirror existing domain modules), D-13 (FSM transitions
  with `errored → processing` re-ingest re-entry edge), D-14 (custom
  `Inspect` impl redacts `provider_asset_id` to last-4-char tag — schema
  enforcement of new security invariant 14).
- **No user input needed:** schema and FSM mirror existing
  `MediaAsset`/`AssetFSM` patterns; redaction posture is the locked v1.6
  security invariant.

### 4. Profile DSL `:streaming` Key

- **Source:** memo §5.2 (verbatim DSL example), STREAM-05.
- **Locked:** D-15 (four locked keys: `:provider`, `:playback_policy`,
  `:ingest_mode`, `:source_variant` — all required, named-only), D-16 (raw
  provider knobs forbidden via NimbleOptions schema), D-17 (image-only and
  AV-only profiles unchanged), D-18 (per-variant `kind` enforcement deferred
  to Phase 34).
- **No user input needed:** the DSL surface is locked in the memo.

### 5. Dispatch Rule (`Rindle.Delivery.streaming_url/3`)

- **Source:** memo §5.1 (verbatim 6-step decision tree).
- **Locked:** D-19 (full decision tree replacing the v1.4 no-op), D-20
  (`opts[:strict]` default `false` for migration friendliness), D-21
  (single `Repo.get_by/2` lookup using the unique index from D-10), D-22
  (`provider_name` derived from module-name underscore), D-23 (return shape
  preserved unchanged from v1.4), D-24 (existing
  `[:rindle, :delivery, :streaming, :resolved]` event preserved with
  documented additive `kind: :hls` extension when Phase 34 lights up the
  provider path).
- **No user input needed:** dispatch rule is the most precisely locked
  surface in the memo; D-20's default was reviewed and accepted.

### 6. Error Vocabulary

- **Source:** memo §8.2 (table of five new atoms), STREAM-07, STREAM-09.
- **Locked:** D-25 (five atoms verbatim), D-26 (reuse v1.4
  `:streaming_not_configured`), D-27 (each atom gets a `Rindle.Error.message/1`
  clause in AV-04/AV-05 cause→action style; bare-atom forms only — map-keyed
  variants deferred), D-28 (STREAM-09 parity-gate test mirrors AV-06-05).
- **No user input needed:** vocabulary is closed and pre-locked.

### 7. Capability Report (`Rindle.Capability.report/0`)

- **Source:** memo §2 STREAM-08.
- **Locked:** D-29 (new module at `lib/rindle/capability.ex`), D-30
  (aggregator shape including `streaming.providers`,
  `streaming.signed_playback_configured?`,
  `streaming.configured_profiles`), D-31 (Phase 33 ships the aggregator
  only; `mix rindle.doctor` refactor is a Phase 36 follow-on).
- **No user input needed:** shape is derived from the
  `mix rindle.doctor` consumption shape Phase 36 will need.

### 8. Standing Decision-Making Preference

- **Source:** `.planning/STATE.md`, user-memory feedback, prior CONTEXT
  precedent (Phase 32 D-21..D-22, Phase 26 D-23, Phase 31, Phase 30).
- **Locked:** D-32 reinforces the preference for downstream agents.
- **No user input needed:** standing preference confirmed.

## Areas NOT Discussed (Out of Phase 33 Scope)

- Mux SDK integration, optional dep declaration, signed-URL minting via
  `Mux.Token.sign/2`, `MuxIngestVariant` worker — Phase 34 (`/gsd-discuss-phase
  34`).
- Webhook plug, raw-body cache, multi-secret rotation, replay window,
  `IngestProviderWebhook` worker — Phase 35.
- `Rindle.Profile.Presets.MuxWeb`, `mix rindle.doctor` streaming smoke,
  `guides/streaming_providers.md`, generated-app `mux-enabled` lane — Phase 36.
- Browser→Mux direct creator upload, LiveView `:provider_asset_*` PubSub —
  Phase 37 (optional pull-forward).

## Deferred Ideas Captured

See CONTEXT.md `<deferred>` section. Brief list:
- Map-keyed error variants (richer than bare atoms) — v1.7+
- `:streaming.source_variant` per-variant `kind` enforcement — Phase 34
- `Rindle.Streaming.Capabilities.require_streaming/2` gate — Phase 37
- `Rindle.Capability.report/0` consumption inside `mix rindle.doctor` —
  Phase 36
- Configurable telemetry redaction — v1.7+
- Webhook event replay tooling — v1.7+
- `cancel_provider_ingest/1` — v1.7+
- DASH support — v1.7+

## Summary

Zero user-facing questions asked. Eight decision areas locked from the
candidate memo + REQUIREMENTS.md + PROJECT.md. CONTEXT.md captures 32
locked decisions (D-01..D-32) plus a wide "agent's Discretion" allow-list
covering implementation choices the planner / executor make autonomously.
Canonical refs include the memo (highest-priority), REQUIREMENTS.md,
PROJECT.md, STATE.md, ROADMAP.md, four prior-phase CONTEXTs (26, 24, 27, 32),
nine code-seam files, and four ecosystem references.

---

*Phase: 33-provider-boundary-state-schema*
*Discussion date: 2026-05-06*
