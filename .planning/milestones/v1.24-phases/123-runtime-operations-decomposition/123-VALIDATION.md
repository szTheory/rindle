---
phase: 123
slug: runtime-operations-decomposition
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-23
---

# Phase 123 — Validation Strategy

## Validation Contract

Phase 123 is an internal, behavior-preserving decomposition. Every slice begins with façade-level
behavior proof, ends with a fresh compile and SAFE-01, and leaves the next slice blocked until that
evidence is green. Tests assert results, database effects, telemetry events, compiled exports/docs,
terminal output, and exit status; they do not freeze private function bodies or incidental source text.

Local Elixir 1.19/OTP 28 output is diagnostic. The repository-supported GitHub Actions Elixir 1.17 /
OTP 27 cells and sole required `CI Summary` are authoritative for PR acceptance. Push-main lanes are
post-merge evidence and remain pending until the implementation PR merges; no Phase 123 plan changes
their topology or claims release readiness from planning/local results.

## Test Infrastructure

| Property | Value |
|---|---|
| **Framework** | ExUnit / Mix with the existing PostgreSQL-backed migration and runtime suites |
| **Config files** | `test/test_helper.exs`, `config/test.exs`, `mix.exs`, `.tool-versions`, `.github/workflows/ci.yml` |
| **Fresh compile** | `MIX_ENV=test mix compile --force` |
| **Focused aggregate** | `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/migration_fast_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` |
| **SAFE-01** | `bash scripts/maintainer/refactor_contract.sh` |
| **Full local gate** | `mix ci && ./scripts/maintainer/repo_hygiene_check.sh` |
| **Authoritative PR gate** | `gh pr checks --required --watch --fail-fast` at the exact head SHA; `CI Summary` on supported cells |

## Requirement → Observable Proof Map

| Requirement | Observable behavior | Automated command / test files | Review evidence |
|---|---|---|---|
| OPS-01 | `RuntimeChecks.run/2` is the sole schedule/result/order/telemetry façade; core, ownership/Oban, and optional integration domains return unchanged IDs/maps with conditional rows and redaction intact. | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` | 123-01 SUMMARY records collaborator ownership, retained exports, representative report parity, and event cardinality/order. |
| OPS-02 | One fixed V1 catalog feeds snapshot/classification; refusals precede DDL; forward/reverse move order, rollback, lock behavior, and host exclusions remain exact. | `mix test test/rindle/migration_fast_test.exs test/rindle/migration_test.exs --seed 0` | 123-02 SUMMARY records forward/reverse decision precedence and real database before/after/rollback evidence. |
| OPS-03 | Runtime status refuses before queries, then collects the exact bounded report; command parsing, text/JSON order/redaction, and non-zero failures remain exact behind collector/formatter seams. | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` | 123-03 SUMMARY records query-tripwire, report shape/limits, formatter parity, output channel, and exit evidence. |
| SAFE-01 | Public signatures, schema/migration behavior, telemetry, error vocabulary, CI identity, and release coupling remain unchanged after each refactor slice. | `bash scripts/maintainer/refactor_contract.sh`; final `mix ci`; repository hygiene | Each plan SUMMARY records a fresh SAFE-01 pass; final verification records local gates and supported PR CI exact SHA. |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test type | Automated command | Status |
|---|---:|---:|---|---|---|---|
| 123-01-01 | 01 | 1 | OPS-01, SAFE-01 | façade behavior + compiled API boundary | `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` | ✅ green — plan receipt and current aggregate |
| 123-01-02 | 01 | 1 | OPS-01, SAFE-01 | optional integration + telemetry + fresh preservation | `MIX_ENV=test mix compile --force && MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0 && bash scripts/maintainer/refactor_contract.sh` | ✅ green — plan receipt and current aggregate |
| 123-02-01 | 02 | 2 | OPS-02, SAFE-01 | fixed catalog + forward preflight behavior | `MIX_ENV=test mix test test/rindle/migration_fast_test.exs --seed 0` | ✅ green — plan receipt and current aggregate |
| 123-02-02 | 02 | 2 | OPS-02, SAFE-01 | forward/reverse DB effects + rollback + fresh preservation | `MIX_ENV=test mix compile --force && MIX_ENV=test mix test test/rindle/migration_fast_test.exs test/rindle/migration_test.exs --seed 0 && bash scripts/maintainer/refactor_contract.sh` | ✅ green — plan receipt and current aggregate |
| 123-03-01 | 03 | 3 | OPS-03 | readiness tripwire + report behavior + refusal telemetry | `MIX_ENV=test mix test test/rindle/ops/runtime_status_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` | ✅ green — plan receipt and current aggregate |
| 123-03-02 | 03 | 3 | OPS-03 | CLI presentation + focused runtime-status/formatter regression | `MIX_ENV=test mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` | ✅ green — plan receipt and current aggregate |

## Objective Evidence Rules

- Runtime diagnostics are tested only through `RuntimeChecks.run/2`, retained test hooks, compiled
  export/docs metadata, and emitted telemetry—not collaborator function-body strings.
- Migration extraction is tested through V1 preflight results plus real PostgreSQL relation state,
  refusal-before-DDL tripwires, injected rollback, lock, privilege, and reversal behavior—not private
  branch text.
