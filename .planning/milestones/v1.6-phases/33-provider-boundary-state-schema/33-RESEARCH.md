# Phase 33: Provider Boundary + State Schema — Research

**Researched:** 2026-05-06
**Domain:** Elixir / Phoenix / Ecto contract surface — promote a reserved
behaviour to a runtime contract, ship an additive Ecto table + FSM, extend
profile DSL via NimbleOptions, replace a no-op delivery delegate with a
deterministic dispatch tree, freeze five new error atoms, and ship a new
capability aggregator. **No external dependencies added.**
**Confidence:** HIGH (every load-bearing pattern is mirrored from existing
v1.4 code; all locked decisions traced to file paths and line numbers in
this repo)

---

## Summary

Phase 33 is almost entirely a **mirror-and-extend** exercise. Every load-bearing
piece has an existing analog in the codebase that the planner can copy
shape-for-shape:

| Phase 33 deliverable | Mirror-from in repo |
|---|---|
| `Rindle.Streaming.Capabilities` | `lib/rindle/storage/capabilities.ex:1-67` (mirror exact `@known` + `known/0` + `safe/1` + `supports?/2` shape; D-03 says **omit** `require_streaming/2` — that lives in Phase 37) |
| `Rindle.Streaming.Provider` (promoted) | `lib/rindle/streaming/provider.ex:1-14` (current 2-callback shim is "reserved with no shipped impls" per CONTEXT D-08; clean redesign, no semver bump) |
| `Rindle.Domain.MediaProviderAsset` schema + changeset | `lib/rindle/domain/media_asset.ex:1-139` (`@states` list, `@primary_key {:id, :binary_id, autogenerate: true}`, `@foreign_key_type :binary_id`, `cast` + `validate_required` + `validate_inclusion(:state, @states)` + `unique_constraint`) |
| `Rindle.Domain.ProviderAssetFSM` | `lib/rindle/domain/asset_fsm.ex:1-77` (`@allowed_transitions` map, `transition/3` returning `:ok \| {:error, {:invalid_transition, from, to}}`, `:telemetry.execute` on the success branch, `Logger.warning` on rejection) |
| `media_provider_assets` migration | `priv/repo/migrations/20260424155129_create_media_assets.exs:1-21` (additive `change/0`, `binary_id` PK, `null: false` on required cols, `index(:state)` and `unique_index` plus partial-where convention) |
| `:streaming` profile DSL key | `lib/rindle/profile/validator.ex:35-48` (`@delivery_schema` is the existing NimbleOptions-validated map under `delivery:`; mirror its `validate_delivery!/1` shape) |
| `Rindle.Delivery.streaming_url/3` (replaced body) | `lib/rindle/delivery.ex:160-192` (current no-op delegate; signature + `@spec` + telemetry emit stay verbatim, body becomes the D-19 decision tree) |
| Five new `Rindle.Error.message/1` clauses | `lib/rindle/error.ex:195-221` (current `:streaming_not_configured` clause is the cause→action shape to mirror) |
| Error parity freeze test | `test/rindle/error_test.exs:1-100` (the `@av_public_reasons` list + `expected_messages = %{...}` + `exact/1` heredoc helper is the AV-06-05 freeze pattern verbatim) |
| `Rindle.Capability.report/0` (new module) | `lib/mix/tasks/rindle.doctor.ex:52-72` + `lib/rindle/ops/runtime_checks.ex:1-66` (current `emit_report/2` and the `report` map shape are the prior art; new module is a thin aggregator over `Capabilities.safe/1` calls) |

**Primary recommendation:** Plan **4 plans** along the locked CONTEXT axes —
(1) Capability vocabulary + Provider behaviour + types, (2) Migration + schema +
FSM + Inspect-redaction, (3) Profile DSL `:streaming` key + dispatch rule
replacement, (4) Error vocabulary + parity gate + `Rindle.Capability.report/0`.
This matches the 4-plan ROADMAP guidance and lines up cleanly with the six
success-criteria axes; cross-plan coupling is minimal because every plan
extends an isolated module.

The dominant risk is **wording-drift in the error parity freeze** (the AV-06-05
lesson: the parity gate test has to assert `String.trim_trailing/1`-normalized
heredocs verbatim). Second-order risk is **DSL shape regret** — once the
`:streaming` map keys ship, downstream MUX-15 (`Rindle.Profile.Presets.MuxWeb`)
and MUX-22 (`require_streaming/2`) build on that exact key list, so getting the
NimbleOptions schema right in Phase 33 is what makes Phases 34-37 a plug-in,
not a refactor.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

All 32 decisions in Phase 33 CONTEXT (D-01..D-32) are locked from the candidate
memo `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md`. The summary below is
verbatim from the CONTEXT decisions block; full rationale lives in the CONTEXT
file.

#### Capability Vocabulary (STREAM-01)
- **D-01:** Ship `Rindle.Streaming.Capabilities` mirroring `Rindle.Storage.Capabilities`: `@known` + `known/0` + `safe/1`.
- **D-02:** Closed vocabulary atoms (locked): `:signed_playback`, `:public_playback`, `:webhook_ingest`, `:server_push_ingest`, `:direct_creator_upload`. Last is *reserved* (no Phase-33 adapter advertises it).
- **D-03:** `require_streaming/2` is **NOT** shipped in Phase 33 (REQ MUX-22, Phase 37).

#### Provider Behaviour (STREAM-02)
- **D-04:** Replace the v1.4 2-callback shim with the locked 6-required + 1-optional callback set (`capabilities/0`, `create_asset/3`, `get_asset/1`, `delete_asset/1`, `signed_playback_url/3`, `verify_webhook/3`, `create_direct_upload/2` — last via `@optional_callbacks`).
- **D-05:** `streaming_url/3` is **NOT** a behaviour callback — lives only on `Rindle.Delivery`.
- **D-06:** Lock public types: `provider_asset_id`, `playback_id`, `provider_state` (`:pending | :uploading | :processing | :ready | :errored | :deleted`), `provider_event` map shape, `capability` atom union.
- **D-07:** Every callback returns `:ok`/`:error` tuple. `verify_webhook/3` returns a normalized `provider_event` map, not a Mux struct.
- **D-08:** Replacing the v1.4 shim is **non-breaking** in adopter terms (no semver bump).

#### State Schema + FSM (STREAM-03, STREAM-04)
- **D-09:** Ship `media_provider_assets` table verbatim from memo §6: `binary_id` PK, FK to `media_assets` with `on_delete: :delete_all`, full column set, `timestamps()`.
- **D-10:** Four indexes verbatim — partial unique on `(provider_name, provider_asset_id)`, unique on `(asset_id, profile, provider_name)`, `[:state]`, `[:state, :updated_at]`.
- **D-11:** Migration generated into `priv/repo/migrations`, idempotent, additive — adopter-owned via `Application.app_dir(:rindle, "priv/repo/migrations")`.
- **D-12:** `Rindle.Domain.MediaProviderAsset` at `lib/rindle/domain/media_provider_asset.ex`. FSM at `lib/rindle/domain/provider_asset_fsm.ex` mirroring `Rindle.Domain.AssetFSM` exactly (`@allowed_transitions`, `transition/3`, telemetry `[:rindle, :provider_asset, :state_change]`, allowlist enforcement).
- **D-13:** Locked transitions: `pending→uploading`; `uploading→processing|errored`; `processing→ready|errored`; `ready→errored|deleted`; `errored→deleted|processing` (re-ingest); `deleted→[]`.
- **D-14:** Custom `Inspect` impl on `MediaProviderAsset` redacts `provider_asset_id` to last-4-char tag (`"...abcd"`); `raw_provider_metadata` opaque (`%{...redacted...}`). Encodes security invariant 14.

#### Profile DSL (STREAM-05)
- **D-15:** Add `:streaming` key to `Rindle.Profile` `delivery:` map. NimbleOptions schema: `:provider` (required module), `:playback_policy` (`:signed | :public`), `:ingest_mode` (`:server_push | :direct_creator_upload`), `:source_variant` (atom).
- **D-16:** Forbid raw provider knobs. Reject any key not in the locked set.
- **D-17:** Image-only and AV-only profiles compile unchanged (`:streaming` is fully optional).
- **D-18:** `source_variant` validation only checks atom is in `variants/0`; per-variant `kind:` enforcement deferred to Phase 34.

#### Dispatch Rule (STREAM-06)
- **D-19:** Replace `lib/rindle/delivery.ex:160` body with locked decision tree (six steps from CONTEXT.md).
- **D-20:** `opts[:strict]` (default `false`) converts step 6 into `{:error, :provider_asset_not_ready}`.
- **D-21:** Provider lookup: single `Repo.get_by/2` keyed by `(asset_id, profile, provider_name)`. No N+1.
- **D-22:** `provider_name` derived from `profile.delivery_policy().streaming.provider |> Module.split() |> List.last() |> Macro.underscore()` (e.g. `Rindle.Streaming.Provider.Mux → "mux"`).
- **D-23:** Step 5 returns `{:ok, %{url, kind: :hls, mime}}` — passes through unchanged. Preserves v1.4 contract `%{url, kind, mime}`.
- **D-24:** Step 6 emits `[:rindle, :delivery, :streaming, :resolved]` with `kind: :progressive` (preserved). When provider path lights up later, same event fires with `kind: :hls`. **Single documented v1.4 contract extension.**

