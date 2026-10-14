---
phase: 133-evidence-charter-and-live-truth
plan: "119"
subsystem: infra
tags: [macos-sandbox, lexbor, provenance, bash, elixir]
requires:
  - phase: 133-114
    provides: macOS network-guard profile and control tuple for comparison
provides:
  - Fresh Plan 120 authorization, safe destination preparation, and source-bound Lexbor fetch route
  - Read-only actual-host guard diagnosis with an explicit unavailable result and zero-child stop
affects: [133-124, 133-120]
actuals:
  tokens: 11057
  tasks: 2
  commits: 5
  plan_head_before: 38c590f15d77300f601edb0406a1ba39055ca866
  plan_head_after: 4e1b14d76780331155caaee07ab4f7b638a1c5c0
tech-stack:
  added: []
  patterns: [fresh-plan authorization, lstat-before-create, bounded host diagnostics]
key-files:
  created: []
  modified:
    - scripts/maintainer/phase_133_recovery.mjs
    - scripts/maintainer/phase_133_recovery.test.mjs
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/phase_133_local_supply.test.mjs
    - scripts/maintainer/phase_133_local_gates.sh
key-decisions:
  - "Plan 120 requires a separate literal authorization; Plan 115 authorization and markers are not transferable."
  - "Qualification requires an allowed control exit and a loopback denial witnessed by EPERM or EACCES; otherwise the result is unavailable and guarded children do not start."
  - "This remediation grants no completion credit for EVID-01, EVID-02, EVID-03, EVID-04, or TRUTH-08."
patterns-established:
  - "Every existing destination ancestor is lstat-checked; only missing private directories are created, then ownership and containment are checked again."
  - "Attempt, clone-started, and checkout-started markers are distinct no-clobber records."
  - "Guard diagnosis reports observed process context and bounded output without weakening the regular fail-closed guard."
requirements-completed: []
coverage:
  - id: D1
    description: "A fresh Plan 120 authorization can reach guarded local-gates with authenticated source inputs, while unsafe paths and replayed authorization fail before Git."
    verification:
      - kind: integration
        ref: "node --test scripts/maintainer/phase_133_recovery.test.mjs"
        status: pass
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_local_gates.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "The actual-host guard route distinguishes a measurable policy denial from a failed control and preserves the zero-child stop."
    verification:
      - kind: integration
        ref: "node --test scripts/maintainer/phase_133_local_supply.test.mjs"
        status: pass
      - kind: other
        ref: "node scripts/maintainer/phase_133_recovery.mjs guard-diagnose --actual-host (exit 0; structured unavailable result recorded below)"
        status: pass
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_local_gates.sh"
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-10-08
status: complete
---

# Phase 133 Plan 119: Evidence Charter and Live Truth Summary

**Fresh Plan 120 fetch admission and a measured macOS guard diagnostic now stop safely when the host control exits 71.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-10-08T00:40:17Z
- **Completed:** 2026-10-08T00:58:16Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a separate Plan 120 recovery route with fresh authorization, source and digest binding, safe creation of a missing private destination parent, no-clobber attempt markers, and authenticated checkout checks. Plan 115 verification remains historical and read-only.
- Added Plan 120 identity and offline-report admission through local-gates so the fresh fake-child integration path reaches the guarded entry.
- Added a read-only guard diagnostic that records and compares the launcher, profile, executable, control argv, observed exit, bounded stderr, and loopback result. The regular guard remains fail-closed.
- The actual host still returns control exit 71. The diagnostic classified it as unavailable, recorded the Plan 114 tuple match and cwd context difference, and opened no Mix/native child. No fetch or qualification was attempted.
- EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending; qualification credit is zero and the eleven edge rows remain flagged for Plan 124.

## Actual-Host Guard Diagnostic

Command: `node scripts/maintainer/phase_133_recovery.mjs guard-diagnose --actual-host` (exit 0; exit 0 means the diagnostic record was produced, not that the guard is available).

Observed result: schema version 1, status `unavailable`, reason `control_exit_nonzero`, detail `non-network control exited 71`. Plan 114 comparison was `tuple_match` for launcher, profile, profile hash, executable, control argv, and denied-child argv; the context comparison reported `cwd` as different. Plan 115 had recorded `guard_unavailable` / `network_guard_control_failed`, exit 71, and omitted launcher, executable, argv, cwd, and control stderr. The current run used `/usr/bin/sandbox-exec`, Node `/Users/jon/.asdf/installs/nodejs/22.14.0/bin/node`, and profile hash `0a5222386587bf836d30a070bd759c0194f999bf5503ba76c6c0f8cb84b19db2`; control stderr was 53 bytes: `sandbox-exec: sandbox_apply: Operation not permitted`. The loopback probe was not run because the control did not pass. Qualification credit was 0 and `requirements_completed` was empty.

The command's stable JSON diagnostic is preserved here as the unavailable record; argv are abbreviated only in this human-readable summary:

