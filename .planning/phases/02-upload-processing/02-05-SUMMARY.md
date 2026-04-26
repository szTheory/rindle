---
phase: 02-upload-processing
plan: "05"
subsystem: attachments
tags: [atomic-promote, purge, idempotent-delete, race-safety]
requires: [ATT-01, ATT-02, ATT-03, ATT-04, ATT-05]
provides:
  - "Atomic attachment replacement"
  - "Async purge worker"
  - "Idempotent detach and delete flow"
key-files:
  modified:
    - lib/rindle.ex
  created:
    - lib/rindle/workers/purge_storage.ex
    - test/rindle/attach_detach_test.exs
requirements-completed: [ATT-01, ATT-02, ATT-03, ATT-04, ATT-05]
completed: 2026-04-25
---

# Phase 02 Plan 05: Atomic Promote & Idempotent Purge Summary

`Rindle.attach/3` and `Rindle.detach/2` now use transactional replacement and async purge semantics so older attachments cannot overwrite newer uploads and storage cleanup remains idempotent.

## Verification

- `mix test test/rindle/attach_detach_test.exs`
- `mix test test/rindle/upload/lifecycle_integration_test.exs`
