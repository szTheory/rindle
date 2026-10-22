---
phase: 139-exact-head-readiness-closure
plan: "06"
subsystem: readiness-retention-and-acceptance
tags: [readiness, durable-evidence, producer-digests, adoption-parity, historical-claims]
requires:
  - phase: 139-05
    provides: Bounded candidate closure and immutable same-subject refresh
provides:
  - Separate producer-run/attempt-bound digest sidecar and authenticated completed-run durable retrieval
  - Exact merged-subject inventory, terminal acceptance controller and refreshed current/historical claim inspection
  - Authoritative synthetic-only adoption check and graph-bound authoritative input hashes
  - Maintainer-dispatched producer, cheap parser-only CI fixture seam and exact repair commands
affects: [139-07]
actuals:
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [separate producer expectations, atomic durable publication, complete tracked inventory, subject-qualified historical claims]
key-files:
  created: [scripts/maintainer/readiness_retention.py, scripts/maintainer/retain_readiness_bundle.sh, scripts/maintainer/readiness_acceptance.py, scripts/maintainer/readiness_adoption.py, scripts/ci/readiness_fixture.exs, scripts/ci/test_readiness_retention.sh, scripts/ci/test_readiness_acceptance.sh, scripts/ci/test_readiness_adoption.sh, scripts/ci/prepare_readiness_fixture_runtime.sh, scripts/ci/test_readiness_fixtures.sh, .github/workflows/readiness-retention.yml]
  modified: [scripts/maintainer/exact_head_readiness.py, scripts/maintainer/readiness_closure.py, scripts/maintainer/readiness_github.py, scripts/maintainer/validate_exact_head_readiness.exs, .github/workflows/ci.yml, RUNNING.md]
key-decisions:
  - Download authenticated producer sidecar first; compare actual archive and manifest bytes to those separate expected hashes.
  - Only execution-mode terminal acceptance on clean merged main may grant historical READY credit; fixture and candidate results grant none.
  - Preserve historical predecessor fingerprints and blocked timing debt without requiring agent-local GSD or temporary matrix files on a producer runner.
  - Revalidate stored graph bytes and collect new mutable observations before any current-head claim; advanced main reports historical readiness only.
requirements-completed: [READY-04, READY-05]
evidence_scope: implementation_only
coverage:
  - id: producer-and-durable-bytes
    description: Completed exact producer identity and separate expected digests bind archive/manifest bytes before atomic restricted durable storage
    verification:
      - kind: integration
        ref: bash scripts/ci/test_readiness_retention.sh
        status: pass
    human_judgment: false
  - id: authoritative-adoption-and-claim-scope
    description: Actual authoritative state and mutated copies reject synthetic pilot/independent/1.0 inflation; merged subject and refreshed terminal graph guard historical/current claims
    verification:
      - kind: integration
        ref: bash scripts/ci/test_readiness_adoption.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_readiness_acceptance.sh
        status: pass
      - kind: integration
        ref: bash scripts/ci/test_readiness_fixtures.sh
        status: pass
    human_judgment: false
  - id: portable-prerequisite-and-owner-regressions
    description: Historical delivery/debt mutations fail without private matrix dependence; existing Doctor/scanner/public-surface and workflow truth remain valid
    verification:
      - kind: integration
        ref: bash .planning/phases/139-exact-head-readiness-closure/139-preflight-test.sh
        status: pass
      - kind: integration
        ref: mix test test/rindle/doctor_test.exs test/install_smoke/twin_cli_test.exs test/install_smoke/live_residue_scan_test.exs test/rindle/public_surface_snapshot_test.exs
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
---

# Producer retention and terminal claim enforcement

`prepare` validates the candidate graph, includes only referenced portable objects and exact
manifest bytes, scans for private-source canaries/known credentials, and writes a deterministic
bounded USTAR/gzip archive. A separate sidecar binds repository, main SHA, workflow, run,
attempt, evidence mode, paired unique artifact names and independent archive/manifest digests.
The explicit main-only producer uploads that pair with pinned actions, no overwrite,
missing-file errors and 30-day retention, exposing both artifact IDs/transport digests.

