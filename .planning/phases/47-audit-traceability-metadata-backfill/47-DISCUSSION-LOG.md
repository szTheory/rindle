# Phase 47: audit-traceability-metadata-backfill - Discussion Log

> **Audit trail only.** Decisions are locked in `47-CONTEXT.md`.

**Date:** 2026-05-25
**Phase:** 47-audit-traceability-metadata-backfill
**Mode:** recovery / closure

## Settled Decisions

- `TUS-07` ownership is single-summary and belongs to `43-02-SUMMARY.md`.
- Phase 45 uses strict per-plan ownership rather than duplicating
  `MUX-20..23` across all summaries.
- The re-audit is part of Phase 47 itself, not a follow-up phase.

## Reasoning Snapshot

- The implementation and verification for Phase 43 and Phase 45 are already
  green; only summary frontmatter drift keeps the strict audit matrix partial.
- Duplicating requirement IDs across multiple summaries would make the audit
  noisier and less trustworthy, not more complete.
- Stopping after metadata edits would leave the repo in an ambiguous state
  where the authoritative audit still disagreed with the files it was auditing.
