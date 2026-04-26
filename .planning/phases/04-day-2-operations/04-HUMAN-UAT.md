---
status: partial
phase: 04-day-2-operations
source: [04-VERIFICATION.md]
started: 2026-04-26T14:35:00Z
updated: 2026-04-26T14:35:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Oban uniqueness keyword shape (CR-03)
expected: Two back-to-back calls to `mix rindle.regenerate_variants` (or `VariantMaintenance.regenerate_variants/1`) result in exactly one Oban job per `(asset_id, variant_name)` pair in a production Oban 2.21 environment, not just in the sandbox test adapter. The `unique: [fields: [:args, :worker, :queue], keys: [:asset_id, :variant_name], ...]` shape needs validation — the `keys:` sub-option exists in Oban 2.17+ community and Oban Pro but exact field names can vary by patch release.
result: [pending]

### 2. verify_storage exit-code behavior for FSM-blocked transitions (CR-07)
expected: Operator understands and accepts that a `failed` variant whose storage object disappears is counted as `:errors` (not `:missing`) by `mix rindle.verify_storage`, which then exits non-zero under the CR-05 contract. Confirm whether a separate `:fsm_blocked` counter is desired to distinguish real storage-connection errors from FSM invariant enforcement. This is a design decision about observable exit semantics, not a correctness bug.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
