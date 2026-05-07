# Phase 33: Provider Boundary + State Schema - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Lock the public seam for provider-aware streaming without adding any Mux code.
Phase 33 ships the contract surface — promoted `Rindle.Streaming.Provider`
behaviour, `Rindle.Streaming.Capabilities` vocabulary, additive
`media_provider_assets` Ecto table + `Rindle.Domain.MediaProviderAsset` schema
+ FSM, profile DSL `:streaming` key, `Rindle.Delivery.streaming_url/3`
dispatch rule, five additive `Rindle.Error` reason atoms, capability report
extension, and an exact-text parity gate — so Phase 34 can land Mux against a
stable, frozen contract.

In scope:
- Capability vocabulary (`Rindle.Streaming.Capabilities`) mirroring
  `Rindle.Storage.Capabilities`
- Promoting `Rindle.Streaming.Provider` from reserved 2-callback shim to a
  runtime contract with the locked 6-required + 1-optional callback set
- Additive `media_provider_assets` table (no change to `media_assets` /
  `media_variants`) and `Rindle.Domain.MediaProviderAsset` schema + changeset +
  `Rindle.Domain.ProviderAssetFSM`
- Profile DSL `:streaming` key (NimbleOptions-validated, named-preset only)
- `Rindle.Delivery.streaming_url/3` deterministic dispatch rule (replaces
  v1.4's no-op delegate; preserves progressive-fallback default with `:strict`
  opt-in)
- Five additive locked `Rindle.Error` reason atoms with exact-text parity gate
- `Rindle.Capability.report/0` aggregator that includes streaming providers and
  signed-playback configuration status
- Reserving the new `Rindle.Streaming.Capabilities` vocabulary entry
  `:direct_creator_upload` for Phase 37 / v1.7

Out of scope:
- Any Mux adapter code (`Rindle.Streaming.Provider.Mux`) — Phase 34
- Webhook plug, raw-body cache, signature verification, multi-secret
  rotation — Phase 35
- Onboarding presets (`Rindle.Profile.Presets.MuxWeb`), doctor streaming
  smoke checks, generated-app `mux-enabled` lane, `guides/streaming_providers.md`
  — Phase 36
- Browser→Mux direct creator upload, `create_direct_upload/2` impl, LiveView
  `:provider_asset_*` PubSub — Phase 37 (optional pull-forward)
- `Rindle.Workers.MuxIngestVariant`, `MuxSyncProviderAsset`, atomic-promote
  on flip-to-ready — Phase 34
- Replacing `Rindle.Processor.AV` or any change to FFmpeg-driven progressive
  delivery — out of milestone scope
- Adding telemetry redaction config, webhook event replay tooling, or
  `cancel_provider_ingest/1` — explicitly deferred to v1.7+

</domain>

<decisions>
## Implementation Decisions

All decisions in this section are locked from the candidate memo
`.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` and REQUIREMENTS.md
STREAM-01..09. Section refs below point at the memo unless noted otherwise.

### Capability Vocabulary (STREAM-01)

- **D-01:** Ship `Rindle.Streaming.Capabilities` as a new module mirroring
  `Rindle.Storage.Capabilities` exactly: a `@known` list, `known/0`, and
  `safe/1` that filters an adapter's `capabilities/0` against the closed
  vocabulary. (Memo §2 STREAM-01; current pattern in
  `lib/rindle/storage/capabilities.ex`.)
- **D-02:** Closed vocabulary atoms (locked, no expansion mid-milestone):
  `:signed_playback`, `:public_playback`, `:webhook_ingest`,
  `:server_push_ingest`, `:direct_creator_upload`. The last is *reserved* —
  Phase 33 ships it in the vocabulary but no adapter advertises it until
  Phase 37 / v1.7. (Memo §2 STREAM-01.)
- **D-03:** `Rindle.Streaming.Capabilities.require_streaming/2` is **not**
  shipped in Phase 33 — that gate is REQ MUX-22 and lives in Phase 37. Phase
  33 ships only the vocabulary + `safe/1` filter + `known/0`.

### Provider Behaviour Contract (STREAM-02)

