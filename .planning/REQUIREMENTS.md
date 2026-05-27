# Requirements — Milestone v1.13 Cancel Direct Upload

**Milestone:** v1.13 — started 2026-05-27  
**Goal:** Close the remaining Mux direct-upload control gap with a narrow public
`cancel_direct_upload/1` surface.

## Requirements

### Public API

- [x] **CANCEL-01**: Adopter can cancel an in-flight direct creator upload via
  `Rindle.Streaming.cancel_direct_upload/1` using the `asset_id` returned from
  `create_direct_upload/2`.

- [x] **CANCEL-02**: Cancel returns `:ok` when the upload is already terminal
  (idempotent re-cancel); returns tagged errors when the asset is not a direct
  creator upload or is not cancellable (e.g. already processing/ready).

### Provider & persistence

- [x] **CANCEL-03**: `create_direct_upload/2` persists the provider `upload_id`
  on the provider row (redacted per security invariant 14 in logs, telemetry,
  and `inspect/2`).

- [ ] **CANCEL-04**: Optional `cancel_direct_upload/1` callback on
  `Rindle.Streaming.Provider`; Mux adapter calls `Mux.Video.Uploads.cancel/2`
  and transitions the provider row to a terminal cancelled/deleted state.

### Proof & support truth

- [ ] **PROOF-01**: Hermetic Mux adapter tests and `Streaming` integration tests
  cover happy-path cancel, idempotent re-cancel, and non-cancellable states.

- [ ] **TRUTH-01**: `guides/streaming_providers.md` documents cancel semantics,
  when adopters should call cancel vs. request a fresh upload URL, and that
  provider-side cancel is Mux-only in v1.13.

## Future Requirements

- **LIFE-05**: Admin/bulk owner-erasure orchestration (batch preview/execute or mix task).
- **STREAM-10**: Second streaming provider as contract test (explicit demand only).
- **MUX-25+**: Provider-agnostic cancel for future adapters (when a second provider ships).

## Out of Scope

| Feature | Reason |
|---------|--------|
| LiveView auto-cancel hook | Adopters call `cancel_direct_upload/1` explicitly; no new helper in v1.13 |
| Local `MediaAsset` purge on cancel | Provider upload abort only; asset row cleanup stays maintenance/erasure scope |
| tus/resumable cancel changes | Separate, already-shipped broker paths |
| Second streaming provider cancel | Mux-only wedge; contract extension deferred |
| Force-delete / bulk erasure | Higher blast radius; separate milestone |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CANCEL-01 | 64, 65 | Complete |
| CANCEL-02 | 64, 65 | Complete |
| CANCEL-03 | 64 | Complete |
| CANCEL-04 | 65 | pending |
| PROOF-01 | 66 | pending |
| TRUTH-01 | 66 | pending |
