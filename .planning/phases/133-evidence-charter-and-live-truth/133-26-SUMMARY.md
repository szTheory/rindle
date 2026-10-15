---
phase: 133-evidence-charter-and-live-truth
plan: 26
subsystem: maintainer-evidence
tags: [nightly, branch-protection, live-truth, exunit, documentation]
status: complete
requires:
  - phase: 133-24
    provides: execution-authenticated package truth and finite live-truth authority
provides:
  - Nightly guidance that separates PR-required classification from strict Nightly gating
  - Current exact-subject receipt and verifier as the supported-cell evidence authority
  - Structured required-check guidance derived from the policy consumed by setup and validation
affects: [133-27, phase-verification, release-train, maintainer-guidance]
actuals:
  tokens: 3045
  tasks: 2
  commits: 4
plan_head_before: 0c75cefd3cf54584ec65ee212cf799d252be07cf
tech-stack:
  added: []
  patterns:
    - Derive documentation expectations from parsed workflow and policy models
    - Mutation-test stale authority meanings rather than relying on positive string presence alone
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-26-SUMMARY.md
  modified:
    - RUNNING.md
    - test/install_smoke/live_truth_parity_test.exs
key-decisions:
  - "Use not-a-required-PR-check only as a branch-protection classification; every declared strict Nightly input remains gating."
  - "Treat the current exact-subject Nightly receipt plus verify-receipt contract as supported-cell authority, independent of historical plan numbering."
  - "Name config/ci_required_checks.json as the sole required-check identity owner and document both repository consumers."
patterns-established:
  - "Guidance parity: prose claims are checked against parsed workflow/config semantics and negative mutations."
  - "Authority naming: current structured artifacts and validators replace historical implementation details."
requirements-completed: [TRUTH-08]
coverage:
  - id: D1
    description: "Maintainer guidance distinguishes absence from PR branch protection from strict Nightly aggregate gating for all four declared lanes."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs#maintainer guidance binds Nightly gates and supported-cell proof to live authorities"
        status: pass
    human_judgment: false
  - id: D2
    description: "Supported-cell evidence authority is the current exact-subject receipt authenticated by verify_nightly_run.sh verify-receipt."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority"
        status: pass
    human_judgment: false
  - id: D3
    description: "Required-check guidance names the structured policy, its CI tuple, sole CI Summary context, and both setup and live-truth consumers."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs#maintainer guidance and both consumers share the structured required-check authority"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
    human_judgment: false
metrics:
  duration: 8m
  completed: 2026-09-11
---

# Phase 133 Plan 26: Durable Maintainer Evidence Authority Summary

**RUNNING.md now derives Nightly gating, exact-subject supported-cell proof, and the sole required CI context from current executable repository authorities.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-11T22:20:27Z
- **Completed:** 2026-09-11T22:28:39Z
- **Tasks:** 2
- **Files modified:** 2 implementation/evidence files plus this summary

## Accomplishments

- Reclassified all four strict Nightly inputs as Nightly-gating while retaining their accurate not-required-on-PR status and bounded GCS inapplicability.
- Replaced historical Plan 07 authority wording with the current exact-subject Nightly receipt and its live `verify-receipt` authentication contract.
- Replaced the removed shell-array claim with `config/ci_required_checks.json`, its exact CI workflow/job/context tuple, and both policy consumers.
- Added negative mutations that reject broad advisory wording, historical plan authority, stale arrays, wrong policy/context identities, and disconnected consumers.

## Task Commits

1. **Task 1: Bind Nightly and receipt guidance to durable authorities**
   - `1dca5b2` — RED Nightly lane, strict consequence, receipt, verifier, and stale-guidance expectations
   - `fad0dfc` — GREEN Nightly-gating and exact-subject authority guidance
2. **Task 2: Name and verify the structured required-check authority**
   - `01b499b` — RED structured-policy and consumer parity expectations
   - `fc88929` — GREEN sole-policy, CI identity, and consumer guidance

## Files Created/Modified

- `RUNNING.md` — distinguishes PR-check status from Nightly gating and names current receipt and required-check authorities.
- `test/install_smoke/live_truth_parity_test.exs` — derives guidance expectations from workflow/policy semantics and mutation-tests stale meanings.
- `.planning/phases/133-evidence-charter-and-live-truth/133-26-SUMMARY.md` — records execution evidence and TDD compliance.

## Decisions Made

- “Not a required PR check” describes branch protection only; it does not downgrade strict Nightly inputs to advisory status.
- The current exact-subject receipt authenticated through `verify_nightly_run.sh verify-receipt` is durable supported-cell authority; plan provenance is historical context only.
- The structured policy owns required-check identity while the setup script projects it into branch protection and live-truth validation cross-checks it against workflow topology.

## TDD Gate Compliance

- Task 1 RED was machine-verified as `RED_EVIDENCE_OK` before implementation; `1dca5b2` precedes `fad0dfc`.
- Task 2 RED was machine-verified as `RED_EVIDENCE_OK` before implementation; `01b499b` precedes `fc88929`.
- Both GREEN implementations passed their focused targets and the full derived-authority suite. No behavior-neutral refactor commit was needed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository's asdf shim had no selected Erlang version, so the first command exited before ExUnit and was rejected as invalid RED. Execution used the installed Homebrew Elixir 1.19.5 / OTP 28.4.1 toolchain already established for local Phase 133 diagnostics; both named assertion failures were then machine-validated.

## Known Stubs

None. The two `nil` matches found by the broad scan are pre-existing assertions for package-proof and resolver behavior, not rendering stubs or placeholders introduced by this plan.

## Threat Flags

None. The changed documentation-to-authority boundaries are the planned mitigations for T-133-99 through T-133-101; no new endpoint, authentication path, file-access behavior, or schema surface was introduced.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority` — 14 tests, 0 failures, 16 excluded.
- `mix format --check-formatted test/install_smoke/live_truth_parity_test.exs` — exit 0.
- `./scripts/maintainer/automation_first_contract.sh` — passed for Phase 133.

## Next Phase Readiness

- Plan 27 can consume current maintainer guidance without stale Nightly, receipt, or required-check authority claims.
- TRUTH-08 guidance evidence is fully automated; no human acceptance checkpoint remains.

## Self-Check: PASSED

All three listed files and all four task commits were found after summary creation.
