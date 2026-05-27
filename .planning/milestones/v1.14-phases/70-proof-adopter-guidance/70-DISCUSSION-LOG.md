# Phase 70: Proof & adopter guidance - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 70-proof-adopter-guidance
**Mode:** assumptions (research-validated, user confirmed)
**Areas analyzed:** Hermetic proof layout, partial-failure mechanism, guides/TRUTH-03, docs parity, canonical app, CLI proof

---

## Assumptions Presented

### Hermetic proof layout
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Split: Phase 68 tests frozen; new `owner_erasure_batch_proof_test.exs` for PROOF-05 gaps | Confident | `owner_erasure_batch_test.exs` (4 tests); 68-VERIFICATION advisory; v1.13 cancel split precedent |
| Extract `test/support/owner_erasure_batch_fixtures.ex` | Likely | Duplicated fixtures across batch_test + task_test |
| No canonical_app batch section | Confident | PROOF-05 hermetic-only; v1.10 single-owner canonical; lifecycle_test.exs |

### Partial-failure mechanism
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Counting repo via `Application.put_env(:rindle, :repo, …)` | Confident | `Config.repo/0` in `owner_erasure.ex`; `broker_test.exs` FailingTransactionRepo |
| Not Mox storage / invalid UUID | Confident | execute does not call storage; CastError raises not batch_owner_failed |
| First-owner failure asserts empty partial_report.owners | Likely | Phase 68 D-08 |

### Guides (TRUTH-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Batch story in `user_flows.md` Story 5 subsection; single-owner first | Confident | D-18; existing Story 5; `lib/rindle.ex` moduledoc |
| `operations.md` thin pointer only | Confident | Phase 69 D-14; operations.md lines 31–35 |
| Replace "bulk orchestration deferred" with shipped batch + unchanged deferrals | Confident | user_flows.md line 264–265; docs_parity requires stale phrase today |

### Docs parity
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend `docs_parity_test.exs` only | Confident | Same owner-erasure truth file; streaming_cancel is separate guide |
| Refute `--owners-file` in operations.md | Likely | D-18 anti-drift |

### CLI proof
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No new install_smoke CLI matrix | Confident | `batch_owner_erasure_task_test.exs` (6 tests); Phase 69 VERIFICATION |

---

## Corrections Made

No corrections — all assumptions confirmed via user reply "Yes, proceed" after subagent research synthesis.

---

## External Research Applied

### Subagent: proof file layout
- Recommendation: Option C split (baseline + proof file + shared fixtures)
- Idiomatic ExUnit: `DataCase async: false`, `describe "PROOF-05:"`, no `@tag :adopter` for batch matrix

### Subagent: partial failure
- Counting txn repo over Mox/invalid UUID/meck
- Must return Ecto 4-tuple from `transaction/1`
- Assert `Repo.get` on attachments for commit proof

### Subagent: guides + parity
- Progressive disclosure: user_flows → moduledoc → mix help
- Stripe/Rails/Hex docs patterns
- Parity snippet list and refutes documented in CONTEXT D-19–D-21

### Subagent: canonical app
- Option A: no batch in lifecycle_test.exs
- v1.10 PROOF-04 single-owner vs PROOF-05 hermetic batch

### Prompts / DNA
- `gsd-rindle-elixir-oss-dna.md`: CI as contract surface, docs-contract gates, layered proof lanes
- `phoenix-media-uploads-lib-deep-research.md`: purge-not-in-transaction

---

## Auto-Resolved

Not applicable (not `--auto` mode).
