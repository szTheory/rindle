---
phase: 133-evidence-charter-and-live-truth
plan: "17"
subsystem: ci-evidence
tags: [github-actions, nightly, ffmpeg, immutable-evidence, dialyzer]
requires:
  - phase: 133-11
    provides: Strict exact-job Nightly summary verdict and supported Dialyzer proof
  - phase: 133-16
    provides: Schema-v2 immutable census and exact-subject live-truth authority
provides:
  - Reviewed post-repair evidence census bound to the exact implementation subject
  - Authenticated repository-owned FFmpeg release lookups in every static workflow caller
  - Fresh first-attempt exact-subject Nightly receipt with ten green declared jobs
affects: [phase-133-verification, phase-134, release-evidence, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
actuals:
  tokens: 11251
  tasks: 3
  commits: 8
tech-stack:
  added: []
  patterns:
    - Pass the least-privileged workflow token explicitly to repository-owned GitHub release API clients
    - Bind reviewed local authority and remote workflow evidence to separate immutable Git identities
key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - .github/workflows/nightly.yml
    - .github/workflows/release.yml
    - test/install_smoke/ci_cache_hygiene_test.exs
    - .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json
key-decisions:
  - "Authenticate every static FFmpeg release lookup with github.token so shared-runner API quotas cannot produce compatibility-only 403 failures."
  - "Preserve each failed or superseded evidence ref and run unchanged; corrections always receive a new subject-derived non-force ref."
  - "Count publication approval only as authorization; requirements close from the reconstructed schema-v2 receipt and ordered automated gates."
patterns-established:
  - "Workflow caller contract: every static install_ffmpeg.sh step maps GITHUB_TOKEN from github.token."
  - "Corrective evidence cycle: repair, regress, rebind census, prove ref absence, publish once, and independently verify the resulting run."
requirements-completed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: "The reviewed twelve-dimension census is canonical and bound to the exact repaired implementation subject through an immutable ledger commit and blob."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "detached-subject evidence_census.exs collection plus validate_evidence_census.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "A fresh first-attempt supported Nightly run proves both fresh and restored Dialyzer paths for the exact published subject."
    requirement: EVID-02
    verification:
      - kind: e2e
        ref: "GitHub Actions Nightly run 34550391882 attempt 1"
        status: pass
      - kind: integration
        ref: "bash scripts/ci/verify_nightly_run.sh verify-receipt"
        status: pass
    human_judgment: false
  - id: D3
    description: "The schema-v2 receipt records the exact declared ten-job set and a strict green Nightly Summary verdict."
    requirement: EVID-03
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_nightly_summary_gate.sh and bash scripts/ci/test_verify_nightly_run.sh"
        status: pass
    human_judgment: false
  - id: D4
    description: "Diagnostic evidence collection preserved byte-identical incident snapshots and accepted no duplicate post-boundary runs."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_nightly_incident.sh and receipt incident snapshot equality"
        status: pass
    human_judgment: false
  - id: D5
    description: "Final local package, release, required-check, adoption, and exact-subject live-truth authority passed in the declared order."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "focused authority chain, mix ci, refactor_contract.sh, exact receipt verification, automation_first_contract.sh"
        status: pass
    human_judgment: false
duration: 3h15m
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 17: Repaired Exact-Subject Nightly Evidence Summary

**An authenticated FFmpeg lookup path and immutable schema-v2 receipt now prove the repaired subject through a first-attempt ten-job green Nightly run with fresh and restored Dialyzer evidence.**

## Performance

- **Duration:** 3h 15m
- **Started:** 2026-09-10T22:16:11Z
- **Completed:** 2026-09-11T01:31:13Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments

- Froze and repeatedly validated the reviewed Phase 133 census while preserving stable candidate identities and explicit reconciliation transitions.
- Made every static CI, Nightly, and release FFmpeg installer caller authenticate GitHub release metadata lookups, with a parsed-workflow regression covering all seven call sites.
- Published exact subject `08d2f4f55fb2f59319a371de56606b2e925e6d54` once to `phase-133-evidence-08d2f4f55fb2` and recorded successful first attempt Nightly run `34550391882`.
- Replaced the stale receipt with schema version 2 authority for ten green jobs, fresh/restored Dialyzer, immutable census commit `1fd1cf5ba0ceae3cb57a4b6cda1312819a84a255`, and unchanged incident snapshots.

## Task Commits

1. **Task 1: align required-check authority regression** - `625efdf` (fix)
2. **Task 1: restore census test quality baseline** - `fbae64c` (refactor)
3. **Task 1: freeze post-repair evidence census** - `6d3a7bb` (feat)
4. **Task 3: format the reconciliation contract after the first rejected receipt** - `03576aa` (style)
5. **Task 3: rebind the census to the formatted subject** - `dff7195` (fix)
6. **Task 3: authenticate FFmpeg release lookups** - `08d2f4f` (fix)
7. **Task 3: rebind the census to the FFmpeg-repaired subject** - `1fd1cf5` (fix)
8. **Task 3: record the accepted exact-subject Nightly receipt** - `7901140` (feat)

Task 2 was a blocking authorization checkpoint and produced no local commit. Its approval authorized publication only and satisfied no requirement.

## Files Created/Modified

- `.github/workflows/ci.yml` - Supplies the read-only workflow token to five static FFmpeg installer calls.
- `.github/workflows/nightly.yml` - Supplies the workflow token to the compatibility-matrix FFmpeg installer.
- `.github/workflows/release.yml` - Supplies the workflow token to the release dry-run FFmpeg installer.
- `test/install_smoke/ci_cache_hygiene_test.exs` - Parses each workflow and rejects unauthenticated static FFmpeg installer calls.
- `test/install_smoke/ci_lane_split_test.exs` - Aligns required-check regression assertions with policy authority.
- `test/install_smoke/evidence_census_test.exs` - Restores canonical census test quality.
- `test/install_smoke/phase_133_reconciliation_test.exs` - Formats and strengthens the reconciliation contract.
- `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json` - Binds the reviewed census to the repaired exact subject.
- `.planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json` - Stores the accepted schema-v2 run, job, Dialyzer, incident, census, and live-truth authority.

## Decisions Made

- Static FFmpeg installer calls receive `${{ github.token }}` explicitly because the installer already scopes that credential to GitHub release metadata requests and workflow permissions remain `contents: read`.
- Failed and superseded evidence identities remain immutable: `phase-133-evidence-fbae64c0c67e` and `phase-133-evidence-03576aacbb41` were neither rewritten nor relabeled.
- The accepted receipt retains its tested implementation subject rather than substituting the later ledger or receipt commit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Formatted the reconciliation contract before accepting evidence**

- **Found during:** Task 3, after otherwise successful run `34537486230`
- **Issue:** The repository-wide `mix ci` formatting gate rejected the reconciliation test, so the successful remote run could not become accepted evidence.
- **Fix:** Applied canonical formatting, strengthened the reconciliation assertions, and rebound the census to the resulting subject.
- **Files modified:** `test/install_smoke/phase_133_reconciliation_test.exs`, `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json`
- **Verification:** Focused reconciliation tests and the ordered repository gates passed before the next dispatch.
- **Committed in:** `03576aa`, `dff7195`

**2. [Rule 1 - Bug] Authenticated FFmpeg GitHub release metadata lookups**

- **Found during:** Task 3, replacement run `34543670960`
- **Issue:** Six `403` responses in the Elixir 1.18 / OTP 28 compatibility cell exposed that workflow callers did not map `github.token` into the installer process, leaving shared runners on unauthenticated API quota.
- **Fix:** Passed `GITHUB_TOKEN: ${{ github.token }}` to all seven static workflow call sites and added parsed-YAML regression coverage requiring the mapping.
- **Files modified:** `.github/workflows/ci.yml`, `.github/workflows/nightly.yml`, `.github/workflows/release.yml`, `test/install_smoke/ci_cache_hygiene_test.exs`
- **Verification:** The regression failed before the fix and passed 19/19 afterward; replacement Nightly run `34550391882` passed every FFmpeg install step and all ten declared jobs.
- **Committed in:** `08d2f4f`, `1fd1cf5`, `7901140`

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes were necessary to make the declared acceptance gates truthful. They preserved the exact-subject and immutable-ref design without expanding product scope.

## Issues Encountered

- The focused package-authority gate initially found no local MinIO service. A scoped Docker MinIO container provided the required test dependency, after which the entire focused chain was rerun from its first command and passed.
- One malformed local push refspec was rejected by Git before contacting the remote. Ref absence was independently re-proved immediately afterward, and the corrected exact refspec performed the sole successful non-force publication.
- Compatibility run `34543670960` failed before the accepted run and remains preserved. The two advisory MuonTrap canary annotations in the accepted run were non-gating by established policy; every declared job remained green.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: credential-scope | `.github/workflows/ci.yml`, `.github/workflows/nightly.yml`, `.github/workflows/release.yml` | The read-only workflow token now enters the repository-owned FFmpeg installer process; the script confines it to GitHub release metadata requests and regression coverage requires the explicit mapping. |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 133 now has a current, independently reconstructed exact-subject baseline for cleanup work in Phases 134-136.
- No Plan 133-17 blockers or goal-preventing stubs remain. Existing dependency advisories remain owned by Phase 134 rather than this evidence-collection plan.

## Self-Check: PASSED

- All nine changed production, test, and evidence files exist.
- All eight task commits resolve in repository history.
- Receipt schema, exact subject/ref, first-attempt run identity, strict verdict, ten-job set, immutable census object, and fresh/restored Dialyzer authority revalidated after the final artifact write.
- Coverage metadata classifies every deliverable as automated and passing.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
