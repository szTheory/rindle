# Phase 70: Pattern Map

**Phase:** 70 - Proof & adopter guidance
**Generated:** 2026-05-27

## Files to Create/Modify

| File | Role | Closest Analog | Key Pattern |
|------|------|----------------|-------------|
| `test/support/owner_erasure_batch_fixtures.ex` | Shared batch test fixtures | `owner_erasure_batch_test.exs` private helpers | TestProfile, User, insert_asset/insert_attachment |
| `test/support/counting_failing_txn_repo.ex` | Fail Nth transaction for partial-failure proof | `broker_test.exs` FailingTransactionRepo + TestRepoProbe | put_env :repo + delegate reads |
| `test/rindle/owner_erasure_batch_proof_test.exs` | PROOF-05 gap scenarios | `owner_erasure_test.exs` shared-asset tests | describe "PROOF-05: …" blocks |
| `guides/user_flows.md` | Batch erasure support truth | Story 5 single-owner section | canonical narrative + deferrals |
| `guides/operations.md` | Thin batch pointer | existing owner-erasure blurb (~line 32) | cross-link only |
| `guides/getting_started.md` | Forward link | existing user_flows pointer (~line 242) | one sentence |
| `test/install_smoke/docs_parity_test.exs` | Vocabulary freeze | owner-erasure test (~line 251) | snippet assert/refute |

## Analog Excerpts

### Shared-asset single-owner fixture (`test/rindle/owner_erasure_test.exs`)

```elixir
shared_asset = insert_asset("assets/shared/original.jpg")
owner_shared_attachment = insert_attachment(shared_asset, owner, "banner")
_other_shared_attachment = insert_attachment(shared_asset, other_owner, "hero")

assert report.retained_shared_assets == %{count: 1, entries: [...]}
```

### Batch happy-path baseline (`test/rindle/owner_erasure_batch_test.exs`)

```elixir
assert {:ok, batch} = Rindle.erase_batch_owner_erasure([owner1, owner2])
refute Repo.get(MediaAttachment, attachment1.id)
refute Repo.get(MediaAttachment, attachment2.id)
```

### Repo injection (`test/rindle/upload/broker_test.exs`)

```elixir
previous_repo = Application.get_env(:rindle, :repo)
Application.put_env(:rindle, :repo, FailingTransactionRepo)
on_exit(fn ->
  case previous_repo do
    nil -> Application.delete_env(:rindle, :repo)
    value -> Application.put_env(:rindle, :repo, value)
  end
end)
```

### Partial failure tuple (`lib/rindle.ex`)

```elixir
{:halt, {:error, {:batch_owner_failed, %{
  owner: owner_ref(owner),
  reason: reason,
  partial_report: build_batch_report(mode, partial_entries)
}}}}
```

### Docs parity owner-erasure freeze (`test/install_smoke/docs_parity_test.exs`)

```elixir
for snippet <- [
  "preview_owner_erasure/2",
  "bulk orchestration",  # Phase 70: replace with batch snippets
  ...
] do
  assert normalized =~ snippet
end
```

### Thin ops pointer pattern (`guides/operations.md`)

```markdown
The supported account-deletion surface is `Rindle.preview_owner_erasure/2` plus
`Rindle.erase_owner/2`. See [`user_flows.md`](user_flows.md) for the canonical flow.
```

## PATTERN MAPPING COMPLETE
