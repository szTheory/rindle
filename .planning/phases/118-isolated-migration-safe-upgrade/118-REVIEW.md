---
phase: 118-isolated-migration-safe-upgrade
reviewed: 2026-08-09T17:19:43Z
depth: standard
files_reviewed: 12
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
  - test/rindle/schema_prefix_contract_test.exs
findings:
  critical: 0
  warning: 2
  info: 0
  total: 2
status: issues_found
---

# Phase 118: Code Review Report

**Reviewed:** 2026-08-09T17:19:43Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

The previously reported nested-Runner defect is fixed: the guide and its
`Ecto.Migrator` test invoke the directional helpers at migration-body scope.
The fixed relation allowlist, prefix validation, identifier quoting, and host
relation boundary are appropriately narrow. Focused fast/API/docs checks pass
(58 tests), and compilation succeeds with warnings treated as errors.

No Critical source defect was found. The two warnings below still prevent the
claimed bounded-refusal and live-upgrade proof from being fully robust. The
known partial shared test database is a verification gate, not itself a
production migration defect; WR-02 identifies the non-hermetic test behavior
that permits that state to affect this suite.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: A malformed or unreadable marker relation bypasses bounded preflight guidance

**File:** `lib/rindle/migration/v1.ex:574-585`
**Issue:** `migration_snapshot/0` calls `marker_rows/1` before the preflight checks
`source_owned?`/`target_owned?` and before it can return an explicit refusal.
For any same-named `rindle_migration_versions` table that is not owned by the
current role, lacks a `version` column, or cannot be selected, this dynamic
`SELECT version` raises a raw Postgrex error instead of the promised bounded
`source_not_owned`/marker-state guidance. This is one of the malformed and
permission-inadequate states the upgrade API is required to refuse safely.

**Fix:** Build the ownership snapshot first and only query marker contents for
relations that are owned and have the expected marker shape. Convert an
unreadable/malformed marker into a dedicated preflight refusal, for example:

```elixir
if marker_relation_owned_and_shaped?(relation_rows, schema) do
  marker_rows_for(schema)
else
  [{schema, :invalid_marker}]
end
```

Then make `valid_marker?/1` reject that state and add integration tests for a
same-named marker table without `version` and for a marker table the migration
role cannot read.

### WR-02: Unboxed migration tests mutate the shared `public` baseline instead of restoring it

**File:** `test/rindle/migration_test.exs:436-520`
**Issue:** The documented `Ecto.Migrator` test intentionally runs outside the
SQL sandbox, creates/drops Rindle relations in `public`, and in `after` removes
the public Rindle tables rather than restoring the pre-test state (lines
509-518). The lock-contention test has the same unboxed/shared-schema pattern
at lines 303-360. Because these changes commit outside the sandbox, later
tests depend on execution order and on whatever the shared `rindle_test`
database happened to contain. This is the concrete cause of the current
clean-database human-verification gate and makes CI/live migration evidence
non-repeatable.

**Fix:** Run these Ecto.Migrator cases against an isolated disposable database,
or snapshot and restore every affected public relation plus migration-ledger
row in `on_exit`. Do not use destructive cleanup as the baseline reset. Add a
test setup assertion that the fixture creates a complete public Rindle set
independently of prior test state.

---

_Reviewed: 2026-08-09T17:19:43Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
