---
phase: 133-evidence-charter-and-live-truth
plan: "125"
subsystem: infra
tags: [codex, worktree, host-guard, authorization, offline-supply, recovery]
requires:
  - phase: 133-119
    provides: Actual-host diagnostic and independent Plan 120 fetch boundary.
  - phase: 133-124
    provides: Source-bound downstream validators and terminal recovery contracts.
provides:
  - Live-verified executor host proof with control 0 and EPERM loopback denial 77.
  - Independent Plan 126 preflight, literal authorization, fetch markers, and supply admission.
  - One-attempt Plan 126 qualification with fresh guards before native and Mix children.
affects: [133-127, 133-126, 133-121, 133-122, 133-123]
actuals:
  tokens: 17103
  tasks: 2
  commits: 4
  plan_head_before: 82f6e68ba6940f7d973003dc3fc49a2fe750ae14
  plan_head_after: b9db4f2555d494825d71b57a048bb75eb64b5706
tech-stack:
  added: []
  patterns:
    - Repeat the exact read-only host diagnostic instead of trusting saved output.
    - Keep fresh authorization and attempt identities separate from terminal history.
    - Recheck the allow/deny guard immediately before native and Mix children.
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-125-HOST-PROOF.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-125-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_recovery.mjs
    - scripts/maintainer/phase_133_recovery.test.mjs
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/phase_133_local_supply.test.mjs
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/test_phase_133_local_gates.sh
    - .planning/WINDOWS.md
key-decisions:
  - "Bind host proof to the current executor executable, argv, worktree, branch, and ancestor base; retain the immutable guard profile digest."
  - "Use a distinct Plan 126 qualification-attempt marker so a different output filename cannot permit another invocation."
  - "Plan 126 supply uses the existing schema-2 offline report and reauthenticates durable paths; historical Plan 115/120 admission functions remain intact."
patterns-established:
  - "Only enumerated Plan 126 authority paths may change after the source freeze."
  - "The saved escalation observation grants no fetch, native-build, Mix, or requirement credit."
requirements-completed: []
qualification_credit: 0
coverage:
  - id: D1
    description: "Saved worktree host proof passes an independent live control/denial check and rejects forged output or mismatched context."
    verification:
      - kind: other
        ref: "node scripts/maintainer/phase_133_recovery.mjs verify-host-proof --plan 133-125 --report .planning/phases/133-evidence-charter-and-live-truth/133-125-HOST-PROOF.json (approved narrow escalation)"
        status: pass
      - kind: unit
        ref: "scripts/maintainer/phase_133_recovery.test.mjs#Plan 125 host proof requires a live positive tuple and rejects forged recorded output"
        status: pass
    human_judgment: false
  - id: D2
    description: "Fresh Plan 126 authority binds source, locked inputs, literal answer, pinned fetch, safe destination, and exclusive attempt markers."
    verification:
      - kind: integration
        ref: "node --test scripts/maintainer/phase_133_recovery.test.mjs scripts/maintainer/phase_133_local_supply.test.mjs"
        status: pass
    human_judgment: false
  - id: D3
    description: "Plan 126 copied qualification reaches guarded fake children once, rejects historical supply, and stops after a lost guard or first red."
    verification:
      - kind: integration
        ref: "scripts/maintainer/phase_133_local_supply.test.mjs#fake collector publishes once with an absent _build parent"
        status: pass
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_local_gates.sh"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
    human_judgment: false
duration: 17 min
completed: 2026-10-08
status: complete
---

# Phase 133 Plan 125: Worktree Host Proof and Fresh Admission Summary

**The GSD worktree witnessed an approved macOS guard control and EPERM denial; Plan 126 now has independent source, authorization, supply, and guarded qualification admission.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-10-08T12:49:28Z
- **Completed:** 2026-10-08T13:06:26Z
- **Tasks:** 2/2
- **Files modified:** 9, including host proof, summary, and resolved deviation ledger entry.
- **Actuals:** 17,103 characters/4 tokens over the committed task diff; four task commits measured from the persisted plan ledger. Metadata commit excluded from this measured interval.

## Accomplishments

- Recorded both bounded observations from this executor. Ordinary sandbox control exited 71 with `sandbox_apply: Operation not permitted`; the exact approved escalation returned control 0, loopback 77, and `POLICY_DENIAL:EPERM`. Both use profile SHA-256 `0a5222386587bf836d30a070bd759c0194f999bf5503ba76c6c0f8cb84b19db2`. The production verifier repeated the live diagnostic successfully, including the tracer gate, and compares current executable/argv rather than Plan 114's historical Node path.
- Added separate Plan 126 preflight/authorization/fetch entry points while preserving Plan 115/120 functions and artifacts. Admission binds SHA/tree, supported runtime, 67 lock-authenticated archives, Vix checksum, pinned Lexbor source, exact destination, and a fresh literal checkpoint digest. Copied tests reject historical decisions, altered inputs/source, unsafe ancestors, and spent attempts before external Git or Mix.
- Added source-freeze enforcement to Plan 126 supply collection and verification. The copied fixture uses 67 authenticated archives and accepts an authority-only commit after freeze. The local runner uses a separate exclusive qualification marker, rechecks guards before Mix children and guarded native runtime probes, and rejects replay, expired guards, and first-red continuation.

## Task Commits

