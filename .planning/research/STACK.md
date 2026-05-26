# Stack Research

**Domain:** Rindle v1.10 — Owner Account Erasure
**Researched:** 2026-05-26
**Confidence:** HIGH

## Context

This milestone adds a new public lifecycle capability, not a new storage
adapter, provider, or protocol. The existing stack remains valid:
Elixir/Phoenix/Ecto in core, Oban for async purge, and the current attachment /
asset schemas as the persistence boundary.

## Recommended Stack For New Capability

| Stack element | Status | Why |
|---------------|--------|-----|
| Existing `Rindle` facade + Ecto repo ownership | Keep | Owner erasure belongs on the same public lifecycle seam as `attach/4` and `detach/3`. |
| Existing `media_attachments` and `media_assets` tables | Keep | The capability is a composition of current rows, not a new persistence family. |
| Existing async purge lane (`PurgeStorage`) | Reuse | Purge is already async, auditable, and outside the DB transaction boundary. |
| Focused lifecycle reporting structs/maps | Add | Dry-run/reporting needs a stable shape without inventing new infrastructure. |
| Hermetic lifecycle integration tests + adopter-facing proof | Add | This capability changes public deletion semantics and needs explicit proof. |

## What Not To Add

| Avoid | Why |
|-------|-----|
| New job family for basic owner erasure | The existing purge lane already handles the destructive storage step. |
| Admin UI or bulk orchestration runtime | Not needed to prove the core lifecycle contract. |
| Single-owner-only storage contract | The repo already allows multiple attachments to point at the same asset. |

## Prior-Art Notes

- Rails Active Storage documents `purge` / `purge_later` as attachment-triggered
  deletion with background cleanup, which reinforces keeping storage deletion
  asynchronous rather than inline.
- Shrine's attacher model reinforces "replace/remove through one explicit
  attachment boundary" rather than scattering deletion logic across callers.

## Sources

- Rindle codebase inspection: `lib/rindle.ex`, `lib/rindle/workers/purge_storage.ex`,
  `lib/rindle/domain/media_attachment.ex`, `guides/user_flows.md`
- Rails Active Storage Overview: https://guides.rubyonrails.org/active_storage_overview.html
- Shrine docs: https://shrinerb.com/docs/attacher

---
*Research completed: 2026-05-26*
