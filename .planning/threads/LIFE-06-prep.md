# LIFE-06 Prep — Force-Delete Shared Assets

Date: 2026-05-28
Status: prep only (no compliance signal; no feature milestone opened)
Requirements: [`.planning/REQUIREMENTS.md`](../REQUIREMENTS.md) LIFE-06-01..03

## Charter gate

**Compliance ticket:** _pending_

Do not run `/gsd-new-milestone` until a concrete compliance/legal ticket is
recorded in the milestone charter.

## Current shipped behavior

- `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` detach owner rows
  and enqueue purge only for assets with zero surviving attachments.
- Shared assets are retained by design; moduledoc denies force-delete
  (`lib/rindle.ex`).
- Batch orchestration reuses `OwnerErasure` per owner.

## Touch-point map (implementation when chartered)

| Surface | Role |
|---------|------|
| `Rindle.Internal.OwnerErasure` | Planner + execute; opts ignored today |
| `Rindle.Workers.PurgeStorage` | Destructive boundary; no-ops when attachments remain |
| `Rindle.preview_batch_owner_erasure/2` / `erase_batch_owner_erasure/2` | Batch facade; must forward per-owner opts |
| `Mix.Tasks.Rindle.BatchOwnerErasure` | Operator CLI; must inherit force opt-in |
| Guides + `docs_parity_test.exs` | Support-truth lock for preview/execute semantics |

## Prerequisite checklist

- [x] Batch facade forwards caller opts minus `:max_owners` (2026-05-28)
- [ ] CLI task forwards force-related opts to batch/single-owner APIs
- [ ] PurgeStorage force path design (preview collateral damage, execute guardrails)
- [ ] Compliance ticket recorded in charter

## Suggested milestone phases (~3)

1. **Contract + preview** — `force:` opt on preview surfaces collateral damage; docs
   parity lock; no destructive default.
2. **Execute + PurgeStorage** — opt-in execute path; batch + CLI inherit; shared-asset
   safety proofs.
3. **Proof + operator truth** — hermetic + adopter proof matrix; operations guide
   parity; milestone audit.

## Explicit non-goals (prep)

- No `:force` implementation until charter opens
- No change to default erasure semantics (retain shared assets unless opted in)
- No admin UI or second provider work

## Related assessment

[post-v117 assessment](2026-05-27-post-v117-milestone-assessment.md) — LIFE-06 ranked
wedge #2; batch opts propagation was latent gap (now closed).
