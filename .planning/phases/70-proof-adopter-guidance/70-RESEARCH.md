# Phase 70: Proof & adopter guidance - Research

**Researched:** 2026-05-27
**Domain:** Hermetic batch owner-erasure proof matrix (PROOF-05) + guide/docs parity (TRUTH-03)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01..D-04:** Keep `owner_erasure_batch_test.exs` as frozen Phase 68 baseline; add `owner_erasure_batch_proof_test.exs` with `describe "PROOF-05: …"` blocks; extract fixtures to `Rindle.Test.OwnerErasureBatchFixtures`; no canonical-app batch mirror.
- **D-05..D-08:** Proof file covers shared-asset batch, partial-failure DB integration, first-owner failure only — not preview aggregation, dedupe, empty/over-limit, or idempotent rerun (already in Phase 68).
- **D-09..D-11:** Partial failure via `Application.put_env(:rindle, :repo, …)` counting wrapper delegating to `Rindle.Repo`; ship `test/support/counting_failing_txn_repo.ex`; no Mox on storage or OwnerErasure mocking.
- **D-12:** No new install_smoke CLI matrix — `batch_owner_erasure_task_test.exs` sufficient.
- **D-13..D-17:** Batch narrative in `user_flows.md` Story 5 subsection; thin ops/getting_started pointers; replace stale "bulk orchestration deferred" with shipped batch API + deferred admin/force-delete/scheduler.
- **D-18..D-21:** Extend `docs_parity_test.exs` only; flip `"bulk orchestration"` snippet to batch vocabulary; refute `--owners-file` / `owner_type` in operations.md.
- **D-22:** Full verification command spans batch test suite + docs parity.

### Claude's Discretion
- Exact describe/test names; counting repo file location; Story 5 heading wording; parity snippet strings.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROOF-05 | Hermetic proof covers batch preview aggregation, per-owner isolation on execute, partial failure handling, idempotent rerun, and retained shared-asset semantics unchanged from v1.10 | Phase 68 baseline tests cover aggregation/isolation/rerun; Phase 70 proof file fills shared-asset + partial-failure DB gaps |
| TRUTH-03 | Guides document batch erasure as supported multi-owner surface; defer force-delete, admin UI, scheduler | Story 5 batch subsection + ops/getting_started thin pointers + docs_parity_test.exs snippet freeze |
</phase_requirements>

## Summary

Phase 70 closes v1.14 with **gap-fill proof** and **support-truth docs** — no new API or CLI. Implementation is already shipped in Phases 67–69; this phase adds test infrastructure, three PROOF-05 integration scenarios, and guide/parity updates.

**Primary recommendation:** Two-plan wave — (1) fixtures + counting repo + proof test file, (2) guides + docs parity.

## Standard Patterns

### Fixture extraction (mirror layered batch tests)

Phase 68 split concerns across modules:
- `owner_erasure_batch_test.exs` — happy-path integration
- `owner_erasure_batch_boundary_test.exs`, `owner_erasure_batch_contract_test.exs`, `owner_erasure_batch_error_test.exs` — boundary/contract/unit

Phase 70 adds `owner_erasure_batch_proof_test.exs` for gaps only. Shared helpers move to:

```elixir
defmodule Rindle.Test.OwnerErasureBatchFixtures do
  def test_profile, do: TestProfile
  def user_module, do: User
  def insert_asset(storage_key), do: ...
  def insert_attachment(asset, owner, slot), do: ...
  def owner_ref(owner), do: ...
end
```

Consumers: `owner_erasure_batch_test.exs` (refactor imports, same assertions), `owner_erasure_batch_proof_test.exs`, `batch_owner_erasure_task_test.exs`.

### Shared-asset proof (mirror `owner_erasure_test.exs`)

Single-owner shared-asset fixtures from `owner_erasure_test.exs` lines 25–90:
- Two owners attach to same asset
- Preview/execute reports `retained_shared_assets.count == 1`
- Execute removes only requesting owner's attachment; shared asset survives

Batch extension: two owners in `[owner1, owner2]`, one shared asset between them — aggregate `retained_shared_assets` and per-owner reports match v1.10 semantics.

### Counting failing transaction repo (extend `broker_test.exs` pattern)

