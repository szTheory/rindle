---
phase: 116-versioned-rindle-migration-module
verified: 2026-07-01T23:01:32Z
status: passed
score: "10/10 must-haves verified"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 116: Versioned `Rindle.Migration` Module Verification Report

**Phase Goal:** Replace the raw 15-file `Ecto.Migrator` copy-paste install path with a versioned, idempotent, Oban-style `Rindle.Migration` module and stop creating the shared `oban_jobs` table on the adopter's behalf -- non-breaking, and the load-bearing foundation v1.23 builds the schema prefix onto.
**Verified:** 2026-07-01T23:01:32Z
**Status:** passed
**Re-verification:** No -- initial verification; no prior `116-VERIFICATION.md` existed.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Adopters install Rindle tables through versioned `Rindle.Migration.up/1` and `down/1`, not the raw packaged migration path. | VERIFIED | `lib/rindle/migration.ex` defines public `up/1` and `down/1`; README, Getting Started, and Upgrading show pinned `Rindle.Migration.up(version: 1)` / `down(version: 1)` snippets; docs parity forbids raw package-path greenfield copy. |
| 2 | The migration API is idempotent, records a Rindle-owned marker, defaults to `public`, and preserves legacy installs. | VERIFIED | `test/rindle/migration_test.exs` exercises default public prefix, idempotent up, `rindle_migration_versions`, scoped down, and option validation; doctor tests accept healthy legacy catalog installs. |
| 3 | Rindle no longer creates, alters, or drops host-owned `oban_jobs`; adopters own `Oban.Migration`. | VERIFIED | `lib/rindle/migration/v1.ex` has no `oban_jobs` or `Oban.Migration` DDL; legacy Oban migration file is a no-op compatibility stub; generated-app smoke proves `rindle_created_oban_jobs?` is false. |
| 4 | README, getting-started, and upgrade docs document host-owned `Oban.Migration`, `oban_jobs`, `mix ecto.migrate`, `mix rindle.doctor`, rollback safety, and default `public`. | VERIFIED | `README.md`, `guides/getting_started.md`, and `guides/upgrading.md` contain the required snippets and ownership copy; `test/install_smoke/docs_parity_test.exs` locks those sections. |
| 5 | Fresh generated-app installs use normal host migrations instead of the legacy package migration directory. | VERIFIED | `test/install_smoke/support/generated_app_helper.ex` writes separate host marker, host Oban, and Rindle migrations; fresh runner uses `host_path`; smoke assertions require `migration_resolution == :host_migrations`. |
| 6 | Legacy packaged migration filenames remain present and existing applied histories stay valid. | VERIFIED | `priv/repo/migrations/20260424205942_create_oban_tables.exs` remains packaged as a compatibility stub; package metadata test asserts the exact filename ships; upgrade guidance keeps historical package replay scoped to 0.1.3-and-earlier upgrades. |
| 7 | Doctor migration inspection works for fresh marker/catalog installs and healthy legacy installs. | VERIFIED | `lib/rindle/ops/runtime_checks.ex` uses `MigrationV1.catalog_requirements/0`, marker versions, and `legacy_packaged_install?`; runtime-check tests cover fresh marker success, healthy legacy success, incomplete schema errors, and warning-only legacy drift. |
| 8 | Runtime status detects setup gaps before missing-table crashes and treats Oban as host-owned readiness. | VERIFIED | `lib/rindle/ops/runtime_status.ex` preflights `rindle_schema` and `oban_jobs`; tests cover `{:setup_incomplete, :rindle_schema}`, `{:setup_incomplete, :oban_jobs}`, success report shape, and configured non-public prefixes. |
| 9 | The full test/release verification surface remains green. | VERIFIED | Verifier ran focused Phase 116 suite: 115 tests, 0 failures; generated-app API guard: 1 test, 0 failures; `bash scripts/install_smoke.sh image`: 3 tests, 0 failures; `mix ci`: 3 doctests + 1252 tests, 0 failures, 4 skipped. |
| 10 | Release-train invariants are preserved. | VERIFIED | `git diff -- .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/release-please-automerge.yml` is empty; `ci.yml` still has `name: CI`; `CI Summary` and release `gate-ci-green` references remain. |

