---
phase: 133-evidence-charter-and-live-truth
plan: "63"
subsystem: evidence
tags: [jose, mix, local-gates, exact-subject]
requires:
  - phase: 133-58
    provides: "Isolated exact-subject local gate runner and lifecycle foundation."
provides:
  - "Fail-closed JOSE compiled-app include preflight before the sole local CI command."
  - "Committed exact-subject real negative and repaired controls for the pinned JOSE include path."
  - "Zero-credit runner-repair prerequisite for Plan 64."
affects: [133-64, phase-133-evidence-charter-and-live-truth]
actuals:
  tokens: 9435
  tasks: 2
  commits: 2
  plan_head_before: b59587d984bf45d7725947ebe8d3f867a0e9e803
tech-stack:
  added: []
  patterns:
    - "Build the dependency app structure from the locked source, compile its Elixir files, then verify the staged include before CI."
key-files:
  created:
    - scripts/maintainer/test_phase_133_jose_structure.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-63-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/test_phase_133_local_gates.sh
key-decisions:
  - "Use Mix.Project.build_structure/2 and focused JOSE Elixir compilation before mix ci; require worktree-bounded source and staged-header SHA-256 equality."
  - "Treat the focused repair as a zero-credit prerequisite; Plan 64 must produce fresh final-source and independent authority."
requirements-completed: []
coverage:
  - id: D1
    description: "The local gate runner validates source and staged JOSE include identity and stops before CI or coverage on invalid preflight data."
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_local_gates.sh (committed runner a6385e2de171ab122516067a6b16586a99a72a04)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Fresh supported-toolchain controls reproduce the missing compiled-app include and prove Mix staging, JOSE compilation, and Record.extract recovery."
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_jose_structure.sh --subject-sha a6385e2de171ab122516067a6b16586a99a72a04"
        status: pass
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_jose_structure.sh --subject-sha a6385e2de171ab122516067a6b16586a99a72a04 --verify-report <transient focused report>"
        status: pass
    human_judgment: false
duration: 80min
completed: 2026-10-01
status: complete
qualification: runner-repair-proven
runner_source_sha: a6385e2de171ab122516067a6b16586a99a72a04
runner_source_tree: 26c807cda6a5e7c2b05338917ecc896b90192929
probe_source_sha: a6385e2de171ab122516067a6b16586a99a72a04
probe_source_tree: 26c807cda6a5e7c2b05338917ecc896b90192929
focused_probe_exit_code: 0
focused_probe_verify_report_exit_code: 0
fake_harness_exit_code: 0
plan62_subject_sha: d3db09b9bd6b77aefdb778db773a638374eaa386
plan62_report_sha256: 15db8492bb6cd98cbbd5dd257f863a53bebe6de9e07e318b3238c0fc77ae57f4
prior_receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
canonical_nightly_receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
remote_action: none
new_local_gate_report: none
census: not_run
---

# Phase 133 Plan 63: JOSE Runner Repair Summary

**A committed Mix preflight now stages the locked JOSE header, compiles the dependency, and proves the missing-include failure reverses on Elixir 1.17.3 / OTP 27.**

## Performance

- **Duration:** 80 min
- **Started:** 2026-10-01T10:10:37-04:00 (worktree session start; exact prompt receipt time was not captured)
- **Completed:** 2026-10-01T11:30:27-04:00
- **Tasks:** 2
- **Files modified or created:** 4

## Accomplishments

