---
phase: 17-api-surface-boundary-audit
plan: 03
subsystem: api
tags: [api-boundary, exdoc, domain, docs]
requires:
  - phase: 17-api-surface-boundary-audit
    provides: boundary harness coverage and prior helper-module visibility cleanup
provides:
  - hidden FSM and stale-policy domain internals via `@moduledoc false`
  - schema-module docs that no longer link to hidden domain internals
  - clean ExDoc build proving public schema types remain visible while invariants stay hidden
affects: [phase-17, exdoc-visibility, domain-docs, api-surface]
tech-stack:
  added: []
  patterns: [module-level hiding for domain invariants, public docs phrased around state tables instead of hidden module links]
key-files:
  created: [.planning/phases/17-api-surface-boundary-audit/17-03-SUMMARY.md]
  modified:
    - lib/rindle/domain/asset_fsm.ex
    - lib/rindle/domain/upload_session_fsm.ex
    - lib/rindle/domain/variant_fsm.ex
    - lib/rindle/domain/stale_policy.ex
    - lib/rindle/domain/media_asset.ex
    - lib/rindle/domain/media_upload_session.ex
    - lib/rindle/domain/media_variant.ex
    - lib/rindle/delivery.ex
    - lib/rindle.ex
    - guides/core_concepts.md
    - guides/secure_delivery.md
    - guides/troubleshooting.md
key-decisions:
  - "Hide the domain invariant modules at the module boundary with `@moduledoc false` instead of per-function suppression."
  - "Replace public docs links to hidden FSM/stale-policy modules with state-table and policy wording so `mix docs --warnings-as-errors` stays green."
patterns-established:
  - "Public schema/reference modules can describe lifecycle semantics without linking directly to hidden implementation modules."
  - "When hidden-module warnings appear after an ExDoc boundary change, fix the outward-facing docs rather than re-exposing internals."
requirements-completed: [API-04]
duration: 2min
completed: 2026-04-30
---

# Phase 17 Plan 03: API Surface Boundary Audit Summary

**Domain FSM and stale-policy modules are now hidden from ExDoc, while the five public schema/reference types stay visible and the docs build no longer links back into those internals.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-30T19:08:40Z
- **Completed:** 2026-04-30T19:10:33Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Added `@moduledoc false` to `Rindle.Domain.AssetFSM`, `Rindle.Domain.UploadSessionFSM`, `Rindle.Domain.VariantFSM`, and `Rindle.Domain.StalePolicy` so the lifecycle invariants stop appearing as public API.
- Kept the five domain schema modules public and updated their docs to describe lifecycle/state behavior without linking to hidden implementation modules.
- Cleared the ExDoc warning path by rewriting public guide and facade references that still pointed at hidden domain internals.

## Task Commits

1. **Task 1: Hide the domain FSM and stale-policy internals while leaving schema modules public** - `9652c45` (`feat`)
2. **Task 2: Prove the schema-vs-FSM boundary in generated docs** - `2c8eae9` (`docs`)

## Files Created/Modified

- `lib/rindle/domain/asset_fsm.ex`, `lib/rindle/domain/upload_session_fsm.ex`, `lib/rindle/domain/variant_fsm.ex`, `lib/rindle/domain/stale_policy.ex` - Hidden lifecycle/stale-policy modules from generated docs.
- `lib/rindle/domain/media_asset.ex`, `lib/rindle/domain/media_upload_session.ex`, `lib/rindle/domain/media_variant.ex` - Preserved public schema docs while removing links to hidden internals.
- `lib/rindle/delivery.ex`, `lib/rindle.ex`, `guides/core_concepts.md`, `guides/secure_delivery.md`, `guides/troubleshooting.md` - Rephrased public docs around lifecycle tables and stale-policy behavior without referencing hidden modules.

## Decisions Made

- Used module-level hiding for the invariant modules because Phase 17's boundary is about removing accidental public module contracts, not just trimming individual function docs.
- Treated stale ExDoc links as a blocking follow-on from the hide operation and fixed the public documentation wording instead of weakening the hidden boundary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced invalid Mix `-x` verification with `--trace`**
- **Found during:** Task 1 verification
- **Issue:** The plan's `mix test ... -x` command is not accepted by the installed Mix version.
- **Fix:** Re-ran the focused harness with `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs --trace`.
- **Files modified:** None
- **Verification:** The boundary harness executed and confirmed the domain hidden-doc assertion passed.
- **Committed in:** Not applicable (verification-only deviation)

**2. [Rule 3 - Blocking] Removed public docs references to newly hidden domain internals**
- **Found during:** Task 2 verification
- **Issue:** `mix docs --warnings-as-errors` failed because public schema/facade/guides still linked to the hidden FSM and stale-policy modules.
- **Fix:** Reworded public docs to point at lifecycle state tables and configured stale-serving behavior instead of hidden module links.
- **Files modified:** `lib/rindle/domain/media_asset.ex`, `lib/rindle/domain/media_upload_session.ex`, `lib/rindle/domain/media_variant.ex`, `lib/rindle/delivery.ex`, `lib/rindle.ex`, `guides/core_concepts.md`, `guides/secure_delivery.md`, `guides/troubleshooting.md`
- **Verification:** `mix docs --warnings-as-errors`
- **Committed in:** `2c8eae9`

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** No scope change. Both fixes were required to verify the intended hidden-invariant/public-schema boundary on the installed toolchain.

## Issues Encountered

- The focused boundary harness still fails on facade rename/shim coverage and ops-module hiding that belong to later Phase 17 plans; the D-05 domain hidden-module assertion is now green.
- Test runs emitted repeated Postgres `too_many_connections` noise from Oban/Postgrex startup, but ExUnit still executed the target file and surfaced the expected later-plan failures.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The domain namespace now follows the locked D-04/D-05 split: schema/reference types stay public, lifecycle invariants stay hidden.
- Plans `17-04` and `17-05` still need to resolve the remaining harness failures for facade verification naming/shims and hidden ops modules.

## Self-Check: PASSED

- Found `.planning/phases/17-api-surface-boundary-audit/17-03-SUMMARY.md`
- Found commit `9652c45`
- Found commit `2c8eae9`

---
*Phase: 17-api-surface-boundary-audit*
*Completed: 2026-04-30*
