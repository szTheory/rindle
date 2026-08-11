---
phase: 120-adoption-proof-release-truth
reviewed: 2026-08-10T22:10:00-04:00
depth: standard
files_reviewed: 17
files_reviewed_list:
  - CHANGELOG.md
  - README.md
  - .github/workflows/ci.yml
  - examples/adoption_demo/mix.exs
  - examples/adoption_demo/priv/repo/migrations/20260528120100_add_oban.exs
  - examples/adoption_demo/priv/repo/migrations/20260809000000_install_rindle.exs
  - examples/adoption_demo/test/rindle_migration_contract_test.exs
  - guides/getting_started.md
  - guides/release_publish.md
  - guides/troubleshooting.md
  - guides/upgrading.md
  - lib/rindle/migration.ex
  - scripts/ci/cohort_demo_smoke.sh
  - test/install_smoke/docs_parity_test.exs
  - test/install_smoke/generated_app_smoke_test.exs
  - test/install_smoke/release_docs_parity_test.exs
  - test/install_smoke/support/generated_app_helper.ex
findings:
  critical: 3
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 120: Code Review Report

**Reviewed:** 2026-08-10T22:10:00-04:00
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

The release-proof implementation has three release-blocking false-positive or rollback defects. In particular, its explicit-public migration cannot undo the installation it creates, and the populated-upgrade checks do not establish the FK, index, marker, or Oban-ownership facts they report.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Explicit-public installation rolls back the wrong schema

**Classification:** BLOCKER

**File:** `/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:1249`

**Issue:** `rindle_migration_source("public")` emits `Rindle.Migration.up(version: 1, prefix: "public")`, but always emits `Rindle.Migration.down(version: 1)`. `Rindle.Migration.Options` defaults an omitted prefix to `"rindle"`, so rolling back a public-compatibility host migration drops `rindle` relations (or no relations) and leaves the public installation intact. The same broken generated source is deliberately copied into the README, Getting Started, and `Rindle.Migration` moduledoc, so adopters receive the unsafe rollback too.

**Fix:** Preserve the selected prefix in the generated `down/0` call and add parity assertions for both `up/0` and `down/0`:

```elixir
prefix_option = if prefix == "public", do: ~s(, prefix: "public"), else: ""

def up, do: Rindle.Migration.up(version: 1#{prefix_option})
def down, do: Rindle.Migration.down(version: 1#{prefix_option})
```

Update the public snippets in `README.md`, `guides/getting_started.md`, and `lib/rindle/migration.ex` to use `down(version: 1, prefix: "public")`.

### CR-02: Populated-upgrade integrity report can pass after FK, index, or marker loss

**Classification:** BLOCKER

**File:** `/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:1319-1330`

**Issue:** The values reported as preservation evidence do not test preservation. `seeded_marker?` only checks that the marker table exists, not that it retains version `1`. `foreign_key_preserved?` only proves the seeded rows can join; a database permits such a join after the FK constraint has been dropped. `index_preserved?` accepts any index on `media_variants`, including its primary-key index, so losing the required unique or query indexes still passes. The phase's release-critical upgrade proof therefore accepts a migration that silently loses integrity guarantees.

**Fix:** Query PostgreSQL catalogs for the required named constraint and indexes, and require the marker contents, not just their containers. For example, assert `pg_constraint.contype = 'f'` for the expected `media_variants.asset_id` FK, require the expected V1 index names from `Rindle.Migration.V1`, and query `rindle.rindle_migration_versions` for exactly `[1]`. Report those concrete facts and assert them in `GeneratedAppIsolationUpgradeTest`.

### CR-03: The generated proof cannot detect Rindle taking ownership of `public.oban_jobs`

**Classification:** BLOCKER

**File:** `/Users/jon/projects/rindle/test/install_smoke/support/generated_app_helper.ex:1338`

**Issue:** `rindle_created_oban_jobs` is calculated as `not host_oban_migration_ran? and oban_jobs_after_rindle?`. The runner always executes the host Oban migration before the Rindle migration, making `host_oban_migration_ran?` true; consequently this field is always false regardless of whether the Rindle migration also creates or alters `public.oban_jobs`. The repository test treats that false value as its ownership proof at `test/install_smoke/generated_app_smoke_test.exs:37`, so the claimed host-ownership regression gate is ineffective.

**Fix:** Capture and compare an Oban catalog snapshot immediately before and after the Rindle migration (for example relation OID/schema plus its columns, constraints, and indexes), and fail if the Rindle step creates or changes it. Keep the separate migration-source assertion as an additional structural check rather than treating table presence as ownership evidence.

---

_Reviewed: 2026-08-10T22:10:00-04:00_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
