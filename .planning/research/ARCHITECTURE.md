# Architecture Research

**Domain:** Rindle v1.10 — Owner Account Erasure
**Researched:** 2026-05-26
**Confidence:** HIGH

## Existing Architecture To Reuse

- `Rindle.attach/4` and `Rindle.detach/3` already encode owner identity through
  `owner_type`, `owner_id`, and `slot`.
- `media_attachments` is the authoritative ownership join table.
- `media_assets` is shared storage-backed state; multiple attachments may point
  at the same asset.
- `PurgeStorage` already handles async destructive cleanup by `asset_id`.

## Recommended Integration Shape

1. Resolve the target owner into the existing attachment identity fields.
2. Query all attachments for that owner.
3. Partition affected assets into:
   - assets that become orphaned after detaching the target owner's rows
   - assets that still have surviving attachments and must be retained
4. Return that partition in dry-run/reporting mode.
5. In execute mode, delete the owner's attachment rows transactionally and
   enqueue purge only for the orphaned asset set.

## Why This Shape

- It respects current repo truth: attachment ownership is row-scoped, while
  purge is asset-scoped.
- It keeps storage side effects out of the transaction boundary.
- It produces a stable user-facing report shape that proof and docs can freeze.

## Build Order

1. Contract + report shape
2. Execute semantics + purge partitioning
3. Proof + docs

## Sources

- Rindle codebase inspection: `lib/rindle.ex`, `lib/rindle/domain/media_attachment.ex`,
  `lib/rindle/domain/media_asset.ex`, `lib/rindle/workers/purge_storage.ex`

---
*Research completed: 2026-05-26*
