---
phase: 120-adoption-proof-release-truth
plan: 13
subsystem: release-proof
tags: [release-please, release-intent, docs-parity, 0.4.0]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: exact-SHA release proof and 0.4.0 staging contract
provides:
  - explicit Release Please 0.4.0 intent procedure
  - regression coverage that blocks the 0.3.3 candidate
affects: [release-train, maintainer-docs, release-docs-parity]
tech-stack:
  added: []
  patterns: [Release-As footer, manifest-aware release parity, automation-owned generated files]
key-files:
  created:
    - .planning/phases/120-adoption-proof-release-truth/120-13-SUMMARY.md
  modified:
    - guides/release_publish.md
    - test/install_smoke/release_docs_parity_test.exs
decisions:
  - "Use the supported Release-As: 0.4.0 commit footer to override the retained pre-major patch behavior; Release Please remains owner of generated version and release artifacts."
metrics:
  completed: 2026-08-19
  tasks: 1
  files: 3
status: complete
---

# Phase 120 Plan 13: Explicit 0.4.0 Release Intent Summary

**The breaking schema-isolation release now requires a `Release-As: 0.4.0` intent footer, blocks the observed 0.3.3 candidate, and preserves Release Please ownership of generated release state.**

## Accomplishments

- Added a failing-first parity contract requiring the explicit 0.4.0 intent, the blocked 0.3.3 candidate, and automation ownership of version artifacts.
- Documented the ordinary PR-first release-intent procedure in the maintained 0.4.0 signoff runbook.
- Kept the manifest-aware `0.3.2` staging / generated `0.4.0` release-note state machine intact.

## Files Created/Modified

- `guides/release_publish.md` — adds the explicit pre-1.0 breaking-release procedure and rejects PR #59's 0.3.3 candidate.
- `test/install_smoke/release_docs_parity_test.exs` — locks the release-intent documentation contract.
- `.planning/phases/120-adoption-proof-release-truth/120-13-SUMMARY.md` — records the plan outcome.

## Verification

- `mix test test/install_smoke/release_docs_parity_test.exs test/install_smoke/docs_parity_test.exs --seed 0` — passed: 57 tests, 0 failures.
- The final release-intent commit is required to expose `Release-As: 0.4.0` as its exact final body line.
- Repository hygiene is run against the final branch snapshot from an independent clone to avoid shared-ref contamination.

## Decisions Made

- Retain `bump-patch-for-minor-pre-major`; this breaking milestone provides its version intent through the supported `Release-As` footer instead of editing generated files.
- Keep the 0.3.3 Release Please candidate blocked until Release Please regenerates an explicitly requested 0.4.0 candidate.

## Deviations from Plan

None - plan executed as written. The hygiene gate is deliberately evaluated in an independent clone because the primary shared checkout is user-owned and locally divergent.

## Known Stubs

None.

## Threat Flags

None. This plan changes no runtime trust boundary; its commit metadata and parity test protect the release-intent boundary described in the plan.

## Self-Check: PASSED

- RED commit `be3bbae` exists and contains only the failing release-parity test.
- The guide's 0.4.0 signoff insertion is scoped before the existing token-rotation section, which remains unchanged from the worktree base.
