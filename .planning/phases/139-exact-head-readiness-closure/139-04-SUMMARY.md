---
phase: 139-exact-head-readiness-closure
plan: "04"
subsystem: current-remote-disposition
tags: [readiness, inbox, security, hex, visibility, redaction]
requires:
  - phase: 139-01
    provides: Immutable graph and finite source policy
  - phase: 139-03
    provides: Bounded GET transport, workflow policy and effective-protection normalization
provides:
  - Complete separate issue, PR, check/history, status, advisory, Dependabot, Hex, protection and terminal sources
  - Actual existing ledger reconciliation over two bounded complete observations
  - Fresh signed-registry audit of both exact lockfiles without project code or existing cache/ignore influence
affects: [139-05, 139-06, 139-07]
actuals:
  tokens: 22202
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [private raw evidence with portable identity-only projections, literal-only lock parsing, isolated Hex registry snapshots, current/historical check attempt binding]
key-files:
  created: [scripts/maintainer/collect_readiness_remote.sh, scripts/maintainer/collect_readiness_remote.py, scripts/maintainer/readiness_hex_audit.exs, scripts/ci/test_readiness_remote.sh]
  modified: [scripts/maintainer/readiness_github.py, scripts/maintainer/readiness_workflow.exs, scripts/maintainer/collect_readiness_runs.py, scripts/maintainer/validate_exact_head_readiness.exs, scripts/ci/test_exact_head_readiness.sh, scripts/ci/test_readiness_runs.sh, scripts/maintainer/live_residue_allowlist/automation_workflows.json, scripts/maintainer/live_residue_allowlist/automation_generators.json]
key-decisions:
  - Preserve each source separately; an empty authorized source cannot replace an unavailable source or another security system.
  - Prove unpublished-advisory visibility with repository admin access, explicit private-state reads and endpoint-specific credential permission evidence.
  - Bind each Actions check to its own historical/current job attempt; an older successful summary cannot become the latest attempt.
  - Run Hex audit against literal-validated lockfiles in new minimal projects with fresh registry homes, empty ignores, TLS and signature verification.
  - Keep private bodies and credentials outside portable evidence; portable records retain coverage, disposition and byte identities.
  - Presence of a fixture option always means fixture mode; null or empty fixture inputs never fall through to network.
requirements-completed: [READY-03, READY-04]
evidence_scope: implementation_only
coverage:
  - id: complete-current-disposition
    description: Separate complete sources reconcile actual ledger policy, exact heads/attempts and terminal items across two reads
    requirement: READY-03
    verification:
      - kind: integration
        ref: bash scripts/ci/test_readiness_remote.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_exact_head_readiness.sh
        status: pass
    human_judgment: false
  - id: visibility-and-byte-boundaries
    description: Inaccessible private sources, private canaries, incomplete Hex snapshots and malformed fixtures cannot become acceptance evidence
    requirement: READY-04
    verification:
      - kind: integration
        ref: bash scripts/ci/test_readiness_remote.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_readiness_runs.sh
        status: pass
    human_judgment: false
  - id: existing-owner-compatibility
    description: Existing inbox collector, disposition validator and isolated qualification remain valid
    verification:
      - kind: integration
        ref: bash scripts/ci/test_collect_inbox.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_validate_inbox_ledger.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_exact_head_qualification.sh
        status: pass
    human_judgment: false
duration: 38min
completed: 2026-10-22
status: complete
---

# Complete current remote disposition

The default collector requires nine distinct complete sources and actual live-mode
`validate_inbox_ledger.sh` acceptance of the captured inventory. It repeats all sources,
ledger identity, admin visibility and current main before producing `collected`, which
is implementation evidence and grants no READY credit. `--only issues` is explicitly
an incomplete tracer; the finite readiness validator rejects its missing sources.

## Task commits

1. `27d7d368` implements the issue tracer, real ledger shape check, terminal lookups,
   identity-only portable records and initial privacy fixtures.
2. `42c1a296` records five reproduced failures: the tracer omitted seven required sources,
   did not run full ledger reconciliation, and could not reject unavailable private sources.
