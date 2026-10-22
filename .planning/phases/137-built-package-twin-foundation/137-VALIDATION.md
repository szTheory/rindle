---
phase: "137"
slug: "built-package-twin-foundation"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-21"
---

# Phase 137 — Validation Strategy

## Test Infrastructure

Existing ExUnit, Jason, shell probes and Docker Compose; no new dependency.
Config: mix.exs, test/test_helper.exs and the new external host's ordinary config.
Quick planning check: `./scripts/maintainer/automation_first_contract.sh`.
Execution quick/full commands and test paths are finalized with the plans below.
Final explicit real run observed 55.63 seconds locally. No CI timing credit.

## Sampling Rate

Run the owning task's focused automated check before each task commit. At each
wave boundary run all available fast twin contract tests. The real Docker trace
uses the explicit `built_package_twin.py run` acceptance path outside default
`mix test`/`mix ci`; it fails nonzero when Docker/PostgreSQL/MinIO are absent.
Before phase verification run that real isolated tracer plus a separate
`built_package_twin.py verify --inputs PATH --receipt PATH` process against its fresh retained runner-owned inputs manifest and receipt, then existing
CI/public-surface regression checks appropriate to the touched files.
Every stage uses a finite deadline; no watch loops or rerun-until-green.

## Per-Task Verification Map

Every command below has executed successfully; current focused checks cover 63 tests, and the broader default suite passed 1717 tests plus 3 doctests. New targets are created by the
named task before its verify command runs. A nonzero exit, zero tests, or the
task's named negative control going green is failure; no manual response closes
a TWIN requirement.

| Task | Requirements | Threats | Automated command / target status |
|---|---|---|---|
| 137-01 T1 | TWIN-01..06 | T-137-01..03 | `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1 python3 scripts/maintainer/built_package_twin.py run --verify --cleanup` — new explicit real acceptance path created here; runner exclusively creates retained `inputs.json` beside receipt/descriptor before resource allocation, and Docker/Postgres/MinIO absence is nonzero. |
| 137-01 T2 | TWIN-05 | T-137-02 | `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1 mix test test/install_smoke/twin_tracer_contract_test.exs --seed 0` — new default-safe fast fixture target owned by 137-01 T1; raced barrier and duplicate stimulus controls reject without booting Docker. |
| 137-02 T1 | TWIN-02 | T-137-04 | `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1 mix test test/install_smoke/twin_package_boundary_test.exs --seed 0` — new, created here; contamination controls reject. |
| 137-02 T2 | TWIN-03 | T-137-05 | Same package-boundary command — target owned by 137-02 T1; missing capabilities reject. |
| 137-03 T1 | TWIN-04 | T-137-06 | `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1 mix test test/install_smoke/twin_fault_test.exs --seed 0` — new, created here; concurrency/counter controls reject. |
| 137-03 T2 | TWIN-05 | T-137-07 | Same fault command — target owned by 137-03 T1; private/manual execution controls reject. |
| 137-04 T1 | TWIN-06 | T-137-08 | `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1 mix test test/install_smoke/twin_receipt_test.exs --seed 0` — new, created here; missing/swapped inputs and same-source foreign-run receipt mutations reject; separate verifier requires explicit `--inputs` and `--receipt`. |
| 137-04 T2 | TWIN-01, TWIN-06 | T-137-09 | Same receipt command — target owned by 137-04 T1; canary exports reject. |
| 137-05 T1 | TWIN-06 | T-137-11 | `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1 mix test test/install_smoke/twin_cleanup_test.exs --seed 0` — new, created here; unknown inventory rejects. |
| 137-05 T2 | TWIN-06 | T-137-10 | Same cleanup command — target owned by 137-05 T1; running/paused/unknown-host refusal preserves database, bucket and temp root, while stopped-host idempotency and decoy controls pass. |
| 137-06 T1 | TWIN-01..06 | T-137-12..13 | `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ASDF_NODEJS_VERSION=20.18.1 mix test test/install_smoke/twin_cli_test.exs --seed 0` — new, created here; blocked/incomplete exits reject. |
| 137-06 T2 | TWIN-01..06 | T-137-01..13 | All six default-safe fast tests together, then a fresh explicit Docker `run --evidence-dir` with normal confirmed-stop cleanup followed by a separate `verify --inputs .../inputs.json --receipt .../receipt.json` process, existing `quality_signal_policy_test.exs` + `ci_lane_split_test.exs`, existing `public_surface_snapshot_test.exs`, and `./scripts/maintainer/automation_first_contract.sh`; exact commands and failure signals are in 137-06-PLAN.md. |

