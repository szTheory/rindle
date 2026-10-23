---
phase: 139-exact-head-readiness-closure
plan: "02"
subsystem: maintainer-qualification
tags: [readiness, package, isolation, cleanup, evidence]
requires:
  - phase: 139-00
    provides: Correct public Doctor host-ledger inspection
  - phase: 139-01
    provides: Finite immutable evidence graph contract
provides:
  - Bounded qualifier for all eighteen local gate owners on a fresh remote-main checkout
  - Real package archive, metadata and payload identities with generated-host Doctor and matrix adapters
  - Observed namespace-bound cleanup and immutable failure-preserving cleanup retry
affects: [139-03, 139-04, 139-05, 139-06, 139-07]
actuals:
  tokens: 20771
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [shell entrypoint with standard-library process ownership, typed opaque evidence objects, owned disposable services]
key-files:
  created: [scripts/maintainer/exact_head_readiness.sh, scripts/maintainer/exact_head_readiness.py, scripts/maintainer/qualify_generated_consumer.exs, scripts/ci/test_exact_head_qualification.sh]
  modified: [scripts/maintainer/validate_exact_head_readiness.exs, scripts/ci/test_exact_head_readiness.sh, scripts/maintainer/live_residue_allowlist/automation_workflows.json]
key-decisions:
  - Public Doctor runs inside the fresh generated consumer against the run-built archive and actual host-owned migrations.
  - Original timing qualification stays blocked and unchanged; current gate owners rerun without numeric timing credit.
  - Cleanup has a separate finite budget and retry operation; a successful retry never rewrites the original attempt.
requirements-completed: [READY-01, READY-04]
evidence_scope: implementation_only
coverage:
  - id: isolated-qualification
    description: All local owners required; wrong subject, bytes, runtime, archive, PLT, cleanup or resource ownership cannot qualify
    requirement: READY-01
    verification:
      - kind: integration
        ref: bash scripts/ci/test_exact_head_qualification.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_exact_head_readiness.sh
        status: pass
    human_judgment: false
  - id: upstream-compatibility
    description: Existing package, recovery, policy, generated-consumer and residue contracts remain valid
    verification:
      - kind: integration
        ref: mix test test/install_smoke/twin_cli_test.exs test/install_smoke/twin_receipt_test.exs test/install_smoke/twin_cleanup_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/live_truth_parity_test.exs
        status: pass
    human_judgment: false
duration: 53min
completed: 2026-10-22
status: complete
---

# Isolated qualification and owned disposal

The qualifier selects authenticated current main, records not_ready before work,
clones a fresh subject, verifies supported runtime probe bytes and snapshots detector
policy inputs. It drives eighteen finite local owners, verifies package byte identities,
and remains globally not_ready until remote closure supplies the five mutable proofs.

## Task Commits

1. Task 1: `47b8bf3c` creates the current-main tracer, exclusive attempts, fresh checkout,
   real bounded subprocess capture and failure probes.
2. Task 2 RED: `b12adfcf` proves one green command cannot satisfy full local qualification.
3. Task 2 GREEN: `359e2946` implements the complete registry, actual upstream adapters,
   observed cleanup, failure-preserving retry and stricter byte/runtime input validation.

## Verification

- Qualification fixtures: 23 tests, zero failures, about six seconds. Real disposable
  Git clones and subprocesses complement mocked expensive owners. The fixtures explicitly
  retain fixture scope and grant no real qualification or READY credit.
- Offline validator: 57 tests, zero failures, about 1.5 seconds, including actual runtime
  bytes, duplicate JSON keys, opaque policy objects and refreshed receipt graphs.
- Existing package/recovery/policy/generated-consumer regression: 112 tests, zero failures,
  17 excluded, 40.3 seconds. The excluded live integration cases are not claimed here.
- Residue scanner regressions: 31 tests, zero failures. Full scan: 667 files, zero
  violations, zero pending removal. Eight exact contract/immutable-receipt entries were
  reviewed and retained; the scanner itself and its policy stayed unchanged.
- Artifact ledger: 3283 tracked files/46 classes passed. Format, Python compile, shell
  syntax, diff hygiene and automation-first checks passed.
- Actual CLI precondition probe at `359e2946`: exit 1, `not_ready/main_changed`, no clone
  created, zero requirements credit. Evidence is retained in
  `/private/tmp/rindle139-unmerged-guard.Zksged`. No full live qualification was attempted
  on this unmerged branch.

## Decisions and Safety Boundaries

The shell delegates bounded process ownership to Python; the Elixir consumer adapter
reuses the existing generated-app helper rather than running an install-smoke command
whose integration tags would be excluded. Public Doctor runs before that exact host's
owned temporary root is removed. Archive bytes, metadata bytes and the native payload
manifest are distinct; the generated helper's legacy metadata field is explicitly
normalized without relabeling it as an archive digest. Matrix verification checks the
same source and artifact identities and uses the existing typed six-case verifier.

Private Postgres and MinIO instances isolate contributor, coverage, seed and consumer
state from existing databases and buckets. Before disposal, database/job/provider,
object/multipart, source and temporary inventories are observed. Descriptor hashes,
namespaces, mount ownership, foreign volume users and network users are checked before
mutation; absence is checked afterwards. Tool caches and retained evidence are explicit
exceptions. Command logs remain bounded and restricted; portable outputs redact known
credentials. Failed/crashed/timed-out attempts remain nonpassing after cleanup retry.

## Deviations from Plan

Internal Python and generated-consumer helper files make process and host ownership
explicit without a new dependency or shipped API. The plan's file inventory now records
those helpers and the narrow residue-contract entries.

The original Phase 136 aggregate cannot be relabeled for a later subject or used to
revive its deferred numeric-speed clause. Its blocked bytes and subject are retained
as historical prerequisite identity; current coverage, Dialyzer, bootstrap and finite
async owners run independently on the new subject. No numeric CI-speed credit is granted.

## Next Phase Readiness

Local receipt production is implemented. Plans 03/04 supply current run/protection and
remote-inventory evidence; Plan 05 joins it. Plan 06 must integrate the fixture runtime
into the currently toolchain-free CI Script Tests seam and reconcile predecessor
preflight portability/current-covered-input handling for the producer workflow; do not
rewrite old verification fingerprints. Actual full local and terminal readiness
acceptance remains Plan 07 after all tracked changes merge. READY-01–05 remain open.

## Self-Check: PASSED

All declared source/test artifacts and task commits exist. Focused automated checks
passed after the final source edits. This summary records implementation coverage,
not an accepted current-main readiness verdict.