3. `e8738e80` implements all sources, current/historical check attempt binding, actual
   full ledger reconciliation, private source authorization, fresh signed Hex evidence,
   byte-bound graph validation and additional fail-closed fixture protections.

The shared transport dependency was discovered during execution. Plan 04 now depends
on completed Plan 03; later waves moved forward by one, preserving all eight plans.
There are six waves. Work remains inline at the user's request.

## Verification

- Remote collector: 53 tests, zero failures, 29.3 seconds. Tests exercise actual CLI
  tracer/full paths, the actual ledger owner, private 404/403/permission gaps, malformed
  and empty inventories, cursor pagination, PR head and complete check attempt history,
  separate statuses, equal timestamps/stable IDs, changed source facts, expired/fired
  exceptions, pending/fired Hex version triggers, every locked package/checksum, unsafe
  registry settings, malicious lock input, private canaries and real child timeouts.
- Workflow collector: 56 tests, zero failures, 20.0 seconds. Two additional adverse probes
  reproduced null fixture JSON and an explicit empty fixture argument reaching network
  authentication. Both now remain fixture-scoped and fail before any network operation.
- Immutable graph validator: 57 tests, zero failures, 3.5 seconds. It checks the loaded Hex
  helper identity, each exact lockfile, full locked package/version coverage, and stable
  registry snapshot records containing the correct outer checksums. Opaque database
  objects stay data rather than accidental receipt graph edges.
- Local qualification: 23 tests, zero failures, 6.0 seconds. Existing inbox collector:
  70 passed, zero failed. Existing ledger validator: 72 passed, zero failed.
- Formatter, Python compilation, shell syntax, diff and automation-first checks pass.
  Residue scan: 675 files, 260 hits, 227 entries, zero violations/pending entries.
  Artifact ledger: 3293 files, 46 classes.

## Actual Hex adapter probe

The adapter follows the installed pinned Hex task's registry access and verification
behavior ([audit source](https://github.com/hexpm/hex/blob/v2.5.1/lib/mix/tasks/hex.audit.ex),
[registry source](https://github.com/hexpm/hex/blob/v2.5.1/lib/hex/registry/server.ex)).
It uses no dependency installation and does not execute the subject's project files.
Literal validation precedes the temporary project's lock loading. Raw ETS snapshots and
command output remain private; portable snapshot rows expose record keys and value hashes,
excluding only operational fetch timestamps from stable database identity.

The live production adapter successfully audited 67 root packages with 17,841 database
records and 49 demo packages with 14,199 records at
`/private/tmp/rindle139-hex-adapter-qen90wxj/evidence`. The root contains the three existing
cowlib exceptions; the demo audit has no advisory packages. A separate live trigger probe
at `/private/tmp/rindle139-hex-extra-probe-8vxtmt3b` read cowlib's latest stable registry
version as `2.21.0`. These adapter probes grant no closing-subject or READY credit.

## Current live gaps

Read-only collection against then-current main
`a046e5be585618d4dfc8f559870e4585b1abb06a` found open PRs 144, 145 and 146 without valid
open dispositions in the committed ledger. The improved early guard returns
`not_ready/pull_undispositioned` before expensive check history at
`/private/tmp/rindle139-live-remote-fast-20261022-inline`.

The earlier bounded full diagnostic captured authorized private-state advisory reads,
then returned `not_ready/remote_forbidden` on the Dependabot alerts endpoint (HTTP 403).
Its raw evidence is restricted at `/private/tmp/rindle139-live-remote-20261022-inline`.
The collector does not turn this source into an empty inventory or inherit the older
ledger's disabled-source exemption as current visibility credit. Private advisories
and alerts have separate permission boundaries
([advisory API](https://docs.github.com/en/rest/security-advisories/repository-advisories#list-repository-security-advisories),
[Dependabot API](https://docs.github.com/en/rest/dependabot/alerts#list-dependabot-alerts-for-a-repository)).

No remote issue/PR mutation, permission expansion, workflow dispatch, merge or publication
occurred. READY-01–05 remain open. The ledger and source visibility must be reconciled
on the eventual closing subject; an unsuccessful live diagnostic is not completion.
