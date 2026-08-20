---
phase: 117
slug: prefix-routing-architecture
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-08
---

# Phase 117 — Validation Strategy

## Test Infrastructure

| Property | Value |
|---|---|
| **Framework** | ExUnit / Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs --seed 0` |
| **Full suite command** | `mix coveralls.multiple --type local --type json` |
| **Estimated runtime** | Existing CI quality lane |

## Sampling Rate

- **After every task commit:** Run the focused ExUnit command for its changed surface.
- **After every plan wave:** Run the relevant Phase 117 focused suite with `--seed 0`.
- **Before phase verification:** Run the full merge-equivalent quality suite plus the prefix-isolation integration proof.
- **Max feedback latency:** One focused ExUnit run.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---|---|---|---|---|---|---|
| 117-01-01 | 01 | 1 | PREFIX-01 | schema/config unit | `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs --seed 0` | covered |
| 117-01-02 | 01 | 1 | PREFIX-03 | selected-versus-decoy integration | `mix test test/rindle/schema_prefix_integration_test.exs --seed 0` | covered |
| 117-02-01 | 02 | 2 | PREFIX-02 | compatibility/contract | `mix test test/rindle/schema_prefix_contract_test.exs --seed 0` | covered |
| 117-02-02 | 02 | 2 | PREFIX-01..03 | full regression | `mix coveralls.multiple --type local --type json` | covered |
| 117-03-01 | 03 | 3 | PREFIX-01, PREFIX-03 | compile-finalization regression | `mix test test/rindle/schema_prefix_contract_test.exs --seed 0` | covered |
| 117-03-02 | 03 | 3 | PREFIX-02 | default/public build authority | `mix test test/rindle/config/config_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0` | covered |
| 117-04-01 | 04 | 3 | PREFIX-01, PREFIX-02 | callback-resistance contract | `mix test test/rindle/schema_prefix_contract_test.exs --seed 0` | covered |
| 117-04-02 | 04 | 3 | PREFIX-03 | facade, Multi, worker, and loaded-struct routing | `mix test test/rindle/schema_prefix_integration_test.exs --seed 0` | covered |
| 117-05-01 | 05 | 3 | PREFIX-01 | owned-schema boundary | `mix test test/rindle/schema_prefix_contract_test.exs --seed 0` | covered |
| 117-05-02 | 05 | 3 | PREFIX-02, PREFIX-03 | build authority and routing regression | `mix coveralls.multiple --type local --type json` | covered |

## Wave 0 Requirements

Existing ExUnit and PostgreSQL test infrastructure cover Phase 117. New focused prefix-contract and
prefix-integration tests are planned as the phase's first implementation tasks.

## Manual-Only Verifications

All Phase 117 behavior must have automated proof. The separately compiled public-compatibility consumer
proof is completed in Phase 120.

## Validation Sign-Off

- [x] Every planned behavior has an automated verification route.
- [x] Existing infrastructure needs no new framework or harness.
- [x] Focused prefix tests and full quality suite are green (35 focused tests; 1,261 full-suite tests, 0 failures).
- [x] `nyquist_compliant: true` set after execution evidence is recorded.

**Approval:** validated 2026-08-08

## Validation Audit 2026-08-08

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Evidence recorded in this audit:

- `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs test/rindle/schema_prefix_contract_test.exs test/rindle/schema_prefix_integration_test.exs --seed 0` — 35 tests, 0 failures.
- `mix coveralls.multiple --type local --type json --slowest 20` — 1,261 tests, 0 failures, 4 skipped, 77 excluded; 81.5% coverage.
