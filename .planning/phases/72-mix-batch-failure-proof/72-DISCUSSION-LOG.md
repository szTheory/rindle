# Phase 72: Mix Batch Failure Proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 72-mix-batch-failure-proof
**Mode:** assumptions + parallel research subagents
**Areas analyzed:** Scope/surface, failure injection, scenario shape, shell assertions

## Assumptions Presented

### Scope and implementation surface
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Test-only; extend `batch_owner_erasure_task_test.exs` | Confident | ROADMAP criteria; mix task lines 105–108; v1.14 thin-wrapper audit |
| Reject runner extract | Confident | Compare to doctor vs batch task; no `Rindle.Ops` for thin wrappers |
| Reject separate proof file | Confident | ROADMAP names one file; PROOF-05 file is API matrix |

### Failure injection harness
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `CountingFailingTxnRepo.with_counting_repo(2, ...)` | Confident | PROOF-05; `config.ex` repo seam; `counting_failing_txn_repo.ex` |
| Reject Mox on OwnerErasure | Confident | No behaviour; wrong layer for txn proof |
| Reject prod `--simulate-failure` | Confident | OSS DNA footguns; adopter surprise |

### Execution mode and batch shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `--execute` + 2 owners + `fail_after: 2` | Likely → **locked** | ROADMAP mid-batch; preview has no txn |
| Skip `fail_after: 1` CLI test | Likely → **locked** | PROOF-05 second test |
| Defer JSON failure path | Likely → **locked** | Success JSON exists |

### Shell assertions
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `Mix.Shell.Process` + ordered `assert_received` | Likely → **locked** | Six existing task tests |
| Error substrings from `error.ex` | Likely → **locked** | `owner_erasure_batch_error_test.exs` |
| DB assertions optional | Likely → **discretion** | PROOF-05 already proves DB |

## Corrections Made

No corrections — research synthesis accepted as locked decisions (maintainer requested one-shot recommendations).

## External Research

Subagent trade studies covered:
- Elixir OSS: thin Mix tasks tested in-process; Ecto migrator/Oban delegate to library modules
- Ecosystem: configurable repo swap (Go sqlmock analogue); reject Ruby-style prod failure gems
- Rindle prompts: layered proof, package tests insufficient without operator path, footgun ledger
- Prior art: PROOF-05 + task test split (v1.14 D-12)

## Rejected Alternatives (summary)

| Alternative | Why rejected |
|-------------|--------------|
| `Rindle.Ops.BatchOwnerErasure` runner | Over-abstraction; risks testing runner not mix wiring |
| Separate `operator_proof_test.exs` | One scenario; ROADMAP file criterion |
| Mox/stub OwnerErasure | No partial commit proof |
| Prod simulation flag | Adopter surprise; scope creep |
| Dry-run + mock facade | Preview never hits transactions |
| `fail_after: 1` CLI test | PROOF-05 covers; empty partial low operator value |
| JSON partial-failure test | Same branch; deferred |
| `CaptureIO` / subprocess mix | Wrong repo convention |