**Score:** 10/10 truths verified (0 present-but-behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/rindle/migration.ex` | Public `Rindle.Migration` API | VERIFIED | Defines documented `up/1` and `down/1`, validates options, dispatches version 1. |
| `lib/rindle/migration/options.ex` | Hidden option validation | VERIFIED | `@moduledoc false`; NimbleOptions schema supports `version: 1`, default `prefix: "public"`, and raises `ArgumentError`. |
| `lib/rindle/migration/v1.ex` | Version-1 DDL and marker helpers | VERIFIED | Creates Rindle tables with `create_if_not_exists`, prefix-aware indexes/references, marker table, helper functions, and scoped rollback. |
| `priv/repo/migrations/20260424205942_create_oban_tables.exs` | Legacy filename compatibility | VERIFIED | File exists and is a no-op compatibility stub; no `Oban.Migration` call or `oban_jobs` DDL. |
| `lib/rindle/ops/runtime_checks.ex` | Hybrid doctor migration health | VERIFIED | Uses marker/catalog/legacy/Oban readiness and configured prefixes. |
| `lib/rindle/ops/runtime_status.ex` | Setup preflight | VERIFIED | Checks Rindle schema and host-owned Oban readiness before report queries. |
| `lib/mix/tasks/rindle.doctor.ex` | CLI rendering | VERIFIED | Renders IDs from `RuntimeChecks` generically; tests assert `[ERROR] doctor.oban_jobs.ready` output. |
| `lib/mix/tasks/rindle.runtime_status.ex` | CLI setup error copy | VERIFIED | Formats `setup_incomplete` errors with `mix rindle.doctor`, `Oban.Migration`, and non-ownership copy. |
| `README.md`, `guides/getting_started.md`, `guides/upgrading.md` | Public install/upgrade docs | VERIFIED | Pinned snippets, host-owned Oban boundary, default public schema, rollback/legacy notes present. |
| `test/rindle/migration_test.exs`, runtime/doc/generated-app tests | Behavioral contract coverage | VERIFIED | Focused tests passed locally. |
| `.github/workflows/ci.yml` | Release-train invariant source | VERIFIED | Unchanged; `name: CI` present. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `test/rindle/migration_test.exs` | `lib/rindle/migration.ex` | Contract calls `Rindle.Migration.up/1` and `down/1` | VERIFIED | Tests call both functions and passed. |
| `lib/rindle/migration.ex` | `lib/rindle/migration/options.ex` | `Options.validate!/1` | VERIFIED | Source dispatches through `Options.validate!()` before version dispatch. |
| `lib/rindle/migration.ex` | `lib/rindle/migration/v1.ex` | `V1.up/1` and `V1.down/1` | VERIFIED | Source dispatches `%{version: 1}` to `V1`. |
| `lib/rindle/ops/runtime_checks.ex` | `lib/rindle/migration/v1.ex` | Catalog helper usage | VERIFIED | Uses `MigrationV1.catalog_requirements/0`, `rindle_tables/0`, and `marker_table/0`. |
| `lib/rindle/ops/runtime_status.ex` | configured repo/prefixes | Setup readiness queries | VERIFIED | Uses `Config.rindle_prefix/0`, `Config.oban_prefix/0`, and `MigrationV1.catalog_requirements/0`. |
| `test/install_smoke/docs_parity_test.exs` | README/guide docs | Section assertions | VERIFIED | Docs parity test passed and asserts pinned snippets plus Oban ownership. |
| `test/install_smoke/support/generated_app_helper.ex` | `test/install_smoke/generated_app_smoke_test.exs` | Report fields | VERIFIED | Helper emits host/Rindle/Oban migration fields; smoke asserts host-owned migration behavior. |
| `RUNNING.md` | `.github/workflows/ci.yml` | Release-train docs and workflow | VERIFIED | `CI Summary` and `name: CI` references present; workflow diff empty. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `lib/rindle/ops/runtime_checks.ex` | `rindle_schema_catalog`, `oban_jobs_catalog` | `information_schema.tables` queries through configured repo | Yes | VERIFIED |
| `lib/rindle/ops/runtime_status.ex` | setup readiness and report queries | `Config.repo().query/all/one` with configured prefixes | Yes | VERIFIED |
| `test/install_smoke/support/generated_app_helper.ex` | generated migration report | Generated app runs real host migrations through `Ecto.Migrator.run/4` on host path | Yes | VERIFIED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Focused Phase 116 contracts pass | `mix test test/install_smoke/docs_parity_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0` | 115 tests, 0 failures | PASS |
| Generated-app public API guard passes | `mix test test/install_smoke/generated_app_smoke_test.exs --seed 0` | 1 test, 0 failures, 13 excluded | PASS |
| Generated app image install proof passes | `bash scripts/install_smoke.sh image` | 3 tests, 0 failures | PASS |
| Full local CI passes | `mix ci` | 3 doctests + 1252 tests, 0 failures, 4 skipped | PASS |
| Workflow invariant diff is empty | `git diff -- .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/release-please-automerge.yml` | no output | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| Conventional probes | `find scripts -path '*/tests/probe-*.sh' -type f` | none found | SKIPPED |
| Phase-declared probes | grep for `probe-*.sh` in Phase 116 plans/summaries | none found | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| MIGRATE-01 | Plans 116-01 through 116-07 | Versioned, idempotent `Rindle.Migration.up/1` + `down/1`; docs updated; default `public`; existing applied migrations valid. | SATISFIED | Migration API/source/tests, docs parity, generated-app smoke, package legacy filename, hybrid legacy doctor checks. |
| MIGRATE-02 | Plans 116-01 through 116-07 | Rindle no longer creates shared `oban_jobs`; adopter owns `Oban.Migration`; docs explain ownership. | SATISFIED | No Oban DDL in migration code or legacy file; runtime/doctor treat `oban_jobs` as host readiness; docs and generated-app smoke prove host-owned Oban. |

No Phase 116 requirements are orphaned in `.planning/REQUIREMENTS.md`; MIGRATE-01 and MIGRATE-02 are both mapped to Phase 116.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `test/install_smoke/package_metadata_test.exs` | 281 | `dryrun-placeholder` literal | INFO | Release metadata test fixture, not a stub implementation. |
| `test/install_smoke/docs_parity_test.exs` | 618 | `TRUTH-07` comment | INFO | Historical requirement comment, not unresolved debt. |
| `guides/troubleshooting.md` | 82 | "not available" in codec guidance | INFO | User-facing troubleshooting text, not placeholder copy. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt markers were found in the reviewed Phase 116 files.

### Human Verification Required

None. All behavior-dependent truths have passing behavioral tests or command evidence.

### Gaps Summary

No blocking gaps found. Phase 116 achieves the roadmap goal and satisfies MIGRATE-01 and MIGRATE-02.

---

_Verified: 2026-07-01T23:01:32Z_
_Verifier: the agent (gsd-verifier)_
