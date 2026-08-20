---
phase: 120-adoption-proof-release-truth
plan: 01
subsystem: testing
tags: [elixir, ecto, postgres, phoenix, package-consumer, install-smoke]
requires:
  - phase: 118-isolated-migration-safe-upgrade
    provides: default rindle schema migration API and fixed owned-relation catalog
  - phase: 119-ownership-boundaries-diagnostics
    provides: independent Rindle and Oban ownership boundaries
provides:
  - Packed generated-app proof with schema-qualified default-install evidence
  - JSON-safe persistence lifecycle evidence from the generated consumer
affects: [package-consumer, release-proof, phase-120]
tech-stack:
  added: []
  patterns: [generated-app fact report, schema-qualified PostgreSQL catalog proof]
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
key-decisions:
  - "Derive the fixed Rindle relation catalog from Rindle.Migration.V1.owned_relations/0 rather than duplicating it in the proof harness."
  - "Generate facts in the consumer and enforce release policy in repository-side ExUnit assertions."
patterns-established:
  - "Default package proofs report selected-schema, decoy-schema, and host-owned public relations independently."
  - "Generated persistence proofs return JSON-safe identifiers and read-back facts to the repository test."
requirements-completed: [PROOF-01, PROOF-02]
coverage:
  - id: D1
    description: Packed default install proves Rindle relations are in rindle, absent from public, and host Oban/ledger relations remain public.
    requirement: PROOF-01
    verification:
      - kind: unit
        ref: mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_fast_contract --seed 0
        status: pass
      - kind: integration
        ref: bash scripts/install_smoke.sh image
        status: pass
    human_judgment: false
  - id: D2
    description: Generated packed consumer completes a public Rindle facade lifecycle and reports a persistence read-back.
    requirement: PROOF-02
    verification:
      - kind: unit
        ref: mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_fast_contract --seed 0
        status: pass
      - kind: integration
        ref: bash scripts/install_smoke.sh image
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-08-10
status: complete
---

# Phase 120 Plan 01: Packed Default Install Proof Summary

**Packed Phoenix consumers now prove default `rindle` ownership, public host infrastructure, and a real Rindle persistence read-back.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-10T03:43:10Z
- **Completed:** 2026-08-10T03:47:22Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Added a fast source/report contract that locks separate host Oban and default Rindle migrations plus the required proof facts.
- Replaced the public-only catalog observation with fixed, schema-qualified Rindle ownership checks derived from `Rindle.Migration.V1.owned_relations/0`.
- Captured generated-app lifecycle identifiers and a real `Repo.get!` read-back, then asserted them alongside packed-artifact provenance and public host relations.

## Task Commits

1. **Task 1: Prove one packed default installation end to end** — `00025a9` (RED), `0a6176c` (GREEN)
2. **Task 2: Exercise real default-routed persistence after boot** — `b45d491` (RED), `f1536b4` (GREEN)

## Files Created/Modified

- `test/install_smoke/support/generated_app_helper.ex` — emits generated host migrations, schema-qualified catalog facts, packed provenance, and lifecycle evidence.
- `test/install_smoke/generated_app_smoke_test.exs` — asserts the fast report contract and image-profile release policy.

## Decisions Made

- The fixed ownership set comes from `Rindle.Migration.V1.owned_relations/0`, preventing catalog drift between migrations and release proof.
- Generated fixture code only provisions and reports facts; repository tests own the assertions about package authority and schema policy.

## Verification

- `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_fast_contract --seed 0` — passed (2 tests).
- `bash scripts/install_smoke.sh image` — passed; built the unpacked artifact and ran the image package-consumer profile.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Known Stubs

None.

## Next Phase Readiness

The generated-app package-consumer harness now provides default-install ownership and persistence facts for subsequent Phase 120 proof slices.

## Self-Check: PASSED

- Both modified test files exist.
- All four TDD commits are present in git history.

---
*Phase: 120-adoption-proof-release-truth*
*Completed: 2026-08-10*
