# Project Research Summary

**Project:** Rindle v1.10 — Owner Account Erasure
**Researched:** 2026-05-26
**Confidence:** HIGH

## Executive Summary

The recommended `v1.10` wedge is a conservative owner/account erasure contract:
give adopters one public dry-run/reporting and execute surface, detach the
target owner's attachment rows, purge only assets that become newly orphaned,
and retain shared assets that still have surviving attachments. This fits
Rindle's core lifecycle mission better than more provider/protocol breadth and
avoids inventing a stricter ownership model than the repo currently enforces.

No new runtime stack is needed. The capability composes the existing ownership
join rows, asset rows, and async purge lane. The key design work is freezing the
public reporting vocabulary and shared-asset rule so implementation, proof, and
docs all describe the same destructive boundary.

## Key Findings

### Stack Additions

- No new storage/provider/protocol layer
- Reuse existing `Rindle` facade, repo ownership, and async purge path
- Add only the reporting shape and proof/docs coverage required by the new
  public lifecycle capability

### Feature Table Stakes

- One supported owner/account erasure facade
- Dry-run/reporting before destructive execution
- Shared-asset retention when another attachment survives
- Idempotent reruns
- Hermetic + adopter-facing proof

### Watch Out For

1. Accidentally purging shared assets
2. Vague docs that overclaim deletion semantics
3. Inline storage deletion in the DB transaction
4. Scope sprawl into admin/bulk tooling
5. Non-idempotent retry behavior

## Implications For Roadmap

### Phase 53: Owner Erasure Contract + Truth Gate

Freeze the public contract, report shape, and non-goals before implementation.

### Phase 54: Execute + Orphan-Safe Purge Wiring

Implement the public execute path and orphan-only purge partitioning.

### Phase 55: Proof + Adopter Guidance

Add hermetic/adopter proof and replace hand-rolled account-deletion guidance.

## Sources

- Rindle codebase inspection: `lib/rindle.ex`, `guides/user_flows.md`,
  `.planning/threads/2026-05-25-next-milestone-ordering.md`
- Rails Active Storage Overview: https://guides.rubyonrails.org/active_storage_overview.html
- Shrine docs: https://shrinerb.com/docs/attacher

---
*Research completed: 2026-05-26*
