---
phase: 133-evidence-charter-and-live-truth
plan: "183"
subsystem: evidence
tags: [sha256, immutable-receipts, registry, offline-tests]
requires:
  - phase: 133-181
    provides: no-authorization historical evidence and zero-credit boundaries
provides:
  - Plan 184-bound collector with independent expected-byte, raw-byte, and canonical digest verification
  - Deterministic raw-child fixture seam shared with production publication and closeout paths
  - Narrow blocked-evidence verification for real preflight or publication readback failures
affects: [133-184, evidence-integrity, qualification-boundary]
actuals:
  tokens: 17358
  tasks: 2
  commits: 6
  plan_head_before: b074daa36f65b0bd131a7d10e98c3b8cd2796303
  plan_head_after: cbb14218ae6e51c0cdccf8d15271e8ae3934d78a
tech-stack:
  added: []
  patterns: [independent serialized-byte and canonical digests, controlled raw-child fixture seam]
key-files:
  created:
    - scripts/maintainer/phase_133_registry_preparation_183.mjs
    - scripts/maintainer/phase_133_registry_preparation_183.test.mjs
  modified:
    - scripts/maintainer/phase_133_registry_preparation_183.mjs
    - scripts/maintainer/phase_133_registry_preparation_183.test.mjs
key-decisions:
  - "Bind all new collector receipts and commands to Plan 184; preserve Plan 182 as immutable untrusted history."
  - "Hash exact expected serialized bytes before publication, compare fresh readback bytes to that hash, and independently validate canonical report content."
  - "A missing outcome is blocked only with a verified failed preflight or a diagnostic whose preserved bytes prove the publication readback failed."
  - "Plan 183 remains fixture-only: all five requirements stay Pending, eleven edge rows remain unresolved, and qualification credit stays zero."
requirements-completed: []
qualification_credit: 0
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
unresolved_edge_rows: 11
coverage:
  - id: D1
    description: "Diagnostic, preparation, and outcome publication checks compare expected serialized bytes independently from canonical report digests."
    verification:
      - kind: unit
        ref: "scripts/maintainer/phase_133_registry_preparation_183.test.mjs#a semantically equivalent byte mutation between publication and readback preserves the first bytes and stops before successors"
        status: pass
      - kind: unit
        ref: "scripts/maintainer/phase_133_registry_preparation_183.test.mjs#real collector publication path separates raw-byte and canonical digests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Controlled raw producer results traverse the shared collection and publication path for ready, red, malformed, empty, nonzero, signal, and timeout branches."
    verification:
      - kind: unit
        ref: "scripts/maintainer/phase_133_registry_preparation_183.test.mjs#ready and first-red branches publish one terminal result without authority"
        status: pass
      - kind: unit
        ref: "scripts/maintainer/phase_133_registry_preparation_183.test.mjs#malformed, empty, nonzero, signal, and timeout child outputs traverse collection as bounded reds"
        status: pass
    human_judgment: false
  - id: D3
    description: "Blocked collection and closeout reject missing failure evidence, corrupt outcomes, preparations, and qualification markers; receipt parent links are mandatory."
    verification:
      - kind: unit
        ref: "scripts/maintainer/phase_133_registry_preparation_183.test.mjs#blocked verification needs evidence of an actual failed publication or preflight"
        status: pass
      - kind: unit
        ref: "scripts/maintainer/phase_133_registry_preparation_183.test.mjs#blocked verification accepts a preserved readback failure but rejects preparation and authority markers"
        status: pass
      - kind: unit
        ref: "scripts/maintainer/phase_133_registry_preparation_183.test.mjs#ready and red outcomes require diagnostic raw parent links; ready also requires preparation link"
        status: pass
    human_judgment: false
duration: 17min
completed: 2026-10-12
status: complete
---

# Phase 133 Plan 183: Diagnostic Publication Digest Repair Summary

**Plan 184-bound publication now verifies expected serialized bytes, canonical content, required receipt links, and evidence for blocked collection without granting qualification credit.**

## Performance

- **Duration:** 17 min (including this reconciliation pass)
- **Started:** 2026-10-12T20:34:00Z
- **Completed:** 2026-10-12T20:50:32Z
- **Tasks:** 2
- **Files modified:** 3 (runner, tests, summary)

## Accomplishments

