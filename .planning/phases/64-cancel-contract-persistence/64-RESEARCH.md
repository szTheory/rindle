# Phase 64: Cancel contract & persistence - Research

**Researched:** 2026-05-27
**Domain:** Streaming direct-upload cancel contract freeze, `provider_upload_id` persistence, FSM terminal edges, security invariant 14
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Public API keyed by Rindle `asset_id` only; bare `:ok` success; no bang variant (D-01..D-05).
- Locked error vocabulary including `:not_cancellable` tagged maps (D-06..D-13).
- Additive `provider_upload_id` column + partial unique index; persist at `create_direct_upload/2` mint time (D-14..D-19).
- FSM edges `pending → deleted` and `uploading → deleted`; FSM-first race orchestration spec (D-20..D-23).
- Optional `cancel_direct_upload/1` on `Rindle.Streaming.Provider`; capability gate `:direct_creator_upload` (D-24..D-27).
- Redact `provider_upload_id` via `@writable`, `Inspect`, and `redact_id/1` (D-28..D-30).

### Out of scope (Phase 65+)
- `Rindle.Streaming.cancel_direct_upload/1` **implementation body**
- Mux adapter `cancel_direct_upload/1` HTTP wiring
- Hermetic/integration tests and guide updates (Phase 66)

### Claude's Discretion
- Exact `Rindle.Error.message/1` copy for `:not_cancellable` forms.
- Migration timestamp/name following repo conventions.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CANCEL-01 | Adopter can cancel via `cancel_direct_upload/1` with `asset_id` | Phase 64 freezes `@type`/`@typedoc`, provider callback, and moduledoc orchestration spec; **function body ships Phase 65**. |
| CANCEL-02 | Idempotent `:ok` vs tagged `:not_cancellable` errors | Phase 64 locks error atoms + `Rindle.Error` messages + FSM allowlist; behaviour tests for FSM/errors in 64; full cancel flow in 65. |
| CANCEL-03 | `create_direct_upload/2` persists `upload_id` redacted per invariant 14 | Migration + schema + `create_direct_upload/2` Multi branch + test assertion on `provider_upload_id`. |
</phase_requirements>

## Summary

Phase 64 is a **contract-and-persistence wedge** on top of shipped v1.6/v1.8 direct-upload machinery. The Mux adapter already returns `upload_id` from `create_direct_upload/2`, but `Rindle.Streaming.create_direct_upload/2` discards it today — only `upload_url` and `asset_id` reach adopters. The highest-leverage 64 work is: (1) persist `provider_upload_id` in the existing `Multi.run(:direct_upload, ...)` success path, (2) add FSM terminal edges to `"deleted"`, (3) freeze the public error surface and provider behaviour callback, and (4) extend redaction parity with `mux_passthrough` / `provider_asset_id`.

`ProviderAssetFSM` currently has no path from `pending` or `uploading` to `deleted` — only `ready` and `errored` reach `deleted`. Adding `pending → deleted` and `uploading → deleted` unblocks Phase 65's FSM-first conditional update without touching webhook handlers (`deleted` rows already reject `video.upload.asset_created` promotion).

**Primary recommendation:** Four plans in two waves — migration/schema (wave 1), FSM + provider callback (wave 1), create persistence + test (wave 2), error/types contract freeze (wave 2).

## Standard Stack

| Component | Version | Role |
|-----------|---------|------|
| `ecto_sql` | mix.lock | Migration + `MediaProviderAsset` changeset |
| `mux` | 3.2.2 | SDK exposes `Mux.Video.Uploads.cancel/2` (Phase 65) |
| ExUnit + Mox | existing | `create_direct_upload` persistence test pattern |

No new dependencies.

## Architecture Patterns

### Persistence at mint time

`lib/rindle/streaming.ex` lines 68-78: adapter returns `{:ok, %{upload_url, upload_id, ...}}` but update only sets `state: "uploading"`. Phase 64 must extend the changeset update to include `provider_upload_id: upload_id` from the adapter result map (key is `upload_id` in adapter return, column is `provider_upload_id` per D-14).

