---
phase: 01-foundation
status: issues_found
updated: 2026-04-24T18:00:59Z
---

# Phase 01 Code Review (Advisory)

Reviewed scope: all files listed in `files_modified` across plans `01-01` through `01-06`.

## Findings

### Medium

1. **Unrecognized stale mode crashes instead of returning a controlled result**
   - **Where:** `lib/rindle/domain/stale_policy.ex` (`resolve_stale_variant/3`)
   - **Risk:** `resolve_stale_variant/3` pattern-matches only `:serve_stale` and `:fallback_original`. Any unexpected mode (for example from runtime config drift) raises `CaseClauseError`, which can turn a recoverable policy misconfiguration into request/job failure.
   - **Remediation:** Add a catch-all clause that returns an explicit error tuple (or safe fallback), and add a test covering unknown mode behavior.

2. **S3 store path reads full file into memory**
   - **Where:** `lib/rindle/storage/s3.ex` (`store/3`)
   - **Risk:** `File.read(source_path)` loads the entire object before upload. For large files this can cause memory spikes and worker instability; under concurrency this becomes a practical DoS vector.
   - **Remediation:** Switch to streaming/multipart upload flow (for example `ExAws.S3.Upload.stream_file/1`) and keep strict size limits enforced before upload.

### Low

1. **Profile-level upload validation trusts declared metadata**
   - **Where:** `lib/rindle/profile.ex` (`validate_upload/1`), `lib/rindle/profile/validator.ex` (`validate_upload/2`)
   - **Risk:** This API validates `content_type`/extension values from the input map, not server-detected MIME bytes. Security-sensitive callers may accidentally use this as an enforcement gate and accept spoofed metadata.
   - **Remediation:** Clarify intent in docs/name (metadata-only), or route this API through `Rindle.Security.UploadValidation` for authoritative MIME detection.

## Validation Notes

- Ran targeted test suites for the reviewed scope:
  - `test/rindle/domain/media_schema_test.exs`
  - `test/rindle/contracts/behaviour_contract_test.exs`
  - `test/rindle/profile/profile_test.exs`
  - `test/rindle/domain/lifecycle_fsm_test.exs`
  - `test/rindle/security/upload_validation_test.exs`
  - `test/rindle/storage/storage_adapter_test.exs`
  - `test/rindle/config/config_test.exs`
- Result: `46 tests, 0 failures, 1 skipped` (MinIO integration skip when env vars are not present).