#### Error Vocabulary (STREAM-07, STREAM-09)
- **D-25:** Five additive locked atoms: `:provider_asset_not_ready`, `:provider_webhook_invalid`, `:provider_sync_failed`, `:provider_quota_exceeded`, `:streaming_provider_requires_asset_struct`.
- **D-26:** Reuse v1.4 `:streaming_not_configured` unchanged.
- **D-27:** Each new atom gets a `def message(%{reason: <atom>}) do ... end` clause matching AV-04/AV-05 cause→action style. Map-keyed variants NOT shipped in Phase 33.
- **D-28:** STREAM-09 parity gate at `test/rindle/error_streaming_freeze_test.exs` (mirrors AV-06's pattern in `test/rindle/error_test.exs`).

#### Capability Report (STREAM-08)
- **D-29:** New `Rindle.Capability` module at `lib/rindle/capability.ex` with `report/0` aggregating storage, processor, streaming surfaces.
- **D-30:** Locked `report/0` shape (see CONTEXT). `signed_playback_configured?` is presence check on `Rindle.Streaming.Provider.Mux` config keys (`signing_key_id` AND `signing_private_key`); does NOT require Mux loaded.
- **D-31:** `mix rindle.doctor` is **NOT** rewritten in Phase 33 (Phase 36 lift).

#### Decision-Making Preference
- **D-32:** Decide-by-default; escalate only for high-blast-radius decisions (semver, destructive, security/compliance).

### Claude's Discretion

(Per CONTEXT.md `<decisions>` block, the planner / executor decides
autonomously without asking the user, so long as locked contract is preserved.)

- Exact NimbleOptions schema layout for `:streaming` (D-15..D-18 invariants must hold).
- Whether `ProviderAssetFSM` is its own file or a sub-module of `MediaProviderAsset`.
- Exact constructor/changeset signature for `MediaProviderAsset` (keep `cast`/`validate_required`/`unique_constraint` pattern).
- Whether `Rindle.Capability.report/0` is a new module or a function in an existing module — public symbol is `Rindle.Capability.report/0` per STREAM-08.
- Exact wording of the five new `Rindle.Error.message/1` clauses (cause→action style; STREAM-09 freezes wording at ship).
- Test file organization for STREAM-09, FSM coverage, dispatch-tree coverage (one file per concern OR a `test/rindle/streaming/` subtree both fine).
- Choice of doctest vs unit test for message-text freeze, so long as exact text is asserted.
- Migration filename timestamp and exact module name (Ecto convention).
- Order of `Rindle.Streaming.Capabilities.known/0` (memo order or alphabetized — cosmetic).
- Inspect-impl truncation length for `last_sync_error` (default to no extra truncation; DB column already 4096).

### Deferred Ideas (OUT OF SCOPE for Phase 33)

- Map-keyed error variants (e.g. `{:provider_quota_exceeded, %{provider, retry_after}}`) — additive in v1.7+ if needed.
- Per-variant `kind:` enforcement on `:streaming.source_variant` — Phase 34.
- `Rindle.Streaming.Capabilities.require_streaming/2` — Phase 37 / MUX-22.
- `Rindle.Capability.report/0` consumption inside `mix rindle.doctor` — Phase 36 / MUX-16.
- Configurable telemetry redaction — v1.7+.
- Webhook event replay tooling (`mix rindle.webhook.replay`) — v1.7+.
- `cancel_provider_ingest/1` — v1.7+.
- DASH support (`kind: :dash`) — v1.7+.
- **All Mux code** — Phase 34. Phase 33 ships **zero** Mux callsites.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STREAM-01 | New `Rindle.Streaming.Capabilities` module with closed vocabulary (`:signed_playback`, `:public_playback`, `:webhook_ingest`, `:server_push_ingest`, `:direct_creator_upload`) | Mirror `lib/rindle/storage/capabilities.ex:1-67` exactly. Pattern in §"Code Examples" below. |
| STREAM-02 | Promote `Rindle.Streaming.Provider` from reserved 2-callback shim to runtime contract with locked `@callback` signatures | Memo §4 (CONTEXT canonical refs) gives verbatim signatures. Replace `lib/rindle/streaming/provider.ex:1-14`. |
| STREAM-03 | Additive `media_provider_assets` Ecto table — one row per `(asset, profile, provider)` — no change to `media_assets` / `media_variants` | Pattern: `priv/repo/migrations/20260424155129_create_media_assets.exs`. Memo §6 verbatim columns + indexes (CONTEXT D-09, D-10). |
| STREAM-04 | `Rindle.Domain.MediaProviderAsset` schema + changeset + FSM (`pending → uploading → processing → ready \| errored \| deleted`) | Schema mirrors `lib/rindle/domain/media_asset.ex:1-139`. FSM mirrors `lib/rindle/domain/asset_fsm.ex:1-77`. CONTEXT D-12, D-13, D-14. |
| STREAM-05 | Profile DSL `:streaming` key with `:provider`, `:playback_policy`, `:ingest_mode`, `:source_variant`, NimbleOptions-validated; raw provider knobs forbidden; image-only and AV-only profiles compile unchanged | Pattern: `lib/rindle/profile/validator.ex:35-48` (existing `@delivery_schema`) + `validate_delivery!/1` at line 211. CONTEXT D-15..D-18. |
| STREAM-06 | `Rindle.Delivery.streaming_url/3` dispatches via deterministic decision tree (provider-ready → URL; in-flight → `:provider_asset_not_ready`; errored → `:provider_sync_failed`; no row → progressive fallback or strict-mode error) | Replace body of `lib/rindle/delivery.ex:160-192` with D-19 tree. Telemetry contract preserved (D-24). |
| STREAM-07 | `Rindle.Error` extends with five additive locked atoms; `:streaming_not_configured` reused unchanged | Pattern: `lib/rindle/error.ex:195-221`. Add five new `def message(%{reason: <atom>})` clauses in AV-04/AV-05 cause→action style (CONTEXT D-25, D-27). |
| STREAM-08 | `Rindle.Capability.report/0` lists detected streaming providers and signed-playback configuration status alongside storage/processor capability output | New module at `lib/rindle/capability.ex` per CONTEXT D-29, D-30. Aggregator over `Rindle.Storage.Capabilities.safe/1`, `Rindle.Streaming.Capabilities.safe/1`. |
| STREAM-09 | ExUnit parity gate asserts exact reason atom + message text for the five new error variants | Mirror `test/rindle/error_test.exs:1-100` (AV-06-05 pattern: `@public_reasons` list + `expected_messages = %{...}` map + `exact/1` `String.trim_trailing/1` heredoc helper). New file at `test/rindle/error_streaming_freeze_test.exs` (CONTEXT D-28). |

**STREAM coverage:** 9 / 9 → planner produces 4 plans aligned to the locked
4-plan guidance.

</phase_requirements>

---

## Architectural Responsibility Map

Phase 33 is library-internal — there is no browser/CDN tier in scope. The five
"tiers" in this map are **logical Rindle layers**, not network tiers, and they
match the existing v1.4 architecture exactly.

| Capability | Primary Layer | Secondary Layer | Rationale |
|------------|---------------|-----------------|-----------|
| Capability vocabulary (`Rindle.Streaming.Capabilities`) | Vocabulary module (`lib/rindle/streaming/`) | — | Mirrors `Rindle.Storage.Capabilities` siblinged at `lib/rindle/storage/capabilities.ex`. Pure data. No Repo, no I/O. |
| Provider behaviour contract | Behaviour module (`lib/rindle/streaming/provider.ex`) | — | `@callback` discipline only. Same layer as `Rindle.Storage`, `Rindle.Processor`. No implementation; Mux-side impl is Phase 34. |
| Schema / changeset | Domain (`lib/rindle/domain/`) | Ecto / Repo via callers | Mirrors `Rindle.Domain.MediaAsset` exactly. Schema is data shape; changeset is validation. Ecto handles persistence; the schema does not. |
| FSM | Domain (`lib/rindle/domain/`) | Telemetry | Mirrors `Rindle.Domain.AssetFSM`. Pure transition allowlist + telemetry emit. No I/O, no Repo writes (caller persists). |
| Migration | Adopter-owned migration directory (`priv/repo/migrations/`) | Ecto migrator | Library ships migration file; adopter app calls `mix ecto.migrate` via documented `Application.app_dir/2` flow (`guides/getting_started.md`). |
| Profile DSL `:streaming` key | DSL validation (`lib/rindle/profile/validator.ex`) | NimbleOptions | Compile-time schema validation. Same layer as existing `@delivery_schema`, `@image_variant_schema`. |
| Dispatch tree (`Rindle.Delivery.streaming_url/3`) | Delivery layer (`lib/rindle/delivery.ex`) | Repo (lookup), Provider behaviour callback (step 5) | Body change only; signature and telemetry preserved. Layer ownership unchanged from v1.4. |
| Error vocabulary | Error module (`lib/rindle/error.ex`) | — | Pattern-match dispatch on `%Rindle.Error{reason: ...}`. Same layer as v1.4 atoms; additive only. |
| Capability report aggregator | New `Rindle.Capability` (`lib/rindle/capability.ex`) | `Rindle.Storage.Capabilities`, `Rindle.Streaming.Capabilities`, `Rindle.AV.Capability`, `Application.get_env/2` | Read-only aggregator. No Repo, no I/O. Phase 36's doctor consumes; Phase 33 just exposes the function. |

**Tier-misassignment risks specific to Phase 33:**
- Putting Repo lookups inside `Rindle.Streaming.Provider` callbacks — those are adapter responsibilities; the behaviour module declares `@callback` only.
- Letting the FSM perform Repo writes — `transition/3` returns `:ok | {:error, ...}`; **the caller** owns the changeset apply / `Repo.update` step (mirrors how `Rindle.Domain.AssetFSM` is used today).
- Putting dispatch logic inside `Rindle.Streaming.Provider.Mux` — that's Phase 34. Phase 33's dispatch lives **only** on `Rindle.Delivery` (D-05).
- Adding any Mux-shaped configuration check directly into `Rindle.Capability.report/0` body in a way that requires `Rindle.Streaming.Provider.Mux` to be loaded — D-30 explicitly requires that the function does not crash when the optional `:mux` dep is not loaded. Use `Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])`-style presence-only checks.

---

## Standard Stack

### Core (no new external dependencies — Phase 33 is contract-only)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `:nimble_options` | `~> 1.1` (already pinned in `mix.exs:68`) | NimbleOptions-validated `:streaming` key in profile DSL [VERIFIED: `mix.exs:68`] | Already used for `@delivery_schema`, `@image_variant_schema`, `@video_variant_schema` — pattern locked in `lib/rindle/profile/validator.ex` |
| `:ecto_sql` | `~> 3.11` (already pinned in `mix.exs:53`) | Migration + schema for `media_provider_assets` [VERIFIED: `mix.exs:53`] | Existing migration pattern at `priv/repo/migrations/20260424155129_create_media_assets.exs` |
| `:telemetry` | `~> 1.2` (already pinned in `mix.exs:81`) | `[:rindle, :provider_asset, :state_change]` emit on FSM transition; `[:rindle, :delivery, :streaming, :resolved]` preserved in dispatch tree [VERIFIED: `mix.exs:81`] | Existing pattern in `lib/rindle/domain/asset_fsm.ex:39-48` |

### Supporting (zero new dependencies)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Built-in `Module.split/1` + `Macro.underscore/1` | OTP/Elixir built-in | Derive `provider_name` string from provider module per D-22 (e.g., `Rindle.Streaming.Provider.Mux → "mux"`) | Inside `Rindle.Delivery.streaming_url/3` body; never exposed to public paths |
| Built-in `defimpl Inspect` | OTP/Elixir built-in | Custom `Inspect` impl on `Rindle.Domain.MediaProviderAsset` redacting `provider_asset_id` to `"...abcd"` per D-14 / security invariant 14 | Schema-level redaction; ensures invariant 14 holds at telemetry / log / `inspect/2` boundary without an opt-in |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Co-locating `ProviderAssetFSM` in the same file as `MediaProviderAsset` | Sibling-file module at `lib/rindle/domain/provider_asset_fsm.ex` | **CONTEXT D-12 explicitly leaves this to executor discretion**; the existing convention is sibling files (`media_asset.ex` ↔ `asset_fsm.ex`). Recommend mirroring convention: separate files. |
| Hand-rolled DSL validation for `:streaming` | NimbleOptions schema with `validate!/2` | Already the established pattern across `Rindle.Profile.Validator` (4 schemas). Hand-rolling would create vocabulary drift. **Use NimbleOptions.** |
| Storing `provider_state` as Ecto-typed enum (`Ecto.Enum`) | Plain `:string` with `validate_inclusion/3` | `MediaAsset` uses plain `:string` + `validate_inclusion(:state, @states)`; consistency wins. Plain string also keeps the schema FSM-coupled rather than enum-coupled. **Use plain `:string`.** |
| Adding a Mux-shaped key check inside `Rindle.Capability.report/0` that uses `Code.ensure_loaded?/1` on the Mux dep | `Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])` presence check | D-30 requires the function not crash when `:mux` dep is missing. `Application.get_env` returns `[]` when nothing configured — never raises. **Use `Application.get_env`.** |

**Installation:** Phase 33 adds **zero** new external dependencies. No
`mix.exs` edits. (`{:mux, "~> 3.2", optional: true}` and
`{:jose, "~> 1.11", optional: true}` arrive in Phase 34 per memo §3 / MUX-01.)
[VERIFIED: CONTEXT.md `<code_context>` "Operational Boundaries Phase 33 Must Not
Cross" — "No Mux dep, no Mux client code, no Mux env-var reads"]

**Version verification:** All three core deps (`nimble_options`, `ecto_sql`,
`telemetry`) are already pinned and stable in `mix.exs`. No `npm view` /
`hex.pm` lookups needed because nothing new is being added.

---

## Architecture Patterns

### System Architecture Diagram

Phase 33 introduces no new runtime data flow — it ships **contract surfaces**
that Phases 34-37 wire to runtime. The diagram below shows the seam shape that
exists *after* Phase 33 ships, with Phase 34+ runtime arrows shown dashed for
context (those are NOT in Phase 33 scope).

```
                   ┌─────────────────────────────────────────────────────┐
                   │ Adopter App (compile-time)                          │
                   │                                                     │
                   │   use Rindle.Profile,                               │
                   │     storage: Rindle.Storage.S3,                     │
                   │     delivery: %{                                    │
                   │       streaming: %{   ← STREAM-05 :streaming key    │
                   │         provider: ...,                              │
                   │         playback_policy: :signed,                   │
                   │         ingest_mode: :server_push,                  │
                   │         source_variant: :web                        │
                   │       }                                             │
                   │     },                                              │
                   │     variants: %{web: %{kind: :video, ...}}          │
                   └────────────────┬────────────────────────────────────┘
                                    │ compile-time validate
                                    ▼
                   ┌─────────────────────────────────────────────────────┐
                   │ Rindle.Profile.Validator                            │
                   │  • @delivery_schema + new @streaming_schema         │
                   │  • NimbleOptions.validate! — refuses raw knobs      │
                   │  • source_variant atom must exist in variants/0     │
                   └─────────────────────────────────────────────────────┘

                                    Adopter calls

                   ┌─────────────────────────────────────────────────────┐
                   │ Rindle.Delivery.streaming_url/3   ← STREAM-06       │
                   │                                                     │
                   │  1. profile.streaming nil?  → existing v1.4 path    │
                   │  2. binary key + streaming? → :streaming_provider_  │
                   │                                requires_asset_struct│
                   │  3. row in (pending|uploading|processing)?          │
                   │                              → :provider_asset_not_ │
                   │                                 ready               │
                   │  4. row in :errored?       → :provider_sync_failed  │
                   │  5. row in :ready?         → provider.signed_       │
                   │                                playback_url/3       │
                   │                                (Phase 34 wires Mux) │
                   │  6. no row?               → progressive fallback OR │
                   │                              :provider_asset_not_   │
                   │                              ready (if :strict)     │
                   │                                                     │
                   │  Telemetry preserved: [:rindle, :delivery,          │
                   │  :streaming, :resolved] with kind: :progressive     │
                   │  (kind: :hls light up in Phase 34)                  │
                   └────────────────┬────────────────────────────────────┘
                                    │ Repo.get_by/2 (asset_id, profile,
                                    │                provider_name)
                                    ▼
                   ┌─────────────────────────────────────────────────────┐
                   │ media_provider_assets (Ecto table)  ← STREAM-03      │
                   │  • binary_id PK                                     │
                   │  • FK to media_assets (on_delete: :delete_all)      │
                   │  • state column drives FSM                          │
                   │  • Inspect impl redacts provider_asset_id (D-14)    │
                   │                                                     │
                   │ Rindle.Domain.MediaProviderAsset (schema)           │
                   │ Rindle.Domain.ProviderAssetFSM (transition allowlist)│
                   │   • [:rindle, :provider_asset, :state_change]       │
                   │     telemetry emitted on every transition           │
                   └─────────────────────────────────────────────────────┘

   - - - - - - - - PHASE 34+ runtime (NOT in Phase 33) - - - - - - - - -

                   ┌─────────────────────────────────────────────────────┐
                   │ Rindle.Streaming.Provider behaviour ← STREAM-02      │
                   │   (callbacks defined; impl Phase 34)                │
                   │                                                     │
                   │  • capabilities/0                                   │
                   │  • create_asset/3       ◀-- Phase 34 MuxIngest      │
                   │  • get_asset/1                                      │
                   │  • delete_asset/1                                   │
                   │  • signed_playback_url/3 ◀-- Phase 34/Delivery step5│
                   │  • verify_webhook/3      ◀-- Phase 35 WebhookPlug   │
                   │  • create_direct_upload/2 (optional, Phase 37)      │
                   └─────────────────────────────────────────────────────┘

                   ┌─────────────────────────────────────────────────────┐
                   │ Rindle.Capability.report/0 ← STREAM-08               │
                   │   %{                                                │
                   │     storage: %{<adapter> => [...caps]},             │
                   │     processor: %{<adapter> => [...caps]},           │
                   │     streaming: %{                                   │
                   │       providers: %{<provider_module> => [...caps]}, │
                   │       signed_playback_configured?: boolean(),       │
                   │       configured_profiles: [profile_module]         │
                   │     }                                               │
                   │   }                                                 │
                   │                                                     │
                   │ Phase 36's mix rindle.doctor will consume — Phase 33│
                   │ ships the aggregator only.                          │
                   └─────────────────────────────────────────────────────┘

                   ┌─────────────────────────────────────────────────────┐
                   │ Rindle.Streaming.Capabilities ← STREAM-01            │
                   │  @known: [:signed_playback, :public_playback,       │
                   │   :webhook_ingest, :server_push_ingest,             │
                   │   :direct_creator_upload]                           │
                   │                                                     │
                   │  Mirrors lib/rindle/storage/capabilities.ex EXACTLY │
                   │  EXCEPT: NO require_streaming/2 (deferred — D-03)   │
                   └─────────────────────────────────────────────────────┘

                   ┌─────────────────────────────────────────────────────┐
                   │ Rindle.Error vocabulary additions ← STREAM-07        │
                   │  Five additive atoms (locked in STREAM-09 freeze):  │
                   │    :provider_asset_not_ready                        │
                   │    :provider_webhook_invalid                        │
                   │    :provider_sync_failed                            │
                   │    :provider_quota_exceeded                         │
                   │    :streaming_provider_requires_asset_struct        │
                   │  Plus reused v1.4 :streaming_not_configured         │
                   └─────────────────────────────────────────────────────┘
```

A reader can trace the primary use case (adopter calls `streaming_url/3`) by
following arrows from the top "Adopter calls" arrow through the dispatch tree
into either the Repo lookup branch (steps 3-5) or the progressive fallback
branch (step 6). The Phase 34+ runtime arrows are the inputs that, once Phase
34 ships, will drive `media_provider_assets` rows from `:pending → :ready` so
step 5 can resolve.

### Recommended Project Structure (additive — preserves all existing files)

```
lib/rindle/
├── capability.ex                    # NEW (STREAM-08): Rindle.Capability.report/0 aggregator
├── delivery.ex                      # MODIFIED: streaming_url/3 body replaced (STREAM-06)
├── error.ex                         # MODIFIED: 5 new message/1 clauses appended (STREAM-07)
├── domain/
│   ├── media_provider_asset.ex      # NEW (STREAM-04): schema + changeset + Inspect impl
│   └── provider_asset_fsm.ex        # NEW (STREAM-04): FSM mirroring asset_fsm.ex
├── profile/
│   └── validator.ex                 # MODIFIED: add :streaming key to @delivery_schema (STREAM-05)
└── streaming/
    ├── capabilities.ex              # NEW (STREAM-01): mirrors storage/capabilities.ex
    └── provider.ex                  # MODIFIED: replace 2-callback shim with locked 6+1 set (STREAM-02)

priv/repo/migrations/
└── YYYYMMDDhhmmss_create_media_provider_assets.exs   # NEW (STREAM-03): additive, idempotent

test/rindle/
├── error_streaming_freeze_test.exs  # NEW (STREAM-09): mirror error_test.exs AV-06-05 pattern
├── capability_test.exs              # NEW (STREAM-08): report/0 shape test
├── delivery_test.exs                # MODIFIED: extend with dispatch-tree decision-cases (STREAM-06)
├── profile/
│   └── validator_test.exs           # MODIFIED: extend with :streaming key validation (STREAM-05)
├── domain/
│   ├── media_provider_asset_test.exs # NEW (STREAM-04): schema + changeset + Inspect impl
│   └── provider_asset_fsm_test.exs   # NEW (STREAM-04): FSM transition matrix
└── streaming/
    ├── capabilities_test.exs        # NEW (STREAM-01): @known invariants
    └── provider_test.exs            # NEW (STREAM-02): behaviour @callback / type assertions
```

### Pattern 1: Capability Vocabulary (mirror `Rindle.Storage.Capabilities`)

**What:** Closed atom vocabulary + `safe/1` filter that protects core code from
adapters that advertise unknown atoms.

**When to use:** Every Rindle "capability surface" (storage, streaming, future
processors). Closed vocabulary, `@known`, `known/0`, `safe/1`, `supports?/2`.

**Source:** `lib/rindle/storage/capabilities.ex:1-67`

```elixir
defmodule Rindle.Streaming.Capabilities do
  @moduledoc false

  @typedoc """
  Known streaming capability atoms.

  `:direct_creator_upload` is reserved — Phase 33 ships it in the vocabulary
  but no adapter advertises it until Phase 37 / v1.7.
  """
  @type capability ::
          :signed_playback
          | :public_playback
          | :webhook_ingest
          | :server_push_ingest
          | :direct_creator_upload

  @known [
    :signed_playback,
    :public_playback,
    :webhook_ingest,
    :server_push_ingest,
    :direct_creator_upload
  ]

  @spec known() :: [capability()]
  def known, do: @known

  @spec safe(module()) :: [capability()]
  def safe(adapter) do
    case adapter.capabilities() do
      capabilities when is_list(capabilities) ->
        Enum.filter(capabilities, &(&1 in @known))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  @spec supports?(module(), capability()) :: boolean()
  def supports?(adapter, capability), do: capability in safe(adapter)
end
```

**Note:** D-03 says **omit** `require_streaming/2` (Phase 37 / MUX-22 lift).
The `Rindle.Storage.Capabilities` analog has both `require_upload/2` and
`require_delivery/2`; Phase 33 keeps things minimal — only `known/0`,
`safe/1`, `supports?/2`.

### Pattern 2: FSM Allowlist + Telemetry Emit (mirror `Rindle.Domain.AssetFSM`)

**What:** Pure functional FSM. `@allowed_transitions` map; `transition/3`
returns `:ok` on allowlist hit (with telemetry emit) or
`{:error, {:invalid_transition, from, to}}` on rejection (with structured
`Logger.warning`).

**When to use:** Every Rindle state machine. Pattern is locked across
`AssetFSM`, `VariantFSM`, `UploadSessionFSM`.

**Source:** `lib/rindle/domain/asset_fsm.ex:1-77`

```elixir
defmodule Rindle.Domain.ProviderAssetFSM do
  @moduledoc false

  require Logger

  @allowed_transitions %{
    "pending" => ["uploading"],
    "uploading" => ["processing", "errored"],
    "processing" => ["ready", "errored"],
    "ready" => ["errored", "deleted"],
    "errored" => ["deleted", "processing"],   # re-ingest re-entry edge (D-13)
    "deleted" => []
  }

  @type state :: String.t()
  @type transition_error :: {:error, {:invalid_transition, state(), state()}}

  @spec transition(state(), state(), map()) :: :ok | transition_error()
  def transition(current_state, target_state, context \\ %{}) do
    if target_state in Map.get(@allowed_transitions, current_state, []) do
      :ok
      |> tap(fn _ ->
        :telemetry.execute(
          [:rindle, :provider_asset, :state_change],
          %{system_time: System.system_time()},
          %{
            profile: Map.get(context, :profile, :unknown),
            provider: Map.get(context, :provider, :unknown),
            from: current_state,
            to: target_state
          }
        )
      end)
    else
      log_transition_failure(current_state, target_state, context)
      {:error, {:invalid_transition, current_state, target_state}}
    end
  end

  defp log_transition_failure(current_state, target_state, context) do
    Logger.warning("rindle.provider_asset.transition_failed",
      asset_id: Map.get(context, :asset_id),
      from_state: current_state,
      to_state: target_state,
      reason: %{
        type: :invalid_transition,
        detail: Map.get(context, :reason, :invalid_transition)
      }
    )
  end
end
```

### Pattern 3: NimbleOptions Schema with `validate!/2` (mirror `Rindle.Profile.Validator`)

**What:** Compile-time validated map under `delivery:`, with explicit allowlist
that rejects unknown keys.

**When to use:** Every Rindle DSL extension that takes adopter-supplied keys.

**Source:** `lib/rindle/profile/validator.ex:35-48` (`@delivery_schema`) +
`lib/rindle/profile/validator.ex:211-232` (`validate_delivery!/1`)

The pattern recommended for STREAM-05 — extend `@delivery_schema` to carry an
optional `:streaming` keyword-list field whose own schema rejects unknown keys:

```elixir
@streaming_schema [
  provider: [
    type: :atom,
    required: true,
    doc: "Module implementing Rindle.Streaming.Provider."
  ],
  playback_policy: [
    type: {:in, [:signed, :public]},
    required: true,
    doc: "Named-preset playback policy. Raw provider knobs forbidden."
  ],
  ingest_mode: [
    type: {:in, [:server_push, :direct_creator_upload]},
    required: true,
    doc: "Named-preset ingest mode. Direct-creator-upload reserved for Phase 37."
  ],
  source_variant: [
    type: :atom,
    required: true,
    doc: "Variant atom from variants/0 that feeds the provider."
  ]
]

@delivery_schema [
  public: [type: :boolean, default: false],
  signed_url_ttl_seconds: [type: {:or, [:pos_integer, nil]}, default: nil],
  authorizer: [type: {:or, [:atom, nil]}, default: nil],
  # NEW (STREAM-05 / D-15..D-18):
  streaming: [
    type: {:or, [{:keyword_list, @streaming_schema}, :map, nil]},
    default: nil,
    doc: "Optional provider-aware streaming configuration."
  ]
]
```

NimbleOptions raises on unknown keys by default — this is the
"raw-provider-knob refusal" mechanism per D-16. The validator has to
normalize map → keyword list (mirror `normalize_delivery_opts!/1` at line
234) before calling `NimbleOptions.validate!/2`.

**`source_variant` cross-reference (D-18):** Per D-18, Phase 33 only checks
that the atom is declared in `variants/0`; it does NOT enforce
`kind: :video | :audio`. That cross-check happens at `validate!/1` time
(see `lib/rindle/profile/validator.ex:168-189`). The variant existence
check fires AFTER variant validation completes, so the validator already
has the canonical variant key list.

### Pattern 4: Schema with `validate_inclusion/3` for State (mirror `Rindle.Domain.MediaAsset`)

**What:** Plain `:string` state column + `@states` list + `validate_inclusion/3`
in changeset. Schema does **not** apply the FSM transition; the caller does
(typical pattern: `FSM.transition/3` returns `:ok` → caller builds changeset
and calls `Repo.update/1`).

**When to use:** Every Rindle Ecto schema with a state machine. Locked across
`MediaAsset`, `MediaVariant`, `MediaUploadSession`.

**Source:** `lib/rindle/domain/media_asset.ex:31-115`

Recommended skeleton for `Rindle.Domain.MediaProviderAsset`:

```elixir
defmodule Rindle.Domain.MediaProviderAsset do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states ~w(pending uploading processing ready errored deleted)

  schema "media_provider_assets" do
    field :profile, :string
    field :provider_name, :string
    field :provider_asset_id, :string
    field :playback_ids, {:array, :string}, default: []
    field :playback_policy, :string
    field :ingest_mode, :string
    field :state, :string, default: "pending"
    field :last_event_id, :string
    field :last_event_at, :utc_datetime_usec
    field :last_sync_error, :string
    field :raw_provider_metadata, :map, default: %{}

    belongs_to :asset, Rindle.Domain.MediaAsset, foreign_key: :asset_id

    timestamps()
  end

  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(provider_asset, attrs) do
    provider_asset
    |> cast(attrs, [
      :asset_id, :profile, :provider_name, :provider_asset_id,
      :playback_ids, :playback_policy, :ingest_mode, :state,
      :last_event_id, :last_event_at, :last_sync_error,
      :raw_provider_metadata
    ])
    |> validate_required([:asset_id, :profile, :provider_name,
                          :playback_policy, :ingest_mode, :state])
    |> validate_inclusion(:state, @states)
    |> validate_inclusion(:playback_policy, ~w(signed public))
    |> validate_inclusion(:ingest_mode, ~w(server_push direct_creator_upload))
    |> unique_constraint([:asset_id, :profile, :provider_name],
         name: :media_provider_assets_asset_id_profile_provider_name_index)
    |> unique_constraint([:provider_name, :provider_asset_id],
         name: :media_provider_assets_provider_name_provider_asset_id_index)
  end
end

defimpl Inspect, for: Rindle.Domain.MediaProviderAsset do
  # D-14: redact provider_asset_id to last-4-char tag; redact raw_provider_metadata
  # opaquely. Encodes security invariant 14.

  def inspect(%Rindle.Domain.MediaProviderAsset{} = struct, opts) do
    redacted = %{
      struct
      | provider_asset_id: redact_last4(struct.provider_asset_id),
        raw_provider_metadata: redact_metadata(struct.raw_provider_metadata)
    }

    Inspect.Any.inspect(redacted, opts)
  end

  defp redact_last4(nil), do: nil
  defp redact_last4(id) when is_binary(id) and byte_size(id) <= 4, do: "...#{id}"
  defp redact_last4(id) when is_binary(id),
    do: "..." <> binary_part(id, byte_size(id) - 4, 4)

  defp redact_metadata(metadata) when map_size(metadata) == 0, do: %{}
  defp redact_metadata(_metadata), do: %{redacted: true}
end
```

### Pattern 5: Additive Migration with Partial Indexes (mirror existing migrations)

**What:** Plain `change/0` migration; no `lock_timeout`, no DDL transaction
disabling (matches every migration in the project per the v1.4 AV migration
moduledoc at `priv/repo/migrations/20260502120000_extend_media_for_av.exs:1-11`).

**When to use:** Every additive Rindle migration.

**Source pattern:** `priv/repo/migrations/20260424155129_create_media_assets.exs:1-21`

```elixir
defmodule Rindle.Repo.Migrations.CreateMediaProviderAssets do
  @moduledoc """
  Phase 33 — additive migration for provider-aware streaming state.

  Adopter image-only and AV-only profiles continue to function unchanged
  (D-17). No data backfill required. No changes to media_assets or
  media_variants. Idempotent and additive (D-11).
  """
  use Ecto.Migration

  def change do
    create table(:media_provider_assets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :asset_id,
          references(:media_assets, type: :binary_id, on_delete: :delete_all),
          null: false
      add :profile, :string, null: false
      add :provider_name, :string, null: false
      add :provider_asset_id, :string
      add :playback_ids, {:array, :string}, default: []
      add :playback_policy, :string, null: false
      add :ingest_mode, :string, null: false
      add :state, :string, default: "pending", null: false
      add :last_event_id, :string
      add :last_event_at, :utc_datetime_usec
      add :last_sync_error, :string
      add :raw_provider_metadata, :map, default: %{}
      timestamps()
    end

    # D-10: four indexes verbatim
    create unique_index(
             :media_provider_assets,
             [:provider_name, :provider_asset_id],
             where: "provider_asset_id IS NOT NULL"
           )

    create unique_index(:media_provider_assets, [:asset_id, :profile, :provider_name])
    create index(:media_provider_assets, [:state])
    create index(:media_provider_assets, [:state, :updated_at])
  end
end
```

**Migration filename timestamp:** Pick a timestamp ≥ `20260502120000` (the v1.4
AV migration); recommended format `YYYYMMDDhhmmss` per Ecto convention.
Discretion item per CONTEXT.md.

### Pattern 6: Behaviour Module with `@optional_callbacks` (mirror `Rindle.Storage` / `Rindle.Processor`)

**What:** Behaviour module declares `@callback`s + types; one callback marked
`@optional_callbacks` for `create_direct_upload/2` (D-04).

**Source:** `lib/rindle/storage.ex:1-199` (12 callbacks); `lib/rindle/processor.ex:1-21`
(1 callback; minimal pattern). The new behaviour follows `Rindle.Storage`'s
typing-rich shape but is shorter (6 required + 1 optional).

**Verbatim signatures:** memo §4 (CONTEXT canonical refs). Reproduced here for
planner convenience; **do not modify** any callback signature without escalating
per D-32.

```elixir
defmodule Rindle.Streaming.Provider do
  @moduledoc """
  Behaviour for streaming providers. v1.6 ships one reference implementation
  (Mux, Phase 34). Adopters MAY implement this behaviour to plug in
  additional providers in v1.7+; v1.6 explicitly does NOT promise
  multi-provider parity.
  """

  @typedoc "Provider-side opaque asset identifier. Never exposed in adopter-facing paths (security invariant 14)."
  @type provider_asset_id :: String.t()

  @typedoc "Public playback locator. For Mux, the playback_id."
  @type playback_id :: String.t()

  @typedoc "Provider state mirrored into media_provider_assets.state."
  @type provider_state ::
          :pending | :uploading | :processing | :ready | :errored | :deleted

  @typedoc "Provider event normalized from a verified webhook payload."
  @type provider_event :: %{
          required(:event_id) => String.t(),
          required(:event_type) => String.t(),
          required(:provider_asset_id) => provider_asset_id() | nil,
          required(:occurred_at) => DateTime.t(),
          required(:raw) => map()
        }

  @typedoc "Capabilities atom set; subset of Rindle.Streaming.Capabilities vocabulary."
  @type capability ::
          :signed_playback | :public_playback | :webhook_ingest
          | :server_push_ingest | :direct_creator_upload

  @callback capabilities() :: [capability()]

  @callback create_asset(profile :: module(), source_url :: String.t(), opts :: keyword()) ::
              {:ok,
               %{
                 provider_asset_id: provider_asset_id(),
                 playback_id: playback_id() | nil,
                 state: provider_state()
               }}
              | {:error, term()}

  @callback get_asset(provider_asset_id()) ::
              {:ok,
               %{
                 provider_asset_id: provider_asset_id(),
                 playback_id: playback_id() | nil,
                 state: provider_state(),
                 raw: map()
               }}
              | {:error, term()}

  @callback delete_asset(provider_asset_id()) :: :ok | {:error, term()}

  @callback signed_playback_url(profile :: module(), playback_id(), opts :: keyword()) ::
              {:ok, %{url: String.t(), kind: :hls | :dash, mime: String.t()}}
              | {:error, term()}

  @callback verify_webhook(
              raw_body :: binary(),
              headers :: %{optional(String.t()) => String.t()},
              secrets :: [String.t()]
            ) ::
              {:ok, provider_event()}
              | {:error, :provider_webhook_invalid}

  @callback create_direct_upload(profile :: module(), opts :: keyword()) ::
              {:ok,
               %{
                 upload_url: String.t(),
                 upload_id: String.t(),
                 provider_asset_id: provider_asset_id() | nil
               }}
              | {:error, term()}

  @optional_callbacks [create_direct_upload: 2]
end
```

**Sanity-check the locked guarantees** (memo §4 / CONTEXT D-04..D-08):
- Every callback returns `:ok` or `:error` tuple — no raised exceptions.
- `verify_webhook/3` returns the **normalized** `provider_event` shape, NOT a
  Mux struct (single boundary preventing Mux-isms in core).
- `signed_playback_url/3` returns `kind: :hls | :dash` — Phase 33 ships the
  type; Mux-Phase 34 returns `:hls`. `:dash` reserved.
- `create_direct_upload/2` is `@optional_callbacks`; v1.6 Mux does NOT
  implement it (Phase 37 only).

### Pattern 7: Dispatch Tree Replacing No-Op Delegate (`Rindle.Delivery.streaming_url/3`)

**What:** Body change — same `@spec`, same arity, same telemetry emit, but the
internal flow becomes the D-19 decision tree.

**Source pattern (current shape):** `lib/rindle/delivery.ex:158-192`

The recommended internal shape (NOT prescriptive; the executor picks the
exact `with` chain). Note the four classification branches plus the v1.4
preserved tail:

```elixir
@spec streaming_url(module(), term(), keyword()) ::
        {:ok, %{url: String.t(), kind: atom(), mime: String.t()}} | {:error, term()}
def streaming_url(profile, asset_or_key, opts \\ []) do
  case classify_streaming_dispatch(profile, asset_or_key, opts) do
    :v1_4_progressive ->
      do_streaming_url_v1_4(profile, asset_or_key, opts)

    {:provider_dispatch, provider, playback_id} ->
      provider.signed_playback_url(profile, playback_id, opts)

    {:error, _reason} = error ->
      error
  end
end

defp classify_streaming_dispatch(profile, asset_or_key, opts) do
  case profile.delivery_policy() |> Map.get(:streaming) do
    nil ->
      :v1_4_progressive

    %{provider: provider} = streaming ->
      cond do
        is_binary(asset_or_key) ->
          {:error, :streaming_provider_requires_asset_struct}

        true ->
          dispatch_provider_lookup(profile, asset_or_key, streaming, provider, opts)
      end
  end
end

defp dispatch_provider_lookup(profile, asset, streaming, provider, opts) do
  provider_name = provider_name_from_module(provider)

  case Rindle.Repo.get_by(Rindle.Domain.MediaProviderAsset,
         asset_id: asset.id,
         profile: inspect(profile),
         provider_name: provider_name
       ) do
    nil ->
      maybe_strict_progressive(opts, profile, asset)

    %{state: state} when state in ~w(pending uploading processing) ->
      {:error, :provider_asset_not_ready}

    %{state: "errored"} ->
      {:error, :provider_sync_failed}

    %{state: "ready", playback_ids: [playback_id | _]} ->
      {:provider_dispatch, provider, playback_id}
  end
end

defp maybe_strict_progressive(opts, profile, asset) do
  if Keyword.get(opts, :strict, false) do
    {:error, :provider_asset_not_ready}
  else
    :v1_4_progressive
  end
end

defp provider_name_from_module(module) do
  module
  |> Module.split()
  |> List.last()
  |> Macro.underscore()
end

defp do_streaming_url_v1_4(profile, asset_or_key, opts) do
  # The CURRENT v1.4 streaming_url/3 body — wrapped in a private fn so it's
  # callable both as the streaming-nil path and as the no-row-progressive-fallback path.
  # Body lives at lib/rindle/delivery.ex:160-192 today; refactor extracts it without changing
  # behavior.
end
```

**Key invariants to preserve:**
- The telemetry event `[:rindle, :delivery, :streaming, :resolved]` MUST still
  fire on `:v1_4_progressive` resolution with `kind: :progressive` (D-24).
  When the provider path lights up in Phase 34, the same event fires with
  `kind: :hls` (single documented v1.4 contract extension).
- Caller-visible `:ok` shape stays `%{url, kind, mime}` (D-23).
- The `v1_4_progressive` branch must actually run the **existing** flow —
  including `authorize_delivery/4`, `require_streaming_support/3`, and
  `resolve_streaming_url/6`. The cleanest refactor pulls the v1.4 body into a
  private function and calls it from both branches; this avoids duplicating
  `:rindle.delivery.streaming.resolved` emission logic.

### Pattern 8: Capability Aggregator (mirror `Rindle.Ops.RuntimeChecks` report shape)

**What:** Read-only function that aggregates `Capabilities.safe/1` calls
across multiple capability surfaces.

**Source:** `lib/rindle/ops/runtime_checks.ex:32-66` (the existing `report` map shape)

**Recommended shape (D-30 verbatim):**

```elixir
defmodule Rindle.Capability do
  @moduledoc """
  Cross-surface capability aggregator. Phase 36's `mix rindle.doctor` will
  consume this; Phase 33 ships the function only.

  Public API stable from Phase 33 — extending the report map in later phases
  is additive only.
  """

  alias Rindle.Config

  @type report :: %{
          storage: %{module() => [atom()]},
          processor: %{module() => [atom()]},
          streaming: %{
            providers: %{module() => [atom()]},
            signed_playback_configured?: boolean(),
            configured_profiles: [module()]
          }
        }

  @spec report() :: report()
  def report do
    %{
      storage: storage_capabilities(),
      processor: processor_capabilities(),
      streaming: streaming_capabilities()
    }
  end

  defp storage_capabilities do
    # Discover storage adapters from configured profiles; call .safe/1 for each.
    Config.profile_modules()
    |> Enum.map(& &1.storage_adapter())
    |> Enum.uniq()
    |> Map.new(fn adapter -> {adapter, Rindle.Storage.Capabilities.safe(adapter)} end)
  end

  defp processor_capabilities do
    # AV is the only known processor surface in v1.6.
    %{Rindle.Processor.AV => Rindle.Processor.AV.capabilities()}
  end

  defp streaming_capabilities do
    profiles = Config.profile_modules()
    configured = Enum.filter(profiles, &profile_has_streaming?/1)
    providers = configured |> Enum.map(&streaming_provider_for/1) |> Enum.uniq()

    %{
      providers: Map.new(providers, fn provider ->
        {provider, Rindle.Streaming.Capabilities.safe(provider)}
      end),
      signed_playback_configured?: signed_playback_configured?(),
      configured_profiles: configured
    }
  end

  defp profile_has_streaming?(profile) do
    profile.delivery_policy() |> Map.get(:streaming) != nil
  end

  defp streaming_provider_for(profile) do
    profile.delivery_policy() |> get_in([:streaming, :provider])
  end

  defp signed_playback_configured? do
    # D-30: presence check on Mux config keys; never requires :mux dep loaded.
    config = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Keyword.get(config, :signing_key_id) not in [nil, ""] and
      Keyword.get(config, :signing_private_key) not in [nil, ""]
  end
end
```

**Note:** `Rindle.Config.profile_modules/0` already exists (used by
`Rindle.Ops.RuntimeChecks` line 37). The aggregator depends on existing
infrastructure — no new helpers needed in Phase 33.

### Anti-Patterns to Avoid

- **Repo I/O inside `Rindle.Streaming.Provider` callbacks.** The behaviour
  declares contract; impl-side Repo writes belong in Phase 34 worker code.
- **Letting the FSM do `Repo.update/1`.** `transition/3` returns `:ok`; the
  caller composes the changeset and persists. Mirrors v1.4's
  `Rindle.Domain.AssetFSM` usage exactly.
- **Adding raw provider knobs to the `:streaming` schema.** D-16 forbids any
  key not in the locked set. NimbleOptions raises on unknown keys by default;
  do not add `validate: ...` callbacks that loosen this.
- **Logging or telemetry-emitting `provider_asset_id` raw.** Security invariant
  14. The `Inspect` impl on `MediaProviderAsset` redacts at the schema layer;
  any new telemetry that emits provider IDs must also redact (last-4-char tag).
- **Crashing in `Rindle.Capability.report/0` when `:mux` dep is not loaded.**
  D-30 explicitly forbids. Use `Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])`-style
  presence checks; never `Code.ensure_loaded?(Rindle.Streaming.Provider.Mux)` calls
  that crash on the missing dep boundary.
- **Modifying any v1.4 callsites of `[:rindle, :delivery, :streaming, :resolved]`.**
  CONTEXT D-24 explicitly preserves the event; the only documented extension is
  the metadata `kind:` field gaining `:hls` once Phase 34 lights up. Existing
  consumers (`test/rindle/delivery_test.exs:352-380`) MUST continue to pass.
- **Using `Code.ensure_loaded?/1` to conditionally include the Mux callback in
  `streaming_capabilities/0`.** Phase 33 ships zero Mux code per CONTEXT
  "Operational Boundaries"; the aggregator's `providers` map is keyed by
  modules that **are** loaded (configured in adopter profiles), so there's no
  conditional-load path needed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DSL key validation that refuses raw provider knobs | Hand-rolled `Map.has_key?` checks against an allowlist | NimbleOptions schema with `validate!/2` | Already the established pattern across `Rindle.Profile.Validator` (4 schemas). Hand-rolling creates vocabulary drift; NimbleOptions raises on unknown keys for free. |
| FSM transition allowlist | Custom `case` chains across the schema's `cast`/`validate_change` callbacks | `@allowed_transitions` map + `transition/3` returning `:ok | {:error, ...}` | Mirrors `Rindle.Domain.AssetFSM`. Pure functional FSMs are testable, telemetry-emitting, and decoupled from Repo writes. Caller composes changeset + persists. |
| Capability set filtering | Direct `adapter.capabilities() |> List.contains?(...)` | `Rindle.Streaming.Capabilities.safe/1` + `supports?/2` | Same reason `Rindle.Storage.Capabilities` exists — adapters can advertise unknown atoms; `safe/1` filters against the closed `@known` vocabulary. Without it, vocabulary drift is silent. |
| Custom `inspect/2` redaction in every callsite | Sprinkling `String.slice(provider_asset_id, -4..-1)` across logs / telemetry / dashboards | Single `defimpl Inspect, for: Rindle.Domain.MediaProviderAsset` | Encodes security invariant 14 at the schema layer; one definition of redaction; impossible to forget on a new logsite. |
| Webhook signature verification | Hand-rolled HMAC + constant-time compare in Phase 33 | **DEFER** — `Mux.Webhooks.verify_header/4` lands in Phase 35 / MUX-10. The `verify_webhook/3` callback is just **declared** in Phase 33; impl is Phase 34. | Phase 33 is contract surface only. `verify_webhook/3` callback signature accepts `secrets :: [String.t()]` so multi-secret rotation in Phase 35 plugs in without callback churn. |
| Provider-asset Repo lookup helpers | Custom query module with named queries | `Repo.get_by(Rindle.Domain.MediaProviderAsset, asset_id: ..., profile: ..., provider_name: ...)` | The unique index on `(asset_id, profile, provider_name)` (D-10) makes `Repo.get_by/2` O(1). No N+1 risk per D-21. Custom query modules add surface for no benefit. |
| Error message formatting / cause→action prose | Helper functions to interpolate cause/action strings | Inline heredocs in each `def message(%{reason: <atom>}) do ... end` clause | Mirrors `lib/rindle/error.ex:46-262`. Helper functions create indirection that makes the parity test (STREAM-09) much harder to read. The freeze test asserts exact string output; clauses must be self-contained heredocs. |
| Capability aggregator caching | `:persistent_term` / ETS cache | Direct re-computation on every `Rindle.Capability.report/0` call | Doctor / runtime_status calls are operator-driven — once per session at most. Caching adds invalidation surface for no gain. |

**Key insight:** Phase 33 is contract surface — almost everything that *looks*
like infrastructure is already a locked pattern in v1.4 / v1.5. The
hand-rolling temptation is highest in error message formatting (where the
cause→action style invites helper extraction) and DSL validation (where
NimbleOptions can feel heavy for "just one new key"). Resist both — the
parity gate (STREAM-09) and the schema validation pattern lock the surface
identically to v1.4 AV-04/AV-05 / v1.4 image variant validation.

---

## Common Pitfalls

### Pitfall 1: STREAM-09 parity gate matches existing AV-06-05 pattern but the heredoc whitespace differs

**What goes wrong:** The freeze test compares heredoc strings byte-for-byte; a
trailing newline in either the test fixture or the message clause body causes
flaky failures.

**Why it happens:** Elixir heredocs include trailing newlines; the existing
pattern (`test/rindle/error_test.exs:318`) uses
`String.trim_trailing/1` (`exact/1` helper) and the message clauses use
`|> String.trim()` to normalize. The two operations are different
(`trim_trailing` only removes trailing whitespace; `trim` removes both ends).

**How to avoid:**
- Match the existing pattern: in `Rindle.Error.message/1` clauses, pipe through
  `|> String.trim()` (matches `lib/rindle/error.ex:67` exactly).
- In the parity test, use the existing `exact/1` helper which does
  `String.trim_trailing/1` (matches `test/rindle/error_test.exs:318` exactly).
- Run the test once during development with `assert ==` and inspect the diff
  on failure — the diff prints both strings character-by-character.

**Warning signs:** Test passes locally but fails in CI; or the assertion error
shows two strings that look identical but byte-counts differ.

### Pitfall 2: `:streaming` DSL map vs. keyword list normalization

**What goes wrong:** Adopters write `delivery: %{streaming: %{...}}`
(map-of-map) **or** `delivery: [streaming: [...]]` (keyword-of-keyword);
NimbleOptions schemas accept keyword lists only by default.

**Why it happens:** `Rindle.Profile.Validator.validate_delivery!/1` already
handles map-or-keyword normalization at the top level
(`normalize_delivery_opts!/1` at line 234). The new `:streaming` sub-schema
needs the same handling — failure to normalize causes `KeyError` raises that
look like adopter config bugs.

**How to avoid:** Reuse the existing `normalize_delivery_opts!/1` pattern (or a
sibling `normalize_streaming_opts!/1`). Convert any incoming map to a keyword
list **before** calling `NimbleOptions.validate!/2`. The existing
`@delivery_schema` does this at validate-delivery time; a second-level
normalize for `:streaming` keeps the pattern symmetric.

**Warning signs:** Compile-time errors like `protocol Enumerable not implemented for ...`
when adopter passes `%{provider: ..., playback_policy: :signed}`.

### Pitfall 3: The dispatch tree's "no row" branch must preserve v1.4 telemetry

**What goes wrong:** A naive D-19 implementation that returns
`{:ok, %{url, kind, mime}}` from the no-row branch without re-emitting the
existing `[:rindle, :delivery, :streaming, :resolved]` telemetry event breaks
the v1.4-frozen contract and breaks `test/rindle/delivery_test.exs:352-380`.

**Why it happens:** It's tempting to short-circuit — "no row, fall back" — and
write a minimal `_ -> Rindle.Delivery.url(...)` shim that skips the
streaming-resolved emission. But `streaming_url/3` is the named
streaming-emit point; switching to `url/3` for fallback emits the wrong
telemetry event (`[:rindle, :delivery, :signed]` instead).

**How to avoid:** Extract the **existing** `streaming_url/3` body (the v1.4
flow at `lib/rindle/delivery.ex:160-192`) into a private function (e.g.
`do_streaming_url_v1_4/3`) and call it from both the
`profile.streaming == nil` branch AND the no-row-progressive-fallback branch.
The single private function preserves the existing `with` chain that
emits `[:rindle, :delivery, :streaming, :resolved]` with `kind: :progressive`.

**Warning signs:** Existing telemetry contract test
(`test/rindle/contracts/telemetry_contract_test.exs:74, 277`) starts failing;
or the existing
`test/rindle/delivery_test.exs:352` "streaming_url/3 emits ... on success"
test goes red.

### Pitfall 4: Plain `:string` state vs. Ecto enum

**What goes wrong:** Choosing `Ecto.Enum` for the `state` column to "match the
FSM atom set" creates a schema-FSM coupling that breaks the existing
`MediaAsset` pattern (which uses plain `:string` + `validate_inclusion/3`).

**Why it happens:** Atom-typed states feel cleaner; `Ecto.Enum` is a
batteries-included option. But the existing FSMs use **string** states
(`"staged"`, `"ready"`, etc.) — the `@allowed_transitions` keys are strings,
the `validate_inclusion/3` allowlist is strings, the test cases assert strings.
Changing this for `MediaProviderAsset` introduces a project-wide split.

**How to avoid:** Use `field :state, :string, default: "pending"` exactly like
`MediaAsset`. The FSM module operates on strings. Atom conversion (if needed
elsewhere) is a caller concern.

**Warning signs:** Schema test fails because `state` is `:pending` (atom) but
`@states` contains `"pending"` (string); or `validate_inclusion/3` returns a
nil-typed error.

### Pitfall 5: Provider-name derivation collides for nested provider modules

**What goes wrong:** D-22's
`Module.split() |> List.last() |> Macro.underscore()` returns `"mux"` for
`Rindle.Streaming.Provider.Mux` (correct). But if v1.7 lands a provider at
`Rindle.Streaming.Provider.Mux.V2` or `Rindle.Streaming.Provider.Cloudflare.Stream`,
`List.last/1` returns `"v2"` and `"stream"` — collisions and surprises.

**Why it happens:** `List.last/1` is a one-element extraction; doesn't account
for nested provider names.

**How to avoid:** D-22 is locked for v1.6 (single provider, Mux). The
collision risk lands in v1.7 when the second provider arrives — the
`provider_name` derivation should be revisited then. Phase 33 ships the D-22
shape verbatim; document the limitation in a moduledoc comment so v1.7
researchers find it. The unique index on `(provider_name, provider_asset_id)`
(D-10) is the safety net — duplicate names will fail at the DB layer.

**Warning signs:** Future provider modules with nested namespaces all derive
to the same `provider_name`. Phase 33 cannot directly mitigate; document only.

### Pitfall 6: Capability report leaks Mux credentials when adopter misconfigures

**What goes wrong:** `signed_playback_configured?` returns `true` because
`Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])` returns
config — but the config map is then logged or telemetry-emitted with the
PEM-formatted private key visible.

**Why it happens:** `Rindle.Capability.report/0` returns a structured map that
can be passed to `inspect/2`, `Logger.info/2`, etc. without redaction. If a
caller logs the **full** report map (including the Mux config under the hood),
the PEM private key leaks.

**How to avoid:** D-30 specifies the report shape — it returns
`signed_playback_configured?: boolean()`, NOT the config keys. **Never**
return the actual config keys from the report — only the boolean presence
check. Doctor consumes the boolean; that's enough for "PASS / FAIL"
guidance. If a future requirement forces returning the config, redact the
PEM at that point.

**Warning signs:** A test or guide example shows `Rindle.Capability.report/0`
returning a `%{streaming: %{config: %{signing_private_key: ...}}}`-shaped map.

### Pitfall 7: The `errored → processing` re-ingest edge surprises operators

**What goes wrong:** Operators who learn the FSM via a state diagram that
shows `errored` as a sink ("once it's errored, it stays errored unless
deleted") miss the `errored → processing` re-ingest edge (D-13). They build
dashboards / runbooks assuming `errored` is terminal until `deleted`.

**Why it happens:** The re-ingest edge is an explicit Phase 34 dependency —
`MuxIngestVariant`'s retry path needs it — but it's a non-obvious FSM
allowance in the abstract.

**How to avoid:** Document the edge in the moduledoc of `ProviderAssetFSM`
with a note: "errored → processing exists to support re-ingest from
Phase 34's MuxIngestVariant retry path; do NOT remove without coordinating
with that worker." Mention it in the Phase 33 commit message if possible.
Phase 34 RESEARCH should re-confirm the edge is still needed.

**Warning signs:** The Phase 33 plan has a task to "ensure errored is
terminal except via deleted" — that's a contradiction with D-13.

---

## Code Examples

All examples below are mirror patterns from existing repo files. Verbatim
shapes per the locked CONTEXT.md decisions.

### Example 1: Streaming Capabilities module (full)

```elixir
# Source pattern: lib/rindle/storage/capabilities.ex:1-67
# CONTEXT D-01, D-02, D-03

defmodule Rindle.Streaming.Capabilities do
  @moduledoc false

  @typedoc """
  Known streaming capability atoms.

  `:direct_creator_upload` is reserved — Phase 33 ships the vocabulary
  entry, but no v1.6 adapter advertises this capability. Phase 37 / v1.7
  is the earliest landing for direct-creator-upload support.
  """
  @type capability ::
          :signed_playback
          | :public_playback
          | :webhook_ingest
          | :server_push_ingest
          | :direct_creator_upload

  @known [
    :signed_playback,
    :public_playback,
    :webhook_ingest,
    :server_push_ingest,
    :direct_creator_upload
  ]

  @spec known() :: [capability()]
  def known, do: @known

  @spec safe(module()) :: [capability()]
  def safe(adapter) do
    case adapter.capabilities() do
      capabilities when is_list(capabilities) ->
        Enum.filter(capabilities, &(&1 in @known))

      _ ->
        []
    end
  rescue
    _ -> []
  end

  @spec supports?(module(), capability()) :: boolean()
  def supports?(adapter, capability), do: capability in safe(adapter)
end
```

### Example 2: Error message clauses (one of five)

```elixir
# Source pattern: lib/rindle/error.ex:195-221
# CONTEXT D-25, D-27 — cause → action style; bare-atom + map-keyed variants

# Bare-atom variant (always present)
def message(%{reason: :provider_asset_not_ready}) do
  """
  The provider asset is not yet ready for playback.

  Check `mix rindle.runtime_status --provider-stuck` to see whether ingest
  is in flight or stuck. If the row is in :uploading or :processing, wait
  for the provider webhook to confirm readiness. If the row stays in
  :processing past the configured threshold, inspect Oban for the
  `MuxIngestVariant` job (Phase 34) and consider re-ingest via
  `Rindle.regenerate_variants/2`.
  """
  |> String.trim()
end

# Repeat the pattern for the other four atoms:
#   :provider_webhook_invalid
#   :provider_sync_failed
#   :provider_quota_exceeded
#   :streaming_provider_requires_asset_struct

# Note: D-27 forbids map-keyed variants (e.g. {:provider_quota_exceeded,
# %{provider: ..., retry_after: ...}}) in Phase 33. Bare atoms only.
```

### Example 3: Parity freeze test (STREAM-09)

```elixir
# Source pattern: test/rindle/error_test.exs:1-100
# CONTEXT D-28 — mirror AV-06-05 freeze pattern

defmodule Rindle.ErrorStreamingFreezeTest do
  use ExUnit.Case, async: true

  @public_streaming_reasons [
    :provider_asset_not_ready,
    :provider_webhook_invalid,
    :provider_sync_failed,
    :provider_quota_exceeded,
    :streaming_provider_requires_asset_struct
  ]

  test "locks the five public streaming reason atoms" do
    assert @public_streaming_reasons == [
             :provider_asset_not_ready,
             :provider_webhook_invalid,
             :provider_sync_failed,
             :provider_quota_exceeded,
             :streaming_provider_requires_asset_struct
           ]
  end

  test "renders exact messages for the five new streaming reason atoms" do
    expected_messages = %{
      provider_asset_not_ready:
        exact("""
        The provider asset is not yet ready for playback.

        Check `mix rindle.runtime_status --provider-stuck` to see whether ingest
        is in flight or stuck. If the row is in :uploading or :processing, wait
        for the provider webhook to confirm readiness. If the row stays in
        :processing past the configured threshold, inspect Oban for the
        `MuxIngestVariant` job (Phase 34) and consider re-ingest via
        `Rindle.regenerate_variants/2`.
        """),
      provider_webhook_invalid: exact("""
      ...
      """),
      provider_sync_failed: exact("""
      ...
      """),
      provider_quota_exceeded: exact("""
      ...
      """),
      streaming_provider_requires_asset_struct: exact("""
      ...
      """)
    }

    for {reason, expected} <- expected_messages do
      error = struct!(Rindle.Error, action: :test_contract, reason: reason)
      assert Rindle.Error.message(error) == expected
    end
  end

  defp exact(text), do: String.trim_trailing(text)
end
```

### Example 4: FSM transition matrix test

```elixir
# Source pattern: test/rindle/domain/lifecycle_fsm_test.exs:1-80
# Tests every D-13 edge plus a representative rejection sample.

defmodule Rindle.Domain.ProviderAssetFSMTest do
  use ExUnit.Case, async: true

  alias Rindle.Domain.ProviderAssetFSM

  describe "provider_asset transition matrix (D-13)" do
    test "accepts the nominal pending → ready path" do
      assert :ok == ProviderAssetFSM.transition("pending", "uploading")
      assert :ok == ProviderAssetFSM.transition("uploading", "processing")
      assert :ok == ProviderAssetFSM.transition("processing", "ready")
    end

    test "accepts errored branches from every in-flight state" do
      assert :ok == ProviderAssetFSM.transition("uploading", "errored")
      assert :ok == ProviderAssetFSM.transition("processing", "errored")
      assert :ok == ProviderAssetFSM.transition("ready", "errored")
    end

    test "accepts terminal-delete from ready and errored" do
      assert :ok == ProviderAssetFSM.transition("ready", "deleted")
      assert :ok == ProviderAssetFSM.transition("errored", "deleted")
    end

    test "accepts re-ingest re-entry edge errored → processing (D-13)" do
      assert :ok == ProviderAssetFSM.transition("errored", "processing")
    end

    test "rejects deleted → anything (terminal sink)" do
      for target <- ~w(pending uploading processing ready errored) do
        assert {:error, {:invalid_transition, "deleted", ^target}} =
                 ProviderAssetFSM.transition("deleted", target)
      end
    end

    test "rejects pending → ready (skips intermediate states)" do
      assert {:error, {:invalid_transition, "pending", "ready"}} =
               ProviderAssetFSM.transition("pending", "ready")
    end

    test "rejects ready → uploading (no backward edges to in-flight)" do
      assert {:error, {:invalid_transition, "ready", "uploading"}} =
               ProviderAssetFSM.transition("ready", "uploading")
    end
  end

  describe "telemetry emission" do
    test "emits [:rindle, :provider_asset, :state_change] on accepted transitions" do
      ref = make_ref()

      :telemetry.attach(
        "provider_asset_fsm_test_#{inspect(ref)}",
        [:rindle, :provider_asset, :state_change],
        fn event, measurements, metadata, _ ->
          send(self(), {event, measurements, metadata})
        end,
        nil
      )

      :ok = ProviderAssetFSM.transition("pending", "uploading", %{
        profile: MyProfile,
        provider: :mux,
        asset_id: "asset-1"
      })

      assert_received {[:rindle, :provider_asset, :state_change], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.profile == MyProfile
      assert metadata.provider == :mux
      assert metadata.from == "pending"
      assert metadata.to == "uploading"

      :telemetry.detach("provider_asset_fsm_test_#{inspect(ref)}")
    end
  end
end
```

### Example 5: Dispatch tree test (decision-tree coverage)

```elixir
# Tests every D-19 branch.

defmodule Rindle.DeliveryStreamingDispatchTest do
  use ExUnit.Case, async: true
  # Setup: Mox for storage, profiles defined in test/support, Repo sandbox.

  describe "streaming_url/3 dispatch tree (D-19)" do
    test "step 1: profile streaming nil falls through to v1.4 progressive" do
      # Asserts that AV-only profile (no :streaming) returns
      # {:ok, %{url, kind: :progressive, mime}} unchanged from v1.4.
    end

    test "step 2: streaming + binary key returns :streaming_provider_requires_asset_struct" do
      assert {:error, :streaming_provider_requires_asset_struct} =
               Rindle.Delivery.streaming_url(StreamingProfile, "uploads/abc.mp4")
    end

    test "step 3a: row in :pending returns :provider_asset_not_ready" do
      # Insert pending row; asserts {:error, :provider_asset_not_ready}
    end

    test "step 3b: row in :uploading returns :provider_asset_not_ready" do
      # Same as above, with :uploading
    end

    test "step 3c: row in :processing returns :provider_asset_not_ready" do
      # Same as above, with :processing
    end

    test "step 4: row in :errored returns :provider_sync_failed" do
      # Insert errored row; asserts {:error, :provider_sync_failed}
    end

    test "step 5: row in :ready dispatches to provider.signed_playback_url/3" do
      # Insert ready row with playback_ids; asserts provider mock called
      # AND result returned unchanged.
    end

    test "step 6: no row + non-strict opts falls through to progressive" do
      # No row; asserts {:ok, %{url, kind: :progressive, mime}}
      # AND telemetry [:rindle, :delivery, :streaming, :resolved] emitted with kind: :progressive
    end

    test "step 6: no row + opts[:strict] = true returns :provider_asset_not_ready (D-20)" do
      assert {:error, :provider_asset_not_ready} =
               Rindle.Delivery.streaming_url(StreamingProfile, asset, strict: true)
    end
  end

  describe "preserved v1.4 telemetry contract (D-24)" do
    test "step 1 (no streaming) emits [:rindle, :delivery, :streaming, :resolved] with kind: :progressive" do
      # Asserts the existing test/rindle/delivery_test.exs:352 behavior unchanged.
    end

    test "step 6 (no row, non-strict) emits [:rindle, :delivery, :streaming, :resolved] with kind: :progressive" do
      # Same telemetry event; same kind; same metadata shape.
    end
  end
end
```

### Example 6: Profile DSL `:streaming` key validation test

```elixir
# Tests D-15..D-18 invariants.

defmodule Rindle.Profile.ValidatorStreamingTest do
  use ExUnit.Case, async: true

  describe "delivery.streaming key (D-15)" do
    test "validates locked named-only options" do
      opts = [
        storage: MyStorage,
        variants: [web: [kind: :video, preset: :web_720p]],
        delivery: [
          streaming: [
            provider: MyProvider,
            playback_policy: :signed,
            ingest_mode: :server_push,
            source_variant: :web
          ]
        ]
      ]

      assert %{delivery: %{streaming: streaming}} =
               Rindle.Profile.Validator.validate!(opts)

      assert streaming.provider == MyProvider
      assert streaming.playback_policy == :signed
      assert streaming.ingest_mode == :server_push
      assert streaming.source_variant == :web
    end

    test "rejects raw provider knobs (D-16)" do
      opts = [
        storage: MyStorage,
        variants: [web: [kind: :video, preset: :web_720p]],
        delivery: [
          streaming: [
            provider: MyProvider,
            playback_policy: :signed,
            ingest_mode: :server_push,
            source_variant: :web,
            max_resolution_tier: "1080p" # raw Mux knob — must be refused
          ]
        ]
      ]

      assert_raise ArgumentError, ~r/unknown options.*max_resolution_tier/, fn ->
        Rindle.Profile.Validator.validate!(opts)
      end
    end

    test "image-only profile compiles unchanged (D-17)" do
      opts = [
        storage: MyStorage,
        variants: [thumb: [width: 128, height: 128, format: :webp, mode: :fit]],
        delivery: []
      ]

      assert %{delivery: delivery} = Rindle.Profile.Validator.validate!(opts)
      refute Map.has_key?(delivery, :streaming) or delivery.streaming == nil
    end

    test "AV-only profile (no streaming) compiles unchanged (D-17)" do
      opts = [
        storage: MyStorage,
        variants: [web: [kind: :video, preset: :web_720p]],
        delivery: []
      ]

      assert %{delivery: delivery} = Rindle.Profile.Validator.validate!(opts)
      refute Map.has_key?(delivery, :streaming) or delivery.streaming == nil
    end

    test "rejects source_variant atom not declared in variants/0 (D-18, partial)" do
      opts = [
        storage: MyStorage,
        variants: [web: [kind: :video, preset: :web_720p]],
        delivery: [
          streaming: [
            provider: MyProvider,
            playback_policy: :signed,
            ingest_mode: :server_push,
            source_variant: :nonexistent
          ]
        ]
      ]

      assert_raise ArgumentError, ~r/source_variant.*nonexistent.*not declared/, fn ->
        Rindle.Profile.Validator.validate!(opts)
      end
    end

    # D-18 explicitly defers per-variant kind: :video | :audio enforcement to
    # Phase 34 — Phase 33 only checks the atom exists in variants/0.
  end
end
```

### Example 7: Capability report shape test

```elixir
defmodule Rindle.CapabilityTest do
  use ExUnit.Case, async: true

  describe "report/0 shape (D-30)" do
    test "returns the locked top-level keys" do
      report = Rindle.Capability.report()

      assert is_map(report.storage)
      assert is_map(report.processor)
      assert is_map(report.streaming)
      assert is_map(report.streaming.providers)
      assert is_boolean(report.streaming.signed_playback_configured?)
      assert is_list(report.streaming.configured_profiles)
    end

    test "signed_playback_configured? is false when Mux config keys are absent" do
      Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, [])

      assert %{streaming: %{signed_playback_configured?: false}} =
               Rindle.Capability.report()
    end

    test "signed_playback_configured? is true when both signing keys are set" do
      Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
        signing_key_id: "key_123",
        signing_private_key: "-----BEGIN PRIVATE KEY-----..."
      )

      assert %{streaming: %{signed_playback_configured?: true}} =
               Rindle.Capability.report()
    after
      Application.delete_env(:rindle, Rindle.Streaming.Provider.Mux)
    end

    test "does NOT crash when :mux dep is not loaded (D-30)" do
      # No need to actually unload the dep; the function uses
      # Application.get_env which never raises on missing config.
      assert %{streaming: _} = Rindle.Capability.report()
    end
  end
end
```

---

## State of the Art

Phase 33 is library-internal contract work; "state of the art" for Rindle's
own architecture is the v1.4 / v1.5 patterns the new code mirrors.

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `Rindle.Streaming.Provider` 2-callback shim (`streaming_url/3`, `capabilities/0`) | 6-required + 1-optional callback set per memo §4 | Phase 33 (this phase) | Non-breaking redesign per D-08 (no shipped impls existed in v1.4); confines Mux-isms to adapter layer |
| `Rindle.Delivery.streaming_url/3` no-op delegate (delegates to `url/3` with kind: :progressive) | Deterministic decision tree per D-19; provider lookup via `Repo.get_by/2`; preserves v1.4 telemetry | Phase 33 | One documented v1.4 contract extension: `kind: :hls` arrives in metadata once Phase 34 lights up the provider path |
| `media_provider_assets`: did not exist | Additive Ecto table with binary_id PK, FK to media_assets, partial-where unique index, four total indexes | Phase 33 | Zero impact on existing tables; mirrors the additive posture of v1.4's `media_variants` migration |
| Profile DSL `delivery: %{public, signed_url_ttl_seconds, authorizer}` | Same plus optional `:streaming` key with locked named-only options | Phase 33 | Image-only / AV-only profiles compile unchanged (D-17); raw provider knobs forbidden (D-16) |
| `Rindle.Error` AV-06-05 vocabulary (8 atoms locked at v1.4 ship) | Same plus 5 additive atoms locked at v1.6 ship via STREAM-09 parity gate | Phase 33 | Bare-atom only in v1.6 (D-27); map-keyed variants additive in v1.7+ if needed |
| `mix rindle.doctor` builds report shape inline | `Rindle.Capability.report/0` aggregator (Phase 36 will refactor doctor onto it) | Phase 33 | Phase 33 ships function only; Phase 36 wires doctor (MUX-16) |

**Deprecated/outdated:**
- The v1.4 reserved 2-callback `Rindle.Streaming.Provider` shim is replaced
  in this phase. CONTEXT D-08 confirms zero adopter impact (no shipped impls
  existed).
- The v1.4 no-op delegate at `lib/rindle/delivery.ex:160-192` is replaced
  in this phase. CONTEXT D-19 confirms the public arity / spec / telemetry
  emit are preserved.

---

## Project Constraints (from CLAUDE.md)

`./CLAUDE.md` does not exist in this repository (verified by Read tool).
Project conventions are inferred from `.planning/PROJECT.md` and existing
code patterns instead.

**Project-level constraints surfaced from `.planning/PROJECT.md` "Constraints"
section that are load-bearing for Phase 33:**

| Constraint | Phase 33 Impact |
|---|---|
| Tech stack: Elixir/Phoenix/Ecto only in core; no non-Elixir runtime | Phase 33 ships Elixir-only code; zero runtime additions; satisfied. |
| Repo ownership: adopter-first; library may keep `Rindle.Repo` only as a local test/dev harness | The new migration ships in `priv/repo/migrations`; adopters call `mix ecto.migrate` against their own Repo per D-11. Satisfied. |
| Background jobs: Oban remains required; multipart flows must integrate with Oban | Phase 33 ships zero new workers (workers are Phase 34/35); satisfied. |
| Security defaults: private delivery default; allowlist guarantees preserved | The schema-level `Inspect` redaction (D-14) plus the closed `:streaming` DSL vocabulary (D-16) preserve allowlist guarantees. Security invariant 14 (added v1.6) is encoded at the schema layer. Satisfied. |
| Capability honesty: adapters advertise only what they truly support; unsupported flows fail as tagged errors | The closed `Rindle.Streaming.Capabilities` vocabulary (D-02) + `safe/1` filter (D-01) enforces this. Satisfied. |
| Backward compatibility: existing presigned PUT flows stay supported | Phase 33 makes zero changes to upload paths; image-only and AV-only profiles compile unchanged (D-17). Satisfied. |

**Project-level constraints from PROJECT.md "Security invariants" that this
phase must encode:**

- **Invariant 14 (added v1.6):** "Raw provider identifiers
  (`provider_asset_id`, provider upload IDs, provider session URIs) are
  never exposed in adopter-facing paths, URLs, logs, telemetry metadata,
  or `inspect/2` output. Only the public-side `playback_id` (or equivalent)
  crosses into URLs. Telemetry metadata redacts provider-internal IDs to
  last-4-char tags. Provider bearer credentials (Mux signing keys, GCS
  resumable session URIs, tus upload URLs) are treated as secrets at rest
  and in transit; custom `Inspect` impls on persistence rows redact them."

  → Phase 33 encodes this via:
  - Custom `defimpl Inspect` on `Rindle.Domain.MediaProviderAsset` (D-14)
  - `Rindle.Capability.report/0` returning `signed_playback_configured?: boolean()`
    instead of the actual config keys (D-30)
  - Documentation note in the moduledoc of `Rindle.Streaming.Provider`
    that `provider_asset_id` is never exposed in adopter-facing paths

---

## Runtime State Inventory

> Phase 33 is **not** a rename / refactor / migration phase in the
> string-replacement sense — it's a contract-extension and additive-table
> phase. There is no string being renamed, no service registration to update,
> and no stored data with a deprecated key. This section is included for
> completeness and to make the absence explicit.

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | None — `media_provider_assets` is a NEW table; no migration of existing data because `media_assets` / `media_variants` are unchanged. | None — additive only |
| Live service config | None — no external services have a string referenced. The new config keys for Phase 34's Mux dep (`signing_key_id`, etc.) are referenced by `Rindle.Capability.report/0` but are NOT set in Phase 33; adopters configure them when Phase 34 ships. | None |
| OS-registered state | None — no Windows Task Scheduler / launchd / systemd / pm2 registrations reference the new names. | None |
| Secrets/env vars | None — no env var renames. The five future Mux env vars (`RINDLE_MUX_TOKEN_ID`, `RINDLE_MUX_TOKEN_SECRET`, `RINDLE_MUX_SIGNING_KEY_ID`, `RINDLE_MUX_SIGNING_PRIVATE_KEY`, `RINDLE_MUX_WEBHOOK_SECRETS`) are introduced but **NOT** read by Phase 33 code (D-31, "no Mux dep, no Mux client code, no Mux env-var reads" per CONTEXT operational boundaries). | None — they will be read by Phase 34 / Phase 35 / Phase 36 code |
| Build artifacts | None — no compiled binaries reference deprecated names. The `:mux` and `:jose` deps are NOT added in Phase 33 (`mix.exs` unchanged); they arrive in Phase 34. | None |

**Nothing found in any category.** Phase 33 is contract-only; the only
"state" being introduced is a new Ecto table whose contents are written by
Phase 34+ workers. Adopters running Phase 33 migration get one new empty
table; their existing rows are unaffected.

---

## Environment Availability

> Phase 33 has **no external dependencies** beyond what's already pinned in
> `mix.exs`. Every dep needed (`:nimble_options`, `:ecto_sql`, `:postgrex`,
> `:telemetry`, `:jason`, `:plug`) is already present.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `:nimble_options` | NimbleOptions schema for `:streaming` profile DSL key | ✓ (`mix.exs:68`) | `~> 1.1` | — |
| `:ecto_sql` | Migration + schema for `media_provider_assets` | ✓ (`mix.exs:53`) | `~> 3.11` | — |
| `:postgrex` | Postgres adapter for migration / schema | ✓ (`mix.exs:54`) | `~> 0.18` | — |
| `:telemetry` | FSM + dispatch-tree telemetry emit | ✓ (`mix.exs:81`) | `~> 1.2` | — |
| Postgres (running) | Test suite migrations | ✓ (assumed; the test alias `mix test` already runs `ecto.migrate --quiet` per `mix.exs:231`) | — | — |
| `:mux` SDK | **NOT used in Phase 33** (Phase 34 only) | — | — | N/A — Phase 33 does NOT depend on `:mux`; the optional dep arrives in Phase 34 |
| `:jose` SDK | **NOT used in Phase 33** (Phase 34/35 only) | — | — | N/A — same as above |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

Phase 33 can ship with a fresh checkout assuming Postgres is reachable for
test runs; that's the same posture as every prior phase since Phase 1.

---

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (Elixir built-in) + ExUnit.CaseTemplate, Mox `~> 1.2`, ExMachina `~> 2.7`, Bypass `~> 2.1` |
| Config file | `test/test_helper.exs` (existing; no new framework) |
| Quick run command | `mix test test/rindle/<focused_dir>/<focused_file>.exs --color` |
| Full suite command | `mix test --color` |

### Phase Requirements → Test Map

| REQ | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| STREAM-01 | `Rindle.Streaming.Capabilities.known/0` returns the locked 5-atom list (incl. reserved `:direct_creator_upload`); `safe/1` filters unknown atoms; `supports?/2` agrees with `safe/1` | unit | `mix test test/rindle/streaming/capabilities_test.exs --color` | ❌ Wave 0 — new file |
| STREAM-02 | `Rindle.Streaming.Provider` declares 6 required + 1 optional callbacks with locked types; `behaviour_info(:callbacks)` exposes correct arities | unit | `mix test test/rindle/streaming/provider_test.exs --color` | ❌ Wave 0 — new file |
| STREAM-03 | Migration creates `media_provider_assets` with all 14 columns, partial-where unique index, three other indexes; idempotent (running twice doesn't crash) | integration (Repo) | `mix test test/rindle/domain/media_provider_asset_test.exs:<line> --color` (also covered by `mix test --color` running migrations) | ❌ Wave 0 — new file (test scaffold) |
| STREAM-04 | (a) Schema cast / changeset / `validate_inclusion` accept all 6 states; (b) FSM `transition/3` accepts every D-13 edge and rejects everything else; (c) FSM emits `[:rindle, :provider_asset, :state_change]` telemetry; (d) `Inspect` impl redacts `provider_asset_id` and `raw_provider_metadata` per D-14 / invariant 14 | unit + property | `mix test test/rindle/domain/media_provider_asset_test.exs test/rindle/domain/provider_asset_fsm_test.exs --color` | ❌ Wave 0 — new files |
| STREAM-05 | (a) `validate!/1` accepts the locked `:streaming` shape; (b) raw Mux knobs raise `ArgumentError`; (c) image-only and AV-only profiles compile unchanged; (d) `source_variant` atom must exist in `variants/0`; (e) per-variant `kind:` enforcement is NOT done in Phase 33 (deferred to Phase 34 per D-18) | unit | `mix test test/rindle/profile/validator_test.exs --color` (extend existing file) | ✅ exists (extends) |
| STREAM-06 | All eight D-19 dispatch branches return the correct atom / `:ok` shape; preserves `[:rindle, :delivery, :streaming, :resolved]` telemetry on the v1.4 progressive paths (steps 1, 6); `:strict` opt converts step 6 to `:provider_asset_not_ready` (D-20) | integration (Repo + Mox) | `mix test test/rindle/delivery_test.exs --color` (extend) and/or `test/rindle/delivery/streaming_dispatch_test.exs` (new) | ✅ exists (extends) and ❌ Wave 0 (optional split) |
| STREAM-07 | Each of five new atoms produces a non-empty `Rindle.Error.message/1` string; `:streaming_not_configured` clause is unchanged | unit | `mix test test/rindle/error_streaming_freeze_test.exs --color` | ❌ Wave 0 — new file |
| STREAM-08 | `Rindle.Capability.report/0` returns the locked top-level shape; `signed_playback_configured?` is `false` with no Mux config and `true` when both keys are set; does NOT crash when `:mux` dep is not loaded (D-30) | unit | `mix test test/rindle/capability_test.exs --color` | ❌ Wave 0 — new file |
| STREAM-09 | The five new error variants render byte-for-byte identical message text under the AV-06-05 freeze pattern; `@public_streaming_reasons` list is locked verbatim | unit (parity gate) | `mix test test/rindle/error_streaming_freeze_test.exs --color` | ❌ Wave 0 — new file (same as STREAM-07) |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/<focused_dir>/ --color` for the
  module(s) being touched. Per the test alias in `mix.exs:231`, this also
  runs `ecto.create --quiet` and `ecto.migrate --quiet` first, so the new
  migration is always applied before unit/integration tests run.
- **Per wave merge:** `mix test --color` (full suite). The full suite must
  remain green at every wave merge boundary — particularly important for
  STREAM-06 because it modifies a core delivery callsite that has 8+
  existing tests (`test/rindle/delivery_test.exs:340-391` and
  `test/rindle/contracts/telemetry_contract_test.exs:74, 277`).
- **Phase gate:** `mix test --color` plus `mix credo --strict --color`,
  `mix dialyzer`, `mix format --check-formatted` all green before
  `/gsd-verify-work`. (Existing CI lane includes all four; no Phase 33
  additions needed.)

### Wave 0 Gaps

The following test files / scaffolding must be created before STREAM-XX
implementation work begins. All gaps are inside `test/rindle/`; the existing
test infrastructure (Repo sandbox, Mox, fixtures) is sufficient.

- [ ] `test/rindle/streaming/capabilities_test.exs` — covers STREAM-01
- [ ] `test/rindle/streaming/provider_test.exs` — covers STREAM-02 (asserts `behaviour_info`)
- [ ] `test/rindle/domain/media_provider_asset_test.exs` — covers STREAM-03 + STREAM-04 (schema, changeset, Inspect)
- [ ] `test/rindle/domain/provider_asset_fsm_test.exs` — covers STREAM-04 (FSM matrix, telemetry)
- [ ] `test/rindle/error_streaming_freeze_test.exs` — covers STREAM-07 + STREAM-09 (parity freeze)
- [ ] `test/rindle/capability_test.exs` — covers STREAM-08
- [ ] (Optional split) `test/rindle/delivery/streaming_dispatch_test.exs` — covers STREAM-06; the alternative is to extend `test/rindle/delivery_test.exs` in-place
- [ ] **No new fixture, no new framework install.** Existing test infrastructure covers everything (Repo sandbox already in `test/test_helper.exs`; Mox / Bypass already loaded; ExMachina factories at `test/support/`). If executor wants new factories for `MediaProviderAsset`, that's a Wave 0 task in plan 2.

**Existing tests at risk that MUST remain green** (regressions to watch):
- `test/rindle/delivery_test.exs:352-380` — STREAM-06 must not break the existing `streaming_url/3` telemetry assertion.
- `test/rindle/delivery_test.exs:382-391` — STREAM-06 must not break the "does NOT emit when url resolution fails" assertion.
- `test/rindle/contracts/telemetry_contract_test.exs:74, 277` — STREAM-06 telemetry preservation contract.
- `test/rindle/error_test.exs` (entire file) — STREAM-07 additions must NOT alter any existing AV reason atom message text (D-26).
- `test/rindle/profile/validator_test.exs` — STREAM-05 must not regress existing image / AV / waveform variant validation.

---

## Security Domain

> `security_enforcement` is not explicitly set to `false` in `.planning/config.json`,
> so this section is required.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | Phase 33 ships zero auth-related code. |
| V3 Session Management | no | No sessions are created or managed in Phase 33. |
| V4 Access Control | yes | The dispatch tree (D-19) preserves `Rindle.Delivery`'s `authorize_delivery/4` step on the v1.4 progressive path, and the new provider path (step 5) delegates URL minting to the provider behaviour — but adopter-side authorization runs **before** dispatch, mirroring `lib/rindle/delivery.ex:128, 168`. No regression in v1.4 access control discipline. |
| V5 Input Validation | yes | NimbleOptions validation on `:streaming` DSL key (D-15..D-18) refuses unknown keys at compile time (D-16); `validate_inclusion/3` on schema state column rejects unknown states; FSM transition allowlist rejects every non-allowlisted state edge. |
| V6 Cryptography | n/a in Phase 33 | Phase 33 ships zero crypto code. The `verify_webhook/3` callback signature is declared in the behaviour but its **implementation** (HMAC-SHA256 + constant-time compare) is Phase 35's `Mux.Webhooks.verify_header/4` delegation — explicit "do not hand-roll" item per memo §3 + CONTEXT operational boundaries. |
| V7 Error Handling | yes | The `Rindle.Error` extensions return tagged atoms (`:provider_asset_not_ready`, etc.) with operator-actionable cause→action message text. STREAM-09 freezes message wording so error-handling code in adopter apps doesn't break on minor copy edits. |
| V8 Data Protection | yes (security invariant 14) | `defimpl Inspect, for: Rindle.Domain.MediaProviderAsset` (D-14) redacts `provider_asset_id` to `"...abcd"` and `raw_provider_metadata` to `%{redacted: true}`. `Rindle.Capability.report/0` (D-30) returns `signed_playback_configured?: boolean()` — never the underlying config keys. Encodes PROJECT.md security invariant 14 verbatim. |
| V9 Communication | n/a in Phase 33 | No outbound HTTP in Phase 33 (Phase 34's Mux REST calls are deferred). |
| V10 Malicious Code | n/a | Phase 33 adds zero new third-party deps. |
| V11 Business Logic | yes | The dispatch tree's `:strict` opt-in (D-20) is the explicit business-logic guardrail for adopters who want provider-only behavior; default is migration-friendly progressive fallback. |

### Known Threat Patterns for Elixir / Phoenix / Ecto Stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Provider ID exfiltration via inadvertent `inspect/2` in logs / telemetry | Information Disclosure | Schema-level `defimpl Inspect` (D-14); `Rindle.Capability.report/0` returns booleans not config (D-30); telemetry metadata redacts provider IDs to last-4-char tags (PROJECT.md invariant 14) |
| DSL injection via raw provider knobs | Tampering | NimbleOptions raises on unknown keys by default; the `@streaming_schema` is a closed allowlist (D-16) |
| FSM state corruption via direct `Repo.update/1` bypass | Tampering | `Rindle.Domain.ProviderAssetFSM.transition/3` is a pre-write guard; callers must invoke FSM before composing changeset; pattern locked across `MediaAsset`, `MediaVariant`, `MediaUploadSession` |
| SQL injection via dynamic provider lookup | Tampering | `Repo.get_by/2` uses parameterized queries (Ecto built-in); no string interpolation (D-21) |
| `provider_name` collision causing wrong-row dispatch | Tampering / Logic flaw | Unique index on `(provider_name, provider_asset_id)` partial-where (D-10); future v1.7 second-provider design will revisit `Module.split |> List.last |> Macro.underscore` per Pitfall 5 |
| Credential leak via Mux config logging | Information Disclosure | `Rindle.Capability.report/0` returns `signed_playback_configured?: boolean()` only (D-30); never returns the actual config keys |
| Time-of-check vs. time-of-use race on `state == :ready` lookup → URL minting | Race condition | Phase 33 ships the dispatch tree; the actual atomic-promote race protection (mirroring v1.4 AV-03-10) lives in Phase 34's `MuxIngestVariant` flip-to-ready path. Phase 33's lookup is read-only; the race is benign in this phase. |

---

## Sources

### Primary (HIGH confidence — direct repo evidence)

All claims about existing patterns are sourced from files in this repo, read
during research:

- `lib/rindle/streaming/provider.ex` — current 2-callback shim being replaced [VERIFIED: read in full]
- `lib/rindle/storage/capabilities.ex` — exact pattern for `Rindle.Streaming.Capabilities` [VERIFIED: read in full]
- `lib/rindle/domain/asset_fsm.ex` — exact pattern for `Rindle.Domain.ProviderAssetFSM` [VERIFIED: read in full]
- `lib/rindle/domain/media_asset.ex` — exact pattern for `Rindle.Domain.MediaProviderAsset` [VERIFIED: read in full]
- `lib/rindle/error.ex` — exact pattern for the five new `def message/1` clauses; line 195-221 is the `:streaming_not_configured` analog [VERIFIED: read in full]
- `lib/rindle/delivery.ex` — `streaming_url/3` body at lines 158-192 to be replaced; preserves `[:rindle, :delivery, :streaming, :resolved]` telemetry contract [VERIFIED: read in full]
- `lib/rindle/profile.ex` and `lib/rindle/profile/validator.ex` — DSL extension target; `@delivery_schema` at lines 35-48; `validate_delivery!/1` at lines 211-232 [VERIFIED: read in full]
- `lib/rindle/storage.ex` — behaviour-pattern reference for `@callback` discipline [VERIFIED: read in full]
- `lib/rindle/processor.ex` — minimal-behaviour pattern reference [VERIFIED: read in full]
- `lib/mix/tasks/rindle.doctor.ex` and `lib/rindle/ops/runtime_checks.ex` — current `report` shape; aggregator pattern for `Rindle.Capability.report/0` [VERIFIED: read in full]
- `priv/repo/migrations/20260424155129_create_media_assets.exs` — additive-migration template [VERIFIED: read in full]
- `priv/repo/migrations/20260502120000_extend_media_for_av.exs` — additive AV migration; the immediate predecessor [VERIFIED: read in full]
- `test/rindle/error_test.exs` — AV-06-05 freeze pattern; STREAM-09 mirror target [VERIFIED: read in full]
- `test/rindle/domain/lifecycle_fsm_test.exs` — FSM matrix test pattern [VERIFIED: read first 80 lines]
- `test/rindle/delivery_test.exs:340-391` — existing `streaming_url/3` telemetry tests that STREAM-06 must NOT regress [VERIFIED: read with offset]
- `mix.exs` — existing dependency set; confirmation that no new deps are needed for Phase 33 [VERIFIED: read in full]
- `.planning/PROJECT.md` — security invariants, especially invariant 14 [VERIFIED: read in full]
- `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` — locked memo with verbatim §4 callbacks, §5 DSL+dispatch, §6 migration, §8.2 errors [VERIFIED: read in full]

### Secondary (MEDIUM confidence — referenced from CONTEXT.md but not re-verified externally)

- Memo §4 verbatim callback signatures [CITED: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` §4]
- Memo §6 verbatim migration column set [CITED: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` §6]
- Memo §5.1 verbatim dispatch tree [CITED: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` §5.1]
- Memo §5.2 verbatim profile DSL extension [CITED: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` §5.2]
- Memo §8.2 verbatim error vocabulary [CITED: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` §8.2]
- Memo §8.4 telemetry kind extension semantics [CITED: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` §8.4]
- Memo §9 row 14 — security invariant on raw provider IDs [CITED: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` §9]

### Tertiary (LOW confidence — none required for Phase 33)

Phase 33 is contract-extension work; no external doc lookups (Hex.pm,
Elixir Forum, NimbleOptions docs) were necessary because every load-bearing
pattern is mirrored from existing in-repo code with HIGH-confidence
provenance.

The CONTEXT.md "Ecosystem references that informed locked decisions" lists
`hexdocs.pm/oban`, `hexdocs.pm/ecto/Ecto.Migration`, and
`hexdocs.pm/nimble_options` — these informed the **memo's** decisions and
do not need re-verification in Phase 33, because the patterns Phase 33
mirrors are already in the v1.4-shipped repo code (which itself uses these
libraries idiomatically).

---

## Assumptions Log

> Per the front-loaded prompt: every claim that wasn't directly sourced from
> repo file content or memo §-cited verbatim is tagged below.

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| (none) | — | — | — |

**This table is empty.** Every claim in this research is either:
- `[VERIFIED]` from a file actually read during this session (every load-bearing pattern), OR
- `[CITED]` from `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` (which CONTEXT.md elevates as the source of truth and which the user already locked via D-32 / decide-by-default), OR
- An obvious convention (e.g., `mix test --color` is the standard test command pattern across the repo's test alias and CI).

There is no `[ASSUMED]` claim that needs user confirmation. The locked memo
+ CONTEXT.md left no contract-shaping decisions for the researcher to
assume; only **discretion** items remain (NimbleOptions schema layout
exact form, FSM file co-location, migration timestamp, etc.), and those
are explicitly delegated to the executor per CONTEXT's "Claude's Discretion"
block — they do not require user confirmation.

---

## Open Questions (RESOLVED)

1. **Should `Rindle.Streaming.Capabilities` ship `supports?/2` even though the comparable `Rindle.Storage.Capabilities` ships `require_upload/2` + `require_delivery/2`?**
   - What we know: D-03 explicitly omits `require_streaming/2` (deferred to Phase 37 / MUX-22). The Storage analog has both `supports?/2` (line 45-46) AND `require_upload/2` (line 48-56) AND `require_delivery/2` (line 58-66).
   - What's unclear: D-03 only mentions omitting `require_streaming/2`; it does NOT say whether `supports?/2` should ship.
   - Recommendation: Ship `supports?/2` (it's the boolean predicate version of `require_*/2` and is harmless in isolation; `Rindle.Capability.report/0` will benefit from it indirectly). Plan can omit it and Phase 37 can add it alongside `require_streaming/2` if executor prefers strict minimalism. **The CODE EXAMPLE above includes `supports?/2`; this is the recommended choice.**
   - **RESOLVED:** Ship `supports?/2` in `Rindle.Streaming.Capabilities` alongside `known/0` and `safe/1` (boolean predicate; harmless without `require_streaming/2`).

2. **In the `:streaming.source_variant` validator, when does the variant existence check run — before or after individual variant validation?**
   - What we know: D-18 says check that the atom is declared in `variants/0`. The existing `validate!/1` in `lib/rindle/profile/validator.ex:168-189` runs `validate_variants!` before `validate_delivery!`.
   - What's unclear: The cleanest refactor either (a) passes the validated variants list into `validate_delivery!/1` so the check happens inline, or (b) does a post-validate check at the top of `validate!/1` after both have run independently.
   - Recommendation: Option (b) — a single post-check function called at the end of `validate!/1`. Cleaner separation, less coupling. Executor discretion per CONTEXT.md.
   - **RESOLVED:** Run `source_variant` existence check at end of `Rindle.Profile.Validator.validate!/1` (cleaner separation than embedding in `validate_delivery!/1`).

3. **Should the dispatch tree's "step 6 progressive fallback" emit a different telemetry metadata field (e.g., `streaming_provider_configured: true | false`) so observability can distinguish "old v1.4 progressive" from "v1.6 fell back from provider"?**
   - What we know: D-24 says "the same event fires with `kind: :hls`" once Phase 34 lights up; v1.4 contract preserved otherwise.
   - What's unclear: Whether observability practitioners will want to distinguish "no streaming configured" from "streaming configured but no row yet."
   - Recommendation: **Don't add new metadata fields in Phase 33.** D-24 explicitly says "preserved unchanged." If Phase 34 / Phase 36 demonstrate a need, extend additively then. Resist scope creep.
   - **RESOLVED:** Do NOT add new metadata fields to step-6 progressive fallback. D-24 says preserved unchanged; resist scope creep.

These three open questions are all in "Claude's Discretion" territory per CONTEXT.md; recommendations are documented for the planner.

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — Every dep used is already in `mix.exs`. No new external deps. Verified against `mix.exs` directly.
- Architecture: HIGH — Every pattern is mirrored from existing v1.4 / v1.5 code; load-bearing analog files were read in full and quoted.
- Pitfalls: HIGH — Pitfalls 1, 3, 4 are sourced from the existing test patterns and v1.4 callsite shapes. Pitfall 5 is documented as a v1.7 concern (not Phase 33 mitigation).
- Security: HIGH — security invariant 14 is explicitly listed in PROJECT.md; the redaction patterns (Inspect impl, capability report boolean) are direct encodings.
- Validation Architecture: HIGH — Existing test framework / sandboxing / Mox stack covers everything; Wave 0 gaps are limited to scaffolding new test files (no infrastructure additions).

**Research date:** 2026-05-06
**Valid until:** 2026-06-06 (30 days; Rindle codebase moves slowly — v1.4 was
2026-05-05 ship, v1.5 was 2026-05-06 ship; the patterns this research mirrors
have been stable across both)

---

## RESEARCH COMPLETE

**Phase:** 33 — Provider Boundary + State Schema
**Confidence:** HIGH

### Key Findings

1. **Phase 33 is contract-extension only — zero new external dependencies.** Every dep is already in `mix.exs` (`:nimble_options ~> 1.1`, `:ecto_sql ~> 3.11`, `:telemetry ~> 1.2`). Mux + JOSE arrive in Phase 34.
2. **Every load-bearing piece has an exact analog in the existing repo** — `Rindle.Streaming.Capabilities` mirrors `Rindle.Storage.Capabilities`; `Rindle.Domain.MediaProviderAsset` mirrors `Rindle.Domain.MediaAsset`; `Rindle.Domain.ProviderAssetFSM` mirrors `Rindle.Domain.AssetFSM`; the new migration mirrors `priv/repo/migrations/20260424155129_create_media_assets.exs`; the freeze test mirrors `test/rindle/error_test.exs` (AV-06-05 pattern). Planner's job is "mirror-and-extend", not "design-from-scratch."
3. **The 4-plan ROADMAP guidance maps cleanly to STREAM-XX axes**: (1) Capabilities + Provider behaviour, (2) Migration + Schema + FSM + Inspect-redaction, (3) Profile DSL + dispatch tree, (4) Error vocab + parity gate + Capability.report. Cross-plan coupling is minimal.
4. **The single largest landmine is regression of `[:rindle, :delivery, :streaming, :resolved]` telemetry** when replacing the no-op delegate body. The v1.4 progressive path body (`lib/rindle/delivery.ex:160-192`) MUST be preserved verbatim and called from BOTH the streaming-nil branch AND the no-row-progressive branch (D-24 + Pitfall 3). Existing tests at `test/rindle/delivery_test.exs:352-391` are the regression tripwire.
5. **Security invariant 14 (added v1.6) lives entirely at the schema layer** via the custom `defimpl Inspect` on `MediaProviderAsset` (D-14) plus `Rindle.Capability.report/0` returning `signed_playback_configured?: boolean()` instead of the actual config keys (D-30). Both are mandatory.

### File Created

`/Users/jon/projects/rindle/.planning/phases/33-provider-boundary-state-schema/33-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|---|---|---|
| Standard Stack | HIGH | Every dep verified against `mix.exs` directly; no new deps added. |
| Architecture | HIGH | All eight load-bearing patterns are direct mirrors from existing v1.4 / v1.5 files (read in full during research). |
| Pitfalls | HIGH | Pitfalls 1, 3, 4 sourced from existing freeze test + telemetry contract test + schema state convention; Pitfalls 2, 5, 6, 7 are forward-looking risk-flags traceable to the locked memo + CONTEXT decisions. |
| Code Examples | HIGH | All seven code examples are mirror skeletons — direct shape copies from existing repo files with the new specifics filled in. |
| Validation Architecture | HIGH | Existing test framework covers all 9 STREAM-XX requirements; Wave 0 gaps are limited to 6-7 new test files (zero infrastructure changes). |

### Open Questions

Three Claude's-Discretion items were surfaced (see "Open Questions" section);
none are user-facing. Recommendations are documented for the planner:
- Ship `supports?/2` in `Rindle.Streaming.Capabilities` (recommended).
- Run `source_variant` existence check at end of `validate!/1` (recommended).
- Don't add new telemetry metadata fields to step-6 progressive fallback (recommended).

### Ready for Planning

Research complete. Planner can now create 4 PLAN.md files along the locked
4-plan ROADMAP axes; every load-bearing analog file path, line range, and
verbatim shape needed is documented above.
