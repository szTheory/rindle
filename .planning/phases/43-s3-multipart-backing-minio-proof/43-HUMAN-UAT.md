---
status: partial
phase: 43-s3-multipart-backing-minio-proof
source: [43-VERIFICATION.md]
started: 2026-05-23T13:44:32Z
updated: 2026-05-23T13:44:32Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. MinIO ≥ 1 GiB tus drop-and-resume completes (SC5 / TUS-09)
expected: With a live MinIO endpoint configured (`RINDLE_MINIO_URL`, `RINDLE_MINIO_ACCESS_KEY`, `RINDLE_MINIO_SECRET_KEY`), running `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` completes a ≥ 1 GiB tus upload over S3 multipart with a mid-flight drop + resume, and the assembled object verifies through `verify_completion/2`.
result: [pending]

### 2. DELETE zero-leak — `list_multipart_uploads` empty after abandonment + reaper (SC5 / TUS-09)
expected: After abandoning a tus session and running the reaper (`AbortIncompleteUploads`/`UploadMaintenance`), `list_multipart_uploads` returns empty for the bucket — zero orphaned S3 multipart parts. Includes the CR-01 abort-failure recovery path (a transient abort failure stamps `tus_abort_failed:` and is re-aborted on the next reaper pass).
result: [pending]

### 3. Post-reap tail-file cleanup (SC5 / IN-04)
expected: After reaping, the node-local `Rindle.tmp/tus/*.tail` (and `*.part`) buffer files for the abandoned session are gone — no leaked local temp files.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
