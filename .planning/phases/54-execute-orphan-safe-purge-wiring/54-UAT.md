---
status: complete
mode: shift-left
phase: 54-execute-orphan-safe-purge-wiring
source:
  - 54-01-SUMMARY.md
  - 54-02-SUMMARY.md
started: 2026-05-26T13:43:19Z
updated: 2026-05-26T13:43:19Z
human_steps_required: 0
automation_deferred: []
---

## Current Test

[testing complete]

## Tests

### 1. Public owner-erasure facade is callable and contract-shaped
expected: `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` are public facade entrypoints with the documented semantic report vocabulary.
result: pass
evidence:
  - `mix test test/rindle/owner_erasure_test.exs test/rindle/api_surface_boundary_test.exs --seed 0`
  - `lib/rindle.ex` exports both functions and the shared `owner_erasure_report()` type.

### 2. Execute detaches owner attachments and reports orphan-only purge work
expected: Executing owner erasure recomputes live detach/purge partitions, deletes the target owner's attachment rows transactionally, and returns a semantic report instead of internal transaction data.
result: pass
evidence:
  - `mix test test/rindle/owner_erasure_test.exs --seed 0`
  - `lib/rindle/internal/owner_erasure.ex` recomputes plan inside `Ecto.Multi`, deletes attachment rows, enqueues purge jobs, and returns semantic counts.

### 3. Idempotent reruns and already-queued purge semantics stay stable
expected: Re-running execute after detach completes returns a zeroed semantic report, and active-state Oban uniqueness conflicts are treated as already-queued success rather than operation failure.
result: pass
evidence:
  - `mix test test/rindle/owner_erasure_test.exs --seed 0`
  - `test/rindle/owner_erasure_test.exs` covers idempotent reruns and `%Oban.Job{conflict?: true}` reporting.

### 4. Purge worker only deletes genuinely orphaned assets
expected: `PurgeStorage` re-checks live attachments immediately before destructive deletion, deleting bytes and the asset row only when no surviving attachment exists.
result: pass
evidence:
  - `mix test test/rindle/workers/purge_storage_test.exs --seed 0`
  - `lib/rindle/workers/purge_storage.ex` exits early on surviving attachments and only purges after the live existence check.

### 5. Shared assets survive stale purge work and public wording stays honest
expected: A shared asset remains intact when one owner detaches and stale purge work runs later, and the public docs describe execute semantics as detach-now plus purge-enqueued-later rather than inline storage deletion.
result: pass
evidence:
  - `mix test test/rindle/attach_detach_test.exs test/rindle/workers/purge_storage_test.exs --seed 0`
  - `lib/rindle.ex`, `guides/user_flows.md`, and `54-CONTEXT.md` all align on retained shared assets, deferred purge, and no force-delete/admin orchestration promise.

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

none

## Notes

- Phase-local verification is green: `mix test test/rindle/owner_erasure_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/workers/purge_storage_test.exs test/rindle/attach_detach_test.exs --seed 0` passed with 27 tests and 0 failures on 2026-05-26.
- Broader integration proof remains environment-blocked outside this UAT artifact: `mix test test/rindle/upload/lifecycle_integration_test.exs test/adopter/canonical_app/lifecycle_test.exs --seed 0` failed because MinIO on `localhost:9000` refused connections.