- **D-04:** Replace the existing 2-callback `Rindle.Streaming.Provider` shim
  (`streaming_url/3`, `capabilities/0`) with the locked 6-required + 1-optional
  callback set in memo §4 verbatim:
  - `capabilities/0`
  - `create_asset(profile, source_url, opts)`
  - `get_asset(provider_asset_id)`
  - `delete_asset(provider_asset_id)`
  - `signed_playback_url(profile, playback_id, opts)`
  - `verify_webhook(raw_body, headers, secrets)`
  - `create_direct_upload(profile, opts)` — `@optional_callbacks` only
- **D-05:** `streaming_url/3` is **NOT** a behaviour callback — it lives only
  on `Rindle.Delivery` (D-15 below). The v1.4-reserved Provider behaviour
  conflated dispatch with provider impl; Phase 33 corrects that. The Provider
  behaviour is the asset-CRUD + signed-playback-URL + webhook-verify boundary,
  not the dispatch surface.
- **D-06:** Lock the public types in the behaviour module verbatim from memo
  §4: `provider_asset_id :: String.t()`, `playback_id :: String.t()`,
  `provider_state :: :pending | :uploading | :processing | :ready | :errored
  | :deleted`, `provider_event` map shape, `capability` atom union.
- **D-07:** Every callback returns `:ok`-tuple or `:error`-tuple. No raised
  exceptions on the happy path. `verify_webhook/3` returns a normalized
  `provider_event` map, not a Mux struct — this is the single boundary that
  prevents Mux-isms leaking into core (memo §4 locked guarantees).
- **D-08:** Removing the existing 2-callback shape is a **non-breaking** change
  in adopter terms: the v1.4 module is documented as "Reserved behaviour for
  future non-progressive streaming providers" with no shipped implementations.
  No semver bump required for this redesign.

### State Schema and FSM (STREAM-03, STREAM-04)

- **D-09:** Ship the `media_provider_assets` table per memo §6 verbatim,
  binary_id primary key, columns: `asset_id` (FK to `media_assets`,
  `on_delete: :delete_all`, not null), `profile`, `provider_name`,
  `provider_asset_id` (nullable until create_asset succeeds), `playback_ids`
  (`{:array, :string}`, default `[]`), `playback_policy`, `ingest_mode`,
  `state` (default `"pending"`), `last_event_id`, `last_event_at`,
  `last_sync_error` (truncated to 4096 chars), `raw_provider_metadata`
  (`:map`, default `%{}`), `timestamps()`.
