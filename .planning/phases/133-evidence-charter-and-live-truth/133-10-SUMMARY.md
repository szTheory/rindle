---
phase: 133-evidence-charter-and-live-truth
plan: "10"
subsystem: ci-evidence
tags: [github-actions, setup-beam, version-parsing, dialyzer, tamper-evidence]
requires:
  - phase: 133-09
    provides: Exact canonical reconstruction and read-only revalidation of Nightly receipts
provides:
  - Anchored numeric-component classification for the sole supported Elixir 1.17 and OTP 27 cell
  - Shared supported-version parsing across Nightly collection and receipt shape validation
  - Explicit collection and receipt regressions for Elixir 11.17, Elixir 1.170, and OTP 127
  - Exact patch-level resolved-version binding to the PLT cache identity
affects: [phase-133-verification, evidence-charter, nightly-dialyzer]
actuals:
  tokens: 2271
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - Parse supported toolchains from anchored numeric components while preserving the original resolved string
    - Reuse one fail-closed predicate at collection and persisted-receipt boundaries
key-files:
  created: []
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
key-decisions:
  - "Accept only Elixir numeric major/minor 1.17 and OTP numeric major 27, with bounded setup-beam prefixes and suffixes."
  - "Preserve resolved patch/build strings verbatim and require both exact strings in the PLT cache key."
patterns-established:
  - "Anchored toolchain identity: support classification operates on numeric components, never substring containment."
  - "Shared receipt boundary: persisted toolchain fields pass the same parser as live job-scoped logs before exact live equality."
requirements-completed: [EVID-02]
coverage:
  - id: D1
    description: "Nightly collection accepts the recorded Elixir 1.17/OTP 27 patch forms while rejecting 11.17, 1.170, and 127 near-matches."
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (84 cases, 0 failures)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Receipt revalidation uses the same anchored predicates and binds exact resolved versions into the PLT cache key."
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (named receipt mutations and no-substring contract)"
        status: pass
    human_judgment: false
duration: 9min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 10: Supported Toolchain Boundary Summary

**Nightly evidence now classifies Elixir 1.17 and OTP 27 at anchored numeric boundaries while retaining exact setup-beam patch strings in receipts and PLT cache identity.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-10T16:39:26Z
- **Completed:** 2026-09-10T16:47:57Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced unanchored Bash and jq substring support checks with shared component parsers for Elixir major/minor `1.17` and OTP major `27`.
- Preserved the recorded `v1.17.3-otp-27` and `OTP-27.3.4.17` strings verbatim through collection, receipt validation, live reconstruction, and PLT cache-key equality.
- Expanded the fake-GitHub suite to 84 passing cases with distinct collection and receipt mutations for `11.17`, `1.170`, and `127`.
- Retained fail-closed handling for missing, duplicate, malformed, stale, and cache-inconsistent evidence.

## Task Commits

1. **Task 1 RED: expose near-match toolchain acceptance** - `4ab4bca` (test)
2. **Task 1 GREEN: anchor collected toolchain versions** - `881c2e0` (feat)
3. **Task 2 RED: pin receipt toolchain boundaries** - `60926e5` (test)
4. **Task 2 GREEN: reuse anchored receipt validation** - `14de23d` (feat)

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` - Shared anchored setup-beam version parsers, unique-value collection checks, receipt boundary validation, and exact cache identity binding.
- `scripts/ci/test_verify_nightly_run.sh` - Named adversarial fake-log states, receipt-only mutations, recorded patch-form fixtures, and the no-substring contract.

## Decisions Made

- Optional prefixes are bounded to setup-beam's known `v` and `OTP-` forms; numeric components still decide support and arbitrary surrounding text is rejected.
- Full resolved strings are never normalized to support labels. The parser decides eligibility, while the untouched value remains the receipt and cache authority.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The current historical receipt remains intentionally stale because live issue `#88` has changed since collection. Real `verify-receipt` passed schema, supported-toolchain, cache, remote reconstruction, and exact-subject local-authority checks before failing at the final fresh incident comparison; no evidence was mutated.
- Shellcheck's default style level reports the pre-existing intentional single-quoted embedded fake-command diagnostics. The warning/error gate (`shellcheck -S warning`) passes.

## Known Stubs

None. Empty shell variables are argument-parser, polling, or embedded-fake initialization and do not flow to accepted evidence.

## Authentication Gates

None. Existing GitHub CLI read access was sufficient for the historical receipt check.

## User Setup Required

None - no external service configuration required.

## Verification

- `bash scripts/ci/test_verify_nightly_run.sh` - 84 cases, 0 failures.
- `bash scripts/ci/test_nightly_incident.sh` - 22 cases, 0 failures.
- `bash scripts/ci/test_nightly_summary_gate.sh` - 49 cases, 0 failures.
- `shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` - exited 0.
- `./scripts/maintainer/automation_first_contract.sh` - passed.
- Real Plan 07 `verify-receipt` invocation - expected nonzero only at the final stale incident-snapshot comparison after accepting the recorded patch-level toolchain and exact cache identity.
- Static forbidden-matcher scan - no `contains("1.17")`, `contains("27")`, or unanchored Bash support match remains.

## Threat Flags

None. The shared parser and exact receipt/cache rebinding implement planned mitigations T-133-38 through T-133-40 without introducing a new endpoint, auth path, file trust boundary, schema, or remote mutation.

## TDD Gate Compliance

- Task 1 RED commit `4ab4bca` demonstrated that `11.17`, `1.170`, and `127` all reached receipt construction; GREEN commit `881c2e0` made all three collection cases fail closed.
- Task 2 RED commit `60926e5` detected the surviving receipt `contains()` fallback; GREEN commit `14de23d` routed receipt fields through the shared parser and exact cache-key checks.

## Self-Check: PASSED

- Both declared modified files and this summary exist.
- Commits `4ab4bca`, `881c2e0`, `60926e5`, and `14de23d` exist in repository history.
- The final fake-GitHub matrix has a nonzero case count and passes completely.
- No tracked deletion, known stub, skipped test, unrun plan verification, or unplanned threat surface remains.

## Next Phase Readiness

- Phase 133's remaining supported-toolchain gap is closed with executable collection and revalidation evidence.
- EVID-02 retains its single supported cell, independent fresh/restored proof, narrow stale rebuild policy, and patch-level cache authority.
- No workflow topology, support matrix, public API, dependency, schema, or later-phase scope changed.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
