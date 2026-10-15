---
phase: 133-evidence-charter-and-live-truth
plan: "02"
subsystem: ci
tags: [dialyzer, plt, github-actions, cache, bash]
requires: []
provides:
  - Authenticated bounded Nightly 93/101 stale-PLT failure fingerprint
  - Fresh and restored Dialyzer modes with one old-PLT-only rebuild
  - Patch-resolved PLT cache identity on the supported Elixir 1.17/OTP 27 Nightly cell
affects: [phase-133-plan-03, phase-136, nightly, dialyzer]
actuals:
  tokens: 5216
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - Fake-command filesystem matrix for shell policy behavior
    - Exact installed toolchain outputs as immutable cache identity
    - Fresh-save-clear-exact-restore sequencing for independent evidence modes
key-files:
  created:
    - scripts/ci/run_nightly_dialyzer.sh
    - scripts/ci/test_nightly_dialyzer.sh
    - scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-FAILURE-FINGERPRINT.json
  modified:
    - .github/actions/setup-elixir/action.yml
    - .github/workflows/nightly.yml
    - test/install_smoke/ci_cache_hygiene_test.exs
key-decisions:
  - "Match stale recovery only to the observed ':dialyzer.run error: Old PLT file <path>' line and preserve every other analysis exit unchanged."
  - "Run fresh construction and analysis before saving, then clear local state and require an exact cache restore before restored analysis."
  - "Keep requested support labels at Elixir 1.17/OTP 27 while keying PLTs on the setup action's exact resolved patch outputs."
patterns-established:
  - "Dialyzer mode boundary: fresh always resets/builds/analyzes; restored analyzes first and rebuilds at most once only for old-PLT evidence."
  - "PLT lineage: OS, architecture, exact resolved OTP/Elixir, and mix/config/ignore hashes all participate without restore prefixes."
requirements-completed: [EVID-02]
coverage:
  - id: D1
    description: "Preserve an authenticated, bounded pre-mutation fingerprint for Nightly 93 and 101 that proves the same primary key crossed OTP 27.3.4.16 to 27.3.4.17 and failed as an old PLT."
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_dialyzer.sh#bounded #93/#101 failure fingerprint is complete"
        status: pass
    human_judgment: false
  - id: D2
    description: "Distinguish fresh, valid-restored, stale-restored, missing, corrupt, build-failure, warning, unknown, and failed-rebuild behavior with exact command counts."
    requirement: EVID-02
    verification:
      - kind: unit
        ref: "bash scripts/ci/test_nightly_dialyzer.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "Execute fresh and restored evidence on the unchanged supported Nightly cell with exact resolved patch versions and input hashes in PLT identity."
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_dialyzer.sh#resolved PLT workflow contract"
        status: pass
      - kind: integration
        ref: "mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs"
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-09-09
status: complete
---

# Phase 133 Plan 02: Supported Nightly Dialyzer Evidence Summary

**Nightly now proves both fresh and exact-restored PLTs under patch-resolved cache identity, with one narrowly fingerprinted stale rebuild and no warning suppression.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-10T00:18:02Z
- **Completed:** 2026-09-10T00:29:27Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Captured authenticated read-only evidence for successful Nightly 93 and failed Nightly 101 without storing raw logs, secrets, or runner paths.
- Added a fail-first shell runner and 11-scenario fake-command matrix proving fresh construction, valid restore, stale-only rebuild, and unsuppressed red outcomes.
- Exposed exact installed Elixir/OTP versions from the setup composite and replaced the requested-label-only PLT key with resolved patch identity plus existing input hashes.
- Sequenced fresh build/analysis, cache save, local removal, exact restore, and restored analysis while keeping Dialyzer outside PR CI on the sole 1.17/27 supported cell.

## Task Commits

Each TDD task used an explicit RED and GREEN commit:

1. **Task 1 RED: failure fingerprint and mode matrix** - `13f088f` (test)
2. **Task 1 GREEN: fail-first mode runner** - `6581c33` (feat)
3. **Task 2 RED: resolved PLT workflow contract** - `93b52ac` (test)
4. **Task 2 GREEN: resolved cache identity and independent modes** - `11f9e2d` (feat)