- Runtime status is tested through normalized results, query-reader tripwires, telemetry capture,
  formatted lines/maps, Mix shell messages, and caught exit terms—not formatter source snapshots.
- Structural scope evidence uses Git path/diff checks only for explicitly immutable surfaces; it does
  not make implementation layout itself a public contract.

## Wave 0 Ownership

All required behavior-bearing suites, PostgreSQL fixtures, telemetry capture helpers, API-boundary
checks, SAFE-01, local CI, hygiene, and supported PR CI carriers already exist. No harness, package, or
external setup is required before implementation.

| Gap / research ambiguity | Resolution | Owner |
|---|---|---|
| RuntimeChecks collaborator count | Three coarse internal domains: core profile/delivery runtime, migration/ownership/Oban, and optional GCS/tus/streaming integrations. `IntegrationChecks` owns all three optional domains exactly per D-123-01. | 123-01 Tasks 1–2 |
| Shared result construction across collaborators | Collaborators return internal schedule/outcome data; `RuntimeChecks` alone constructs maps, wraps telemetry, sorts, and aggregates per D-123-02. | 123-01 Tasks 1–2 |
| One migration classifier versus two | Start with one `Preflight` module and explicit direction functions/branches; share predicates only where refusal precedence stays obvious. No separate directional module or duplicated catalog is planned. | 123-02 Tasks 1–2 |
| Formatter helper compatibility | Keep all four current task-module helpers as delegates to one internal formatter, so direct callers/tests remain valid per D-123-06. | 123-03 Task 2 |

There are no unresolved Open Questions. These choices are local and reversible, follow the agent's
discretion in `123-CONTEXT.md`, and do not alter a locked public or migration contract.

## Sampling Cadence

- **After every task:** Run that task's focused command before its atomic non-release `chore:` commit.
- **After Plan 123-01:** Fresh compile, full runtime-check/telemetry focus, then SAFE-01; Plan 123-02 stays blocked until green.
- **After Plan 123-02:** Fresh compile, fast plus database migration proof, then SAFE-01; Plan 123-03 stays blocked until green.
- **After Plan 123-03:** Run the complete focused aggregate, SAFE-01, `mix ci`, and repository hygiene.
- **Before PR acceptance:** Confirm only owned internal/runtime test files changed and the forbidden-surface diff is empty.
- **PR acceptance:** Run `gh pr checks --required --watch --fail-fast`, record exact head SHA, and require supported Elixir 1.17/OTP 27 `CI Summary` success.
- **After merge:** Record push-main lane results before any release-readiness claim; those results are external pending evidence, not a planning blocker.

## Non-Release Delivery and Scope Gate

Implementation commits and the PR title use `chore:`/`test:` intent, never a release-triggering feature
or fix type. The following command must remain quiet at final review:

`git diff --quiet main...HEAD -- .github/workflows mix.exs mix.lock priv/repo/migrations lib/rindle/admin .planning/milestones`

The allowed implementation surface is limited to the runtime checks, migration V1 internals,
runtime-status collector, Mix-task formatter, and their focused tests named in the three plans.

## Phase Gate

1. `MIX_ENV=test mix compile --force`
2. Run the complete focused aggregate from Test Infrastructure.
3. `bash scripts/maintainer/refactor_contract.sh`
4. `mix ci`
5. `./scripts/maintainer/repo_hygiene_check.sh`
6. Run the forbidden-surface diff gate above.
7. On the implementation PR, `gh pr checks --required --watch --fail-fast` succeeds at the exact head SHA with supported Elixir 1.17/OTP 27 and `CI Summary` authoritative.
8. Treat push-main checks as pending until merge and require them before release readiness; do not modify code or policy for unsupported local-toolchain-only variance.

## Validation Sign-Off Criteria

- [x] Every task's focused command passed before its atomic commit.
- [x] Fresh compile and SAFE-01 passed after each of the three ordered slices.
- [x] OPS-01 façade reports, conditional rows, exports, and telemetry remain exact.
- [x] OPS-02 fixed catalog, refusal precedence, move effects/order, rollback, locks, and reversal remain exact.
- [x] OPS-03 filters, readiness tripwire, report shapes/limits, text/JSON order/redaction, and exit semantics remain exact.
- [x] Full focused aggregate, `mix ci`, and repository hygiene passed locally.
- [x] Forbidden public/schema/migration-file/telemetry/error/CI/release/dependency/Admin/archive surfaces had no diff.
- [x] Supported PR CI was green at exact SHA `ad99ed9979517de507771b28ed55c69cef5205f3` (PR #85, run `32612445302`, CI Summary `97128954793`).
- [x] Delivery remained a non-release chore and no deferred Phase 124–126 work appeared.

## Validation Audit 2026-08-23

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Current-checkout receipt: `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/migration_fast_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs test/rindle/contracts/telemetry_contract_test.exs --include contract --seed 0` passed: **136 tests, 0 failures, 4 excluded**. The aggregate contains every behavior suite named by the task map; compile, SAFE-01, full CI, hygiene, and exact-head supported CI receipts remain recorded in the plan summaries and verification report.
