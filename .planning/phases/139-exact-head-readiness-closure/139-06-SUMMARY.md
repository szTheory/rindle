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
  commits: 5
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
  - id: bounded-ci-harness-overlap
    description: All legacy commands and readiness fixtures remain required within the unchanged CI Script Tests job, with both registered groups awaited and failures/timeouts preserved
    verification:
      - kind: integration
        ref: bash scripts/ci/test_script_test_groups.sh
        status: pass
      - kind: integration
        ref: mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_timing_automation_test.exs test/install_smoke/ci_cache_hygiene_test.exs
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
---

# Producer retention and terminal claim enforcement

## Package-proof transport repair

CI run 39879109098 attempt 2 passed the retried optional-dependency install but
Proof reached its existing 15-minute job limit in the package-authority suite.
An isolated traced reproduction first exposed a separate generated-consumer
transport defect: database creation honored `PGPORT`, while the generated Repo
omitted it for migrations. The generated test config now binds the same explicit
port. A real Phoenix-template regression failed with `nil` instead of 61234,
then passed after the fix (41 tests, zero failures, 40 excluded).
Logs: `/private/tmp/rindle139-proof-2be3514f/test.log` (red) and
`/private/tmp/rindle139-proof-69928ac3/test.log` (green). Both runs disposed only
their unique PostgreSQL/MinIO containers. The full package proof and final-main
acceptance remain pending; this transport repair grants no readiness credit.
After formatting, the full offline live-truth owner suite passed: 41 tests,
zero failures, one live MinIO case excluded, in 30.2 seconds. Blocking Credo,
the live residue scan (693 files, 273 hits, 240 exact allowances), and the
automation-first contract also passed.

The traced port-corrected baseline completed all package-authority tests in
437.2 seconds (41 tests, zero failures, 16 excluded); the live case alone took
400.1 seconds. Four post-rebuild mutations each reran an independent generated
consumer. The verifier now delegates its unchanged post-rebuild byte/source/
argv/lifecycle assertions to a pure comparison seam. The mutation tests call
that same seam; it returns no normalized authority. Public verification still
rebuilds the committed package/helper and real lifecycle before normalizing,
and both hostile-helper and hostile-context live checks remain in place.
No cache, caller-proof bypass, dependency, workflow, or timeout change was added.

The revised live suite completed in 222.3 seconds (42 tests, zero failures,
16 excluded), retaining every rejection and adding a failed-lifecycle mutation.
Logs: `/private/tmp/rindle139-proof-f9937835/test.log` (baseline) and
`/private/tmp/rindle139-proof-914e79df/test.log` (revised live suite).
The final transport unit fixture invokes the actual config patcher without a
generator installation: its offline owner suite passed 42 tests, zero failures,
one live case excluded (`/private/tmp/rindle139-proof-af43ba9b/test.log`).
`mix quality_signals` passed with 97 contract tests and unchanged baselines.
These are local repair measurements, not the deferred CI speed requirement or
final-main acceptance; GitHub must still verify the exact pushed source.

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

## Post-review integration evidence

The review branch incorporates current main `a046e5be` as an ancestry-only merge.
Its fourteen shared-file conflicts were older pre-merge Phase 136 records versus
later verified closeout and subsequent removal-only ratchets; resolution preserved
the verified branch tree byte-for-byte. Main itself was unchanged.

Two adverse real-state mutations exposed adoption prose gaps: reversed independent
pilot assertions and current synthetic-based 1.0 authorization. Both failed before
repair and pass afterward (19 adoption fixtures). The inventory now includes every
tracked Phase 139 artifact in addition to declared source and all eight plans;
context and summary presence are asserted through real temporary Git checkouts.
The twin runbooks distinguish historical no-Doctor-credit receipts from the corrected
public Doctor exercised by current readiness.

