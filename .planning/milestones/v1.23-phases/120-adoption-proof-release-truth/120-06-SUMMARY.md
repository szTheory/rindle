---
phase: 120-adoption-proof-release-truth
plan: 06
subsystem: release-documentation
tags: [release-please, changelog, release-signoff, docs-parity, package-consumer, cohort]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: packed install, public compatibility, Cohort, and operational-upgrade proof surfaces
  - phase: 118-isolated-migration-safe-upgrade
    provides: host-owned public-to-rindle migration and guarded reverse procedure
  - phase: 119-ownership-boundaries-diagnostics
    provides: separate Rindle and host-owned Oban ownership/diagnostic boundaries
provides:
  - Release Please-compatible staged 0.4.0 breaking-change notes
  - Exact-SHA maintainer signoff chain for package, demo, Cohort, packed, and public proof
  - Manifest-aware parity contracts for the staging-marker promotion
affects: [release-please, release-workflow, docs-parity, 0.4.0-release]
tech-stack:
  added: []
  patterns:
    - Manifest-aware parity distinguishes a pre-release staging block from Release Please's generated final heading.
    - Release guidance separates diagnostic checkout commands from authoritative exact-SHA packaged CI evidence.
key-files:
  created:
    - .planning/phases/120-adoption-proof-release-truth/120-06-SUMMARY.md
  modified:
    - CHANGELOG.md
    - guides/release_publish.md
    - test/install_smoke/release_docs_parity_test.exs
key-decisions:
  - "While the manifest remains 0.3.2, one Unreleased / 0.4.0 marker stages the breaking notes; Release Please must promote its content into [0.4.0] and remove the marker."
  - "Local docs, image-package, and Cohort checks diagnose readiness, while a green exact-SHA CI run plus Release workflow gates authorizes publication."
patterns-established:
  - "Release-facing parity tests read live workflow files so maintained job and step names cannot drift."
requirements-completed: [PROOF-01, PROOF-02, DOCS-01]
coverage:
  - id: D1
    description: "0.4.0 breaking-change notes retain default-schema, public-compatibility, ownership, maintenance, and guarded-rollback truth through Release Please promotion."
    requirement: DOCS-01
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Maintainer release signoff names the live proof, package-consumer, adoption-demo, Cohort, preflight, and public-artifact gates without turning local checks into authority."
    requirement: PROOF-01
    verification:
      - kind: unit
        ref: "test/install_smoke/release_docs_parity_test.exs#0.4.0 schema-isolation signoff names local diagnostics and exact-SHA evidence"
        status: pass
    human_judgment: false
  - id: D3
    description: "Packed and Cohort schema-isolation evidence is available to a release maintainer."
    requirement: PROOF-02
    verification:
      - kind: integration
        ref: "Phase 120 full evidence sequence"
        status: unknown
    human_judgment: true
    rationale: "The shared dirty workspace blocked or detached broad verification receipts; release authority remains the exact-SHA GitHub Actions run."
duration: 4h 18m
completed: 2026-08-10
status: complete
---

# Phase 120 Plan 06: Release Truth and Exact-SHA Signoff Summary

**Release Please-compatible 0.4.0 schema-isolation notes and a parity-locked maintainer chain now connect local diagnosis to exact-SHA package, demo, Cohort, preflight, and public-artifact release proof.**

## Performance

- **Duration:** 4h 18m
- **Started:** 2026-08-10T17:08:59Z
- **Completed:** 2026-08-10T21:26:26Z
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Staged a single Release Please-compatible `## Unreleased / 0.4.0` note that explains the breaking `rindle` default, explicit public pairing, host migration ownership, maintenance limits, guarded rollback, and separate Oban/ledger ownership.
- Added manifest-aware release parity that requires the staged marker at manifest 0.3.2, then requires generated `[0.4.0]` notes and rejects the stale marker after promotion.
- Added a compact schema-isolation signoff section that preserves exact-SHA CI authority while naming the live Proof, Package Consumer, Adoption Demo, Cohort, preflight, version, dry-run, and public-artifact gates.

## Task Commits

1. **Task 1: Stage one Release Please-compatible 0.4.0 breaking-change note**
   - `c1640cc` test: added the manifest-aware release-note parity contract
   - `91e1812` docs: staged truthful 0.4.0 breaking-change notes
2. **Task 2: Bind maintainer signoff to packed, demo, docs, and exact-SHA evidence**
   - `c9d8a1a` test: locked live local-diagnostic, CI-job, and promotion-review evidence
   - `eb792d2` docs: documented the exact-SHA schema-isolation signoff chain
   - `b732ee8` style: formatted the release parity contract for the repository formatter

## Files Created/Modified

- `CHANGELOG.md` — staged 0.4.0 breaking schema-isolation notes for Release Please promotion.
- `guides/release_publish.md` — local diagnostic sequence, Cohort boot assertion, promotion review, and authoritative exact-SHA evidence chain.
- `test/install_smoke/release_docs_parity_test.exs` — manifest-aware changelog and live-workflow release-signoff contracts.

## Decisions Made

- Release Please remains the only authority for final version, tag, and generated changelog heading; this plan never mutates the manifest or package version.
- The Cohort cold-start command proves its boot/schema path locally, but only the matching exact-SHA GitHub Actions result participates in release authorization.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Formatting] Formatted the modified release parity test**
- **Found during:** Task 2
- **Issue:** `mix ci` rejected a formatter drift in `release_docs_parity_test.exs` after the new contract was added.
- **Fix:** Ran the repository formatter on the task-owned test file.
- **Files modified:** `test/install_smoke/release_docs_parity_test.exs`
- **Verification:** Focused docs/release parity suite passed with 56 tests, 0 failures.
- **Committed in:** `b732ee8`

**Total deviations:** 1 auto-fixed (Rule 1 - formatting).
**Impact on plan:** No scope expansion; the task-owned test now satisfies the repository formatter.

## Issues Encountered

- `bash scripts/maintainer/check_docs_links.sh` reported 45 existing planning-artifact findings across unrelated guides and `RUNNING.md`; the Task 2 release guide did not introduce a link failure.
- `cd examples/adoption_demo && mix precommit` failed its inherited schema-fixture assertion because `public.media_assets` already existed in the shared database; the plan explicitly identifies this dirty-workspace condition and no fixture or unrelated source was changed.
- `mix ci` stopped at an unrelated formatting drift in `test/install_smoke/docs_parity_test.exs`; the plan-owned parity test was formatted and its focused suite passed.
- The packed image smoke and both focused generated-app commands were started and completed in the execution environment, but its detached runner did not return final exit receipts. The Cohort Docker smoke likewise yielded during image build without a final receipt. Exact-SHA GitHub Actions remains the authoritative release proof.

## Known Stubs

None.

## Next Phase Readiness

- The 0.4.0 release PR can now promote the staged changelog text into generated `[0.4.0]` notes and remove the staging marker under a parity contract.
- A release maintainer must obtain the exact-SHA CI and Release workflow evidence before publication; the current shared workspace failures do not change that requirement.

## Self-Check: PASSED

- Confirmed `CHANGELOG.md`, `guides/release_publish.md`, and `test/install_smoke/release_docs_parity_test.exs` exist.
- Confirmed task commits `c1640cc`, `91e1812`, `c9d8a1a`, `eb792d2`, and `b732ee8` exist in git history.
- Final focused verification passed: 56 tests, 0 failures.

---
*Phase: 120-adoption-proof-release-truth*
*Completed: 2026-08-10*