```json
{
  "schema_version": 1,
  "plan": "133-119",
  "status": "unavailable",
  "reason": "control_exit_nonzero",
  "detail": "non-network control exited 71",
  "identity": "0a5222386587bf836d30a070bd759c0194f999bf5503ba76c6c0f8cb84b19db2",
  "profile": "(version 1) (allow default) (deny network*)",
  "profile_sha256": "0a5222386587bf836d30a070bd759c0194f999bf5503ba76c6c0f8cb84b19db2",
  "host_context": {
    "platform": "darwin",
    "executable": "/Users/jon/.asdf/installs/nodejs/22.14.0/bin/node",
    "cwd": "/Users/jon/projects/rindle/.claude/worktrees/agent-p119-1791419679",
    "actual_host_requested": true
  },
  "current": {
    "platform": "darwin",
    "cwd": "/Users/jon/projects/rindle/.claude/worktrees/agent-p119-1791419679",
    "profile_sha256": "0a5222386587bf836d30a070bd759c0194f999bf5503ba76c6c0f8cb84b19db2",
    "executable": "/Users/jon/.asdf/installs/nodejs/22.14.0/bin/node",
    "launcher": "/usr/bin/sandbox-exec",
    "control_argv": ["/usr/bin/sandbox-exec", "-p", "(version 1) (allow default) (deny network*)", "/Users/jon/.asdf/installs/nodejs/22.14.0/bin/node", "-e", "process.exit(0)"],
    "control_exit": 71
  },
  "control": {
    "exit_code": 71,
    "error": null,
    "stdout": "",
    "stdout_bytes": 0,
    "stderr": "sandbox-exec: sandbox_apply: Operation not permitted\n",
    "stderr_bytes": 53,
    "stderr_truncated": false
  },
  "loopback": null,
  "plan114": {
    "status": "tuple_match",
    "context_mismatches": ["cwd"],
    "prior_control_exit": 0,
    "current_control_exit": 71
  },
  "plan115": {
    "status": "present",
    "recorded_status": "guard_unavailable",
    "reason": "network_guard_control_failed",
    "control_exit_in_detail": 71,
    "fields_not_recorded": ["control_argv", "launcher", "executable", "cwd", "control_stderr"]
  },
  "qualification_credit": 0,
  "requirements_completed": []
}
```

## Task Commits

1. **Task 1 RED:** `5d5252ed` (fresh Plan 120 recovery-route regression)
2. **Task 1 RED:** `ddc423af` (local-gates admission regression)
3. **Task 1 GREEN:** `4445079b` (source-bound Plan 120 fetch route)
4. **Task 2 RED:** `2d1160c5` (measurable host guard diagnosis regression)
5. **Task 2 GREEN:** `4e1b14d7` (measured host guard diagnosis)

## Files Created/Modified

- `scripts/maintainer/phase_133_recovery.mjs` - independent Plan 120 authorization and safe fetch route; recovery CLI diagnostic.
- `scripts/maintainer/phase_133_recovery.test.mjs` - fresh authorization, destination safety, and replay rejection coverage.
- `scripts/maintainer/phase_133_local_supply.mjs` - Plan 120 admission and measured host guard diagnostic.
- `scripts/maintainer/phase_133_local_supply.test.mjs` - control failure, allowed control, non-policy denial, and policy-denial cases.
- `scripts/maintainer/phase_133_local_gates.sh` - accepts the new Plan 120 offline report identity while preserving the guarded entry.

## Decisions Made

- Plan 115's consumed authorization and markers remain unusable for Plan 120.
- An exit-71 control is unavailable; it cannot be treated as evidence that loopback is denied. No Mix/native work begins without the positive control-plus-policy-denial witness.
- The diagnostic stays read-only and reports observations without inferring a cause from the Plan 114/115 difference.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Admit the fresh Plan 120 report at the local-gates boundary**
- **Found during:** Task 1 (fresh Plan 120 integration path)
- **Issue:** The recovery route could produce a fresh Plan 120 report, but the local-supply identity and local-gates admission accepted only the prior plan identity, so the acceptance path could not reach the guarded entry.
- **Fix:** Added Plan 120 as a separately identified offline report route; retained the independent fresh authorization and guarded-child checks.
- **Files modified:** `scripts/maintainer/phase_133_local_supply.mjs`, `scripts/maintainer/phase_133_local_gates.sh`
- **Verification:** Recovery regression suite and local-gates fake-child harness passed.
- **Committed in:** `4445079b`

**Total deviations:** 1 auto-fixed (Rule 3 - Blocking). **Impact:** The admission change was required to complete the plan's stated fresh-route acceptance; it grants no fetch, qualification, or requirement credit.

## Issues Encountered

The actual host control reproducibly exits 71 with `sandbox_apply: Operation not permitted`; no supported policy-denial witness can be established in this run. The deterministic unavailable record is captured above. This is the plan's designed stop condition; no guarded Mix/native child or network fetch was run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 124 can consume the fresh Plan 120 route and the measured unavailable guard record. Plan 120 remains behind Plan 124 and must receive a new literal authorization before any fetch; qualification remains blocked until the host control succeeds and loopback is independently denied by EPERM/EACCES. The five requirements and eleven edge rows remain open/flagged for their assigned verification work.

## Self-Check: PASSED

Before this summary commit, all five modified implementation/test files existed and all five task commits were present in this worktree. The automation-first planning contract passed. The summary is the only planning artifact staged by the metadata commit; STATE.md and ROADMAP.md were left to the orchestrator.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-08*
