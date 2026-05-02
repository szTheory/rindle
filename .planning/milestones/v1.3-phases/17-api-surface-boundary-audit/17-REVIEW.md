---
phase: 17-api-surface-boundary-audit
reviewed: 2026-04-30T19:29:01Z
depth: standard
files_reviewed: 29
files_reviewed_list:
  - mix.exs
  - README.md
  - guides/getting_started.md
  - lib/rindle.ex
  - lib/rindle/live_view.ex
  - lib/rindle/config.ex
  - lib/rindle/security/filename.ex
  - lib/rindle/security/mime.ex
  - lib/rindle/security/storage_key.ex
  - lib/rindle/security/upload_validation.ex
  - lib/rindle/profile/validator.ex
  - lib/rindle/profile/digest.ex
  - lib/rindle/storage/capabilities.ex
  - lib/rindle/domain/asset_fsm.ex
  - lib/rindle/domain/upload_session_fsm.ex
  - lib/rindle/domain/variant_fsm.ex
  - lib/rindle/domain/stale_policy.ex
  - lib/rindle/internal/variant_failure_logger.ex
  - lib/rindle/ops/metadata_backfill.ex
  - lib/rindle/ops/upload_maintenance.ex
  - lib/rindle/ops/variant_maintenance.ex
  - lib/rindle/workers/promote_asset.ex
  - lib/rindle/workers/process_variant.ex
  - lib/rindle/workers/purge_storage.ex
  - lib/rindle/upload/broker.ex
  - lib/rindle/domain/media_upload_session.ex
  - test/rindle/api_surface_boundary_test.exs
  - test/rindle/live_view_test.exs
  - test/install_smoke/docs_parity_test.exs
findings:
  critical: 0
  warning: 2
  info: 0
  total: 2
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-04-30T19:29:01Z
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

Phase 17 mostly lands the intended public-surface cleanup: the boundary tests pass, the targeted smoke tests pass, and `mix docs --warnings-as-errors` succeeds. The remaining problems are both in the `Rindle.LiveView` integration path: the helper no longer matches the broker-managed upload lifecycle it documents, and it exposes incorrect callback metadata. The current test suite only checks exported functions and doc text, so both regressions pass green.

## Warnings

### WR-01: LiveView presign path bypasses the broker state transition

**File:** `lib/rindle/live_view.ex:73-96`
**Issue:** `allow_upload/4` creates a session with `Rindle.initiate_upload/2` and then calls `adapter.presigned_put/3` directly. That skips `Rindle.Upload.Broker.sign_url/1`, which is the path that transitions the session from `"initialized"` to `"signed"` ([`lib/rindle/upload/broker.ex:128-145`](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:128)). `consume_uploaded_entries/3` later calls `Rindle.verify_completion/2`, but broker verification only allows the `"verifying"` transition from `"signed"`, `"uploading"`, or `"uploaded"` ([`lib/rindle/domain/upload_session_fsm.ex:6-16`](/Users/jon/projects/rindle/lib/rindle/domain/upload_session_fsm.ex:6)). In the real LiveView flow the session stays `"initialized"`, so verification can fail with an invalid-transition error even though the docs and tests imply the integration is supported.
**Fix:**
```elixir
case Rindle.Upload.Broker.sign_url(session.id) do
  {:ok, %{session: signed, presigned: presigned}} ->
    {:ok,
     %{
       uploader: "Rindle",
       url: presigned.url,
       method: Map.get(presigned, :method, "PUT"),
       headers: Map.get(presigned, :headers, %{}),
       session_id: signed.id,
       asset_id: signed.asset_id
     }, socket}
end
```
Add an integration test that exercises the external signer and then verifies the upload through `consume_uploaded_entries/3`.

### WR-02: LiveView callback metadata publishes a fake `asset_id`

**File:** `lib/rindle/live_view.ex:87-94`
**Issue:** the metadata returned to LiveView includes `asset_id: Ecto.UUID.generate()`, which is unrelated to the asset row created by the broker. The callback therefore receives a phantom asset id, and the moduledoc example reinforces the mistake by showing `entry.asset_id` instead of reading from `meta` ([`lib/rindle/live_view.ex:25-29`](/Users/jon/projects/rindle/lib/rindle/live_view.ex:25)). Any caller that tries to attach or query by that id will target a non-existent asset.
**Fix:**
```elixir
meta = %{
  uploader: "Rindle",
  url: presigned.url,
  method: Map.get(presigned, :method, "PUT"),
  headers: Map.get(presigned, :headers, %{}),
  session_id: signed.id,
  asset_id: signed.asset_id
}
```
If the helper wants to guarantee post-verification accuracy, overwrite `meta[:asset_id]` with the `asset.id` returned by `Rindle.verify_completion/2` before calling the user callback. Add a test that asserts the callback receives the persisted asset id.

---

_Reviewed: 2026-04-30T19:29:01Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
