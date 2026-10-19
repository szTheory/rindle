---
phase: 135-repository-and-code-craft-consolidation
plan: 06
subsystem: code-craft
status: complete
tags: [craft, credo, readability, refactor, CRAFT-05]
requires: ["135-02", "135-04"]
provides:
  - "complexity baseline shrunk by the five mechanical-trigger pilot identities (27 -> 22 entries, 31 -> 24 findings)"
  - "five traced readability changes in scripts/maintainer/readability_changes.json"
affects: [lib/rindle/ops, lib/rindle/upload/tus_protocol.ex, scripts/maintainer, test/install_smoke]
tech-stack:
  added: []
  patterns:
    - "Flatten Credo Nesting by extracting intention-named private helpers; no public name, arity, return shape or error tuple changes"
    - "Each baseline shrink travels with a readability_changes.json entry anchored to the removed identity"
key-files:
  created:
    - .planning/phases/135-repository-and-code-craft-consolidation/135-06-SUMMARY.md
  modified:
    - lib/rindle/ops/sweep_orphaned_temp_files.ex
    - lib/rindle/ops/lifecycle_repair.ex
    - lib/rindle/ops/runtime_checks/core_checks.ex
    - lib/rindle/ops/runtime_checks.ex
    - lib/rindle/upload/tus_protocol.ex
    - scripts/maintainer/credo_complexity_baseline.json
    - scripts/maintainer/credo_quality_normalize.exs
    - scripts/maintainer/readability_changes.json
    - test/install_smoke/credo_policy_test.exs
decisions:
  - "The credo_quality normalizer's hard-coded baseline size guard (27/31) moves in lockstep with the policy-test literals at each shrink (26/30, 24/28, 22/24)."
  - "Trace entries carry an extra human-readable summary field next to the validator-required fields; the validator ignores unknown fields."
metrics:
  duration: "~45m"
  completed: 2026-10-19
estimate:
  tokens: 90000
  tasks: 3
actuals:
  tokens: 5900
  tasks: 3
  commits: 3
plan_head_before: d8bf703db1b5ffcf683f17ca242fef12ee26921f
plan_head_after: 89a167676bee3626dea4a02beb8867df4c0b7a98
---

# Phase 135 Plan 06: CRAFT-05 Readability Pilot Summary

Five mechanical-trigger Credo Nesting findings in the ops and tus modules are flattened into intention-named private helpers. Their five identities are removed from the complexity baseline (27 entries/31 findings down to 22/24), and each removal has a traced entry in `readability_changes.json` tied to `quality-maintainability-curated-complexity`.

## Tasks

| Task | Change | Commit |
| ---- | ------ | ------ |
| 1 (tracer) | `sweep_orphaned_temp_files.ex`: `process_run_dir/4` directory branch -> `sweep_directory/5` + `age_run_dir/5` (Nesting if) | c72882f2 |
| 2 | `lifecycle_repair.ex`: reduce out of the telemetry closure -> `requeue_selected_variants/3` (Nesting fn); `core_checks.ex`: with out of nested closures -> `variant_runtime_failures/4` (Nesting with) | e9e3ada5 |
| 3 | `runtime_checks.ex`: `schema_catalog/5` + `query_marker_versions/3` (Nesting fn x2); `tus_protocol.ex`: `parse_checksum_value/1`, `decode_checksum/2`, `put_metadata_pair/2`, `put_decoded_metadata/3` (Nesting case x2) | 89a16767 |

Trace ids: `craft-sweep-orphaned-temp-files-nesting` (cohesion), `craft-lifecycle-repair-nesting` (cohesion), `craft-core-checks-nesting` (cohesion), `craft-runtime-checks-nesting` (cohesion), `craft-tus-protocol-nesting` (failure-semantics). All have `pr: null` until merge.

## Baseline split (read from origin/main d8bf703d)

- 27 entries before: 5 pilot, 13 with a developer-approved-phase removal trigger, 9 other mechanical-trigger entries.
- 22 entries after. Compared as full JSON entries, they equal the 13 + 9 that are not pilot entries, so they are byte-unchanged. `git diff origin/main` on the baseline has 0 added lines (removal-only).
- Policy literals: 22 entries, count sum 24, 2 entries with count 2.

## Verification (final tree)

- `credo_quality.sh`: pass. `refactor_contract.sh`: pass. `mix compile --warnings-as-errors` and `mix format --check-formatted`: pass.
- Focused tests: sweep (with snapshot and credo policy) 23/0. lifecycle_repair and runtime_checks 37/0. runtime_checks, gcs, streaming, tus_plug and api_surface_boundary (with snapshot and policy) 134/0. `public_surface_snapshot_test` is unchanged and passes.
- `craft_boundary_check.sh origin/main`: ok. `validate_readability_trace.sh --base origin/main`: ok (base). `--offline`: ok (offline).
- `scripts/ci/test_craft_contract_tools.sh`: 52 passed, 0 failed.
- `mix test test/install_smoke`: 359 tests, 0 failures, 17 excluded.
- Full default `mix test`: 3 doctests, 1639 tests, 0 failures, 87 excluded, 4 skipped, 2 invalid. The 2 invalid tests are `Rindle.DoctorThresholdsTest`, whose setup_all failed because `Doctor.ModuleInformation.build/2` returned `:module_not_found` under the custom MIX_BUILD_PATH. This is a known environment artifact; the module is untouched.
  - The first full run had 16 `Rindle.Upload.BrokerTest` failures. Postgres refused connections (`too_many_connections`) because other agents were using the same database. On a rerun, `broker_test.exs` alone passed 27/0, and a second full run had 0 failures.
- `scan_live_residue.exs --check`: ok. `automation_first_contract.sh`: pass. A search of scripts, test, lib and .github for `planning/phases/135` found 0 hits.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The credo_quality normalizer hard-codes the baseline size**
- **Found during:** Task 1
- **Issue:** `scripts/maintainer/credo_quality_normalize.exs` raises unless the baseline has exactly 27 identities and 31 occurrences. Any shrink made `credo_quality.sh` and `credo_policy_test.exs` fail ("complexity baseline is malformed").
- **Fix:** Updated the guard literals along with the policy-test literals in each task (26/30, 24/28, 22/24). The file is not in `files_modified`, but every shrink needs this change.
- **Files modified:** scripts/maintainer/credo_quality_normalize.exs
- **Commits:** c72882f2, e9e3ada5, 89a16767

## Threat mitigations

- T-135-17: the tus response path is unchanged. Every error atom (`:invalid_checksum`), the `{:ok, nil, nil}` absent-header result and the metadata skip semantics are preserved. tus_plug_test, the api_surface_boundary hidden-function checks and the full suite are green.
- T-135-18: the baseline diff is removal-only. The credo_quality multiset matches, and the trace `--base` anchor check passes.
- T-135-SC: no packages were installed.

## Known Stubs

None.

## Self-Check: PASSED

- All modified files exist.
- Commits c72882f2, e9e3ada5 and 89a16767 are ancestors of HEAD.