Full parser-only suite after the claim repair: **292 tests, zero failures in 89 seconds**
(`/private/tmp/rindle139-pr-fixtures-final.log`); the final inventory change has a
separate fresh 21-test acceptance regression. Supported-toolchain **`mix ci` exited 0**:
**3 doctests, 1755 tests, zero failures, 87 excluded, 4 skipped**, in its own new
PostgreSQL partition; owned database disposal exited 0. Log:
`/private/tmp/rindle139-pr-mix-ci.log`. This is local implementation/PR validation,
not actual terminal exact-main acceptance. Plan 07 and READY-01–05 remain open.

## Current inbox prerequisite reconciliation

PRs 144, 145 and 146 were read directly through their authenticated PR and file
endpoints: each is open, behind main, and modifies only mix.lock. The review branch
now retains them for separate dependency landing, pinned to their observed head SHAs,
with rebase and fresh CI Summary/package/adopter proof required before a landing
decision. This changes local disposition data only and grants no merge or READY credit.
Offline ledger validation and its 72-case harness pass. The remote-source fixture
baseline supplies explicit synthetic open PRs instead of importing live candidate heads.

A fresh execution-mode diagnostic against unchanged main `a046e5be` still returns
`not_ready: pull_undispositioned` because the collector correctly reads the ledger
**at that remote subject**, where these new dispositions are not yet merged. Evidence:
`/private/tmp/rindle139-reconciled-remote-inline/verdict.json`. This is expected source
binding, not permission to combine an unmerged ledger with main's manifest. Complete
security visibility, producer credentials, scheduled proof and durable storage still
need actual post-merge observations.

## PR runner-context regression

Draft PR 163 runs CI on the review branch. Its first CI Script Tests job exposed
an ambient-environment assumption in the temporary-storage fixture: on Actions,
the production guard correctly returns durable_host_required before it checks
whether a destination is ephemeral. The fixture now explicitly simulates a durable
host for that one path test; the separate runner-rejection test still asserts the
real runner gate. Production retention policy is unchanged. The failure was
reproduced locally with GITHUB_ACTIONS=true/RUNNER_TEMP set; all **292 fixtures then
passed in 84 seconds** under that same runner environment. Evidence:
`/private/tmp/rindle139-runner-retention-red.log` and
`/private/tmp/rindle139-runner-fixtures-green.log`. CI still must pass on the final
PR head before any merge. No READY acceptance is inferred from this repair.

## Preserve the five-minute CI seam with bounded overlap

The repaired CI run 39869147860 passed all 292 readiness fixtures in 162 seconds,
then reached the unchanged five-minute job ceiling during the existing contract
harnesses. Its Nightly incident harness passed all 48 cases before cancellation;
this was aggregate job runtime, not an assertion failure. The CI Script Tests job
now runs the complete existing command group and the readiness group concurrently,
with exactly two registered top-level process groups, a 240-second shared budget,
full wait/exit aggregation, output caps and owned interruption/timeout disposal.
The original five-minute job limit, all fourteen existing commands, workflow/job
identity, dependencies, required context and release authority remain unchanged.

The exact new workflow run body passed locally: both group exit codes were zero,
all old harnesses passed and all 292 readiness fixtures passed (87 seconds for that
group). Four new real-child regressions cover both-success, either failure while
awaiting the other group, and bounded timeout disposal. Existing parsed CI/cache/
quality policy regressions passed **70 tests, zero failures**. Artifacts:
`/private/tmp/rindle139-overlap-step.log`,
`/private/tmp/rindle-script-groups-0fd028b8d2a602e3/results.json`,
`/private/tmp/rindle139-overlap-policy.log`. The final PR head still needs green
required CI; these implementation checks grant no terminal READY credit.


## Storage/access recommendation and three-group scheduling repair

User approved PR #163 squash merge after all required final-head checks pass and
continuation of Plan 07. That approval is saved privately under
`/Users/jon/Library/Application Support/Rindle/readiness/pr-163-merge-authorization.json`;
the persistent parent is mode 0700. No backup configuration is inferred. The new
`guides/readiness_evidence.md` records the local-files-plus-encrypted-backup default,
30-day Actions transfer retention, repository-scoped expiring read token permissions,
and the separate local dispatch credential. No new dependency or storage service is added.