- Added a fixed JOSE preflight after `mix deps.get`. It selects the locked `:jose` dependency, builds the standard app structure, compiles JOSE Elixir sources, and verifies the staged header resolves inside the detached worktree with bytes identical to the fetched source.
- Added a real two-worktree focused probe. On committed source `a6385e2de171ab122516067a6b16586a99a72a04` and tree `26c807cda6a5e7c2b05338917ecc896b90192929`, the negative control had a readable source header and no compiled-app header; `Record.extract/2` exited 1 with the expected missing-header error. The repaired control passed Mix structure creation, focused JOSE compilation, and `Record.extract/2` (all exit 0). Source and staged header SHA-256 both equal `eebde9a6693f67120e6aa5f6866c68d370e7411320a546eddb140421ddbfc56a`.
- Extended the fake-Mix harness for missing source, absent or mismatched staged headers, and preflight failure. Each invalid case exits before `mix ci` and coverage. The green and red sequencing, one-shot CI, conditional coverage, and sanitized receipt checks pass on the committed runner source.
- Kept this work focused: no full `mix ci`, canonical coverage run, census, remote lookup, new local-gate report, or external action was performed.

## Task Commits

1. **Task 1 RED: regression controls** - `d65daae95c89779becda02e02c076de249a3f7da` (`test(133-63): add JOSE staging regression controls`).
2. **Task 1 GREEN: runner preflight** - `a6385e2de171ab122516067a6b16586a99a72a04` (`feat(133-63): stage and compile JOSE before local gates`).

## Files Created/Modified

- `scripts/maintainer/phase_133_local_gates.sh` - performs and verifies the focused JOSE preflight before CI.
- `scripts/maintainer/test_phase_133_local_gates.sh` - checks fail-closed preflight and unchanged runner sequencing.
- `scripts/maintainer/test_phase_133_jose_structure.sh` - proves negative and repaired controls on the supported toolchain.
- `.planning/phases/133-evidence-charter-and-live-truth/133-63-SUMMARY.md` - zero-credit Plan 64 prerequisite.

## Decisions Made

- Mix cleanup can remove a preflight-created app directory if the dependency has not been compiled, so the preflight also compiles only JOSE Elixir sources before the next CI process.
- The probe and runner bind the staged header to the exact fetched source hash and detached worktree. The initial repair is not final combined-source authority.
- Plan 62 remains immutable: subject `d3db09b9bd6b77aefdb778db773a638374eaa386`, report SHA-256 `15db8492bb6cd98cbbd5dd257f863a53bebe6de9e07e318b3238c0fc77ae57f4`; the canonical Nightly receipt remains at SHA-256 `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Bound credential-key redaction matching**
- **Found during:** Task 1 fake-harness diagnostics.
- **Issue:** The diagnostic redactor used an ambiguous repeated credential-key prefix that stalled while processing the bounded 60-line regression fixture.
- **Fix:** Replaced the ambiguous repetition with a bounded 128-character prefix while preserving redaction for namespaced and camel-case credential keys.
- **Files modified:** `scripts/maintainer/phase_133_local_gates.sh`.
- **Verification:** The committed fake harness passes its successful and failing diagnostic canary checks.
- **Committed in:** `a6385e2de171ab122516067a6b16586a99a72a04`.

**Total deviations:** 1 auto-fixed (Rule 1: 1 bug).
**Impact:** The redaction fix keeps the planned bounded diagnostic path responsive without changing CI or coverage cardinality.

## Issues Encountered

- The fake harness initially matched escaped outer JSON for a camel-case key assertion. It now parses the saved report before checking that the credential key remains visible and its value is redacted.
- The worktree shares Git metadata outside the writable workspace. Normal commit attempts hit the sandbox boundary; the authorized commits were retried with Git metadata access and the repository hooks ran.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 63 is a complete, zero-credit runner-repair prerequisite for Plan 64. Plans 133-56, 133-60, and 133-61 remain blocked; EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending. Plan 64 must generate fresh real evidence after its reconciler changes are committed and obtain matching REVIEW, SECURITY, and Nyquist authorities. This initial probe does not satisfy those authorities or authorize qualification, census, remote lookup, or release claims.

## Self-Check: PASSED

- Summary, runner, fake harness, and focused probe exist; both Task 1 commits are present.
- Plan 62 report and canonical Nightly receipt hashes match their immutable recorded values.
- All five Phase 133 requirements remain pending; STATE.md and ROADMAP.md are unchanged.
- `./scripts/maintainer/automation_first_contract.sh` passed.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-01*