- **D-10:** Ship the four indexes from memo §6 verbatim:
  - `unique_index([:provider_name, :provider_asset_id], where:
    "provider_asset_id IS NOT NULL")`
  - `unique_index([:asset_id, :profile, :provider_name])`
  - `index([:state])`
  - `index([:state, :updated_at])` (drives Phase 34's stuck-row sweeper)
- **D-11:** Migration is generated into `priv/repo/migrations` with the same
  adopter-owned migration handoff as the v1.4 AV migration (`AV-02-08`
  pattern); adopter apps run it via the documented
  `Application.app_dir(:rindle, "priv/repo/migrations")` flow already taught
  in `guides/getting_started.md`. Migration is idempotent and additive
  (memo §1 in-scope #5).
- **D-12:** `Rindle.Domain.MediaProviderAsset` lives at
  `lib/rindle/domain/media_provider_asset.ex` (mirrors `media_asset.ex`).
  Schema includes a `changeset/2` constructor and a state-typed read; FSM
  lives in a sibling `Rindle.Domain.ProviderAssetFSM` at
  `lib/rindle/domain/provider_asset_fsm.ex` mirroring
  `Rindle.Domain.AssetFSM` exactly (`@allowed_transitions` map, `transition/3`
  emitting `[:rindle, :provider_asset, :state_change]` telemetry, allowlist
  enforcement returning `{:error, {:invalid_transition, from, to}}`).
- **D-13:** Locked FSM transitions (memo §2 STREAM-04, §6, §7):
  ```
  pending    → uploading
  uploading  → processing | errored
  processing → ready | errored
  ready      → errored | deleted
  errored    → deleted | processing  # re-ingest path
  deleted    → []
  ```
  `errored → processing` is the re-ingest re-entry edge consumed by Phase
  34's `MuxIngestVariant` retry path; locked here so Phase 34's worker can
  rely on it.
- **D-14:** Custom `Inspect` impl on `Rindle.Domain.MediaProviderAsset`
  redacts `provider_asset_id` to last-4-char tag (`"...abcd"`) per security
  invariant 14 (memo §9 row 14). `raw_provider_metadata` is kept opaque (the
  Inspect impl truncates to `%{...redacted...}`). This freezes invariant 14
  at the schema layer so telemetry / logs / `inspect/2` output never leak
  raw provider IDs.

### Profile DSL (STREAM-05)

- **D-15:** Add `:streaming` key to the `Rindle.Profile` `delivery:` map.
  Validated through NimbleOptions with locked schema (memo §5.2):
  - `:provider` — module implementing `Rindle.Streaming.Provider`, required
  - `:playback_policy` — `:signed | :public`, required, named only
  - `:ingest_mode` — `:server_push | :direct_creator_upload`, required,
    named only
  - `:source_variant` — atom naming a variant in the same profile, required
- **D-16:** Forbid raw provider knobs. NimbleOptions schema rejects any key
  not in the locked set (no `:max_resolution_tier`, no `:input` shape, no
  `:mp4_support`, no `:passthrough`). Raw-knob escape hatch is "write a
  custom processor" (memo §5.2).
- **D-17:** Image-only and AV-only profiles compile and exercise the v1.4
  lifecycle byte-for-byte (memo §2 phase-33 success criterion). NimbleOptions
  treats `:streaming` as fully optional; absence keeps current delivery
  behavior.
- **D-18:** `:streaming.source_variant` validation only checks the atom is
  declared in `variants/0`. Per-variant `kind: :video | :audio` enforcement
  (e.g. "source_variant must be `kind: :video`") is **deferred to Phase 34** —
  the contract holds the shape; Mux-specific validation lives where Mux is
  imported.

### Dispatch Rule (STREAM-06)

- **D-19:** Replace the v1.4 no-op delegate at `lib/rindle/delivery.ex:160`
  with the deterministic decision tree from memo §5.1, applied verbatim:
  ```
  streaming_url(profile, asset_or_key, opts):
    1. profile streaming nil          → existing v1.4 progressive path
    2. streaming configured + binary key → {:error,
                                            :streaming_provider_requires_asset_struct}
    3. media_provider_assets row in
       (:processing, :uploading, :pending) → {:error, :provider_asset_not_ready}
    4. row in :errored                → {:error, :provider_sync_failed}
    5. row in :ready                  → provider.signed_playback_url(profile,
                                          playback_id, opts)
    6. no row                         → progressive fallback (existing path);
                                          emits [:rindle, :delivery, :streaming,
                                          :resolved] kind: :progressive
  ```
- **D-20:** `opts[:strict]` (default `false`) converts step 6 into
  `{:error, :provider_asset_not_ready}`. Default is non-strict because mixed
  legacy assets need gradual migration (memo §5.1, §8.1 rule 2). This is the
  one adopter-facing default that's hard to flip later; the memo's reasoning
  (migration friendliness; first-adopter cohort is greenfield anyway) is
  accepted.
- **D-21:** Provider lookup for steps 3-5 is a single `Repo.get_by/2` keyed by
  `(asset_id, profile, provider_name)` — uses the unique index from D-10.
  No N+1 risk.
- **D-22:** The lookup uses `provider_name` derived from
  `profile.delivery_policy().streaming.provider |> Module.split() |>
  List.last() |> Macro.underscore()` (e.g. `Rindle.Streaming.Provider.Mux` →
  `"mux"`). Stored as opaque string in the row; never rendered to public
  paths.
- **D-23:** Step 5's `provider.signed_playback_url/3` call returns the
  `{:ok, %{url, kind: :hls, mime}}` shape; `Rindle.Delivery.streaming_url/3`
  passes that through unchanged so the v1.4 return contract
  (`{:ok, %{url, kind, mime}}`) is preserved. No caller changes.
- **D-24:** Step 6's progressive fallback emits the existing v1.4
  `[:rindle, :delivery, :streaming, :resolved]` event with `kind:
  :progressive` — preserved verbatim. When Phase 34 lights up the provider
  path (step 5), the same event fires with `kind: :hls`. This is the **single
  documented v1.4-contract extension** in v1.6 (memo §8.4 final paragraph);
  consumers asserting `kind == :progressive` are documented to update in the
  v1.6 upgrade notes.

### Error Vocabulary (STREAM-07, STREAM-09)

- **D-25:** Extend `Rindle.Error` with five additive locked atoms (memo §8.2;
  REQUIREMENTS STREAM-07):
  - `:provider_asset_not_ready`
  - `:provider_webhook_invalid`
  - `:provider_sync_failed`
  - `:provider_quota_exceeded`
  - `:streaming_provider_requires_asset_struct`
- **D-26:** Reuse the v1.4 `:streaming_not_configured` atom unchanged. No
  rename, no expansion, no semver shift.
- **D-27:** Each new atom gets a `def message(%{reason: <atom>}) do ... end`
  clause in `lib/rindle/error.ex` with operator-actionable copy following the
  existing AV-04/AV-05 message style (cause → action). Map-keyed variants
  (e.g. `{:provider_quota_exceeded, %{provider: ..., retry_after: ...}}`) are
  **not** added in Phase 33 — the bare-atom form is the locked public surface
  for v1.6; richer maps can extend additively later if Phase 34/35 prove a
  need.
- **D-28:** `STREAM-09` parity gate: a new ExUnit test asserts the exact
  reason atom and the exact message text for all five new variants, mirroring
  the AV-06-05 freeze pattern. Test lives at
  `test/rindle/error_streaming_freeze_test.exs` (mirrors AV-06's
  `test/rindle/error_av_freeze_test.exs` if present, otherwise a fresh
  parity-style test using the `Rindle.Error.message/1` API).

### Capability Report Extension (STREAM-08)

- **D-29:** Ship a new `Rindle.Capability` module at
  `lib/rindle/capability.ex` with `report/0` returning a structured map that
  aggregates storage, processor, and streaming capability surfaces. Today the
  doctor task at `lib/mix/tasks/rindle.doctor.ex` builds its own report shape
  inline (`emit_report/2`); `Rindle.Capability.report/0` becomes the
  canonical aggregator that doctor *and* `mix rindle.runtime_status` can
  consume.
- **D-30:** `Rindle.Capability.report/0` shape (locked):
  ```elixir
  %{
    storage: %{<adapter> => [capability_atom, ...]},
    processor: %{<adapter> => [capability_atom, ...]},
    streaming: %{
      providers: %{<provider_module> => [capability_atom, ...]},
      signed_playback_configured?: boolean(),
      configured_profiles: [profile_module]
    }
  }
  ```
  `signed_playback_configured?` is a presence check on the
  `Rindle.Streaming.Provider.Mux` config keys (memo §8.3) — `true` only if
  `signing_key_id` AND `signing_private_key` are both set. The check
  references the config keys but does **not** require Mux to be loaded; if
  the optional `:mux` dep is not loaded the field is `false` with no crash.
- **D-31:** `mix rindle.doctor` is **not** rewritten to consume this in
  Phase 33 — that's a Phase 36 lift (REQ MUX-16 ships streaming-config
  validation through doctor). Phase 33 ships the report aggregator; doctor
  refactor is a Phase 36 follow-on that has no adopter-visible bearing on
  Phase 33's success criterion.

### Decision-Making Preference

- **D-32:** Reinforce the standing project preference from `.planning/STATE.md`
  and the v1.5 / v1.4 CONTEXT.md continuum: downstream researchers, planners,
  and executors decide by default and present one coherent recommendation
  set. Escalate only for genuinely high-blast-radius decisions
  (semver-significant public API reshapes, destructive or irreversible
  operations, security/compliance boundary changes).

### the agent's Discretion

The candidate memo locks the contract surface; the items below are
implementation choices the planner / executor should make autonomously
without asking the user, so long as the locked contract is preserved.

- Exact NimbleOptions schema layout for the `:streaming` key (so long as
  D-15..D-18 invariants hold)
- Whether `Rindle.Domain.ProviderAssetFSM` lives in its own file or as a
  namespaced sub-module of `Rindle.Domain.MediaProviderAsset`, mirroring
  whichever local convention the planner picks per `AssetFSM` analogy
- Exact constructor/changeset signature for `MediaProviderAsset` (keep the
  `cast`/`validate_required`/`unique_constraint` pattern from `MediaAsset`)
- Whether `Rindle.Capability.report/0` is exposed via a new module or a
  function in an existing module, so long as the public symbol is
  `Rindle.Capability.report/0` per REQUIREMENTS STREAM-08
- Exact wording of the five new `Rindle.Error.message/1` clauses (keep the
  AV-04/AV-05 cause→action style; STREAM-09 freezes the wording at ship)
- Test file organization for STREAM-09 parity, FSM transition coverage,
  dispatch-rule decision-tree coverage (one file per concern is fine; a
  single `test/rindle/streaming/` subtree mirroring `lib/rindle/streaming/`
  is also fine)
- Choice of doctest vs unit test for the message-text freeze, so long as
  exact text is asserted somewhere
- Migration filename timestamp and exact module name (Ecto convention)
- Whether `Rindle.Streaming.Capabilities.known/0` returns the list ordered
  the same as memo §2 STREAM-01 or alphabetized (purely cosmetic)
- Inspect-impl truncation length for `last_sync_error` in the schema struct
  (default to no extra truncation — the DB column is already truncated to
  4096)

</decisions>

<specifics>
## Specific Ideas

- The single most important Phase 33 invariant: **no Mux code lands**. The
  five new `Rindle.Error` atoms and the new behaviour callbacks must hold
  their shape across all of v1.6 — STREAM-09's parity gate is the freeze
  point (mirrors AV-06-05).
- The current `Rindle.Streaming.Provider` 2-callback shim is documented as
  "reserved" with no shipped impls; its replacement with the 6-required +
  1-optional callback set is a clean redesign, not a breaking change.
- The current `lib/rindle/delivery.ex:160` `streaming_url/3` no-op delegate
  is the conversion point — Phase 33 replaces its body with the dispatch
  rule from D-19 while keeping the public arity / return shape identical
  for adopters not yet using `:streaming`.
- The `:streaming.source_variant` shape mirrors the `from:` key already
  used in `Rindle.Profile` for cross-variant derivatives (poster from
  `:web`, waveform from `:audio`), so adopters learn one referencing model
  rather than two.
- `Rindle.Domain.ProviderAssetFSM` should ape `Rindle.Domain.AssetFSM`
  byte-for-byte in shape: `@allowed_transitions` map, `transition/3` with
  `:telemetry.execute` emit, `{:error, {:invalid_transition, from, to}}`
  on disallowed edges.
- The custom `Inspect` impl on `MediaProviderAsset` (D-14) is the
  schema-level enforcement of the new security invariant 14 (Phase 33
  promotes invariant 14 to PROJECT.md as part of STREAM-01 — it's already
  listed there as added v1.6).
- `Rindle.Capability.report/0` is positioned as the consumer surface for
  Phase 36's `mix rindle.doctor` streaming validation — it's **not**
  consumed by doctor in Phase 33; it just exists with the locked shape so
  Phase 36 doesn't need a contract negotiation.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before
planning or implementing.**

### Source of truth (locked recommendation)
- `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` — the locked
  recommendation memo. Section index: §1 scope; §2 STREAM-01..09 phase-33
  requirements; §4 behaviour with @callback signatures (verbatim); §5.1
  dispatch rule (verbatim); §5.2 profile DSL (verbatim); §6 Ecto migration
  (verbatim); §8.2 error vocabulary (verbatim); §8.4 telemetry; §9 security
  invariants. **This memo is the highest-priority reference; everything
  else is supporting.**

### Phase scope and milestone constraints
- `.planning/ROADMAP.md` — Phase 33 goal, success criteria, and v1.6
  phase summary
- `.planning/REQUIREMENTS.md` — STREAM-01..09 (lines 17-52)
- `.planning/PROJECT.md` — current milestone posture, adopter-first runtime
  ownership, and 14 numbered security invariants (invariant 14 added v1.6
  is the security-invariant Phase 33 must encode)
- `.planning/STATE.md` — current project status, Decision-Making Preference
  (decide-by-default, escalate-only-impactful)

### v1.6 supporting research
- `.planning/research/PROVIDER-ADAPTERS-MILESTONE-MEMO.md` — prior
  2026-05-05 memo superseded by the locked memo above (kept for context;
  do not act on)
- `.planning/research/SUMMARY.md` / `STACK.md` / `ARCHITECTURE.md` /
  `FEATURES.md` / `PITFALLS.md` — milestone-level research context

### Prior phase decisions Phase 33 must honor
- `.planning/milestones/v1.4-phases/26-delivery-surface/26-CONTEXT.md` —
  v1.4 reservation of `streaming_url/3`, the
  `[:rindle, :delivery, :streaming, :resolved]` telemetry event, and the
  `signed_url_ttl_seconds` profile policy that signed Mux JWTs must respect
- `.planning/milestones/v1.4-phases/24-domain-model-dsl-extension/24-CONTEXT.md` —
  additive Ecto migration posture, schema and FSM patterns Phase 33 mirrors
  for `MediaProviderAsset` / `ProviderAssetFSM`
- `.planning/milestones/v1.4-phases/27-html-helpers-liveview-integration/27-CONTEXT.md` —
  AV error vocabulary freeze pattern (AV-06-05) Phase 33 mirrors for
  STREAM-09
- `.planning/milestones/v1.5-phases/32-upgrade-migration-safety/32-CONTEXT.md` —
  current adopter-owned migration handoff posture (memo §6 is consistent
  with Phase 32's locked posture)

### Existing code seams Phase 33 must extend / replace
- `lib/rindle/streaming/provider.ex` — current 2-callback reserved shim;
  Phase 33 replaces with the 6-required + 1-optional callback set
- `lib/rindle/delivery.ex` (line 160 `streaming_url/3`, line 265
  `:streaming_not_configured` site, line 158 `@spec`) — current no-op
  delegate to be replaced with the dispatch rule (D-19)
- `lib/rindle/error.ex` (line 195 `:streaming_not_configured` clause) —
  pattern to mirror for the five new atoms (STREAM-07)
- `lib/rindle/storage/capabilities.ex` — the canonical pattern
  `Rindle.Streaming.Capabilities` mirrors (`@known`, `known/0`, `safe/1`)
- `lib/rindle/profile.ex` — DSL extension target for the `:streaming` key
- `lib/rindle/domain/media_asset.ex` — schema pattern
  `Rindle.Domain.MediaProviderAsset` mirrors
- `lib/rindle/domain/asset_fsm.ex` — FSM pattern
  `Rindle.Domain.ProviderAssetFSM` mirrors verbatim (`@allowed_transitions`
  map, `transition/3`, telemetry emit, allowlist enforcement)
- `lib/rindle/processor.ex` and `lib/rindle/processor/av/` — behaviour
  shape Phase 33 follows (`@callback` discipline; `:ok` / `:error` tuple
  returns; no exceptions on happy path)
- `lib/mix/tasks/rindle.doctor.ex` — current report-emit machinery that
  Phase 36 will refactor onto `Rindle.Capability.report/0` (Phase 33
  ships the aggregator only)

### Migration-related references
- `priv/repo/migrations/` — additive migration target directory; mirror
  the v1.4 AV migration posture
- `guides/getting_started.md` — adopter-facing migration handoff doc that
  references `Application.app_dir(:rindle, "priv/repo/migrations")`; Phase
  33 must keep this contract intact

### Ecosystem references that informed locked decisions
- `https://hexdocs.pm/oban/Oban.html` — `unique` constraint shape Phase 34
  workers will rely on (Phase 33 only needs to leave the row shape clean
  enough for Phase 34's idempotency keys to land)
- `https://hexdocs.pm/ecto/Ecto.Migration.html` — additive-migration
  semantics the new table follows
- `https://hexdocs.pm/nimble_options/NimbleOptions.html` — DSL validation
  Phase 33 uses for the `:streaming` key
- Mux Elixir SDK reference (https://github.com/muxinc/mux-elixir,
  https://github.com/muxinc/mux-elixir/blob/master/lib/mux/webhooks.ex,
  https://github.com/muxinc/mux-elixir/blob/master/lib/mux/token.ex) —
  consumed by Phase 34/35; Phase 33 only needs to leave behaviour
  signatures shaped so the SDK plugs in cleanly

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/rindle/storage/capabilities.ex` — exact pattern to mirror for
  `Rindle.Streaming.Capabilities`. Same `@known` list + `known/0` + `safe/1`
  shape; literally a copy with a different vocabulary tuple.
- `lib/rindle/domain/asset_fsm.ex` — exact pattern to mirror for
  `Rindle.Domain.ProviderAssetFSM`. Same `@allowed_transitions` map,
  `transition/3` returning `:ok | {:error, {:invalid_transition, from, to}}`,
  `:telemetry.execute` emit on success.
- `lib/rindle/domain/media_asset.ex` — schema pattern to mirror for
  `Rindle.Domain.MediaProviderAsset` (binary_id, `@states` list, changeset
  with `validate_inclusion(:state, @states)`, `cast`/`validate_required`
  pattern).
- `lib/rindle/error.ex` (line 195 onward) — exact pattern to mirror for the
  five new `def message(%{reason: <atom>})` clauses (cause → action shape).
- `lib/rindle/delivery.ex` (line 158) — `streaming_url/3` `@spec` and
  signature already exist; Phase 33 replaces the body, not the signature.
- `priv/repo/migrations/` — existing v1.4 AV migration is the structural
  template for the new `create_media_provider_assets` migration.

### Established Patterns
- **Adopter-owned migrations:** Rindle ships migration files in
  `priv/repo/migrations`; adopter apps run them via the
  `Application.app_dir(:rindle, "priv/repo/migrations")` flow. Phase 33's
  new migration follows this exactly — no inline runtime migration, no
  hidden migrator.
- **Reserved-then-promoted seams:** Phase 26 reserved `streaming_url/3`,
  Phase 33 promotes it. This is the Rindle convention (mirrors v1.4
  reserved-then-promoted patterns for AV-04 and AV-05 surfaces).
- **Behaviour callbacks return `:ok` / `:error` tuples:** every existing
  `@callback` in `lib/rindle/processor.ex` and `lib/rindle/storage.ex`
  follows this discipline; the new behaviour mirrors it verbatim.
- **`:streaming_not_configured` atom is reused** unchanged from v1.4
  (`lib/rindle/error.ex:195`); the five new atoms are additive only,
  preserving the v1.4 freeze.
- **Capability vocabularies are `@known` + `known/0` + `safe/1`:** see
  `lib/rindle/storage/capabilities.ex`. `Rindle.Streaming.Capabilities`
  follows the exact same module shape.

### Integration Points
- `Rindle.Delivery.streaming_url/3` is the public dispatch entrypoint —
  Phase 33's body change (no-op → decision tree) is the primary
  adopter-visible behavior shift.
- `Rindle.Profile` DSL `:streaming` key is the configuration entrypoint
  per profile.
- `media_provider_assets` table is the durable state surface Phase 34
  reads/writes through.
- `Rindle.Capability.report/0` is the aggregator surface Phase 36
  refactors `mix rindle.doctor` onto.
- The behaviour at `lib/rindle/streaming/provider.ex` is the contract
  surface Phase 34 implements as `Rindle.Streaming.Provider.Mux`.

### Operational Boundaries Phase 33 Must Not Cross
- **No Mux dep, no Mux client code, no Mux env-var reads.** All Mux
  arrives in Phase 34 (`{:mux, "~> 3.2", optional: true}`,
  `{:jose, "~> 1.11", optional: true}`).
- **No webhook plug, no raw-body cache, no signature verification.** All
  arrives in Phase 35.
- **No `Rindle.Profile.Presets.MuxWeb`, no doctor streaming smoke, no
  `guides/streaming_providers.md`.** All arrives in Phase 36.
- **No `create_direct_upload/2` impl** (the callback exists in the
  behaviour as `@optional_callbacks`, but no concrete implementation
  ships).
- **Existing `Rindle.Processor.AV` is not touched.** Mux is additive; the
  FFmpeg-driven progressive path is preserved as the safety-net fallback
  (dispatch rule step 6).

</code_context>

<deferred>
## Deferred Ideas

- Map-keyed error variants (e.g.
  `{:provider_quota_exceeded, %{provider, retry_after}}`) — Phase 33 ships
  bare-atom forms; richer variants can extend additively in v1.7+ if real
  adopter feedback proves a need
- Per-variant `kind: :video | :audio` enforcement on
  `:streaming.source_variant` — deferred to Phase 34 where Mux-specific
  validation lands
- `Rindle.Streaming.Capabilities.require_streaming/2` capability gate —
  Phase 37 / REQ MUX-22
- `Rindle.Capability.report/0` consumption inside `mix rindle.doctor` —
  Phase 36 / REQ MUX-16 (Phase 33 ships the aggregator; doctor refactor is
  a Phase 36 follow-on)
- Configurable telemetry redaction config (Phase 33 hardcodes last-4-char
  redaction in the schema's Inspect impl) — explicitly deferred to v1.7+
  per memo §13
- Webhook event replay tooling (`mix rindle.webhook.replay`) — explicitly
  deferred to v1.7+ per memo §13
- `cancel_provider_ingest/1` cancellation surface — explicitly deferred to
  v1.7+ per memo §13
- DASH support (`kind: :dash`) — explicitly deferred to v1.7+ per memo §4

</deferred>

---

*Phase: 33-provider-boundary-state-schema*
*Context gathered: 2026-05-06*
*Source of truth: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md`*
