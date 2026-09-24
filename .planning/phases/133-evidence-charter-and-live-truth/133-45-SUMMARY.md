---
phase: 133-evidence-charter-and-live-truth
plan: "45"
subsystem: nightly-incident
tags: [github-actions, artifact-retention, replay, bash, jq]
requires: []
provides:
  - Authenticated bounded replay from a retained scheduled-attempt checkpoint.
  - Fail-closed validation for expired evidence, issue-history drift, and checkpoint tampering.
affects: [nightly-incident, phase-133-reconciliation]
actuals:
  tokens: 6500
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: ["Immutable per-attempt checkpoint artifacts with exact-run and issue-preimage binding"]
key-files:
  created: []
  modified:
    - scripts/ci/manage_nightly_incident.sh
    - scripts/ci/test_nightly_incident.sh
    - test/install_smoke/nightly_policy_test.exs
    - .github/workflows/nightly.yml
key-decisions:
  - "Persist a separate immutable checkpoint artifact for each successful scheduled replay, bound to the same attempt's strict verdict artifact and issue history."
  - "Require the effective artifact retention window to meet the 14-day policy and keep at least one hour of expiry margin before replay mutation."
patterns-established:
  - "Replay from the last authenticated run/attempt pair and require exhaustive evidence for every later attempt."
  - "Hash canonical event and issue preimages into a verifiable checkpoint chain."
requirements-completed: [EVID-03, EVID-04]
coverage:
  - id: D1
    description: Nightly replay resumes after earlier verdict artifacts expire, while missing or conflicting active-epoch evidence fails before issue mutation.
    requirement: EVID-03
    verification:
      - kind: integration
        ref: scripts/ci/test_nightly_incident.sh#expired evidence and checkpoint cases
        status: pass
    human_judgment: false
  - id: D2
    description: Scheduled attempts publish exact 14-day verdict and checkpoint artifacts, and checkpoint provenance is cross-checked against the workflow attempt and incident history.
    requirement: EVID-04
    verification:
      - kind: integration
        ref: test/install_smoke/nightly_policy_test.exs#incident lifecycle consumes the strict verdict after every gating result
        status: pass
      - kind: integration
        ref: scripts/ci/test_nightly_incident.sh#checkpoint expiry-boundary cases
        status: pass
    human_judgment: false
completed: "2026-09-24T20:20:03Z"
---

# Phase 133 Plan 45: Bounded Nightly Incident Replay Summary

Authenticated replay checkpoints now let the Nightly incident drainer continue after normal artifact expiry while preserving fail-closed handling for missing active evidence, altered issue history, and forged checkpoint data.

**Started:** 2026-09-24T20:00:00Z  
**Completed:** 2026-09-24T20:20:03Z  
**Duration:** 20 min  
**Tasks:** 2 completed  
**Files modified:** 4

## Accomplishments

- Added a per-attempt checkpoint artifact carrying the last authenticated run/attempt, strict verdict digest, issue number/state, issue-history digest, and chained digest. The drainer validates artifact provenance, the exact workflow attempt, the anchor verdict, and the current issue preimage before trusting the cursor.
- Bounded replay to attempts after the checkpoint. Expired pre-epoch events are allowed; expired or absent events in the active epoch, malformed retention metadata, issue drift, and checkpoint tampering fail before incident mutation.
- Added an hourly expiry safety margin and kept the verdict and checkpoint uploads at the exact 14-day policy.
- Preserved the already committed ordered-attempt behavior and expanded the fake-GitHub matrix for checkpoint expiry, tampering, concurrent history advancement, and the retention cap.

## Task Commits

1. **Task 1: Resume replay from an authenticated durable checkpoint** — `b9647180` (`fix`)
2. **Task 2: Authenticate scheduled attempts as distinct ordered events** — `bc3d7265` (`fix`, existing commit reconciled during recovery)

## Verification

- `bash -n scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh` — passed.
- `shellcheck scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh` — passed.
- `bash scripts/ci/test_nightly_incident.sh` — 26 passed, 0 failed.
- `ASDF_ERLANG_VERSION=27.3.4.15 MIX_HOME=/tmp/rindle-gsd-mix-home HEX_HOME=/tmp/rindle-gsd-hex-home mix test test/install_smoke/nightly_policy_test.exs --seed 0` — 7 tests, 0 failures.
- `./scripts/maintainer/automation_first_contract.sh` — passed.
- `git diff --check` — passed.

## Decisions Made

- Checkpoints are separate immutable workflow artifacts, not caller-provided files. Their run/attempt identity and event digest are cross-checked against the retained strict verdict artifact.
- The entire canonical incident inventory is hashed into each checkpoint so concurrent or manual issue-history changes invalidate the stored replay origin.
- Phase requirements EVID-03 and EVID-04 remain pending because other gap-closure plans and terminal reconciliation still own their completion gates.

## Deviations from Plan

None. Task 2's production commit predated this recovery; its existing test and structural-test results were reconciled from the handoff and the commit scope.

## Issues Encountered

The local asdf invocation initially lacked an Erlang selection. Re-running the focused test with the project's recorded Erlang 27.3.4.15 toolchain and the existing temporary Mix/Hex homes passed.

## Next Phase Readiness

Plan 133-46 is next. Plans 133-47 through 133-49 remain open, and Phase 133 requirements remain pending until terminal automated reconciliation.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-24*
