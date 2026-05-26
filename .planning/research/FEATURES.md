# Feature Research

**Domain:** Rindle v1.10 — Owner Account Erasure
**Researched:** 2026-05-26
**Confidence:** HIGH

## Table Stakes

### Owner Erasure Contract

- One public owner/account erasure entrypoint instead of instructing adopters
  to loop `detach/3` manually.
- A dry-run/reporting mode that tells callers what will be detached, purged, or
  retained.
- Explicit shared-asset retention semantics when another live attachment still
  exists.
- Idempotent reruns for already-erased owners.

### Proof And Docs

- Hermetic proof that shared assets survive and newly orphaned assets purge.
- Adopter-facing guidance that shows the supported account-deletion flow.
- Explicit non-goals so adopters do not infer bulk compliance tooling or force
  delete semantics that are not yet shipped.

## Differentiators

- Reporting that surfaces retained shared assets explicitly rather than silently
  skipping them.
- Reuse of the existing purge lane, preserving Rindle's async/auditable storage
  semantics.
- Truth-aligned docs that explain why shared assets are retained and what a
  caller should do if they need stricter policy.

## Anti-Features

- Force-deleting assets that still have surviving attachments.
- Admin dashboard work or bulk orchestration in the same wedge.
- Reframing the milestone as protocol/provider breadth.

## Sources

- Rindle codebase inspection: `lib/rindle.ex`, `guides/user_flows.md`,
  `.planning/threads/2026-05-25-next-milestone-ordering.md`

---
*Research completed: 2026-05-26*
