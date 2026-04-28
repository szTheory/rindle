---
phase: 06-adopter-runtime-ownership
reviewed: 2026-04-28T09:44:26Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - config/config.exs
  - config/test.exs
  - guides/background_processing.md
  - guides/getting_started.md
  - guides/troubleshooting.md
  - lib/rindle.ex
  - lib/rindle/config.ex
  - lib/rindle/upload/broker.ex
  - lib/rindle/workers/process_variant.ex
  - lib/rindle/workers/promote_asset.ex
  - lib/rindle/workers/purge_storage.ex
  - test/adopter/canonical_app/lifecycle_test.exs
  - test/rindle/config/config_test.exs
  - test/rindle/upload/broker_test.exs
  - test/rindle/upload/lifecycle_integration_test.exs
  - test/support/data_case.ex
  - test/test_helper.exs
findings:
  critical: 0
  warning: 2
  info: 0
  total: 2
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-28T09:44:26Z
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Reviewed the Phase 06 runtime-repo ownership changes across config, facade, broker, workers, docs, and the new adopter-focused test lanes. The repo seam itself is implemented consistently and the targeted file-level test commands pass, but the phase leaves one test-harness regression and one material coverage gap in the newly repo-neutral purge path.

## Warnings

### WR-01: Targeting `test/rindle/upload` still skips the integration proof lane

**File:** `test/test_helper.exs:12-24`
**Issue:** The new exclusion logic only unlocks `:integration` tests when the CLI args match a narrow adopter/file-name heuristic. A normal targeted run like `mix test test/rindle/upload` still reports `Excluding tags: [:integration, ...]` and skips the lifecycle proofs entirely, which creates false confidence for developers and automation that run the directory instead of the exact file path.
**Fix:**
```elixir
targeted_adopter_or_integration? =
  System.argv()
  |> Enum.any?(fn arg ->
    String.contains?(arg, "test/adopter/") or
      String.contains?(arg, "test/rindle/upload/")
  end)
```

### WR-02: The adopter-repo lane never executes `PurgeStorage` after the worker repo seam change

**File:** `test/adopter/canonical_app/lifecycle_test.exs:178-184`
**Issue:** Phase 06 changed `lib/rindle/workers/purge_storage.ex` to resolve persistence through `Rindle.Config.repo/0`, but the adopter proof stops at `assert_enqueued/1`. No adopter-repo test actually performs `PurgeStorage`, so a future regression back to `Rindle.Repo` inside the worker would still leave the phase green.
**Fix:**
```elixir
assert :ok = perform_job(PurgeStorage, %{"asset_id" => asset.id, "profile" => asset.profile})
assert Repo.get(MediaAsset, asset.id) == nil
```

Run that in the adopter lane after `Rindle.detach/3`, and assert the storage object is gone through the adopter-owned setup.

---

_Reviewed: 2026-04-28T09:44:26Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