## Files Created/Modified

- `scripts/ci/run_nightly_dialyzer.sh` - Implements exact fresh/restored modes and one stale-only recovery.
- `scripts/ci/test_nightly_dialyzer.sh` - Exercises behavior and workflow structure with exact command counts.
- `scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh` - Provides deterministic analyzer/build outcomes for the shell matrix.
- `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-FAILURE-FINGERPRINT.json` - Stores bounded Nightly 93/101 provenance and diagnosis.
- `.github/actions/setup-elixir/action.yml` - Forwards exact installed Elixir and OTP outputs while retaining existing cache outputs.
- `.github/workflows/nightly.yml` - Runs fresh-save-clear-restore-restored Dialyzer evidence with a patch-resolved PLT key.
- `test/install_smoke/ci_cache_hygiene_test.exs` - Updates CACHE-03 to assert the new evidence ordering.

## Decisions Made

- Recovery requires the exact observed old-PLT line shape; generic corruption, missing state, warnings, and unknown failures are never retried.
- The fresh runner builds and analyzes without consuming restored bytes. The workflow then removes local state and requires an exact-key restore before the restored runner executes.
- A `plt-v3` namespace makes the identity correction explicit, while exact setup outputs and all prior input hashes prevent cross-patch or cross-input fallback.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reconciled the obsolete CACHE-03 save assertion**

- **Found during:** Task 2 focused ExUnit verification
- **Issue:** The existing regression test required the superseded cache-miss-only save guard and failed the planned unconditional fresh evidence topology.
- **Fix:** Changed the assertion to require fresh analysis before save and exact restore afterward, while continuing to reject `if: always()`.
- **Files modified:** `test/install_smoke/ci_cache_hygiene_test.exs`
- **Verification:** The focused 21-test ExUnit command passed.
- **Committed in:** `11f9e2d`

---

**Total deviations:** 1 auto-fixed bug
**Impact on plan:** The regression lock now tests the planned D-06 topology; no product, support, suppression, PR CI, or public contract scope changed.

## Issues Encountered

- The pinned Elixir 1.17.3/OTP 27.2 toolchain is not installed locally. Focused ExUnit verification ran diagnostically on installed Elixir 1.19.5/OTP 28.4.1; the supported 1.17/27 authority remains the Nightly workflow this plan repairs.

## Known Stubs

None.

## Authentication Gates

None. Existing authenticated `gh` access was sufficient for bounded read-only evidence collection.

## User Setup Required

None - no external service configuration required.

## Verification

- `bash scripts/ci/test_nightly_dialyzer.sh` - 24 cases, 0 failures.
- `mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs` - 21 tests, 0 failures on the installed diagnostic toolchain.
- `shellcheck scripts/ci/run_nightly_dialyzer.sh scripts/ci/test_nightly_dialyzer.sh scripts/ci/fixtures/fake_nightly_dialyzer_mix.sh` - passed.
- `YamlElixir.read_from_file!/1` for the setup composite and Nightly workflow - passed.
- `mix format --check-formatted test/install_smoke/ci_cache_hygiene_test.exs` - passed.
- `./scripts/maintainer/automation_first_contract.sh` - passed after active planning evidence changed.
- Preservation diff confirmed `.dialyzer_ignore.exs` and `.github/workflows/ci.yml` are unchanged.

## Next Phase Readiness

- Plan 03 can consume the repaired Dialyzer result in a strict Nightly aggregate without changing PR `CI Summary` semantics.
- Phase 136 can ratchet the unchanged curated ignore set against trustworthy supported-cell evidence.
- Live scheduled/dispatch acceptance remains owned by the completed Nightly wiring sequence and later exact-head closure; no local newer toolchain is presented as support authority.

## TDD Gate Compliance

- RED commits precede GREEN commits for both tasks, and each RED run failed on the missing behavior it introduced.

## Self-Check: PASSED

- All declared runner, test, fingerprint, composite, and workflow artifacts exist.
- All four task commits are present in Git history.
- Every task acceptance criterion and plan-level automated verification passed with non-zero case/test counts.
- No known stub, open broken-window entry, or unrun verification blocks the plan goal.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-09*
