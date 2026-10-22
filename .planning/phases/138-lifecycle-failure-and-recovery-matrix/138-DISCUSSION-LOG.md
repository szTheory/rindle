# Phase 138: Lifecycle Failure and Recovery Matrix - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research or execution agents.
> Decisions are captured in CONTEXT.md; substantive research is linked there separately.

**Date:** 2026-10-21
**Mode:** assumptions, as configured by `workflow.discuss_mode`
**Areas analyzed:** consumer/package boundary; protocol/Oban; AV/repair; provider
ordering/idempotence; restart; residue/cleanup; evidence/security; CLI/DX; scope/workflow.

## Process

Validated Phase 138 with canonical `init.discuss-phase-assumptions`. There was no existing
context, research or plan. Loaded active project/requirements/state/methodology, prior context
and relevant source/prompt material. A typed GSD assumptions analyzer read local code and
returned uncertainties. Three explicitly requested research agents investigated those gaps
using local contracts and primary official sources. A final independent adversarial pass
challenged the combined proposal. All agents returned terminal results; none edited files.

The user explicitly requested research breadth/depth with diminishing returns, coherent
recommendations, idiomatic Elixir/Plug/Ecto/Phoenix, consumer-centred DX and a small flat
dependency tree. Normal OpenGSD stages and automation-first acceptance remain standing rules.

## Assumptions Presented

| Assumption | Initial confidence | Evidence |
|---|---|---|
| Extend the external packaged host, ordinary Repo/default Oban and existing CLI. | Confident | Phase 137 context; built_package_twin.py; host application/config. |
| Recreate tus client at a committed offset on the same S3 node. | Likely, resolved by research | TusPlug deployment constraint; generated client precedent; tus spec. |
| Reuse delete-once fault but independently observe absence and a distinct durable restart cut. | Likely, resolved by research | Host storage/tracer; purge worker; completion transaction; Oban public APIs. |
| Use real video failure plus public runtime_status/requeue and validate actual output. | Likely, resolved to fixed download fault and ordinary retry exhaustion | ProcessVariant, lifecycle_repair, runtime_status collector, AV tests/FFmpeg docs. |
| Use signed provider ingress and the shipped Mux adapter with local HTTP. | Likely, resolved by adapter/config/source review | Provider behaviour, Mux HTTP base_url, webhook Plug/worker, Mux guidance. |
| Require source-owned complete matrix predicates and pre-disposal domain inventory. | Confident | twin_receipt.py, twin_cleanup.py, Phase 137 context. |

## Corrections and Adversarial Refinements

- Initial provider proposal focused on pending duplicates and ready-then-stale-created.
  Independent review required post-completion duplicates AND stale-errored events, exposing
  a likely existing state regression rather than choosing a favourable passing subset.
- The user was shown that event timestamps are recorded but do not gate transitions,
  while ready-to-errored is allowed. Behavioural regression proof is still required;
  no executed failure or accepted fix is claimed during discussion.
- Clarified that one original plus explicitly configured derivative keys is the shipped
  ready lifecycle; a one-total-object reading would misstate existing semantics.
- Clarified S3 missing DELETE success versus error-atom unit coverage; no fabricated 404.
- Clarified separate tus client recovery and host SIGKILL at a durable preclaim cut;
  neither is a mid-PATCH/cross-node or executing-job-rescue guarantee.
- Clarified AV diagnostic failure versus discarded-job evidence and real repair enqueue;
  an active retry/uniqueness conflict is not new repair.
- Corrected an early Oban delay estimate using pinned source; deadlines need actual execution
  and scheduler margin, not a tightly inferred retry-duration guarantee.
- Clarified public janitor is a Mix task, has a prerequisite expiry/abort lane and only
  cleans its declared upload work. Require observed partial domain effects before death,
  real multipart coverage and separate owners/inventories for other resources.
- Read current `brandbook/README.md`; current brand system supersedes the prompt seed.

## User Scope Decision

Question: “For phase 138, I recommend the full six-case matrix and narrowly scoped
correctness fixes if adversarial provider tests confirm stale-event regression or duplicate
effects, while preserving public APIs and schema. Keep Doctor's migration-ledger fix for
phase 139. Should I capture that scope in the phase context?”

Options:
1. Adopt the recommendations and bounded fixes.
2. Evidence only; leave confirmed defects open.

**User answer:** “Adopt the recommendations and bounded fixes.”

This explicit response authorizes the captured recommendation set and bounded correctness
slice. It does not satisfy any RECOV acceptance requirement. No automatic defaults were used
to bypass the workflow's confirmation gate.

## Reviewed Todos

The canonical matcher suggested Doctor's ledger issue (0.6) and two CI/release items (0.2).
Doctor is not needed by the public failed-variant diagnostic/repair path; the user explicitly
retained it for Phase 139. Other matches are unrelated. No todo was folded or marked complete.

## External Research

Primary sources and concrete pros/cons are preserved in `138-DISCUSS-RECOMMENDATIONS.md`
and linked from CONTEXT.md. They include tus 1.0, pinned Oban 2.21.1 source/API, official
FFmpeg/ffprobe, Mux signatures/delivery/ordering, S3 object/multipart semantics and Docker
volume lifecycle. No cloud account, external mutation or matrix execution occurred.

## Methodology

Applied all relevant project lenses: adopter-first, repo-truth, research-first, narrow-then-
escalate, idiomatic Elixir, automation-first, durable memory, diminishing returns and parity
triple-lock where user-visible protocol/support claims change. Graphical design, rendering,
new product axes and broad compatibility work are not relevant to this headless matrix.

## Outcome

Capture ready-for-planning context and direct handoff to `$gsd-plan-phase 138` in the current
authoritative worktree. No PLAN, implementation, RECOV closure, readiness, merge or release
claim. Auto-advance remains disabled.
