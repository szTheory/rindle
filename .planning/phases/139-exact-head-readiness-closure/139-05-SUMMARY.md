---
phase: 139-exact-head-readiness-closure
plan: "05"
subsystem: readiness-closure-controller
tags: [readiness, immutable-refresh, bounded-execution, cleanup, process-ownership]
requires:
  - phase: 139-02
    provides: Complete isolated local qualification and observed disposal
  - phase: 139-03
    provides: Exact main CI/scheduled Nightly/effective protection collection
  - phase: 139-04
    provides: Complete current disposition and security collection
provides:
  - One bounded same-subject candidate controller with early remote preflight and final complete reobservation
  - Immutable original-manifest refresh with distinct byte-bound receipts and correctly rebased artifact references
  - Nonpassing initial/terminal attempts, private crash diagnostics and signal-aware owned child disposal
affects: [139-06, 139-07]
actuals:
  tokens: 14148
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [candidate-only authority, exclusive evidence reservation, atomic final publication, separate bounded cleanup, registered POSIX process groups]
key-files:
  created: [scripts/maintainer/readiness_closure.py, scripts/maintainer/readiness_process.py, scripts/ci/test_exact_head_closure.sh]
  modified: [scripts/maintainer/exact_head_readiness.py, scripts/maintainer/validate_exact_head_readiness.exs, scripts/ci/test_exact_head_qualification.sh, scripts/maintainer/live_residue_allowlist/automation_workflows.json]
key-decisions:
  - Check remote eligibility before expensive local qualification and compare all mutable facts again before publication.
  - Candidate ready remains candidate_only with requirements_credit false, including execution-mode candidates.
  - Preserve original manifest bytes; refreshed artifacts and observation projections use separate confined paths and verified combined-graph validation.
  - Preserve the initial nonpassing record and private failure diagnostics, including failed cleanup without relabeling the qualifier's original attempt.
  - Stop registered child groups on interruption and give the qualifier time for its own bounded resource disposal before emergency retry.
requirements-completed: [READY-01, READY-02, READY-03, READY-04]
evidence_scope: implementation_only
coverage:
  - id: complete-candidate-and-refresh
    description: Same-subject collectors, local proof registry and all five fresh mutable receipts must pass the actual graph validator
    verification:
      - kind: integration
        ref: bash scripts/ci/test_exact_head_closure.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_exact_head_readiness.sh
        status: pass
    human_judgment: false
  - id: bounded-failure-and-disposal
    description: Crash, absent scheduled proof, source/main drift, timeout, interrupt, malformed cleanup and swapped/omitted/forged refreshed proof cannot publish readiness
    verification:
      - kind: integration
        ref: bash scripts/ci/test_exact_head_closure.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_exact_head_qualification.sh
        status: pass
    human_judgment: false
  - id: shared-collector-regression
    description: Current workflow, protection, security, disposition and package-identity contracts remain valid
    verification:
      - kind: integration
        ref: bash scripts/ci/test_readiness_runs.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_readiness_remote.sh
        status: pass
    human_judgment: false
duration: 50min
completed: 2026-10-22
status: complete
---

# Bounded candidate closure and immutable refresh

`close --repo OWNER/REPO --output NEW_DIRECTORY` reserves a nonpassing attempt, resolves
main and requires the clean closing checkout. It checks both remote collectors before
local qualification, then repeats complete remote/adoption observations, rejects changed
facts or query policy, builds the byte-bound graph, runs the actual validator and rechecks
main before atomic publication. Successful output is `candidate_ready`, `candidate_only`,
with no requirement credit. No candidate or fixture pass is terminal READY acceptance.

`refresh --repo OWNER/REPO --manifest PATH --output NEW_DIRECTORY` copies the original
verified graph without changing manifest bytes, gathers fresh same-subject mutable facts,
and writes a separate envelope containing all five new receipt identities. Namespaced
artifact references and their normalized observation bytes are rebased together. Omitted,
swapped, failed or forged-ready envelope content cannot override graph policy. Changes to
the original manifest or its referenced objects before publication prevent a refreshed
candidate from being published.

## Task commits

1. `31b28fe9` adds the actual-validator candidate/refresh tracer, confined immutable object
   import, explicit fixture-only orchestration and preliminary authoritative adoption read.
2. `4cb20531` reproduces five failure-path gaps: missing crash/invalid-fixture terminal
   records, lost scheduled-run reason, incorrect cleanup byte comparison and premature
   refresh publication after original-manifest mutation.
3. `3462992e` fixes those gaps and adds bounded signal-aware process ownership, separate
   cleanup budgets and original-attempt-preserving retry.

## Verification

- Closure: 28 tests, zero failures, 34.1 seconds. Uses the real immutable validator and
  real CLI paths. Covers candidate success, immutable refresh, wrong/mixed subjects or
  evidence modes, current-state pilot boundaries, changed main/source/query, missing
  scheduled proof, corrupt objects, crash persistence, actual command deadlines,
  SIGTERM/child termination, failed/malformed cleanup, distinct cleanup budget, original
  byte preservation, and omitted/swapped/forged refreshed receipts.
- Qualification: 25 tests, zero failures, 7.9 seconds. Added real inner-child interruption
  and the hard cleanup ceiling even when collection time remains.
- Validator: 57 tests, zero failures, 7.1 seconds in concurrent shared regression.
- Workflow collector: 56 tests, zero failures, 34.6 seconds concurrently. Remote collector:
  53 tests, zero failures, 48.8 seconds concurrently. These remain fixture scope.
- Formatter, Python compilation, shell syntax, automation-first and diff checks pass.
  Staged-file residue scan: 679 files, 261 hits, 228 entries, zero violations/pending entries.
  Artifact ledger: 3298 files, 46 classes. Staging before these checks includes new files
  in the repository's tracked-file scanners.

## Operational bounds and retained failures

Collection has a 9600-second total command deadline. Individual collectors and commands
retain their smaller deadlines. An interrupted qualifier receives up to 270 seconds for
its own disposal, and emergency cleanup retry has a separate 270-second bound. The
qualifier itself now has a hard 240-second disposal ceiling and a separate 45-second
finalization bound. No missing scheduled run waits indefinitely or dispatches a substitute.

The initial attempt remains immutable. The terminal verdict and attempt pointer stay
nonpassing on errors, and diagnostic exception content stays in restricted storage.
Cleanup retries verify the actual original attempt bytes and never convert failure into
qualification success. The shared POSIX helper registers owned groups across spawn and
restores the child's signal mask so nested owners can receive termination and stop their
own commands before resource disposal.

A real read-only CLI probe at `/private/tmp/rindle139-unmerged-close-20261022-inline`
returned `not_ready/closing_subject_not_checked_out` for then-current main
`a046e5be585618d4dfc8f559870e4585b1abb06a`. It stopped at the main check before remote
collectors, cloning or local services. This unmerged implementation cannot certify itself.

## Remaining integration

Plan 06 owns the full authoritative adoption mutation suite, producer sidecar/archive
transport, durable retrieval, final acceptance/claim classification, minimal CI fixture
runtime and prerequisite portability. The preliminary reader already requires open pilot
markers, the declared synthetic boundary and pre-1.0 actual project/release state, but
its broader claim-parity integration is not represented as completed READY-05 here.

Original blocked timing/deferral bytes remain historical data references in native run
receipts and retain zero numeric speed credit. Current scheduled Nightly cancellation,
undispositioned PRs 144–146 and unavailable Dependabot visibility remain open live gaps.
READY-01–05 remain open until actual Plan 07 post-merge acceptance with durable bytes.