- Corrected the tautological publication check: expected bytes are serialized and hashed before the write, then compared to fresh file bytes. Canonical `report_sha256` is validated independently.
- Routed deterministic raw child results through the shared collector, diagnostic publication, readback, and terminal outcome path. Ready fixtures use authenticated offline supply inputs; no synthetic 67/96 ready receipt is assembled.
- Restricted blocked verification to documented failed offline-input/host-guard preflight evidence or preserved noncanonical publication bytes with no verified outcome. Missing an outcome after a valid result is rejected.
- Required diagnostic parent links for red and ready outcomes and preparation links for ready outcomes. Tests reject missing links, byte and content changes, replay, malformed/empty/nonzero/signal/timeout child output, corrupt outcomes, preparations, and qualification markers.
- Preserved Plan 182's raw and canonical hashes and immutable untrusted status. No producer or qualification process was invoked; all five requirements remain Pending, eleven edges remain unresolved, and credit is zero.

## Task Commits

1. **Task 1 RED: Reproduce diagnostic publication digest mismatch** - `b0e206bf` (test)
2. **Task 1 GREEN: Separate publication and report digests** - `bb4489e4` (fix)
3. **Task 2: Verify blocked collection closeout** - `b2597bce` (feat)
4. **Plan metadata from original execution** - `3d1564e5` (docs)
5. **Correction RED: Reject publication and blocked-evidence gaps** - `a89439fb` (test)
6. **Correction GREEN: Verify publication bytes and blocked evidence** - `cbb14218` (fix)

**Plan metadata:** committed immediately after this summary is written.

## Files Created/Modified

- `scripts/maintainer/phase_133_registry_preparation_183.mjs` - expected-byte readback verification, shared raw-child collection seam, required parent links, and narrow blocked-evidence checks.
- `scripts/maintainer/phase_133_registry_preparation_183.test.mjs` - ten fixture-only tests covering publication mutations, terminal branches, child failures, no-replay, blocked closeout, and required links.

## Decisions Made

- Keep Plan 182 immutable and untrusted; do not infer a producer cause from its stderr digest.
- Treat only verified offline-input/host-guard failures or a proven failed publication readback as blocked evidence. Never treat a missing outcome by itself as a valid halt.
- Keep Plan 183 fixture-only and retain the actual-host guard as a hard production precondition.
- Leave EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 Pending, with eleven edge rows unresolved and zero qualification credit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced the self-comparison in the publication digest check**
- **Found during:** Correction Task 1 (publication mutation regression)
- **Issue:** The collector hashed bytes only after rereading them, then compared that value with another hash of the same bytes; it did not authenticate publisher input bytes.
- **Fix:** Compute the expected serialized-byte SHA-256 before publication and compare it with fresh readback bytes, then validate the canonical report digest separately.
- **Files modified:** `scripts/maintainer/phase_133_registry_preparation_183.mjs`, `scripts/maintainer/phase_133_registry_preparation_183.test.mjs`
- **Verification:** Focused suite passes, including semantically equivalent formatting mutation between write and readback; committed as `cbb14218`.

**2. [Rule 2 - Missing Critical] Narrowed blocked evidence and required raw parent links**
- **Found during:** Correction Task 2 (blocked collection and closeout regressions)
- **Issue:** Any red/ready diagnostic without an outcome could be called blocked, arbitrary preflight errors lacked evidence, and null parent links bypassed validation.
- **Fix:** Require recognized preflight failure evidence or preserved bytes that differ from the publisher's canonical serialization; reject missing outcomes without such evidence; require diagnostic and preparation parent links by branch.
- **Files modified:** `scripts/maintainer/phase_133_registry_preparation_183.mjs`, `scripts/maintainer/phase_133_registry_preparation_183.test.mjs`
- **Verification:** Focused suite passes for legitimate blocked branches and false positives; committed as `cbb14218`.

**Total deviations:** 2 auto-fixed (1 bug, 1 missing critical validation). **Impact:** Repairs close the publication trust gap while keeping the scope fixture-only and zero-credit.

## Issues Encountered

- The original Plan 183 summary claimed all five requirements complete and overstated test coverage. Those claims are corrected here: `requirements-completed` is empty, `qualification_credit` is zero, and coverage cites the tests that now pass.
- No live producer, qualification, network request, or requirement/edge closure was performed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 183's correction is committed before any Plan 184 source freeze. Plan 184 may use a fresh source only after this manifest-scoped merge; its actual-host guard remains mandatory. All five requirements are Pending and qualification credit remains zero.

## Self-Check: PASSED

- Both owned `_183` files exist and the original four commits plus both correction commits are ancestors of the current branch.
- The Plan 182 diagnostic remains unchanged; its PREPARATION and OUTCOME remain absent.
- All five requirement checkboxes remain Pending; `.planning/STATE.md` and `.planning/ROADMAP.md` were not edited.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-12*