`retrieve` authenticates repository, completed successful run/current attempt and artifact
metadata, verifies API transport digests, downloads the sidecar first and checks producer
identity before trusting its expected archive and manifest hashes. Bounded ZIP/USTAR readers
reject traversal, symlinks/extensions, duplicate/extra members and private canaries. Verified
bytes are read back, files/directories are synced, and the restricted copy plus locator is
published atomically. Parent-sync failure rolls publication back. Live retrieval refuses
Actions runners and recognized temporary storage. Fixture retrieval is explicitly fixture-only.

`verify-subject` requires clean local HEAD equal to authenticated main and every declared
source path plus all eight plans at that SHA. `accept` correlates a unique main workflow
request, bounds its wait, retrieves completed producer bytes durably, runs the actual immutable
refresh validator, and rechecks subject/adoption before writing the terminal verdict. A forged
ready scalar cannot override missing or failed receipts. Existing output directories remain
immutable. `claim-status` checks referenced bytes and the stored graph; advanced main yields
historical scope, while matching main requires another complete mutable refresh.

The callable adoption check reads real requirements/project, Mix version, release manifest
and release intent. It rejects closed PILOT-01/02, positive independent-adopter claims and
1.0 authority from synthetic proof. Close/refresh/accept call it, and the graph validator binds
all five authoritative input hashes in adoption observations. CI uses only already root-locked
Jason/yamerl in a private minimal parser runtime; it does not run native qualification.

## Evidence

- Full parser-only fixture run: **290 tests, zero failures in 83 seconds** (59 validator,
  25 qualifier, 56 workflow, 53 remote, 28 closure, 31 retention, 17 adoption, 21 acceptance).
  Log: `/private/tmp/rindle139-plan06-fixtures-final.log`.
- Final retention/adoption/acceptance rerun: **31/17/21 tests, zero failures**.
- Doctor/twin CLI/live scanner/public-surface owner regressions: **58 tests, zero failures**.
- Unchanged `mix quality_signals`: passed, including **97 contract tests, zero failures**.
- CI Summary **6**, Nightly Summary **49**, incident lifecycle **48**, protection guard **6**
  assertions passed. New producer workflow passes actionlint. Existing CI retains its six
  preexisting actionlint diagnostics; the added steps introduce zero diagnostics.
- Staged live residue scan: **690 files, 272 hits, 239 reviewed exact entries**, zero violations.
  Artifact ledger: **3310 files, 46 classes**. Narrow allowance edits retain byte-idempotence.
- Portable prerequisite adverse fixtures and automation-first contract pass. UI safety has no
  UI/block; schema has no drift; codebase drift skips because no STRUCTURE.md exists.
- Live read-only `verify-subject` against main `a046e5be585618d4dfc8f559870e4585b1abb06a`
  correctly returned `not_ready: closing_subject_not_checked_out`, before producer dispatch.

## Deviations and remaining live prerequisites

The source operations were committed together before the separate CI/docs integration commit
because retention, authoritative parity and controller fixtures share the same graph runtime.
A shared fixture module replaces shell-source extraction. The preflight was made portable:
old reports remain historical with their original fingerprints, and current eighteen-gate /
six-case qualification supplies fresh proof. Original timing debt bytes remain pinned and
unchanged, with no numeric-speed acceptance credit. Separate subject and accept output paths
avoid attempting to reuse an immutable evidence reservation.

**No terminal execution acceptance, producer dispatch or live durable retrieval ran. All
READY-01–05 remain open.** Plan 07 still needs the complete PR train merged onto main,
a successful newest scheduled Nightly, reconciled current inbox/security dispositions and
complete authorized security-source visibility. The observed PRs 144–146 are undispositioned,
Dependabot GET returned 403, and `READINESS_READ_TOKEN` is absent from repository secret
names. Provisioning credentials/security policy and merging are separate maintainer actions;
no credential, protection, PR, release or security setting was changed by this plan.
