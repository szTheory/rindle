---
phase: 120-adoption-proof-release-truth
plan: 10
subsystem: install-smoke
tags: [elixir, postgresql, package-consumer, migration, proof]
requires:
  - phase: 120-adoption-proof-release-truth
    provides: exact Rindle marker, foreign-key, named-index, and public Oban catalog snapshot evidence
provides:
  - snapshot-only public.oban_jobs preservation reports
  - a regression rejecting the obsolete provenance-derived ownership field
affects: [package-consumer, upgrade-proof, release-proof]
tech-stack:
  added: []
  patterns: [exact before-after catalog equality, source-level report contract regression]
key-files:
  created:
    - .planning/phases/120-adoption-proof-release-truth/120-10-SUMMARY.md
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
key-decisions:
  - "Generated reports no longer project host migration provenance as Oban evidence; complete catalog snapshot equality is the sole preservation decision."
requirements-completed: [PROOF-01]
coverage:
  - id: D1
    description: "Generated-app reports reject the obsolete Oban ownership predicate and preserve the complete public.oban_jobs snapshot contract."
    requirement: PROOF-01
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0"
        status: pass
    human_judgment: false
metrics:
  duration: 8m
  completed: 2026-08-10
  tasks: 1
  files: 2
status: complete
---

# Phase 120 Plan 10: Snapshot-Only Oban Proof Summary

**Generated-app release reports now prove the host-owned public Oban boundary solely through exact, complete before/after catalog snapshots.**

## Accomplishments

- Removed both default and historical generated-report projections that consumed `rindle_created_oban_jobs` from migration JSON.
- Added a focused `phase_120_upgrade_contract` source regression that rejects reintroducing the obsolete field and requires both Oban snapshots plus equality.
- Retained the existing exact marker `[1]`, named foreign key, three named-index, and damaged-Oban-snapshot regression coverage.

## Task Commits

1. **Task 1 / RED: Lock snapshot-only Oban evidence** — `9f94c01`
2. **Task 1 / GREEN: Remove obsolete Oban report predicate** — `67bfb5e`

## Verification

- `mix format --check-formatted test/install_smoke/support/generated_app_helper.ex test/install_smoke/generated_app_smoke_test.exs` — passed.
- `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` — passed (8 tests, 0 failures).
- `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_fast_contract --seed 0` — passed (11 tests, 0 failures).
- `! rg -n 'rindle_created_oban_jobs' test/install_smoke/support/generated_app_helper.ex` — passed; no helper report path projects or consumes the obsolete field.

## Decisions Made

- The host Oban boundary is release evidence only when the populated, normalized `public.oban_jobs` snapshots are non-empty and exactly equal; host-migration provenance remains outside report projections.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None - this plan removes an internal report field and adds a repository source-contract regression; it introduces no new endpoint, auth path, file-access pattern, or schema change.

## Next Phase Readiness

Plan 120-11 can rerun the clean packed/Cohort proof with the snapshot-only report contract.

## Self-Check: PASSED

- Both modified install-smoke files exist.
- Commits `9f94c01` and `67bfb5e` exist in git history.
