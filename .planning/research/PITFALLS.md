# Pitfalls Research

**Domain:** Rindle v1.10 — Owner Account Erasure
**Researched:** 2026-05-26
**Confidence:** HIGH

## Main Risks

1. **Deleting shared assets by accident**
   `attach/4` / `detach/3` are slot-scoped while purge is asset-scoped. Owner
   erasure must check for surviving attachments before enqueueing purge.

2. **Hiding destructive behavior behind vague docs**
   If the report shape and retained-shared-asset rule are not explicit,
   adopters will infer stricter semantics than the implementation provides.

3. **Doing storage deletion inline in the transaction**
   That breaks the existing durability posture and risks half-applied account
   deletion on transient storage failures.

4. **Letting the wedge sprawl into admin tooling**
   UI and bulk orchestration are tempting, but they dilute proof and delay the
   core contract.

5. **Non-idempotent reruns**
   Account deletion flows are often retried from jobs or operator tooling; a
   second run must be a stable no-op/report, not a failure.

## Prevention Strategy

- Freeze shared-asset retention as a milestone-level decision before code.
- Treat dry-run/reporting as part of the public contract, not an optional extra.
- Reuse the existing async purge path.
- Defer admin/bulk tooling explicitly in requirements and roadmap.
- Add proof that exercises reruns.

## Sources

- Rindle codebase inspection: `lib/rindle.ex`, `.planning/STATE.md`,
  `.planning/threads/2026-05-25-next-milestone-ordering.md`

---
*Research completed: 2026-05-26*
