---
phase: 133-evidence-charter-and-live-truth
plan: "07"
subsystem: ci-evidence
tags: [github-actions, nightly, dialyzer, exact-sha, evidence]
requires:
  - phase: 133-06
    provides: committed twelve-dimension census ledger bound to subject 4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2
provides:
  - Fixture-proven exact-run GitHub CLI collector
  - Canonical first-attempt Nightly receipt for the committed Phase 133 subject
  - Supported Elixir 1.17 / OTP 27 fresh and restored Dialyzer authority
affects: [phase-133-verification, phase-134, release-evidence]
actuals:
  tokens: 10986
  tasks: 3
  commits: 4
tech-stack:
  added: []
  patterns:
    - Exact remote ref and workflow identity preflight before dispatch
    - Job-scoped GitHub Actions log evidence instead of whole-run log inference
    - Receipt commits preserve the earlier tested implementation SHA
key-files:
  created:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json
  modified: []
key-decisions:
  - "Read supported toolchain/cache markers only from the exact Dialyzer job and strict verdict evidence only from Nightly Summary."
  - "Accept GitHub's expanded `test \"green\" = \"green\"` enforcement line because writes to GITHUB_OUTPUT are masked from logs."
  - "Keep receipt subject_sha at 4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2 rather than relabeling the later receipt commit."
duration: 62min
completed: 2026-09-09
status: complete
---

# Phase 133 Plan 07: Exact-Subject Nightly Evidence Summary

**One authorized exact-SHA publication produced a machine-validated first-attempt Nightly receipt with supported fresh/restored Dialyzer, strict green aggregation, and diagnostic incident nonmutation.**

## Performance

- **Duration:** 62 min
- **Started:** 2026-09-10T02:25:42Z
- **Completed:** 2026-09-10T03:27:42Z
- **Tasks:** 3
- **Files created/modified:** 3

## Accomplishments

- Added a 28-case fake-`gh` matrix covering exact success plus foreign repository/workflow/ref/SHA, rerun, partial job/mode, red/nonterminal, timeout/API, local-authority, cache, strict-verdict, and incident-mutation failures.
- Published subject `4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2` once, without force, to `phase-133-evidence-4f83e153eb7e`, then proved the ref independently and through collector preflight.
- Validated the census and live-truth authorities from a clean detached worktree at the exact subject SHA.
- Recorded GitHub Actions run `34432289094`, attempt 1, with all ten declared jobs successful.
- Bound resolved Elixir `v1.17.3-otp-27`, OTP `OTP-27.3.4.17`, one fresh PLT build/analysis, one restored analysis, exact cache identity, zero stale rebuilds, and a green strict verdict into the canonical receipt.
- Proved the open `nightly-failure` issue set was unchanged across the diagnostic dispatch; the workflow performed no issue mutation.

## Task Commits

1. **Task 1 RED: add failing exact-run collector matrix** - `f9c4ffd` (test)
2. **Task 1 GREEN: verify exact diagnostic Nightly runs** - `ef864a2` (feat)
3. **Task 3 deviation: scope live evidence logs by job** - `a2dbeaf` (fix)
4. **Task 3: record exact-subject Nightly evidence** - `625b7d3` (test)

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` - Exact repository/workflow/ref/SHA preflight, bounded dispatch selection, job-scoped evidence validation, incident comparison, and canonical receipt verification.
- `scripts/ci/test_verify_nightly_run.sh` - Deterministic 28-case fake GitHub matrix and remote-mutation argv guard.
- `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json` - Canonical accepted receipt for run `34432289094` and subject `4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2`.

## Decisions Made

- Whole-run logs are not a valid source for supported toolchain identity because compatibility jobs emit other Elixir/OTP versions; evidence queries use exact validated job IDs.
- GitHub masks values written to `$GITHUB_OUTPUT`, so strict green evidence is the expression-expanded enforcement command together with the successful exact `Nightly Summary` job.
- The receipt commit is evidence about the earlier census-bound implementation subject and never becomes the tested subject itself.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Scoped live evidence extraction to exact job IDs**

- **Found during:** Task 3 live run validation
- **Issue:** Whole-run logs contained setup output from all compatibility cells, making resolved Elixir/OTP evidence ambiguous even though the supported Dialyzer job was green.
- **Fix:** Resolve the validated `Dialyzer` and `Nightly Summary` job IDs and fetch only their logs; extend the fake argv contract to require job-scoped reads.
- **Files modified:** `scripts/ci/verify_nightly_run.sh`, `scripts/ci/test_verify_nightly_run.sh`
- **Commit:** `a2dbeaf`

**2. [Rule 1 - Bug] Matched strict-verdict parsing to GitHub's masked output behavior**

- **Found during:** Task 3 inspection of the successful live run
- **Issue:** The fixture printed `verdict=green`, but GitHub masks `$GITHUB_OUTPUT` writes and exposes the resolved value in `test "green" = "green"` instead.
- **Fix:** Accept the bounded expanded enforcement marker from the exact successful `Nightly Summary` job and update the fixture to reproduce real logs.
- **Files modified:** `scripts/ci/verify_nightly_run.sh`, `scripts/ci/test_verify_nightly_run.sh`
- **Commit:** `a2dbeaf`

**3. [Rule 3 - Blocking] Reconstructed the captured pre-run incident snapshot after fail-closed parsing**

- **Found during:** Task 3 receipt recovery after the successful run
- **Issue:** The collector captured the pre-run snapshot in memory, then correctly exited before writing a receipt when toolchain parsing was ambiguous.
- **Fix:** Queried all `nightly-failure` issues and proved every creation/update/closure timestamp preceded the run boundary, then re-read the unchanged open exact-label set for both canonical snapshots. No second dispatch was performed.
- **Files modified:** `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json`
- **Commit:** `625b7d3`

---

**Total deviations:** 3 auto-fixed blocking/live-evidence issues
**Impact on plan:** The fixes made collection match real GitHub log semantics without broadening remote permissions, dispatching again, mutating issues, or changing the tested subject.

## Authentication Gates

- GitHub CLI authentication was valid and the authorized push/dispatch completed normally.
- Local Hex printed an expired-session warning, but all dependencies were public and fetched successfully; no credential was required for the local authority gates.

## Verification

- `bash scripts/ci/test_verify_nightly_run.sh` - 28 passed, 0 failed.
- Detached exact-subject census collector/validator and live-truth validator - passed; derived-authority suite reported 6 tests, 0 failures.
- Exact remote ref/SHA comparison plus collector `preflight` - passed.
- Collector `verify-receipt` against live run `34432289094` - passed.
- `mix ci` on installed diagnostic Elixir 1.19.5 / OTP 28.4.1 - passed; 1,460 tests, 0 failures, 4 excluded.
- `bash scripts/maintainer/refactor_contract.sh` - 97 contract tests, 0 failures.
- `./scripts/maintainer/automation_first_contract.sh` - passed.
- Clean detached `./scripts/maintainer/repo_hygiene_check.sh` - 11 PASS, 1 divergence warning, 0 BLOCK.

## Known Stubs

None. Empty shell variables in the collector are argument-parser initialization, not user-facing or acceptance stubs.

## Self-Check: PASSED

- All three planned artifacts exist.
- All four task commits exist.
- The receipt independently validates against the exact remote ref and live GitHub run.
