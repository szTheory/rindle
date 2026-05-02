---
phase: 21-verify-02-hexdocs-reachability-probe
plan: 01
subsystem: infra
tags: [github-actions, hexdocs, hexpm, release, testing]
requires:
  - phase: 16-live-publish-execution-and-post-publish-verification
    provides: "public_verify release lane, Hex.pm index wait, and release runbook parity pattern"
  - phase: 20-v1.3-verification-and-metadata-closure
    provides: "VERIFY-02 forward reference and parity-test ownership for release verification"
provides:
  - "Versioned HexDocs reachability probe in `public_verify` with redirect-following GET and bounded retries"
  - "Runbook parity for the HexDocs probe in the routine release sequence and workflow contract"
  - "Install-smoke assertions for probe naming, placement, literal URL, and retry/failure semantics"
affects: [v1.3 verification, release workflow, release runbook, install-smoke]
tech-stack:
  added: []
  patterns: ["Inline GitHub Actions probe loops guarded by install-smoke parity tests"]
key-files:
  created: [.planning/phases/21-verify-02-hexdocs-reachability-probe/21-01-SUMMARY.md]
  modified:
    - .github/workflows/release.yml
    - guides/release_publish.md
    - test/install_smoke/release_docs_parity_test.exs
    - test/install_smoke/package_metadata_test.exs
key-decisions:
  - "Kept the HexDocs probe inline in `public_verify` rather than extracting a helper script, matching the plan boundary."
  - "Locked the workflow to the literal `https://hexdocs.pm/rindle/$VERSION` probe string so guide/workflow parity can fail on drift."
  - "Used a TDD RED/GREEN sequence in the parity suite to force the final workflow URL shape and placement contract."
patterns-established:
  - "Release runbook changes must mirror workflow step names and concrete commands closely enough for literal install-smoke parity."
  - "Public verification steps in `public_verify` should be ordered and asserted by substring positions when YAML parsing is unnecessary."
requirements-completed: [VERIFY-02]
duration: 7min
completed: 2026-05-02
---

# Phase 21 Plan 01: HexDocs Reachability Probe Summary

**Post-publish release verification now proves the versioned HexDocs URL with a bounded redirect-following probe and CI parity locks that enforce its placement and retry contract**

## Performance

- **Duration:** 7 min
- **Started:** 2026-05-02T01:20:00Z
- **Completed:** 2026-05-02T01:26:52Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Added `Verify HexDocs reachability` to `.github/workflows/release.yml` between the Hex.pm index wait and public package smoke steps.
- Updated `guides/release_publish.md` so the routine release sequence and workflow contract explicitly name the HexDocs probe and its retry behavior.
- Extended install-smoke coverage so CI fails if the probe step, literal URL, placement, or bounded retry semantics drift.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the bounded HexDocs reachability probe to public_verify** - `44b8aa2` (`feat`)
2. **Task 2: Sync the maintainer runbook to the shipped docs probe contract** - `65ed318` (`docs`)
3. **Task 3: Extend install-smoke parity tests to lock the probe in place** - `7409708` (`test`), `f6008ea` (`feat`)

## Files Created/Modified

- `.github/workflows/release.yml` - added the inline HexDocs probe with redirect following, 5-minute deadline, 15-second polling, and terminal failure messaging.
- `guides/release_publish.md` - mirrored the new step name, command contract, and post-publish check sequence.
- `test/install_smoke/release_docs_parity_test.exs` - added guide/workflow parity coverage for the HexDocs step name and probe command.
- `test/install_smoke/package_metadata_test.exs` - added `public_verify` ordering and retry-contract assertions for the HexDocs probe.
- `.planning/phases/21-verify-02-hexdocs-reachability-probe/21-01-SUMMARY.md` - recorded execution outcomes for this plan.

## Decisions Made

- Kept the probe inline in workflow YAML to stay within the plan’s no-helper-script boundary.
- Used the literal HexDocs URL in the workflow instead of an intermediate shell variable because the plan’s artifact contract and parity tests needed concrete string enforcement.
- Reused the existing Hex.pm propagation envelope (`DEADLINE=$(( SECONDS + 300 ))`, `sleep 15`) rather than inventing a new timeout policy.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Locked the workflow to the literal versioned HexDocs URL**
- **Found during:** Task 3 (Extend install-smoke parity tests to lock the probe in place)
- **Issue:** The initial probe used `URL="https://hexdocs.pm/rindle/$VERSION"` and then curled `"$URL"`, which satisfied behavior but weakened the plan’s literal artifact/parity contract.
- **Fix:** Replaced the shell variable usage with an inline `curl --fail --location --silent --show-error "https://hexdocs.pm/rindle/$VERSION"` command and added parity assertions for that exact snippet.
- **Files modified:** `.github/workflows/release.yml`, `test/install_smoke/package_metadata_test.exs`, `test/install_smoke/release_docs_parity_test.exs`
- **Verification:** `mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/package_metadata_test.exs`
- **Committed in:** `f6008ea` (workflow), `7409708` (tests)

---

**Total deviations:** 1 auto-fixed (`Rule 2`)
**Impact on plan:** Narrow correctness/parity fix only. No scope expansion beyond the release-contract files named in the plan.

## Issues Encountered

- The first RED attempt compiled with a malformed string-sigil assertion in `package_metadata_test.exs`; this was corrected immediately so the RED signal reflected the intended workflow mismatch instead of a syntax error.

## TDD Gate Compliance

- RED gate commit present: `7409708` (`test(21-01): add failing HexDocs probe parity coverage`)
- GREEN gate commit present: `f6008ea` (`feat(21-01): lock HexDocs probe workflow contract`)
- REFACTOR gate not needed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `VERIFY-02` is now enforced in the shipped release workflow and local install-smoke parity suite.
- Shared planning state files were intentionally left untouched for the orchestrator to update.

## Self-Check

PASSED

- Summary file exists: `.planning/phases/21-verify-02-hexdocs-reachability-probe/21-01-SUMMARY.md`
- Task commits verified: `44b8aa2`, `65ed318`, `7409708`, `f6008ea`

---
*Phase: 21-verify-02-hexdocs-reachability-probe*
*Completed: 2026-05-02*
