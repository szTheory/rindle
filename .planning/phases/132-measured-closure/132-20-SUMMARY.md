---
phase: 132-measured-closure
plan: 20
subsystem: ci-timing-preservation
tags: [github-actions, preservation, coverage, no-publish, ci-14]
dependency_graph:
  requires: [132-19]
  provides: [repaired-source-preservation, mutation-free-publication-preflight]
  affects: [132-21, CI-14, COV-05, SAFE-02]
tech_stack:
  added: []
  patterns: [git-reproduced-transition-manifest, snapshot-equality-preflight]
key_files:
  created: [".planning/phases/132-measured-closure/132-20-SUMMARY.md"]
  modified: [".planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md"]
key_decisions:
  - "The active preservation subject is Plan 132-19 source commit a4bbbd1, while the validator-required stage identity remains plan-132-14-repair."
  - "Plan 132-21 alone may consume the no-publish preflight for live timing mutation."
requirements-completed: []
coverage:
  - id: D1
    description: "Git-reproduced preservation authority for the repaired timing controller."
    verification:
      - kind: integration
        ref: "mix coveralls.multiple --type local --type json; scripts/install_smoke.sh image"
        status: pass
    human_judgment: false
  - id: D2
    description: "No-publish publication-readiness preflight with remote and local snapshot equality."
    verification:
      - kind: integration
        ref: "scripts/ci/collect_pr_timing_receipt.sh preflight --no-publish"
        status: pass
    human_judgment: false
metrics:
  duration: "~25m"
  completed_date: "2026-08-27"
status: complete
---

# Phase 132 Plan 20: Repaired-source preservation census Summary

The Plan 132-19 controller subject is preserved by fresh coverage, quality, packed-consumer, bounded-drift, and zero-mutation preflight evidence.

## Tasks Completed

1. Bound the active schema-v2 manifest to `a4bbbd1bba6077134934a4e6b9a9bf63924b47e9`, retained historical stages, and recorded fresh preservation authorities.
2. Ran the controller in `preflight --no-publish` mode and persisted an independently comparable before/after snapshot record.

## Verification

- `mix format --check-formatted`
- Focused timing-controller, lane-split, and observability tests: 18/0 and 34/0
- `bash scripts/ci/test_ci_summary_gate.sh`, `mix quality_signals`, SAFE-01, automation-first, and repository hygiene
- One `mix coveralls.multiple --type local --type json`: 5149/6269 relevant lines, inclusive 82.13% integer floor passed
- `bash scripts/install_smoke.sh image` and `git diff --check`
- Machine-only controller preflight: remote PR head, labels, exact-head run IDs, timing receipt identity, state, and lock all unchanged

## Task Commits

1. Task 1 — `d13cada` `docs(132-20): preserve repaired controller subject`
2. Task 2 — `1c38281` `docs(132-20): record mutation-free timing preflight`

## Decisions Made

- Preserve the validator's fixed third-stage identifier while binding it to the new Plan 132-19 subject.
- Leave CI-14 open; only Plan 132-21 is authorized to collect fresh live timing evidence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored the validator-required third-stage identifier**
- **Found during:** Task 2 preflight
- **Issue:** The semantic `plan-132-19-repair` identifier did not satisfy the shipped controller's fixed schema-v2 contract.
- **Fix:** Restored `plan-132-14-repair` while retaining the Git-derived Plan 132-19 source commit and exact stage delta.
- **Files modified:** `.planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md`
- **Verification:** Mutation-free preflight reparsed and Git-reproduced the manifest successfully.
- **Committed in:** `1c38281`

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed the preservation receipt and this summary exist.
- Confirmed task commits `d13cada` and `1c38281` exist in Git history.

## Next Phase Readiness

Plan 132-21 has a fresh machine-green preflight and may collect the bounded live exact-ten receipt. No human UAT artifact was created.
