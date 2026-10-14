---
phase: 133-evidence-charter-and-live-truth
plan: "209"
subsystem: planning-forensics
tags: [inherited-dirt, forensic-archive, lossless-proof, adoption-gate, freeze-readiness]
status: complete
halted: false
gate_tests_green: true
format_green: true
hygiene_negative_probe_flagged: true
committed_rerun_green: true
lock_holder_alive_at_removal: false
clean_status_empty: true
adoption_commit: 584baab5
timeout_fix_commit: 6e7bf58c
archive_commit: 3018b7d5
base_commit: c7c2413254f64530105f9aca5fcd10ad87b40730
patch_sha256: 7d61c0ada9ffebcd17aab8c854445be45b1d6b06147bef49377fd6e30eb7ed50
lock_pid: 91863
qualification_credit: 0
requirements_completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requires:
  - phase: 133-205
  - phase: 133-206
  - phase: 133-207
  - phase: 133-208
provides:
  - committed lossless forensic archive of the ten inherited dirty paths and .planning/milestone.lock
  - adoption commit of the five inherited code/test fixes (gated green before and after commit)
  - timeout budget for the slow reconciliation tests so Plan 203's ci stage does not hit the 60 s ExUnit default
  - clean, freeze-ready working tree and machine-checked green summary that gates Plan 203
affects: [133-203]
tech-stack:
  added: []
  patterns: [binary full-index patch archive proven in a disposable detached worktree, dead-holder lock removal via ps -p]
key-files:
  created:
    - .planning/forensics/133-209-inherited-dirt/inherited.patch
    - .planning/forensics/133-209-inherited-dirt/milestone.lock.copy
    - .planning/forensics/133-209-inherited-dirt/MANIFEST.json
    - .planning/forensics/133-209-inherited-dirt/verify_lossless.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-209-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_registry_compat_139.exs
    - test/install_smoke/phase_133_registry_compat_138_test.exs
    - test/install_smoke/phase_133_registry_compat_139_test.exs
    - test/install_smoke/phase_133_registry_compat_test.exs
    - test/planning_path_hygiene_test.exs
    - test/install_smoke/phase_133_reconciliation_test.exs
decisions:
  - "Revision 2: the revision 1 committed-bytes rerun was red only on an ExUnit 60 s timeout; 6e7bf58c tags the twelve tests measured at about 30 s or more with timeout: 300_000; step 8 and Task 3 rerun green."
duration: ~150min across three runs
completed: 2026-10-14
---

# Phase 133 Plan 209: Inherited Dirt Archive and Adoption Gate Summary

**Complete.** The inherited dirt is archived losslessly (`3018b7d5`), the five inherited code/test fixes are adopted (`584baab5`), the slow reconciliation tests have a timeout budget (`6e7bf58c`), the focused tests are green on the committed bytes, the five planning docs are restored to HEAD, the dead-holder lock is removed, and the working tree is clean. Plan 203 may start. Its own precondition and its one-time authorization literal still apply.

## Gates

| Gate | Result |
|---|---|
| Task 1 archive + lossless proof | `3018b7d5`; `verify_lossless.sh` exit 0 (rechecked in Task 2 and Task 3) |
| Focused tests, inherited bytes, `--seed 0` (revision 1 run) | `133 tests, 0 failures` (780.9 s) |
| `mix format --check-formatted`, four formatter-covered test paths | exit 0 |
| LOCK-05 negative probe | dir A flagged only `probe_real_root_test.exs`; dir B exit 0 |
| Adoption commit | `584baab5`, exactly the five paths |
| Committed-bytes rerun, revision 1 | `133 tests, 1 failure` (ExUnit 60 s timeout, Plan 48 report-gate test); designed halt `9540a013` |
| Timeout fix | `6e7bf58c`, 12 `@tag timeout: 300_000` lines in the reconciliation test, format exit 0 |
| Committed-bytes rerun, revision 2, `--seed 0` | **`133 tests, 0 failures`** (900.1 s, exit 0), with the six touched paths equal to HEAD |

### Timeout budget
A `--slowest 25` run under load (1250.4 s total, `133 tests, 0 failures`) measured these tests:
- Plans 43–54 map drift: 173.3 s, against its old 180 s tag.
- Plan 48 report-gate: 91.8 s.
- Plans 55–57 map, Plan 41/42 tuple and Plan 55 digests: 53–55 s each.
- Fresh-authority (line ~1620): 46.1 s.
- Plan 85: 41.4 s.
- Five more at 30–33 s.

Every test of about 30 s or more now carries `timeout: 300_000`. No assertions changed.

### LOCK-05 probe follow-up (informational)
The nested-call form `File.read!(Path.join(File.cwd!(), ".planning/STATE.md"))` is **not** flagged. This is expected: the guard regex `[^)]*` cannot cross the `)` of a nested call. The gap predates Phase 133 and is accepted as T-133-560, a follow-up rather than a gate.

## Lock disposition
- `.planning/milestone.lock` held pid 91863, which equals MANIFEST `lock.pid`, and its bytes matched the MANIFEST sha256.
- Just before removal, `ps -p 91863 -o pid=` exited non-zero with empty output, so the holder was dead and the lock was removed with `rm` on that single path.
- A byte copy is preserved in the archive (`milestone.lock.copy`).

## Restored paths
Each was checked against its MANIFEST `worktree_sha256` (no drift), then restored with `git restore --source=HEAD --staged --worktree`. The inherited bytes stay recoverable from `inherited.patch`.
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/state.json`
- `.planning/phases/133-evidence-charter-and-live-truth/.continue-here.md`
- `.planning/phases/133-evidence-charter-and-live-truth/133-VERIFICATION.md`

Afterwards, `git status --porcelain --untracked-files=all` was empty and the `ALLOWED_AFTER_FREEZE` node check passed.

## Edges, requirements, credit
- All eleven edge rows stay **unresolved**:
  - EVID-01: boundary, adjacency, empty, ordering, precision
  - EVID-02: unclassified
  - EVID-03: boundary, precision
  - EVID-04: idempotency, concurrency
  - TRUTH-08: unclassified
- EVID-01..04 and TRUTH-08 stay **Pending**.
- Qualification credit is **0**. This plan only removes the `receipt_host_scope` blocker in front of Plan 203.

## Ordering contract
Any GSD bookkeeping written after this plan (STATE, ROADMAP, state.json, handoffs) must be **committed before Plan 203's freeze**, not left dirty. A re-created `.planning/milestone.lock` must be absent at freeze time.

## Deviations from Plan
- The revision 1 executor subagent lost its API connection after its step 8 run. The orchestrator recovered the results from the logs.
- The revision 2 timeout fix, step 8 rerun and Task 3 were run inline by the orchestrator, as Plan 209 revision 2 (`f488351a`) specifies.

## Commits
- `3018b7d5` docs(133-209): archive inherited working-tree dirt before Plan 203 freeze
- `6c4210a0` docs(133-209): record designed halt - adoption gate red (first run)
- `6e87a22c` docs(133-209): revise adoption gate (revision 1)
- `584baab5` fix(133-209): adopt inherited fixture-root hygiene and registry-compat fixes
- `9540a013` docs(133-209): record designed halt - committed-bytes rerun red (revision 1 run)
- `6e7bf58c` test(133-209): give slow reconciliation tests a 300s timeout budget
- `f488351a` docs(133-209): revise adoption gate (revision 2)
- (this summary) docs(133-209): complete inherited dirt archive and adoption gate
