---
phase: 139-exact-head-readiness-closure
plan: "03"
subsystem: workflow-evidence
tags: [readiness, github, scheduled, protection, immutable-evidence]
requires:
  - phase: 139-01
    provides: Finite immutable evidence graph and source policy
provides:
  - Bounded authenticated GET transport with complete Link pagination and restricted raw responses
  - Ordered committed-workflow topology and newest exact-main current-attempt collection
  - Scheduled incident archive verification and effective classic/parent ruleset reconciliation
affects: [139-04, 139-05, 139-06, 139-07]
actuals:
  tokens: 21675
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [ordered detailed YAML nodes, finite condition parser, two complete normalized observations, shared immutable remote policy]
key-files:
  created: [scripts/maintainer/collect_readiness_runs.sh, scripts/maintainer/collect_readiness_runs.py, scripts/maintainer/readiness_github.py, scripts/maintainer/readiness_workflow.exs, scripts/ci/test_readiness_runs.sh]
  modified: [scripts/maintainer/validate_exact_head_readiness.exs, scripts/ci/test_exact_head_readiness.sh, scripts/maintainer/live_residue_allowlist/automation_workflows.json, scripts/maintainer/live_residue_allowlist/automation_generators.json]
key-decisions:
  - Preserve ordered matrix values, including auxiliary booleans in GitHub displayed job names.
  - Use the same finite topology and remote contract for collection and immutable receipt verification.
  - Preserve the intended classic admin bypass while requiring strict CI Summary app binding and compatible active rulesets without bypass actors.
  - Pin approved CI behavior except script-test steps and pin exact-SHA release workflow bytes; intentional topology or release changes require explicit policy review.
  - Original blocked timing and deferral receipts retain their exact hashes and zero numeric acceptance credit.
requirements-completed: [READY-02, READY-04]
evidence_scope: implementation_only
coverage:
  - id: complete-workflow-observation
    description: Current attempt, complete derived jobs, newest execution, actual scheduled incident and effective protection must agree
    requirement: READY-02
    verification:
      - kind: integration
        ref: bash scripts/ci/test_readiness_runs.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_exact_head_readiness.sh
        status: pass
    human_judgment: false
  - id: prior-policy-compatibility
    description: Local qualification and existing strict scheduled/protection policies remain valid
    verification:
      - kind: integration
        ref: bash scripts/ci/test_exact_head_qualification.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_nightly_summary_gate.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_setup_branch_protection.sh
        status: pass
    human_judgment: false
duration: 30min
completed: 2026-10-22
status: complete
---

# Exact-subject workflow collection

The collector derives the complete job inventory from subject-bound workflow bytes,
selects the newest matching execution without filtering for success, reads every job
page from the selected current attempt, and repeats run/attempt and newest-run checks.
Two full observations and current-main checks bound the invocation. Successful collection
is `collected`, never final readiness, and fixture evidence grants no READY credit.

## Task commits

1. `9f8a6b9e` implements the CI tracer, shared GET transport and topology parser,
   plus initial scheduled incident/protection integration.
2. `b9668629` records reproduced failures: foreign incident workflow references were
   accepted and a compatible sole-context ruleset was incorrectly rejected.
3. `cfc6e630` fixes those failures, binds and bounds incident archive bytes, verifies
   active effective rule parameters, preserves historical timing receipts, and handles
   workflow filename-to-numeric-ID pagination without accepting foreign resources.

## Verification

- Workflow collector: 54 tests, zero failures, 20.3 seconds. Includes actual CLI fixture
  transport, ordered matrix/include/exclude, conditional skips, missing main-only/matrix
  work, newest failed/pending/cancelled runs, partial reruns, changed attempts, foreign
  pagination, count truncation, unknown topology, incident identity/archive safety,
  effective compatible/incompatible rulesets, protection visibility/app drift, release
  coupling/fork trigger drift, source changes and exact original timing preservation.
- Immutable validator: 57 tests, zero failures, 2.6 seconds. It independently derives
  topology from graph-bound input bytes, verifies archive-decoded incident identity,
  and requires its loaded topology helper to match the graph's helper identity.
- Existing isolated qualifier: 23 tests, zero failures, 6.1 seconds.
- Existing Nightly summary policy: 49 passed, zero failed. Protection guard: six passed,
  zero failed. Formatter, Python compilation, shell syntax and diff checks pass.
- Residue scan: 672 files, 256 hits, 223 entries, zero violations/pending entries.
  Artifact ledger: 3289 files, 46 classes. Automation-first phase contract passes.

## Read-only live observations and limits

The actual current main observed during implementation was
`a046e5be585618d4dfc8f559870e4585b1abb06a`, not this unmerged implementation branch.
The CI-only collector verified all 23 derived jobs from run `39624064249`, attempt 1,
including the conditionally skipped Mux job, and retained two complete observations at
`/private/tmp/rindle139-live-ci-20261022-inline`.

The full live collector returned `not_ready/latest_attempt_not_green`: the newest exact
scheduled Nightly was run `39741997542`, attempt 1, with overall conclusion `cancelled`.
Its evidence remains at `/private/tmp/rindle139-live-runs-20261022-inline`. A separate
read-only download verified artifact `12409728629` against the API digest
`382fdd2e74a3844bf7a7d062fb98139558694f8b1d7757ae0f66abe8f7f1adff` and decoded the
incident verdict. That artifact is green but cannot replace the cancelled workflow's
full successful attempt. The dedicated adverse fixture enforces this boundary.

No workflow was dispatched or rerun, protection changed, PR merged, or package published.
READY-01–05 remain open. A future closing subject still requires its own scheduled run,
full remote visibility, complete local qualification and durable evidence verification.

## Deviations and integration debt

The shell entrypoint delegates to standard-library Python for bounded transport and
restricted evidence storage. Existing pinned yamerl/Jason dependencies supply ordered
YAML nodes and JSON; no dependency was added. Shared helpers and validator integration
were added to the plan inventory as necessary implementation seams.

Approved CI semantics are pinned after excluding only the existing `ci-script-tests`
job's steps. Plan 06 may add cheap fixture setup/steps there without weakening other
CI/fork behavior or adding a recurring cloud lane. Release workflow bytes remain pinned.
The minimal fixture runtime, producer retention and historical preflight portability
remain Plan 06 work. GitHub observations do not claim a cross-endpoint atomic snapshot.
