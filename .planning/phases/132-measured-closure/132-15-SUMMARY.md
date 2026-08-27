---
phase: 132-measured-closure
plan: 15
subsystem: ci-preservation-evidence
tags: [github-actions, provenance, coverage, preflight, packed-consumer]
dependency_graph:
  requires: [132-12, 132-13, 132-14]
  provides: [post-repair immutable subject, schema-v2 transition manifest, mutation-free timing preflight]
  affects: [132-16 terminal timing receipt, CI-14, COV-05, SAFE-02]
tech_stack:
  added: []
  patterns: [Git-reproduced preservation manifests, inclusive integer coverage validation, snapshot-equality no-publish preflight]
key_files:
  created: []
  modified:
    - .planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md
decisions:
  - "The Plan 132-12, 132-13, and 132-14 repair ranges are three distinct contiguous stages; planning evidence and executable target blobs are recorded separately."
  - "A strict-ancestor no-publish preflight is sufficient to authorize only the bounded terminal sampler; it cannot close CI-14."
metrics:
  duration: "~9 minutes"
  completed_date: "2026-08-27"
status: complete
---

# Phase 132 Plan 15: Post-repair preservation Summary

The repaired timing controller subject is now bound to a Git-reproducible three-stage manifest, fresh COV-05/SAFE-02 authorities, and a mutation-free terminal-sampler preflight.

## Tasks Completed

1. Re-censused the immutable repaired subject from Git; recorded its schema-v2 transition manifest, positive-denominator coverage evidence, packed image-consumer proof, and no-publish preflight receipt.

## Verification

- `mix format --check-formatted` — passed.
- `mix test test/install_smoke/ci_timing_automation_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0` — passed (52 tests).
- `bash scripts/ci/test_ci_summary_gate.sh` — passed (6 cases).
- `mix quality_signals`, `bash scripts/maintainer/refactor_contract.sh`, `./scripts/maintainer/automation_first_contract.sh`, and `./scripts/maintainer/repo_hygiene_check.sh --ci` — passed.
- One `mix coveralls.multiple --type local --type json` authority — passed; structural parsing found 5,149 covered of 6,269 relevant lines and passed the inclusive 82.13% floor.
- `bash scripts/install_smoke.sh image` — passed.
- `collect_pr_timing_receipt.sh preflight --no-publish` — passed with PR #96's remote head as a strict ancestor of the repaired subject; before/after PR, workflow, receipt, marker, state, and lock snapshots matched.
- `git diff --check` — passed.

## Task Commit

1. **Task 1: Re-census and preflight the post-repair immutable subject** — `99c9fd6` (docs)

## Files Modified

- `.planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md` — three-stage Git/blob manifest, fresh preservation receipt, and immutable no-publish preflight evidence.

## Decisions Made

- The completed Plan 132-12 boundary is `1671cdd`, the formatter tracking boundary is `214e56c`, and the repaired preserved subject is `73e2c33`; their manifest stages are contiguous and independently reproducible.
- CI-14 remains open. Only Plan 132-16's API-backed exact-ten receipt may close it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Receipt formatting] Removed trailing whitespace from the preservation anchor lines.**
- **Found during:** Task 1
- **Issue:** `git diff --check` reported trailing whitespace in the new receipt section.
- **Fix:** Normalized the Markdown anchor lines before the task commit.
- **Files modified:** `.planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md`
- **Verification:** `git diff --check` passed.
- **Committed in:** `99c9fd6`

**Total deviations:** 1 auto-fixed (Rule 1: 1).
**Impact:** Formatting-only; no evidence, chronology, or product surface changed.

## Known Stubs

None.

## Threat Flags

None — this plan added planning evidence only and introduced no network endpoint, auth path, file access pattern, or trust-boundary implementation.

## Next Phase Readiness

Plan 132-16 may consume the exact manifest and preserved SHA for bounded terminal sampling. It must retain the exact-ten, two-sequence, inclusive 480/600 identity and cannot treat this local preservation evidence as CI-14 closure.

## Self-Check: PASSED

- Confirmed the preservation receipt and this summary exist.
- Confirmed task commit `99c9fd6` exists in Git history.
- Confirmed the schema-v2 manifest has one begin/end pair and the repaired subject SHA matched HEAD during preflight.
