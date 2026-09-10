---
phase: 133-evidence-charter-and-live-truth
plan: "16"
subsystem: ci-evidence
tags: [git-objects, sha256, canonical-json, exact-subject, nightly]
requires:
  - phase: 133-12
    provides: Cardinality-safe exact Nightly run selection
  - phase: 133-13
    provides: Authenticated census detectors and contained evidence locations
  - phase: 133-15
    provides: Executable live-truth release and required-check authority
provides:
  - Schema v2 Nightly receipts with immutable census path, digest, blob, commit, subject, and detailed receipt authority
  - Exact commit:path ledger materialization independent of caller-worktree bytes
  - Deterministic live-truth model digests and a 109-case adversarial verification matrix
affects: [133-17, phase-133-verification, nightly-evidence, EVID-01, EVID-02, TRUTH-08]
actuals:
  tokens: 6987
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns:
    - Bind mutable evidence paths to explicit Git commit and blob identities before validation
    - Canonicalize regenerated authority before exact receipt equality and digesting
key-files:
  created: []
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
key-decisions:
  - "Keep the census ledger commit distinct from the Nightly subject while recording and independently validating both identities."
  - "Materialize ledger authority only from recorded commit:path bytes; caller-worktree ledger state is relevant during collection but ignored during stored-receipt verification."
  - "Hash the canonical live-truth model without its ephemeral authority_root locator so identical subject truth has a deterministic digest."
patterns-established:
  - "Cross-object authority: ledger path, SHA-256, blob, commit, subject, and regenerated receipt must all agree."
  - "Stored evidence verification reconstructs authority from immutable objects and never refreshes or repairs the receipt."
requirements-completed: [EVID-01, EVID-02, TRUTH-08]
coverage:
  - id: D1
    description: "Nightly schema v2 records and revalidates detailed census authority from immutable Git-object bytes plus deterministic exact-subject live truth."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (immutable-object happy path; 109 cases total)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every local-authority field and missing, dirty, substituted, jointly forged, or caller-worktree ledger state fails closed or remains correctly independent."
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (field and materialization mutation matrix)"
        status: pass
      - kind: other
        ref: "shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "Live-truth authority is bound to the exact Nightly subject through a canonical deterministic model SHA-256."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (live-truth subject, digest, and regenerated-model mutations)"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 16: Immutable Local Nightly Authority Summary

**Nightly schema v2 now reconstructs census authority from an exact Git commit and blob, embeds the detailed regenerated receipt, and binds exact-subject live truth to a deterministic model digest.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-09-10T21:44:33Z
- **Completed:** 2026-09-10T22:02:57Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced status-only local authority with exact census ledger path, SHA-256, blob, containing commit, Nightly subject, and complete regenerated receipt fields.
- Materialized census bytes with `git show commit:path`, verified blob and digest identity, and passed only the temporary immutable object path into detached-subject collectors and validators.
- Derived a canonical live-truth model at the exact subject and stored its deterministic SHA-256 after excluding the ephemeral authority-root locator.
- Expanded the fake-Git and receipt matrix from 89 to 109 passing cases across individual fields, object absence/substitution, dirty collection, regenerated drift, receipt immutability, and caller-worktree independence.

## Task Commits

1. **Task 1 RED: expose mutable local authority receipts** - `926664a` (test)
2. **Task 1 GREEN: bind local authority to immutable Git objects** - `5756873` (feat)
3. **Task 2 RED: expose ledger identity mutation paths** - `eaba8ac` (test)
4. **Task 2 GREEN: reject local authority identity drift** - `dd9a16e` (fix)
5. **Task 2 correctness fix: preserve Git identity in detached validation** - `bb3168d` (fix)

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` - Resolves and materializes immutable ledger objects, emits schema v2 local authority, and reconstructs it during receipt verification.
- `scripts/ci/test_verify_nightly_run.sh` - Provides fake Git/Mix object behavior, exact argv assertions, and the complete local-authority mutation matrix.

## Decisions Made

- Ledger commit and Nightly subject remain separate explicit identities, preserving the census ledger's anti-self-reference design.
- Collection rejects a dirty or untracked canonical ledger, while verification intentionally ignores the caller-worktree copy and trusts only the receipt-bound Git object.
- The live-truth digest omits `authority_root` because that path is an ephemeral locator, not semantic authority.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rejected empty generated authority JSON**

- **Found during:** Task 2 regenerated live-truth mutation coverage
- **Issue:** Canonicalizing an empty JSON stream could exit successfully and hash a newline, allowing a meaningless model digest.
- **Fix:** Required both generated census and live-truth streams to decode to JSON objects before canonicalization or hashing.
- **Files modified:** `scripts/ci/verify_nightly_run.sh`, `scripts/ci/test_verify_nightly_run.sh`
- **Verification:** The regenerated census and live-model drift cases fail closed; the complete 109-case matrix passes.
- **Committed in:** `bb3168d`

**2. [Rule 1 - Bug] Restored detached Git identity for subject validators**

- **Found during:** Task 2 final real-execution review
- **Issue:** A plain archived source tree lacked the `.git` identity required by the repository-owned census validator's exact-HEAD check.
- **Fix:** Materialized the subject as a bounded detached temporary worktree while keeping the independently materialized ledger object outside that checkout.
- **Files modified:** `scripts/ci/verify_nightly_run.sh`, `scripts/ci/test_verify_nightly_run.sh`
- **Verification:** All fixed subject validators retain Git identity and the 109-case matrix plus ShellCheck pass.
- **Committed in:** `bb3168d`

---

**Total deviations:** 2 auto-fixed bugs.
**Impact on plan:** Both fixes are necessary to preserve exact-subject correctness and fail-closed evidence semantics; no public API, workflow topology, package, schema, or remote mutation scope changed.

## Issues Encountered

None beyond the auto-fixed correctness issues above.

## Known Stubs

None. Empty shell variables are bounded parser, selected-run, and fake-command initialization; they do not represent incomplete authority or UI data.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `bash scripts/ci/test_verify_nightly_run.sh` - 109 passed, 0 failed.
- `shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` - passed with no warning-or-higher findings.
- `./scripts/maintainer/automation_first_contract.sh` - passed for the active Phase 133 planning artifacts.

## Threat Flags

None. The implementation closes the planned mutable-worktree, Git-object, and detached-subject trust boundaries without introducing a new network, authentication, file-selection, or schema surface.

## TDD Gate Compliance

- Task 1 RED commit `926664a` failed because schema v1 exposed only status strings; GREEN commit `5756873` established immutable object materialization and schema v2.
- Task 2 RED commit `eaba8ac` exposed missing-path, blob, hash, regenerated receipt, and regenerated model gaps; GREEN commits `dd9a16e` and `bb3168d` made the complete adversarial matrix pass.

## Self-Check: PASSED

- Both declared modified files exist.
- Commits `926664a`, `5756873`, `eaba8ac`, `dd9a16e`, and `bb3168d` exist in repository history.
- All task acceptance criteria and plan-level verification commands passed with 109 nonzero cases.
- No tracked file was deleted, no generated task artifact is untracked, and no known stub or skipped verification blocks the plan goal.

## Next Phase Readiness

- CR-04 is closed: local census and live-truth authority has immutable detailed meaning independent of the caller worktree.
- Plan 133-17 can recollect fresh exact-subject remote evidence using schema v2; the existing stale stored receipt remains rejected.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
