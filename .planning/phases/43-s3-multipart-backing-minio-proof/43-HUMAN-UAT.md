---
status: complete
phase: 43-s3-multipart-backing-minio-proof
source: [43-VERIFICATION.md]
started: 2026-05-23T13:44:32Z
updated: 2026-05-23T13:55:00Z
---

## Current Test

[testing complete]

## Tests

### 1. MinIO ≥ 1 GiB tus drop-and-resume completes (SC5 / TUS-09)
expected: A ≥ 1 GiB tus upload over S3 multipart with a mid-flight drop + resume completes and verifies through `verify_completion/2`.
result: passed — completes to a `ready` asset with `byte_size == 1 GiB`; `list_multipart_uploads` empty after reaper.

### 2. DELETE zero-leak — `list_multipart_uploads` empty after abandonment + reaper (SC5 / TUS-09)
expected: After abandoning a tus session and running the reaper, `list_multipart_uploads` returns empty — zero orphaned S3 multipart parts.
result: passed — tus DELETE returns 204; `list_multipart_uploads` empty for the deleted key.

### 3. Post-reap tail-file cleanup (SC5 / IN-04)
expected: After reaping, the node-local `Rindle.tmp/tus/*.tail` buffer for the abandoned session is gone.
result: passed — after fixing a pre-existing 43-10 test bug (commit 5343e4f) so the session stays incomplete/abandoned, the reaper removes the tail.

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None — all SC5 MinIO criteria proven against live MinIO (`mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` → 3 tests, 0 failures). See `minio_live_run` in 43-VERIFICATION.md.
