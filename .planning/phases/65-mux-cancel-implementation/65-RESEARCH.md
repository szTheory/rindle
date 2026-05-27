# Phase 65: Mux cancel implementation - Research

**Researched:** 2026-05-27
**Domain:** Mux direct-upload cancel HTTP stack + FSM-first `Streaming.cancel_direct_upload/1`
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- FSM-first conditional `update_all` to `deleted` before provider HTTP (D-01..D-07).
- `@cancellable_states ~w(pending uploading)` shared with FSM parity tests (D-02).
- Row lookup by `asset_id` + `ingest_mode: "direct_creator_upload"` only (D-08..D-10).
- Mux HTTP maps 403 and 404 → `:ok`; adapter maps 429 / other 4xx/5xx (D-11..D-14).
- Provider failure after local `deleted` does not roll back (D-15..D-17).
- Phase 65 test wedge: contract export flip + one happy-path hermetic test (D-18..D-20).

### Out of scope
- Full PROOF-01 matrix, guide, integration create→cancel — Phase 66.
- Oban retry, PubSub, MediaAsset purge, LiveView helper.

### Claude's Discretion
- Private helper names; optional telemetry on partial provider failure.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CANCEL-04 | Mux adapter `cancel_direct_upload/1` via `Uploads.cancel/2`; facade orchestrates FSM + adapter | Two-plan wedge: Mux stack (65-01) then `Streaming.cancel_direct_upload/1` (65-02). |
</phase_requirements>

## Summary

Phase 65 implements the body deferred from Phase 64. The Mux SDK (`mux` 3.2.2) exposes `Mux.Video.Uploads.cancel/2`. The implementation mirrors the existing `create_upload` / `delete_asset` layering: `Mux.Client` behaviour → `Mux.HTTP` SDK wrapper → `Mux` adapter normalization → `Rindle.Streaming` orchestration.

**Critical idempotency correction:** Mux returns **403** (not only 404) when an upload is already `cancelled`, `timed_out`, or `asset_created`. Mapping both 403 and 404 to `:ok` at the HTTP layer (D-12) prevents false `:provider_sync_failed` on re-cancel — unlike `delete_asset/1` which only needs 404.

**Race guard:** Conditional `Repo.update_all` with `state IN @cancellable_states` prevents TOCTOU with `video.upload.asset_created` webhook linker (already rejects `deleted` rows).

**Primary recommendation:** Two plans in two waves — Mux HTTP stack (wave 1), Streaming orchestration + contract flip + happy-path test (wave 2).

## Standard Stack

| Component | Version | Role |
|-----------|---------|------|
| `mux` | 3.2.2 | `Mux.Video.Uploads.cancel/2` |
| Ecto | mix.lock | Conditional `update_all` FSM gate |
| ExUnit + Mox | existing | `ClientMock` hermetic tests |

No new dependencies.

## Architecture Patterns

### Layering (mirror create/delete)

```
Streaming.cancel_direct_upload(asset_id)
  → load MediaProviderAsset row
  → conditional update_all → deleted
  → provider.cancel_direct_upload(provider_upload_id)
       → Mux.cancel_direct_upload/1
            → http_client().cancel_upload(upload_id)
                 → Uploads.cancel(client, upload_id)
```

### HTTP idempotency (D-12)

```elixir
case Uploads.cancel(client, upload_id) do
  {:ok, _body, _env} -> :ok
  {:error, _msg, %{status: status}} when status in [403, 404] -> :ok
  {:error, msg, env} -> {:error, msg, env}
end
```

### Adapter normalization (D-13, mirror create_direct_upload)

```elixir
case http_client().cancel_upload(upload_id) do
  :ok -> :ok
  {:error, _msg, %{status: 429}} -> {:error, :provider_quota_exceeded}
  {:error, _msg, %{status: status}} when status in 500..599 -> {:error, :provider_sync_failed}
  {:error, _msg, %{status: status}} when status in 400..499 -> {:error, :provider_sync_failed}
  {:error, reason} -> {:error, reason}
end
```

### Streaming orchestration sketch (D-01..D-07)

```elixir
@cancellable_states ~w(pending uploading)

def cancel_direct_upload(asset_id) when is_binary(asset_id) do
  repo = Rindle.Config.repo()

  with {:ok, row} <- fetch_direct_upload_row(repo, asset_id),
       {:ok, profile} <- resolve_profile(row),
       {:ok, streaming} <- fetch_streaming_config(profile),
       :ok <- require_direct_upload_capability(streaming.provider),
       {:ok, upload_id} <- require_upload_id(row),
       {:ok, from_state} <- transition_to_deleted(repo, row),
       :ok <- best_effort_provider_cancel(streaming.provider, upload_id, row, from_state) do
    :ok
  end
end
```

`transition_to_deleted/2` uses `{count, _} = repo.update_all(...)` WHERE `id` and `state in @cancellable_states`; on `{0,_}` re-read and classify `deleted` vs `:not_cancellable`.

### Test wedge (D-18..D-20)

- Flip `cancel_direct_upload_contract_test.exs`: `assert function_exported?/2`.
- New `cancel_direct_upload_test.exs` (or extend create test file): insert `pending` row with `provider_upload_id`, `expect(ClientMock, :cancel_upload, ...)`, assert `:ok` and `state == "deleted"`.

## Code Examples

### Extend Client behaviour

```elixir
@callback cancel_upload(upload_id :: String.t()) ::
            :ok | {:error, term()} | {:error, term(), term()}
```

### Capabilities check

`Capabilities.supports?(provider, :direct_creator_upload)` already used by `create_direct_upload/2` — reuse for cancel.

## Validation Architecture

| Behavior | Requirement | Test Type | Command |
|----------|-------------|-----------|---------|
| Mux HTTP 403/404 idempotency | CANCEL-04 | unit (adapter via mock) | `mix test test/rindle/streaming/provider/mux/` |
| Adapter 429/5xx normalization | CANCEL-04 | unit | same |
| FSM conditional update | CANCEL-04 | integration | `mix test test/rindle/streaming/cancel_direct_upload_test.exs` |
| Public export | CANCEL-04 | contract | `mix test test/rindle/streaming/cancel_direct_upload_contract_test.exs` |
| Happy path cancel | CANCEL-04 | hermetic | `mix test test/rindle/streaming/cancel_direct_upload_test.exs` |

Deferred to Phase 66: idempotent re-cancel, `:not_cancellable` matrix, Mux 403 adapter tests, create→cancel integration.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| FSM/SQL drift | `@cancellable_states` module attribute + test asserting parity with `ProviderAssetFSM.allowed_transitions/0` |
| 403 treated as failure | HTTP layer owns 403→`:ok` before adapter |
| Provider call inside transaction | HTTP strictly after `update_all`, no `Repo.transaction` wrapper |
| `String.to_atom` on profile | `String.to_existing_atom/1` only (D-09) |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/65-mux-cancel-implementation/65-CONTEXT.md` — locked decisions
- `lib/rindle/streaming/provider/mux.ex` — create/delete normalization
- `lib/rindle/streaming/provider/mux/http.ex` — SDK wrapper patterns
- `.planning/research/v1.8/MUX-DIRECT-UPLOAD-RESEARCH.md` — 403 idempotency

### Secondary (HIGH confidence)
- `.planning/phases/64-cancel-contract-persistence/64-RESEARCH.md` — Phase 65 orchestration notes
- `lib/rindle/workers/ingest_provider_webhook.ex` — `deleted` row rejection
