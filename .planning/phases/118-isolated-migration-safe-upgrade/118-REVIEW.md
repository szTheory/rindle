---
phase: 118-isolated-migration-safe-upgrade
reviewed: 2026-08-09T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - README.md
  - guides/getting_started.md
  - guides/upgrading.md
  - lib/rindle/migration.ex
  - lib/rindle/migration/options.ex
  - lib/rindle/migration/v1.ex
  - test/install_smoke/docs_parity_test.exs
  - test/rindle/api_surface_boundary_test.exs
  - test/rindle/migration_default_build_probe.exs
  - test/rindle/migration_fast_test.exs
  - test/rindle/migration_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 118: Code Review Report

**Reviewed:** 2026-08-09T00:00:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

The fixed-prefix validation and identifier quoting boundaries are appropriately narrow, and the focused fast, API-boundary, and documentation-parity tests pass. However, the copy-pasteable populated-upgrade migration does not actually perform the table moves because it nests Ecto migration commands during the runner's flush. This is a data-migration release blocker.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Published populated-upgrade migration silently leaves all relations in `public`

**File:** `guides/upgrading.md:94-100`
**Issue:** The example wraps both the timeout and `Rindle.Migration.move_*` calls in `execute(fn -> ...)`. `execute/1` functions run only during the final `Ecto.Migration.Runner.flush/0`. When the deferred helper then calls `V1.move_owned_relations/3`, its `execute("ALTER TABLE ...")` calls are appended to the runner queue *after* that flush has already copied and begun iterating its command list. Ecto does not recursively flush commands appended by a currently executing command, so the migration completes successfully after setting `lock_timeout` while none of the seven `ALTER TABLE ... SET SCHEMA` commands run. The subsequent deployment uses a `rindle`-compiled runtime against tables still in `public`.

**Fix:** Do not defer the helper itself. Queue the local timeout, then call the helper directly from the migration callback so its DDL is present before the runner's final flush:

```elixir
def up do
  execute(fn -> repo().query!("SET LOCAL lock_timeout = '5s'") end)
  Rindle.Migration.move_public_to_rindle(version: 1)
end

def down do
  execute(fn -> repo().query!("SET LOCAL lock_timeout = '5s'") end)
  Rindle.Migration.move_rindle_to_public(version: 1)
end
```

Alternatively, redesign `Rindle.Migration.V1` to issue its DDL immediately inside one deferred callback and preserve transaction/error handling. Add an integration test that executes the documented callback shape via `Ecto.Migrator`, then asserts all seven relations changed schema.

## Warnings

### WR-01: The integration coverage does not execute the documented Ecto callback shape

**File:** `test/rindle/migration_test.exs:173-275`
**Issue:** Move tests call `Rindle.Migration.move_*` directly before their test runner flushes. Documentation parity only checks required strings (`test/install_smoke/docs_parity_test.exs:211-239`). Neither covers the nested `execute(fn -> Rindle.Migration.move_* ... end)` form in the guide, which is why the runner-queue failure in CR-01 remained green.

**Fix:** Define a test migration using the exact public guide structure and run it through `Ecto.Migrator`/`Ecto.Migration.Runner`; assert the `rindle` schema contains every `V1.owned_relations/0` relation and `public` no longer contains them. Keep this test even after correcting the guide so future examples cannot reintroduce deferred helper invocation.

---

_Reviewed: 2026-08-09T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