`T-137-SC` applies to each plan's package legitimacy boundary. No new dependency
is authorized; host lock resolution and unexpected package rejection are tested.

## Multi-Source Coverage Audit

| Source | Item | Plan | Status |
|---|---|---|---|
| GOAL | Production-faithful fresh-package synthetic host with trusted redacted lifecycle/residue evidence | 01–06 | COVERED |
| REQ | TWIN-01 synthetic/non-pilot identity | 01, 04, 06 | COVERED |
| REQ | TWIN-02 fresh external archive and private/repo exclusion | 01–02 | COVERED |
| REQ | TWIN-03 adopter-owned host and live services | 01–03 | COVERED |
| REQ | TWIN-04 documented deterministic fault | 01, 03 | COVERED |
| REQ | TWIN-05 persisted retry and separate runtime | 01, 03 | COVERED |
| REQ | TWIN-06 typed redacted bound receipt and cleanup | 01, 04–05 | COVERED |
| RESEARCH | Dedicated small container host, one exact tar and accepted host lock | 01–02 | COVERED |
| RESEARCH | Public ingress, storage callback, atomic counter, default Oban and quiescent restart | 01, 03 | COVERED |
| RESEARCH | Retained runner-owned expected inputs, finite semantic receipt, redaction, complete pre-disposal inventories and active-host-safe janitor | 01, 04–06 | COVERED |
| RESEARCH | Single maintainer UX and existing CI topology | 06 | COVERED |
| CONTEXT | D-137-01..04 host/package/version boundary | 01–02 | COVERED |
| CONTEXT | D-137-05..09 public/durable/fault/restart boundary | 01, 03 | COVERED |
| CONTEXT | D-137-10..12 receipt/privacy/cleanup | 01, 04–05 | COVERED |
| CONTEXT | D-137-13..15 small dependency, UX, workflow/fences | 01, 06 | COVERED |

Deferred RECOV, READY, numeric speed, independent adoption, frontend and new
provider/service work are excluded by the locked phase boundary, not missing
Phase 137 items. The spec-less probe has 13 proposed edges: eight resolved to
executable truths in Plans 03/04 and five flagged assumptions in Plan 04.

## Wave 0 Requirements

Owning implementation tasks create new test files before their verify commands
run. Existing ExUnit and shell infrastructure supplies the framework. Plans must
record all new test paths and dependency order without a separate scaffolding wave.

## Manual-Only Verifications

All phase behaviors have automated verification. Credential or irreversible-action
authorization, if later needed, cannot close a TWIN requirement.

## Validation Sign-Off

- [x] Every task has a runnable automated command and stated failure direction
- [x] No three consecutive tasks lack an automated verification
- [x] Every new command target has an owning creation task
- [x] Real package/Oban/restart/cleanup tracer and separate verifier with retained inputs and receipt are required for acceptance; default `mix test` does not require Docker
- [x] No watch-mode commands or invented timing evidence
- [x] All checks pass during execution before Nyquist compliance is claimed

Approval: executable acceptance passed. Final retained run: `/private/tmp/rindle-twin-137-accepted-9hf_wi4o`.
Run, separate explicit-inputs verify and repeated cleanup each exited 0. The native
compile step was observed uncached. Real running/paused cleanup refusals preserved
all owned storage before successful stopped-host disposal. Source/receipt/cleanup
mutation controls passed; no human response closed any requirement.

## Execution Notes

All twelve task checks have passing executable evidence in the six summaries.
The versioned-host Doctor diagnostic found a legacy-ledger false failure; Plan 02
was narrowly rescoped after repeated blocking, and that defect remains a normal
pending todo. Direct catalog/version/image/storage checks are required and passed.
No Doctor pass, independent pilot, AV execution, numeric CI speed or readiness credit.
Five spec-less assumptions remain explicitly scoped as in Plan 04; no invented
acceptance was counted. The two source prohibitions are now exercised by strict
receipt/synthetic-label and privacy-canary tests.

## Validation Audit 2026-10-22

| Metric | Count |
|---|---|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
