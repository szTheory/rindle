# Phase 66: Proof & adopter guidance - Research

**Researched:** 2026-05-27
**Domain:** PROOF-01 hermetic test matrix + TRUTH-01 guide/docs parity for Mux direct-upload cancel
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- PROOF-01 closes in default `mix test` — not install-smoke generated-app lane (D-01).
- Extend `cancel_direct_upload_test.exs`, keep `mux_cancel_upload_test.exs` as-is (D-02, D-12).
- Add `http_cancel_upload_test.exs` for HTTP 403/404 only; add `base_url` passthrough in `build_client/0` (D-04, D-05).
- Create→cancel integration via real `create_direct_upload/2` (D-03).
- Streaming edge matrix: idempotent re-cancel, `:not_cancellable` table, missing upload_id, provider failure no rollback (D-06..D-10).
- TRUTH-01: cancel subsection under §4.1, §10 Oban disambiguation, intro bullet, docs parity test (D-13..D-17).
- Do NOT extend `direct_upload_flow_test.exs` (webhook-only story).

### Out of scope
- New public API, LiveView helper, MediaAsset purge, PubSub, Oban retry worker, second provider, tus cancel.

### Claude's Discretion
- Exact test names; optional quota failure test (D-10); guide prose satisfying D-14 checklist.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROOF-01 | Hermetic Mux adapter tests and Streaming integration tests cover happy-path cancel, idempotent re-cancel, and non-cancellable states | Two-plan wedge: HTTP Bypass + streaming matrix (66-01), then guide + parity (66-02). |
| TRUTH-01 | `guides/streaming_providers.md` documents cancel semantics, fresh-URL contrast, Mux-only v1.13 scope | §4.1 subsection + §10 disambiguation + `streaming_cancel_docs_parity_test.exs`. |
</phase_requirements>

## Summary

Phase 66 completes the proof/documentation wedge deferred from Phases 64–65. Implementation is shipped; this phase adds tests and adopter-facing truth only.

**HTTP idempotency gap:** Phase 65 maps 403/404→`:ok` in `Mux.HTTP.cancel_upload/1` but only exercises it via `ClientMock` returning `:ok`. Phase 66 adds Bypass tests hitting real `Uploads.cancel/2` through `Mux.HTTP` with `base_url` redirected — same seam as GCS (`Keyword.get(cfg, :base_url)` → client opts).

**Streaming matrix gap:** Phase 65 shipped one happy-path hermetic test (hand-inserted `uploading` row). Phase 66 adds create→cancel integration, idempotent double-call, table-driven `:not_cancellable`, missing upload_id, and provider-failure-without-rollback cases.

**Guide gap:** §4.1 ends at fresh-URL note with no cancel guidance; §10 "cancel" means Oban job cancel — adopters will confuse the two without TRUTH-01.

**Primary recommendation:** Two plans in two waves — PROOF-01 test matrix (wave 1), TRUTH-01 guide + docs parity CI (wave 2).

## Standard Stack

| Component | Version | Role |
|-----------|---------|------|
| ExUnit + Mox | existing | Streaming/adapter hermetic tests via `ClientMock` |
| Bypass | existing (GCS precedent) | HTTP 403/404 idempotency on `Mux.HTTP` |
| `mux` | 3.2.2 | `Mux.Video.Uploads.cancel/2` → `PUT /video/v1/uploads/{id}/cancel` |

No new dependencies.

## Architecture Patterns

### Test layering (mirror Phase 65→66 wedge)

```
PROOF-01 coverage
├── http_cancel_upload_test.exs     — real HTTP module, Bypass 403/404
├── mux_cancel_upload_test.exs      — unchanged (ClientMock adapter normalization)
└── cancel_direct_upload_test.exs   — Streaming orchestration matrix + create→cancel
```

### base_url seam (D-04)

```elixir
defp build_client do
  cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

  with {:ok, token_id} <- fetch_required(cfg, :token_id),
       {:ok, token_secret} <- fetch_required(cfg, :token_secret) do
    base_opts =
      case Keyword.get(cfg, :base_url) do
        url when is_binary(url) -> [base_url: url]
        _ -> []
      end

    {:ok, Mux.Base.new(token_id, token_secret, base_opts)}
  end
end
```

