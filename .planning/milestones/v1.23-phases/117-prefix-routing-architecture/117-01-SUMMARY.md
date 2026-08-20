---
phase: 117-prefix-routing-architecture
plan: 01
subsystem: database
tags: [ecto, postgres, schema-prefix, compile-time-config]
requires:
  - phase: 116-migration-substrate
    provides: Rindle-owned schema and migration boundaries
provides:
  - Validated compile-time prefix metadata for all Rindle-owned Ecto schemas
  - Explicit public compatibility mode with independent Oban diagnostics
affects: [118-schema-provisioning, 119-runtime-boundaries, 120-release-proof]
tech-stack:
  added: []
  patterns: [shared Ecto base schema macro, compile-time schema prefix validation]
key-files:
  created: [lib/rindle/schema.ex]
  modified: [lib/rindle/config.ex, lib/rindle/domain/media_asset.ex, lib/rindle/domain/media_attachment.ex, lib/rindle/domain/media_variant.ex, lib/rindle/domain/media_upload_session.ex, lib/rindle/domain/media_processing_run.ex, lib/rindle/domain/media_provider_asset.ex]
key-decisions:
  - "All six Rindle-owned schemas receive their prefix through Rindle.Schema at compile time."
  - "Only rindle and public are supported Rindle prefix values; Oban remains independently configured."
patterns-established:
  - "Use Rindle.Schema for Rindle-owned Ecto tables so schema-backed queries and structs carry one prefix."
requirements-completed: [PREFIX-01, PREFIX-02, PREFIX-03]
coverage:
  - id: D1
    description: "All six owned schemas and newly built structs carry selected prefix metadata and binary keys."
    requirement: PREFIX-01
    verification:
      - kind: unit
        ref: test/rindle/domain/media_schema_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: "Compile-time prefix defaults to rindle, supports explicit public compatibility, and rejects unsupported values."
    requirement: PREFIX-02
    verification:
      - kind: unit
        ref: test/rindle/config/config_test.exs
        status: pass
    human_judgment: false
  - id: D3
    description: "Runtime diagnostic routing follows compiled Rindle metadata while Oban stays independent."
    requirement: PREFIX-03
    verification:
      - kind: unit
        ref: test/rindle/ops/runtime_status_test.exs
        status: pass
    human_judgment: false
duration: 4min
completed: 2026-08-09
status: complete
---

# Phase 117 Plan 01: Prefix Routing Architecture Summary

Rindle-owned data now uses one validated compile-time Ecto prefix contract, defaulting to `rindle` with an explicit `public` compatibility build mode.

## Accomplishments

- Added `Rindle.Schema`, which validates `:rindle_prefix` as `"rindle"` or `"public"` at schema compilation and preserves the binary key defaults.
- Routed all six Rindle domain schemas through the macro; new structs and schema-backed operations now carry the selected prefix metadata.
- Made `Rindle.Config.rindle_prefix/0` return the same compiled decision while leaving `oban_prefix` runtime-configurable and independent.
- Updated affected runtime-status coverage for the intentional compile-time, rather than mutable runtime, routing contract.

## Verification

- `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs --seed 0` — PASS (30 tests)
- `mix test test/rindle/config/config_test.exs test/rindle/domain test/rindle/ops/runtime_status_test.exs --seed 0` — PASS (161 tests)
- `mix test --seed 0` — PASS (1,256 tests, 0 failures; 4 skipped, 77 excluded)
- `mix format --check-formatted ...` — PASS
- `Oban.Job.__schema__(:prefix) == nil` is asserted in focused schema coverage.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 - Blocking test environment] Kept the test build in explicit public compatibility mode**
   - **Found during:** Task 2
   - **Issue:** Existing test database fixtures are provisioned only in `public`; compiling tests with the new default `rindle` made schema-backed integration coverage target absent tables before Phase 118 provisions `rindle`.
   - **Fix:** Set the test compile-time prefix to `public`, then added dynamic compilation coverage proving the package default remains `rindle` when no compatibility setting is supplied.
   - **Files modified:** `config/test.exs`, `test/rindle/config/config_test.exs`, `test/rindle/ops/runtime_status_test.exs`
   - **Verification:** Complete default test suite passed.
   - **Commit:** 92e7211

2. **[Rule 3 - Compile-time API correction] Moved compile-environment resolution into the caller module body**
   - **Found during:** Task 2
   - **Issue:** Elixir only permits `Application.compile_env/3` in a module body, not inside the macro implementation function.
   - **Fix:** The macro emits the validated `@schema_prefix` expression into each consuming schema module.
   - **Files modified:** `lib/rindle/schema.ex`
   - **Verification:** Focused and full test suites passed.
   - **Commit:** 92e7211

**Total deviations:** 2 auto-fixed (2 Rule 3). **Impact:** No production routing, migration, Repo, or Oban behavior was broadened; test compatibility is an explicit compile-time `public` mode.

## Self-Check: PASSED

- `lib/rindle/schema.ex` exists.
- Task commits `21231b0` and `92e7211` exist.