### Migration precedent

Mirror `priv/repo/migrations/20260524120000_add_mux_passthrough_to_media_provider_assets.exs`:
- `add :provider_upload_id, :string`
- partial unique index `(provider_name, provider_upload_id) WHERE provider_upload_id IS NOT NULL`

### FSM change

```elixir
# Current (excerpt)
"pending" => ["uploading", "errored"],
"uploading" => ["processing", "errored"],

# Target
"pending" => ["uploading", "errored", "deleted"],
"uploading" => ["processing", "errored", "deleted"],
```

### Provider behaviour

Add optional callback (D-24):

```elixir
@callback cancel_direct_upload(upload_id :: String.t()) :: :ok | {:error, term()}
@optional_callbacks [create_direct_upload: 2, cancel_direct_upload: 1]
```

### Error freeze pattern

Follow `test/rindle/error_streaming_freeze_test.exs` — add `:not_cancellable` to public atoms list and byte-for-byte message tests for tagged `reason` forms passed through `Rindle.Error.message/1`.

### Public cancel function deferral

`Streaming.cancel_direct_upload/1` **def** and orchestration body belong in Phase 65 per CONTEXT. Phase 64 ships:
- `@type cancel_direct_upload_result` and `not_cancellable_detail` in `streaming.ex`
- `@typedoc` + moduledoc subsection documenting FSM-first orchestration (D-22)
- Provider callback + error vocabulary

Contract test can assert types are defined and FSM allows cancel edges without calling a not-yet-exported function.

### Mux cancel idempotency (Phase 65 reference)

`delete_asset/1` maps 404 → `:ok` (`lib/rindle/streaming/provider/mux.ex:301-304`). Phase 65 `cancel_direct_upload/1` should mirror for Mux upload already cancelled/timed_out/404.

## Code Examples

### Extend create_direct_upload persistence

```elixir
case streaming.provider.create_direct_upload(profile, adapter_opts) do
  {:ok, %{upload_url: upload_url, upload_id: upload_id}} ->
    case provider_asset
         |> MediaProviderAsset.changeset(%{
           state: "uploading",
           provider_upload_id: upload_id
         })
         |> repo.update() do
```

### Inspect redaction

```elixir
provider_upload_id: Rindle.Domain.MediaProviderAsset.redact_id(asset.provider_upload_id),
```

### create_direct_upload_test assertion (add)

```elixir
assert provider_row.provider_upload_id == "mux-upload-id-123"
refute inspect(provider_row) =~ "mux-upload-id-123"
```

## Anti-Patterns

- Storing `upload_id` in `raw_provider_metadata` (webhook clobber) — D-18
- Reusing `mux_passthrough` as cancel handle — D-17
- Exposing `{:invalid_transition, _, _}` on public cancel API — D-12
- Returning Mux 404 as `{:error, :not_found}` — D-07
- Adding `"cancelled"` FSM state — D-20

## Validation Architecture

| Property | Value |
|----------|-------|
| Framework | ExUnit (Mix) |
| Quick run | `mix test test/rindle/streaming/create_direct_upload_test.exs test/rindle/domain/provider_asset_fsm_test.exs test/rindle/error_streaming_freeze_test.exs` |
| Full suite | `mix test` |
| Migration verify | `test/rindle/domain/migration_test.exs` catalog introspection |

### Per-requirement verification

| REQ | Automated command | File |
|-----|-------------------|------|
| CANCEL-03 | `mix test test/rindle/streaming/create_direct_upload_test.exs` | asserts `provider_upload_id` persisted + redacted inspect |
| CANCEL-02 (partial) | `mix test test/rindle/domain/provider_asset_fsm_test.exs` | FSM `pending/uploading → deleted` |
| CANCEL-01/02 (partial) | `mix test test/rindle/error_streaming_freeze_test.exs` | `:not_cancellable` messages frozen |
| Schema | `mix test test/rindle/domain/migration_test.exs` | column + partial unique index |

## RESEARCH COMPLETE
