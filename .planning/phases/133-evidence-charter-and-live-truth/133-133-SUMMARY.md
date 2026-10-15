---
phase: 133-evidence-charter-and-live-truth
plan: "133"
subsystem: provenance
tags: [hex, git, source-acquisition]

# Dependency graph
requires:
  - phase: "133-131"
    provides: "Completed compatibility finding used as historical source context."
provides:
  - "Fresh, exact authorization and production-verifiable one-clone provenance for Hex v2.5.1."
affects: ["133-135"]

# Actuals
actuals:
  tokens: 20248
  tasks: 3
  commits: 6

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "No-clobber authorization, one-shot clone marker, pinned Git identity, and durable source-file digest inventory."

key-files:
  created:
    - scripts/maintainer/phase_133_hex_source.mjs
    - test/install_smoke/phase_133_hex_source_test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-PREFLIGHT.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-AUTHORIZATION.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-133-CLONE-STARTED.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-RETRIEVAL.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-133-SUMMARY.md
  modified: []

requirements-completed: []

coverage:
  - id: D1
    description: "Official Hex v2.5.1 source retrieval is bound to a fresh decision, one clone invocation, and pinned source bytes."
    verification:
      - kind: other
        ref: "node scripts/maintainer/phase_133_hex_source.mjs verify-retrieval"
        status: pass
    human_judgment: false

duration: 14min
completed: 2026-10-08
status: complete
---

# Phase 133 Plan 133-133: Pinned Hex source retrieval

**Hex v2.5.1 source was acquired once from the official repository and verified at its pinned commit and tree with a durable 221-file SHA-256 inventory.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-10-08T22:52:26Z
- **Completed:** 2026-10-08T23:06:13Z
- **Tasks:** 3
- **Files created:** 7

## Accomplishments

- Implemented the exact-source preflight and one-shot acquisition gate, with focused tests; the frozen preflight SHA-256 is `aa0a46ae7dfbfd7fd6ece5b1984146622d04540528f06a5097d494daf5800d10`.
- Recorded the user’s fresh answer, “Authorize exactly this clone,” against the exact URL, commit, destination, clone argv, and preflight digest. The receipt records zero qualification credit and no completed requirements.
- Ran exactly one `git clone --no-checkout` through the production `acquire-once` gate. Retrieval reports status `retrieved`, clone exit code 0, and one network request.
- Verified the origin `https://github.com/hexpm/hex.git`, HEAD `a43131c26aeca06064959297d737991163f5ac5d`, tree `778c9a1387d22da9ea8830d1f02b84c9f7402c7d`, and 221 source-file hashes.
- Left all five requirements Pending and all eleven edge rows unresolved. No build, Mix command, mux request, or qualification ran.

## Files Created/Modified
- `scripts/maintainer/phase_133_hex_source.mjs` — production source acquisition verifier and one-shot gate.
- `test/install_smoke/phase_133_hex_source_test.mjs` — exact-source and mutation-rejection tests.
- `.planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-PREFLIGHT.json` — frozen preflight.
- `.planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-AUTHORIZATION.json` — fresh exact clone decision.
- `.planning/phases/133-evidence-charter-and-live-truth/133-133-CLONE-STARTED.json` — no-retry invocation marker.
- `.planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-RETRIEVAL.json` — pinned source identity and file digest inventory.
- `.planning/phases/133-evidence-charter-and-live-truth/133-133-SUMMARY.md` — plan outcome and next gated dependency.

## Checks Run

- node --test test/install_smoke/phase_133_hex_source_test.mjs — 3/3 passed during Task 1.
- node scripts/maintainer/phase_133_hex_source.mjs verify-preflight --report .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-PREFLIGHT.json — passed.
- node scripts/maintainer/phase_133_hex_source.mjs verify-authorization --preflight .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-PREFLIGHT.json --authorization .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-AUTHORIZATION.json — passed.
- node scripts/maintainer/phase_133_hex_source.mjs verify-retrieval --preflight .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-PREFLIGHT.json --authorization .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-AUTHORIZATION.json --started .planning/phases/133-evidence-charter-and-live-truth/133-133-CLONE-STARTED.json --retrieval .planning/phases/133-evidence-charter-and-live-truth/133-133-SOURCE-RETRIEVAL.json — passed; returned the pinned commit and tree.
- ./scripts/maintainer/automation_first_contract.sh — passed after authoring this summary.

## Task Commits

1. **Task 1: Implement the source acquisition gate and tests** — `d6dadc733ba7dc2fe964b42bdbaa1503b45a5236`
2. **Task 1: Freeze the exact source preflight** — `b2095e56bbd2a4feeb3cab4a9c56072acbd3bd41`
3. **Task 2: Record the fresh exact source authorization** — `42f9634884b6258765d62714f4c7a33b49b37ca0`
4. **Task 3: Record the one-shot clone and verified retrieval** — `76dd7da9934ccb938a7dea64e9d6e3a86a84f4a1`

**Plan metadata:** recorded by the GSD summary commit and executor lifecycle record.

## Source Evidence

- **URL:** `https://github.com/hexpm/hex.git`
- **Commit:** `a43131c26aeca06064959297d737991163f5ac5d`
- **Tree:** `778c9a1387d22da9ea8830d1f02b84c9f7402c7d`
- **Destination:** `/private/tmp/rindle-phase133-hex-v2.5.1-a43131c26aeca06064959297d737991163f5ac5d`
- **Preflight SHA-256:** `fc02f8c84c425109339422d714185542837435cd070bceee6ef1218bf3d3940a`
- **Authorization SHA-256:** `35449174439068d60a910b0c2b070f98c2c2a47c1d1f40fb4060ea603ca55222`
- **Clone-start marker SHA-256:** `58d20ff07a7f5775c5226948b34acbec1aef911dcb6c7edfcef4072a369901bc`
- **Retrieval report SHA-256:** `11cb81b87b98372db6d39299be5638088c9e04f43a44ab2b2b29ab1cc9f490e3`

## Issues Encountered

The isolated executor could not commit the authorization receipt under the default sandbox because Git’s worktree index lock is stored beneath the read-only shared `.git` directory. The failed launch and incomplete worker were reconciled without running the clone. After explicit sandbox escalation for the GSD commit helper, the receipt committed successfully and both production verifiers passed. The clone then ran once through the guarded gate.

## Decisions Made

- Preserve the gate’s canonical `authorize` enum and include the exact user answer text in the authorization receipt.
- Source acquisition provides provenance only. Plan 135 retains its independent build preflight and authorization; this plan grants no qualification or requirement credit.

## Deviations from Plan

- Git metadata writes required a one-time escalated GSD commit for the authorization receipt after the default sandbox rejected index-lock creation. No code, source scope, or one-clone guard was changed.

## Next Phase Readiness

Plan 133-135 may begin its Wave 3 build-preflight work from this verified retrieval. It requires a distinct exact build decision. This plan does not authorize a build, Mix execution, cache qualification, or mux request.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-08*

## Self-Check

PASSED — all three plan tasks are committed, the exact pinned retrieval verifier passes, and the automation-first contract passes.
