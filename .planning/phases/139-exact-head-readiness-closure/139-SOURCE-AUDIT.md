# Phase 139 Multi-Source Coverage Audit

All items below are planned. Phase 133–138 implementation prerequisites pass the executable
`139-preflight.sh` in the authoritative worktree; READY-01–05 still require Phase 139 execution
and later exact-main acceptance. The no-credit numeric speed deferral is an amended scope fact.

## Artifacts this phase produces

Tracked implementation paths: `lib/rindle/ops/runtime_checks.ex`, `lib/rindle/ops/runtime_checks/ownership_checks.ex`, `test/rindle/doctor_test.exs`, `scripts/maintainer/validate_exact_head_readiness.exs`, `scripts/maintainer/exact_head_readiness.sh`, `scripts/maintainer/collect_readiness_runs.sh`, `scripts/maintainer/collect_readiness_remote.sh`, `scripts/maintainer/retain_readiness_bundle.sh`, `scripts/ci/test_exact_head_readiness.sh`, `scripts/ci/test_exact_head_qualification.sh`, `scripts/ci/test_readiness_runs.sh`, `scripts/ci/test_readiness_remote.sh`, `scripts/ci/test_exact_head_closure.sh`, `scripts/ci/test_readiness_retention.sh`, `scripts/ci/test_readiness_adoption.sh`, and `.github/workflows/readiness-retention.yml`. Existing `.github/workflows/ci.yml` and `RUNNING.md` are modified. Plan 07 changes no tracked implementation file; it executes final acceptance after these and all planning artifacts merge.

Added planning prerequisites: `.planning/phases/139-exact-head-readiness-closure/139-preflight.sh`, `139-preflight-test.sh`, and `139-EXECUTION-RECOVERY.md`. Plan 00 changes the existing `Rindle.Ops.RuntimeChecks` migration-ledger producer and `Rindle.Ops.RuntimeChecks.OwnershipChecks` migration predicates; `test/rindle/doctor_test.exs` gains the versioned host, legacy, upgrade, catalog/marker and Oban cases. The supported host wrapper fixture is `test/twin/host/priv/repo/migrations/20261021000000_install_twin.exs`. The public `mix rindle.doctor` command keeps its existing API.

New callable/CLI surface: `validate_contract/2`; `validate_exact_head_readiness.exs --manifest --root --verdict [--refresh-envelope]`; `exact_head_readiness.sh qualify|close|refresh|verify-subject|accept|claim-status`; `collect_readiness_runs.sh --repo --subject --output --fixture`; `collect_readiness_remote.sh --repo --subject --output --fixture`; `retain_readiness_bundle.sh prepare|retrieve`. These are maintainer tooling. Phase 134–138 upstream adapter names are now bound to tracked code in Plans 02 and 04. Plan 00 also corrects the existing public Doctor implementation without new public API/schema. The `close` form takes `--repo --output`, resolves main itself, and rejects a caller-supplied different subject; its verdict is a candidate. The `refresh` form writes a subject-preserving immutable envelope linking original manifest digest, new mutable receipt byte digests, interval, validator identity, adoption parity and verdict; the validator checks this graph. The `retrieve` form discovers a distinct producer digest sidecar from authenticated completed run/attempt artifacts before comparing archive and manifest bytes. The `accept` form is the terminal post-merge acceptance controller. `claim-status` prevents historical completion metadata from becoming an unqualified claim for later main.

| Source | ID or theme | Plan | Status |
|---|---|---|---|
| GOAL | One authoritative exact-current-head verdict with honest synthetic boundary | 01–07 | COVERED |
| REQ | READY-01 isolated supported qualification | 02,05,07 | COVERED |
| GOAL/REQ | Public Doctor versioned host wrapper correction assigned to Phase 139 by PROJECT/STATE | 00,02,07 | COVERED |
| REQ | READY-02 main CI, scheduled Nightly, effective protection | 03,05,07 | COVERED |
| REQ | READY-03 complete current dispositions | 04,05,07 | COVERED |
| REQ | READY-04 fail-closed manifest | 01,05,06,07 | COVERED |
| REQ | READY-05 pilot/adoption truth | 01,06,07 | COVERED |
| RESEARCH | upstream executable preflight, exact toolchain, package archive/payload identity, cleanup | 02 | COVERED |
| RESEARCH | newest full attempts, scheduled incident, effective rules | 03 | COVERED |
| RESEARCH | source-complete inventory, private security visibility, two observations | 04 | COVERED |
| RESEARCH | finite receipt graph, subject-preserving refresh envelope, bounded terminal join, failed attempt persistence | 01,05 | COVERED |
| RESEARCH | producer-side digest sidecar, portable byte-verified retention, synthetic adoption parity, interval-qualified live acceptance and historical metadata | 06,07 | COVERED |
| CONTEXT | D-01 | 01,05,07 | COVERED |
| CONTEXT | D-02 | 01,05,07 | COVERED |
| CONTEXT | D-03 | 01,05,07 | COVERED |
| CONTEXT | D-04 | 01,05 | COVERED |
| CONTEXT | D-05 | 01,02 | COVERED |
| CONTEXT | D-06 | 01,02 | COVERED |
| CONTEXT | D-07 | 01,02 | COVERED |
| CONTEXT | D-08 | 01,02 | COVERED |
| CONTEXT | D-09 | 01,02 | COVERED |
| CONTEXT | D-10 | 01,02 | COVERED |
| CONTEXT | D-11 | 03 | COVERED |
| CONTEXT | D-12 | 03 | COVERED |
| CONTEXT | D-13 | 03 | COVERED |
| CONTEXT | D-14 | 03 | COVERED |
| CONTEXT | D-15 | 03 | COVERED |
| CONTEXT | D-16, as amended by recorded 2026-10-21 numeric timing deferral | 03,06,07 | COVERED; no speed credit |
| CONTEXT | D-17 | 04,05 | COVERED |
| CONTEXT | D-18 | 04,05 | COVERED |
| CONTEXT | D-19 | 04,05 | COVERED |
| CONTEXT | D-20 | 04,05,07 | COVERED |
| CONTEXT | D-21 | 04,05 | COVERED |
| CONTEXT | D-22 | 04,05 | COVERED |
| CONTEXT | D-23 | 06,07 | COVERED |
| CONTEXT | D-24 | 06,07 | COVERED |
| CONTEXT | D-25 | 06,07 | COVERED |

## Spec-less edge coverage

No Phase 139 SPEC exists. The seven unresolved fallback rows remain assumptions until executable probes run. READY-01, READY-02, READY-04, READY-05 unclassified rows are covered by their respective adversarial fixture suites in Plans 02, 03, 01/05, and 06; they are not resolved by this planning note. READY-03 adjacency assumes equal observation timestamps need stable ID tie-breaking; empty assumes an authenticated complete zero-item page is valid only after ledger reconciliation while null is unavailable; ordering assumes equal timestamps sort by stable ID. Plan 04 fixtures test these choices. Any mismatch with completed Phase 134 policy becomes a nonpassing contract discrepancy requiring a plan revision.