`OwnerErasure.execute/2` calls `Config.repo().transaction/1` once per owner. Batch runs `Enum.reduce_while` sequentially — owner1 commits before owner2 starts.

```elixir
defmodule Rindle.Test.CountingFailingTxnRepo do
  @delegate Rindle.Repo

  def transaction(fun) when is_function(fun, 0) do
    case next_count() do
      n when n == fail_after() ->
        {:error, :plan, :forced_batch_failure, %{}}
      _ ->
        @delegate.transaction(fun)
    end
  end

  def transaction(multi), do: ...
  def all(q), do: @delegate.all(q)
  # delegate get/insert/update/delete/preload/one/...
end
```

Test setup:
```elixir
previous = Application.get_env(:rindle, :repo)
Application.put_env(:rindle, :repo, CountingFailingTxnRepo)
Application.put_env(:rindle, :counting_failing_txn_repo, fail_after: 2)
on_exit(fn -> restore previous end)
```

Partial-failure scenario (D-06):
- owner1 + owner2 each with orphan attachment
- `fail_after: 2` → owner1 execute succeeds, owner2 fails
- Assert `{:error, {:batch_owner_failed, detail}}`
- `length(detail.partial_report.owners) == 1`
- owner1 attachment gone, owner2 attachment still present

First-owner failure (D-07):
- Single owner or `fail_after: 1`
- Assert `partial_report.owners == []`

### Guide support truth (mirror v1.13 cancel + Phase 69 deferral)

- **`user_flows.md` Story 5:** canonical narrative (~15–25 lines batch subsection after single-owner flow)
- **`operations.md`:** thin index (~8–12 lines) — API names + mix task + link to user_flows; NO JSON schema, flag table, or `--owners-file`
- **`getting_started.md`:** one forward sentence to user_flows batch subsection

Replace line 264–265 stale deferral:
```
Admin UI, bulk orchestration, and force-delete policy for still-shared assets remain deferred.
```
With shipped batch + remaining deferrals:
```
Batch multi-owner erasure is supported via `Rindle.preview_batch_owner_erasure/2`,
`Rindle.erase_batch_owner_erasure/2`, and `mix rindle.batch_owner_erasure`.
Admin UI, force-delete policy for still-shared assets, and scheduler/cron erasure jobs remain deferred.
```

### Docs parity (extend existing owner-erasure freeze)

Current test at `docs_parity_test.exs:251` requires `"bulk orchestration"` snippet — **must flip in same PR** as guide prose (D-19).

Add assertions:
- `"preview_batch_owner_erasure"`, `"erase_batch_owner_erasure"`, `"batch_owner_erasure"`, `"batch_owner_failed"`, `"partial_report"` in user_flows
- operations has batch pointer without `--owners-file` or `owner_type`
- getting_started links batch to user_flows

## Validation Architecture

| Behavior | Requirement | Test Type | Command |
|----------|-------------|-----------|---------|
| Shared-asset batch preview/execute aggregates retained_shared_assets | PROOF-05 | integration | `mix test test/rindle/owner_erasure_batch_proof_test.exs --only describe:"PROOF-05"` |
| Partial failure commits early owners; partial_report + DB state | PROOF-05 | integration | same |
| First-owner failure yields empty partial_report.owners | PROOF-05 | integration | same |
| Phase 68 baseline unchanged | PROOF-05 | regression | `mix test test/rindle/owner_erasure_batch_test.exs` |
| Batch narrative in user_flows Story 5 | TRUTH-03 | docs parity | `mix test test/install_smoke/docs_parity_test.exs` |
| Ops/getting_started thin pointers | TRUTH-03 | docs parity | same |
| Stale bulk-orchestration deferral removed | TRUTH-03 | docs parity | same (refute old phrase) |

## Plan Split Recommendation

| Plan | Wave | Scope | Requirements |
|------|------|-------|--------------|
| 70-01 | 1 | Fixtures, counting repo, proof test file | PROOF-05 |
| 70-02 | 2 | Guides + docs_parity_test.exs | TRUTH-03 |

Wave 2 depends on Wave 1 only for verification command cohesion — guides can technically land in parallel but sequential keeps parity flip atomic with guide prose.

## RESEARCH COMPLETE
