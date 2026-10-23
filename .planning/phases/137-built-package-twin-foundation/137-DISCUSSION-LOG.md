# Phase 137: Built-Package Twin Foundation - Discussion Log (Assumptions Mode)

> Audit trail only. Do not use as input to planning, research or execution agents.
> CONTEXT.md owns the decisions; the research reports contain evidence and alternatives.

**Date:** 2026-10-21
**Phase:** 137-built-package-twin-foundation
**Mode:** Research-first assumptions, recommendations delegated by user.
**Areas analyzed:** package boundary and host, Elixir/OTP/Ecto/Oban execution,
fault seams, restart, receipts, security/privacy, cleanup, CI, maintainer DX and scope.

## User Direction

The user requested a return to normal OpenGSD workflow, then asked to consider all
relevant decisions through parallel primary-source research, concrete alternatives,
pros/cons/tradeoffs, ecosystem lessons and adversarial review. They requested one
coherent recommendation set and said to "auto follow those" recommendations.
They prefer a small copy to another dependency and current brandbook guidance over
older prompt references. This delegates routine decisions; it is not implementation,
merge, live-provider, release or requirement-acceptance authorization.

No additional assumption-confirmation question was needed after that explicit
delegation. No --auto flag or persistent auto-advance setting was inferred.

## Initial Assumptions and Revisions

| Initial assumption | Confidence before research | Final disposition / evidence |
| --- | --- | --- |
| Cohort should be the primary host | Likely | Replaced with minimal external Phoenix host; Cohort has path fallback, inline jobs, unrelated boot dependencies and a different lock. Package research compares three serious alternatives. |
| Real Repo/Oban and actual host runtime replacement are necessary | Confident | Confirmed; pinned Oban source distinguishes helper/manual/normal execution. Selected default instance, normal queues, no Sandbox, committed state and between-attempt restart. |
| A storage/processor/provider behaviour is a viable injected fault seam | Likely | Narrowed to the actually configurable storage adapter. Processor worker dispatch is hardcoded; no new production hook. |
| Private schema use must be rejected | Overbroad wording | Adversarial review found publicly documented schemas/read queries. Guard unsupported calls and mutations, not all schema aliases. Prefer facade/status for the bounded tracer. |
| External process plus clean paths sufficiently isolates package use | Incomplete | Selected one existing Docker/Compose path with staged inputs/no checkout mount. Ordinary same-user native execution cannot deny arbitrary checkout reads. |
| Durable fault state could be a file or table | Likely | Settled on one tiny fixed host PostgreSQL counter; existing Repo gives atomic cross-runtime state without a file claim/reset protocol. |
| A valid receipt proves acceptance | False without semantics | Explicitly distinguish integrity, semantics and trust. Acceptance fails on incomplete/blocked/failed facts; offline self-consistency cannot defeat a malicious trusted collector. |
| Zero resources after disposal proves cleanup | False | Require terminal/domain cleanup observations before disposal, complete inventories and explicit bounded infrastructure/history allowances. |

## Research Dispatch and Synthesis

- Package/host/DX branch: compared Cohort export, minimal generated host and full
  smoke-harness generalization; checked Hex/Mix/Phoenix/Ecto primary sources and
  exact source/locks/cache behavior.
- Runtime branch: pinned Oban 2.21.1 source, Ecto/OTP semantics, public profile/storage
  seams, real retry cadence, pause/re-read barrier and OS runtime ownership.
- Evidence/security/SRE branch: compared typed Jason versus new schema/framework
  dependencies, semantic validation, redaction, resource ownership, cleanup and CI cost.
- Independent adversarial pass: checked all three reports and actual source. It
  corrected attach argument order, public schema classification, partial purge
  effects, container image/toolchain assumptions and the pause barrier.
- Parent integration: reviewed all prompts and methodology, applied JTBD/consumer
  ergonomics, verified relevant Rails/Shrine/AWS primary lessons, and collapsed the
  alternatives into the single direction in CONTEXT.md.

## Primary-Source Topics Resolved

- Hex local archive versus unpack/fetch behavior; metadata digest versus tar digest.
- Phoenix generator cache and inherited prebuilt code risk.
- Oban direct helper, manual drain, normal producer and persisted acknowledgement.
- Ecto Sandbox versus independently committed processes; host migrations/ownership.
- OTP child supervision versus whole BEAM/container replacement.
- Storage cleanup outside transactions, concurrent attachment races, idempotent effects,
  multipart inventory, readiness, safe logging and provenance trust limits.

Direct source links and file locations are in the research reports. Runtime/toolchain
budgets and installed-tool commands remain ordinary implementation probes, not user
preference questions or new research platforms.

## Scope Disposition and Stopping Point

All six TWIN requirements have an executable acceptance direction. No unresolved
high-blast-radius choice remains. The full Phase 138 matrix, Phase 139 readiness,
numeric speed deferral and three unrelated CI/release todos remain outside scope.

Research stopped after independent challenge converged on the same host, package,
runtime, fault state, observation and cleanup boundaries. Further breadth would not
change the selected architecture. No service/test/collector/package installation,
remote mutation or requirement closure occurred during discussion.
