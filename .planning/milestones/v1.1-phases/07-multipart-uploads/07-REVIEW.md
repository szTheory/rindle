---
phase: 07-multipart-uploads
reviewed: 2026-04-28T12:35:06Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - /Users/jon/projects/rindle/lib/rindle.ex
  - /Users/jon/projects/rindle/lib/rindle/upload/broker.ex
  - /Users/jon/projects/rindle/lib/rindle/storage.ex
  - /Users/jon/projects/rindle/lib/rindle/storage/s3.ex
  - /Users/jon/projects/rindle/lib/rindle/storage/local.ex
  - /Users/jon/projects/rindle/lib/rindle/domain/media_upload_session.ex
  - /Users/jon/projects/rindle/priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs
  - /Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex
  - /Users/jon/projects/rindle/lib/rindle/workers/abort_incomplete_uploads.ex
  - /Users/jon/projects/rindle/test/rindle/upload/broker_test.exs
  - /Users/jon/projects/rindle/test/rindle/storage/storage_adapter_test.exs
  - /Users/jon/projects/rindle/test/rindle/ops/upload_maintenance_test.exs
  - /Users/jon/projects/rindle/test/rindle/workers/maintenance_workers_test.exs
  - /Users/jon/projects/rindle/test/rindle/storage/s3_test.exs
  - /Users/jon/projects/rindle/test/rindle/upload/lifecycle_integration_test.exs
  - /Users/jon/projects/rindle/test/adopter/canonical_app/lifecycle_test.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---
# Phase 7: Code Review Report

**Reviewed:** 2026-04-28T12:35:06Z
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Re-reviewed the full Phase 07 multipart upload scope after commit `5ee51b2` and verified the updated adopter and maintenance coverage.

The prior multipart abandonment gap in `Rindle.Upload.Broker` is resolved: failed multipart-session persistence now triggers a best-effort remote abort, and the new regression test covers that path. The initialized-multipart expiry path is also covered end-to-end now, including the adopter MinIO lifecycle.

Verification run:

- `mix test test/rindle/upload/broker_test.exs test/rindle/ops/upload_maintenance_test.exs test/rindle/workers/maintenance_workers_test.exs`
- `mix test test/adopter/canonical_app/lifecycle_test.exs --include adopter`

Repo seam safety looks acceptable in the touched code: the broker and maintenance services continue to source persistence through `Config.repo/0`, and the new rollback test proves the multipart initiation path compensates correctly when that seam returns a transaction failure.

One warning-level correctness risk remains in cleanup for mixed-adapter deployments, so the phase is not yet clean.

## Warnings

### WR-01: Cleanup still applies one storage adapter to every expired session

**File:** `/Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex:69-75,122-139,172-198,252-280`
**Issue:** `cleanup_orphans/1` resolves a single `storage_mod` once per run from `opts[:storage]` or `:rindle, :default_storage`, then uses that adapter for every expired session. Phase 07 explicitly supports profile-specific adapters (`Rindle.storage_adapter_for/1`, asset `profile` persistence), but expired-session cleanup does not resolve the adapter from the session's associated asset/profile. In a deployment with multiple profiles backed by different adapters, cleanup can call `delete/2` or `abort_multipart_upload/3` against the wrong backend. If that backend reports success or `:not_found`, the code deletes the session row and permanently loses the only persisted handle needed to clean up the real remote object or multipart upload.
**Fix:**
```elixir
query =
  from(s in MediaUploadSession,
    where: s.state == "expired",
    preload: [:asset]
  )

defp storage_for_session(session, opts) do
  case Keyword.get(opts, :storage) do
    nil ->
      with asset when not is_nil(asset) <- session.asset,
           profile when is_binary(profile) <- asset.profile,
           mod <- String.to_existing_atom(profile),
           true <- Code.ensure_loaded?(mod),
           true <- function_exported?(mod, :storage_adapter, 0) do
        {:ok, mod.storage_adapter()}
      else
        _ -> {:error, :storage_adapter_unresolved}
      end

    storage_mod ->
      {:ok, storage_mod}
  end
end
```
Resolve the storage adapter per session from `session.asset.profile` when no explicit adapter override is supplied, and keep the row retryable when that resolution fails.

---

_Reviewed: 2026-04-28T12:35:06Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