Read-only live diagnosis confirmed Dependabot alerts are disabled (the authenticated
403 explicitly says so), rather than merely inaccessible. READINESS_READ_TOKEN remains
absent. Separate authorization for enabling alerts and human secret provisioning is
pending; no security setting, credential or release was changed.

CI run 39871137258 passed all 292 readiness fixtures in 155 seconds, but the serial
legacy group exhausted the 240-second shared budget during hygiene fixtures. The
independent Nightly incident command now has its own third owned group. Every original
workflow command remains exactly once; all three groups are awaited, any failure or
timeout stays nonpassing, and the 240-second shared bound/five-minute job remain.
The driver now prints its aggregate failure reason as well as recording it locally.
Six real-process/command-preservation regressions pass. Final CI remains required.

The exact workflow body then passed locally under the runner environment with all
three group exit codes zero; all original harnesses and all 292 readiness fixtures
passed (91 seconds for the readiness group). Logs: `/private/tmp/rindle139-three-groups-step.log`
and `/private/tmp/rindle139-three-groups-final.log`. Automation-first and diff checks passed.


## Live prerequisite setup and CI owner-test correction

On 2026-10-22 the user authorized the recommended prerequisite setup. The GitHub
vulnerability-alerts PUT succeeded, setting GET returned 204, and the complete
alerts GET succeeded. Automatic security-update PRs remain disabled. A first empty
read is not terminal inventory acceptance; fresh source coverage is still required.
Time Machine reports no configured destination. The private evidence parent is
ready; backup configuration and producer secret are pending user input. Chrome is
at GitHub Confirm access, requiring the user's passkey before fine-grained token
setup. No broad CLI token was replicated into Actions.

Run 39872109756 passed the complete CI Script Tests job (all three group exits
zero; 292 readiness fixtures in 217 seconds), plus Integration, Contract, package
consumer, adoption smoke and both optional-dependency cells. Both Quality cells
reported the same three failures: two Nightly policy assertions pinned obsolete
individual script step labels, and RUNNING accidentally included a release-system
name forbidden by the adopter-doc copy guard. The actual policy was preserved: the
updated test requires all fifteen carrier lines (the fourteen original commands
and the process-group regression), unconditional/nonmasked execution, the unchanged
five-minute job and sole required join. Driver real-process tests separately require
all owned groups to finish and propagate any failure. RUNNING uses the existing
release-automation wording; release authority and workflow bytes are unchanged.

The focused reproduction was **31 tests, 3 failures**; after correction, the workflow,
docs, CI timing/cache and quality owner suite passed **101 tests, zero failures**.
Its new isolated database was checked absent before use and removed afterward. Logs:
`/private/tmp/rindle139-policy-red.log`, `/private/tmp/rindle139-policy-green.log`.
Required final-head CI and actual Plan 07 terminal acceptance remain pending; no
READY credit is inferred from configuration or these checks.

The obsolete source-disabled ledger exception was removed after the authenticated
setting/read succeeded; existing advisory exceptions and dependency PR dispositions
are unchanged. Hex audit remains a separate source. The scanner allowlist changes
only the existing policy literal's trailing list comma; no new entry or broad baseline
regeneration was introduced.

The user completed GitHub authentication, then generated and submitted the prepared
Rindle-only seven-day read token directly to Actions. Secret metadata confirms
READINESS_READ_TOKEN creation at 2026-10-22T23:47:29Z; no token value entered agent
output or a tracked file. The user selected ~/Dropbox, resolving to the existing
CloudStorage Dropbox folder. ~/Dropbox/Rindle/readiness is prepared at 0700 for
redacted evidence; no terminal bundle exists to copy and cloud sync is unverified.
After the ledger correction, 72 ledger, 53 remote and 21 acceptance fixtures pass;
live residue scan reports 693 files/273 hits/240 reviewed entries with zero violations,
and the artifact ledger covers 3314 files/46 classes. These are implementation and
setup checks only, with no terminal READY credit.


## Proof docs-link repair from live progress check