1. **Task 1 RED: live host-proof contract** — `91efea6f` (`test`).
2. **Task 1 GREEN: live verifier and saved executor proof** — `5fac9c27` (`feat`).
3. **Task 2 RED: fresh Plan 126 authority contract** — `54a6c388` (`test`).
4. **Task 2 GREEN: fresh admission and guarded qualification** — `b9db4f25` (`feat`).

The following metadata commit contains this summary and the resolved WINDOWS entry.

## Files Created/Modified

- `133-125-HOST-PROOF.json` — ordinary and approved observations, exact command/context, and zero child counters.
- `phase_133_recovery.mjs` and its tests — live proof, fresh Plan 126 authority, pinned safe fetch, and supply/qualification entry points.
- `phase_133_local_supply.mjs` and its tests — fresh source/path restrictions, 67-archive and pin checks, guarded native probes, and copied fake-child evidence.
- `phase_133_local_gates.sh` and its shell tests — Plan 126 admission, exclusive qualification marker, and per-child guard checks.
- `.planning/WINDOWS.md` — entry 41 records the resolved Node fixture deviation; pre-existing entries retain their status.

## Verification

- Production `verify-host-proof` passed under narrowly approved escalation: control 0, denial 77, EPERM, exact immutable profile. Ordinary sandbox verification failed closed as expected; diagnostic process exit 0 alone was never accepted.
- `node --test scripts/maintainer/phase_133_recovery.test.mjs scripts/maintainer/phase_133_local_supply.test.mjs` — 15 tests passed, 0 failures, 0 skipped; the supply fixture reported 80 assertions, using fake runtime/sandbox/Mix children.
- `bash scripts/maintainer/test_phase_133_local_gates.sh` — passed sequencing, JOSE snapshots, diagnostics, private-transient, and no-clobber checks. Approved escalation was needed for fixture Git object/worktree metadata writes; no real Mix qualification or network fetch ran.
- Shell syntax, `git diff --check`, and the automation-first contract passed.
- All five requirement checkboxes and traceability statuses remain Pending. STATE.md, ROADMAP.md, REQUIREMENTS.md, the canonical Nightly receipt, and historical Plan 115/120 artifacts were not modified.

## TDD Gate Compliance

- Task 1's named test failed because `verifyHostProof` was absent; Task 2's named test failed because `verifyPlan126Preflight` was absent. Both were assertion failures in discovered tests, with imports loaded, not fixture or syntax failures.
- Actual TAP output and exit codes were persisted to `_build/phase133-125-task1-red.json` and `_build/phase133-125-task2-red.json`. `gsd_run check tdd-red-evidence` returned `RED_EVIDENCE_OK` for each before implementation.
- Each RED commit precedes its GREEN commit. The full focused suite passed after implementation; no separate refactor commit was needed.

## Decisions Made

- The read-only executor proof establishes the guard route only. Fresh authorization and any necessary narrowly scoped execution approvals still belong to Plan 126.
- Plan 126 uses existing schema-2 supply reports rather than transferring Plan 115's durable-manifest identity.
- Added `133-126-QUALIFICATION-ATTEMPT.json` to the enumerated post-freeze authority paths. Its exclusive creation binds one invocation to source and supply digest, independent of the requested report filename.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Made the fake asdf executable compatible with Node 20**

- **Found during:** Task 1's required focused test run.
- **Issue:** The extensionless fake asdf script used ESM `import`, so this executor's Node 20 rejected it before the runtime assertions could execute.
- **Fix:** Used CommonJS `require` inside that generated extensionless fixture. No package install or runtime behavior changed.
- **Files modified:** `scripts/maintainer/phase_133_local_supply.test.mjs`.
- **Verification:** Full focused suite passed; WINDOWS entry 41 is fixed.
- **Committed in:** `5fac9c27`.

**Total deviations:** 1 auto-fixed (Rule 3). **Impact:** Enabled the prescribed tests on the observed Node executable without expanding product scope.

## Issues Encountered

The ordinary Codex sandbox cannot start the inner macOS sandbox control. The plan-authorized exact read-only escalation succeeded. The shell fixture harness separately needed Git metadata write permission; its approved execution used fake children only. Neither permission grants future Plan 126 fetch or qualification authorization.

## User Setup Required

None for Plan 125.

## Next Phase Readiness

Ready for Plan 133-127's downstream validator rebase, before Plan 133-126 freezes its source. No Plan 126 fetch, native build, Mix qualification, census, Nightly, or remote mutation was executed here. D-01–D-17, all five requirements, and all eleven edge rows remain open with zero qualification credit.

Plan 127/126 interface notes:

- Plan 126 preflight remains schema 1 and adds `inputs: {cache, packages, vix: {path, filename, sha256}}` plus `operation: {url, commit, destination}`. `packages` is the full `parseLock` result; runtime version labels remain `erlang: 27.3.4.15`, `elixir: 1.17.3-otp-27`.
- The supply artifact is a Plan 126 schema-2 offline report, accepted by `verify-prerequisites` and `verify-qualification`. Collect it with the frozen `--subject`; enumerated authority-only descendants are accepted.
- Preserve and validate `133-126-QUALIFICATION-ATTEMPT.json` alongside the other Plan 126 markers. Do not reuse Plan 120's stopped digest or attempt paths.

## Self-Check: PASSED

Both new artifacts and all four task commits exist. The live host verifier, full focused Node suite, shell harness, syntax/diff checks, and automation-first contract passed. Shared STATE.md, ROADMAP.md, and REQUIREMENTS.md are byte-unchanged from the executor base. No outstanding stub or skipped verification was introduced.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-08*
