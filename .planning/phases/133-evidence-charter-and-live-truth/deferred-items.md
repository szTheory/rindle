# Deferred Items

## Plan147 shared-cache blocker

- The shared host Hex cache changed during Plan 147 Task 1 full-suite verification, causing existing Plan 143 readiness and protected-artifact checks to fail.
  status: resolved
  **Evidence:** `133-147-TASK-1-VERIFICATION.json` preserves the actual 46/48 report and the cache change from `f321667cbe7704108614fcb3dfb8f81962111d7152abb4f1dabd6003666411d6` to `fbbd46b5ce3477fd8b07812acf1807e00a65da94e90cf4b255b8f3195ab2dd88`.
  **Original checkpoint boundary:** Both fixture repairs were attempted; the new Plan 147 tests pass. No host-cache writer was identified or stopped, and no production preflight, authorization, request, or requirement closure ran. Stabilize the shared cache before the executor reruns the full Task 1 gate; do not weaken cache verification.
  **Resolution (2026-10-10):** Copied Plan 143, 145 and 147 receipts now freeze private cache snapshots with matching destinations and hashes. The long-duration effects baseline excludes the independently mutable host cache, while private-cache tampering and production cache drift remain rejected. The real Hex cache was not restored or mutated. Task 1 GREEN commit `4097b3ac`, its committed tracer rerun, and the Task 2 post-publication run each passed 48/48 tests; all four nested histories passed 46/46 in each run. The automation-first contract passed. Current host admission and the zero-request Plan 147 preflight were independently production-verified and committed in `6dbf2cbf`. No authorization, request marker, retrieval, supply or requirement credit exists; Task 3 awaits its fresh digest-bound literal decision.

## Plans107/108 fixture authority mismatch

- Plans 107/108 recorded nine Plan 64/79 fixture failures; Plan 114 restored the immutable authority bytes and repaired the append boundary. Its summary records the full reconciliation suite passing. WINDOWS entry 40 is fixed.
  status: resolved
  resolution_authority: 133-114-SUMMARY.md (full reconciliation repair); WINDOWS entry40 also records the Plans107/108 repair.

## Plan84 fixture authority mismatch

- Plan 84 recorded five Plan 65/66/79 fixture failures; the same Plan 114 fixture repair resolved the historical authority mismatch, and its full-suite result is recorded in `133-114-SUMMARY.md`.
  status: resolved
  resolution_authority: 133-114-SUMMARY.md (full reconciliation repair); WINDOWS entry40 also records the Plans107/108 repair.

## Plan47 formatting fixed; full gates remain unrun

- Plan 47's formatter discrepancy at `nightly_policy_test.exs:206` was corrected by Plan 57 commit `997a1aa0`; Plan 57's changed-file formatting checks passed. Its separate later `mix ci` failure and unrun gates remain represented by WINDOWS entry 36 for fresh qualification in Plan 120.
  status: pending
  next_action: Retain WINDOWS entry36 as open; the formatter repair alone does not satisfy the unrun full-gate evidence.