CI run 39874185827 passed both Quality cells, all script fixtures, Integration,
Contract, package-consumer, Adopter, adoption smoke/unit and brandbook. Proof's
adopter docs link hygiene gate rejected three GitHub-only Markdown link patterns.
The local gate reproduced the same three failures. RUNNING now links the two
maintainer guides by their generated HTML names; the twin and readiness guides
link back to running.html. The readiness guide is included in ExDoc extras and
the existing Maintainer group, so the new target actually exists. No runtime,
required-check identity, CI timeout or release-authority change was made.

After repair, check_docs_links.sh passes. A real mix docs build exits zero, and
HTML parsing confirms all four cross-links and the readiness anchor resolve in
the generated site. The existing generated-release-doc assertion, formatting,
automation-first contract and diff whitespace check pass. The build still emits
existing unrelated documentation-reference warnings; this is not a zero-warning
claim. Required checks must pass again on the new PR head. No READY credit.


## Persistent prerequisite failures reconciled on 2026-10-23

CI 39887885433 on 624a4155 passed the repaired Proof lane. One bounded failed-job
retry (attempt 2) passed Package Consumer in 6m30s, but the adoption smoke job again
exhausted both bounded FFmpeg downloads from the Azure Ubuntu mirror. No further
unchanged retry was dispatched. The apt helper now gives the official HTTPS Ubuntu
archive explicit priority while preserving runner fallback mirrors, package signature
verification, cached-index fast installation, two attempts and all timeout values.
APT's documented mirror transport chooses randomly without priority metadata; see
https://manpages.debian.org/bookworm/apt/apt-transport-mirror.1.en.html.

Scheduled Nightly 39919175401 passed all test lanes, Summary and verdict persistence,
but its incident lifecycle repeatedly classified an absent open target as an uncertain
mutation until the five-minute job cancelled. Read-only issue events show #131 was
closed by szTheory on 2026-10-20, without the lifecycle recovery marker. Replay now
tracks the incident owning its authenticated opening marker, enforces ownership for
later markers, and appends historical recovery evidence to that same closed issue
when a later authenticated green verdict exists. It does not reopen the issue. A
still-red manual closure conflict fails before any mutation instead of retrying.
The close path uses an explicit comment for an already closed target because the
GitHub CLI returns success before applying --comment in that state; primary source:
https://github.com/cli/cli/blob/trunk/pkg/cmd/issue/close/close.go. Existing immutable
verdict authentication, checkpoint checks, ordering and duplicate-marker refusals remain.

The old manager failed all six added manual-closure/ownership/idempotence cases
(48 passed, 6 failed). The repaired manager passed all 54 cases. Focused canonical
CI cache/apt and Nightly policy owner checks passed 30 tests, zero failures, using
an isolated owned database; all owned services were removed. All six process-group
regressions passed. Shell syntax, ShellCheck and diff checks passed. Logs:
/private/tmp/rindle139-nightly-replay-diagnostic/before-tests.log,
/private/tmp/rindle139-nightly-repair-tests.log,
/private/tmp/rindle139-proof-95edefd1/test.log and
/private/tmp/rindle139-script-groups-owner.log.

A read-only local replay against downloaded live artifacts stopped before any
simulated mutation at the pre-existing checkpoint issue-digest guard; it grants no
live repair credit. Actual scheduled runner execution remains required. No source
was retried as acceptance, no new dependency was added, and READY-01–05 remain open.
PR #163 auto-merge was temporarily disabled to include these fixes and will be
restored only after the tested repair is pushed; its existing final-head CI approval
remains applicable. The accepted historical timing deferral retains zero credit.

The official runner-image source was checked before merge:
https://github.com/actions/runner-images/blob/main/images/ubuntu/scripts/build/configure-apt-sources.sh.
It sets Azure priority 1, archive priority 2 and security priority 3. The initial
repair used archive priority 1 and could therefore tie Azure. It was corrected to
priority 0, and the owner fixture now uses the runner's exact three-entry layout,
including trailing slashes and priorities. This intentionally supersedes f9de501f's
mirror priority; final-head CI must run on the correction before authorized merge.