### Bypass cancel path

Mux SDK: `PUT /video/v1/uploads/{upload_id}/cancel` with Basic auth.

Bypass setup: open Bypass, set `Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, http_client: Rindle.Streaming.Provider.Mux.HTTP, base_url: "http://localhost:#{port}", token_id/secret: test values)`, call `Mux.HTTP.cancel_upload/1` directly (not through adapter — adapter would map 403 to `:provider_sync_failed` per D-05).

### Streaming test patterns (reuse Phase 65 harness)

- `DirectUploadProfile` module + `ClientMock` Application env — copy from `cancel_direct_upload_test.exs` / `create_direct_upload_test.exs`.
- Table-driven `:not_cancellable`: `@tag state: "processing"` etc.; use `reject(&ClientMock.cancel_upload/1)` or `stub` with flunk.
- Idempotent re-cancel: `stub(ClientMock, :cancel_upload, fn _ -> :ok end)` allowing two calls; assert `:ok` twice.
- Provider failure: `expect(..., fn _ -> {:error, :provider_sync_failed} end)` after first transition; re-fetch row → `state == "deleted"`.

### Docs parity pattern

Mirror `phoenix_tus_truth_parity_test.exs`: read `guides/streaming_providers.md`, assert substring checklist from D-17.

## Validation Architecture

| Behavior | Requirement | Test Type | Command |
|----------|-------------|-----------|---------|
| Mux HTTP 403/404 idempotency | PROOF-01 | unit (Bypass) | `mix test test/rindle/streaming/provider/mux/http_cancel_upload_test.exs` |
| Create→cancel integration | PROOF-01 | integration | `mix test test/rindle/streaming/cancel_direct_upload_test.exs` |
| Idempotent re-cancel | PROOF-01 | integration | same |
| `:not_cancellable` matrix | PROOF-01 | integration | same |
| Missing upload_id | PROOF-01 | integration | same |
| Provider failure no rollback | PROOF-01 | integration | same |
| Guide cancel semantics | TRUTH-01 | docs parity | `mix test test/install_smoke/streaming_cancel_docs_parity_test.exs` |
| Public export (regression) | PROOF-01 | contract | `mix test test/rindle/streaming/cancel_direct_upload_contract_test.exs` |

Phase-scoped verification command (from CONTEXT):

```bash
mix test test/rindle/streaming/cancel_direct_upload_contract_test.exs \
         test/rindle/streaming/cancel_direct_upload_test.exs \
         test/rindle/streaming/provider/mux_cancel_upload_test.exs \
         test/rindle/streaming/provider/mux/http_cancel_upload_test.exs \
         test/install_smoke/streaming_cancel_docs_parity_test.exs
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Bypass test uses adapter instead of HTTP | Test `Mux.HTTP.cancel_upload/1` directly with `http_client` unset (defaults to HTTP module) |
| Mock 403 at adapter layer | D-05: only HTTP module tests exercise status codes; adapter tests stay ClientMock `:ok` |
| Guide §10 Oban wording confuses adopters | D-15 explicit "Provider upload cancel vs Oban job cancel" block with link to §4.1 |
| Copying delete_asset 404 test gap | Bypass tests for cancel per D-04; do not mock terminal states at ClientMock only |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/66-proof-adopter-guidance/66-CONTEXT.md` — locked D-01..D-17
- `.planning/phases/65-mux-cancel-implementation/65-RESEARCH.md` — deferred matrix items
- `lib/rindle/streaming/provider/mux/http.ex` — cancel_upload/1, build_client/0
- `test/rindle/storage/gcs_concatenate_test.exs` — Bypass + base_url precedent
- `test/install_smoke/phoenix_tus_truth_parity_test.exs` — docs parity template

### Secondary (HIGH confidence)
- `deps/mux/lib/mux/tesla.ex` — `Mux.Base.new/3` accepts `base_url:` opt
- `deps/mux/lib/mux/video/uploads.ex` — cancel path `/video/v1/uploads/{id}/cancel`
- `guides/streaming_providers.md` — §4.1 and §10 edit sites
