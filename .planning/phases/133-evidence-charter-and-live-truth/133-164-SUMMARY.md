---
phase: 133-evidence-charter-and-live-truth
plan: "164"
subsystem: testing
tags: [esm, symlink, registry, detached-checkout]
requires:
  - phase: 133-162
    provides: bounded diagnostic identifying the lexical/canonical temp-path mismatch
provides:
  - Canonicalized Plan 154 ESM main-entry comparison
  - Real detached lexical-child regression plus canonical and import-only coverage
affects: [133-163, registry-closure]
actuals:
  tokens: 3209
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: ["Compare canonical filesystem identities for symlinked ESM entrypoints"]
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-164-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_registry_closure_154.mjs
    - scripts/maintainer/phase_133_plan159_authority.test.mjs
    - scripts/maintainer/phase_133_registry_closure_154.test.mjs
key-decisions:
  - "Canonicalize both the argv script path and fileURLToPath(import.meta.url) with fs.realpathSync at the final main guard."
  - "Keep all five requirements Pending and grant zero qualification credit; Plan 164 repairs a prerequisite only."
requirements-completed: []
coverage:
  - id: D1
    description: "A real exact-source detached Plan 154 child invoked through the lexical temp path emits one JSON outcome or a structured nonzero halt."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "node --test scripts/maintainer/phase_133_plan159_authority.test.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Lexical alias and canonical invocations share the same guarded failure behavior, while module import remains inert."
    requirement: EVID-02
    verification:
      - kind: unit
        ref: "node --test scripts/maintainer/phase_133_registry_closure_154.test.mjs scripts/maintainer/phase_133_plan159_authority.test.mjs"
        status: pass
    human_judgment: false
duration: 56min
completed: 2026-10-11
status: complete
commits: 2
plan_head_before: b1293a647451a0538fbca4ac34a1396f6f3e0e2f
plan_head_after: 004e7b6dc7d4b59443c679cbc2feb65c49877ceb
---

# Phase 133 Plan 164: Plan 154 Entry Guard Summary

The Plan 154 ESM entry guard now recognizes lexical temp-directory aliases and preserves the real child’s machine-readable outcome.

## Performance

- **Duration:** 56 minutes
- **Started:** 2026-10-11T08:13:25Z
- **Completed:** 2026-10-11T09:09:02Z
- **Tasks:** 2
- **Files modified:** 4 (including this summary)

## Accomplishments

- Reproduced the red case before the fix: on the host’s `/var` to `/private/var` temp alias, the exact detached child exited 0 with empty stdout and stderr.
- Changed only the final entry guard to compare `fs.realpathSync(path.resolve(process.argv[1]))` with `fs.realpathSync(fileURLToPath(import.meta.url))`; `main()`, its catch/exit behavior, and all source, receipt, signed-supply, and zero-network gates remain intact.
- Added bounded detached-child assertions for exactly one parseable result or a structured nonzero halt, and producer tests for lexical/canonical unsupported-mode calls and import-only behavior.
- Kept Plan 161 and Plan 162 artifacts untouched. Plan 163 remains a separate downstream plan; no authorization or attempt was created.

## Task Commits

1. **Task 1: Canonicalize the Plan 154 entry guard and lock in the real-child regression** — `67a7416c` (fix)
2. **Task 2: Cover lexical alias, canonical invocation, and import-only behavior** — `004e7b6d` (test)

## Files Created/Modified

- `scripts/maintainer/phase_133_registry_closure_154.mjs` — symlink-safe ESM main guard.
- `scripts/maintainer/phase_133_plan159_authority.test.mjs` — real detached child output and red/green regression.
- `scripts/maintainer/phase_133_registry_closure_154.test.mjs` — lexical/canonical child and import-only regression.
- `.planning/phases/133-evidence-charter-and-live-truth/133-164-SUMMARY.md` — execution evidence and zero-credit handoff.

## Verification

- Red before repair: `node --test scripts/maintainer/phase_133_plan159_authority.test.mjs` failed at the new fail-closed assertion, recording lexical/canonical path difference and status 0 with zero output bytes.
- Green after repair: `node --test scripts/maintainer/phase_133_plan159_authority.test.mjs` — 7 passed, 0 failed.
- Final suites: `node --test scripts/maintainer/phase_133_registry_closure_154.test.mjs scripts/maintainer/phase_133_plan159_authority.test.mjs` — 16 passed, 0 failed.
- `./scripts/maintainer/automation_first_contract.sh` — passed.
- `git diff --check` — passed.

## Decisions Made

- The test accepts the producer’s valid machine-readable success result or its structured, nonzero halted result; status-0 empty output always fails.
- The import-only child must produce no output and must not invoke `main()`.

## Deviations from Plan

None — plan executed as written.

## Issues Encountered

- The GSD commit helper initially could not create the shared worktree index lock inside the sandbox. Retrying the same GSD helper with elevated access succeeded; no raw Git staging or commit fallback was used.
- An intermediate test-edit script produced a syntax error before any commit; the file was reconstructed from the committed version and the corrected regression passed.

## Next Phase Readiness

The Plan 154 entrypoint prerequisite is repaired and committed. EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain Pending; all eleven evidence edges remain unresolved; qualification credit remains zero. No authorization, qualification, census, Nightly, remote action, receipt publication, or network retrieval occurred. The orchestrator may now recompute readiness for Plan 163.

## Self-Check: PASSED

- Both task commits exist and are measured from `plan_head_before` above (2 commits before this summary’s metadata commit).
- Required source and regression files exist; final automated suites and automation-first contract passed.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-11*
