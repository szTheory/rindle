# Phase 119: Ownership Boundaries & Diagnostics - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `119-CONTEXT.md`; this log preserves the analysis.

**Date:** 2026-08-09
**Phase:** 119-ownership-boundaries-diagnostics
**Mode:** assumptions, expanded research review
**Areas analyzed:** prefix authority, ownership-safe catalog inspection, doctor diagnostics, runtime-status refusal contract, operator DX

## Assumptions Presented

| Area | Assumption | Confidence | Evidence |
|------|------------|------------|----------|
| Prefix authority | Rindle prefix remains compile-time while Oban stays independently host configured. | Likely | `lib/rindle/schema.ex`, `lib/rindle/config.ex`, `test/rindle/config/config_test.exs` |
| Ownership-safe inspection | Restrict inspection to Rindle's seven owned relations and host `oban_jobs`; leave `schema_migrations` untouched. | Confident | `lib/rindle/migration/v1.ex`, `lib/rindle/ops/runtime_checks.ex`, `test/rindle/migration_test.exs` |
| Doctor mismatch reporting | Report effective Rindle and Oban prefixes separately and name a supported Rindle prefix mismatch. | Likely | `lib/rindle/ops/runtime_checks.ex`, `test/rindle/doctor_test.exs`, `118-CONTEXT.md` |
| Runtime refusal | Preflight before report queries and return bounded errors rather than database exceptions. | Likely | `lib/rindle/ops/runtime_status.ex`, `lib/mix/tasks/rindle.runtime_status.ex`, `test/rindle/runtime_status_task_test.exs` |

## Expanded Research Applied

- **Local architecture review:** Found duplicated doctor/runtime catalog and Oban-prefix paths. The review recommends one internal inspection snapshot and resolving the actual default host Oban binding to prevent false-green readiness followed by queries against a different prefix.
- **Ecosystem review:** Ecto supports explicit schema/prefix boundaries and Oban retains independent host migration/config ownership. PostgreSQL catalog predicates should bind values; identifiers require an allowlisted quoting seam. References: [Ecto Migration](https://hexdocs.pm/ecto_sql/Ecto.Migration.html), [Oban Migration](https://hexdocs.pm/oban/Oban.Migration.html), [PostgreSQL schemas](https://www.postgresql.org/docs/current/ddl-schemas.html), [`quote_ident`](https://www.postgresql.org/docs/current/functions-string.html).
- **Product/DX review:** Keep the operator funnel migration → doctor → runtime status → explicit repair. Use structured output, one action, no raw errors, and calm ownership language aligned with `prompts/rindle-brand-book.md`.

## Corrections Made

- **Prefix authority:** The initial assumption of retaining `:rindle, :oban_prefix` as the practical Oban source was refined. The approved decision makes the resolved default host Oban binding canonical and keeps the existing key only as a compatibility/drift signal.

## Approval

The maintainer approved the cohesive recommendation set, including the host-Oban canonical binding decision, on 2026-08-09.
