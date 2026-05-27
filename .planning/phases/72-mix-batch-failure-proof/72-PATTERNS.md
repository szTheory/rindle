# Phase 72 — Pattern Map

**Phase:** 72 — Mix Batch Failure Proof
**Mapped:** 2026-05-27

## Files to Modify

| File | Role | Closest analog |
|------|------|----------------|
| `test/rindle/batch_owner_erasure_task_test.exs` | Target — add PROOF-06 test | Same file (existing 6 tests) |

## Pattern: API partial failure → CLI proof

**Source:** `test/rindle/owner_erasure_batch_proof_test.exs` (PROOF-05)

```elixir
CountingFailingTxnRepo.with_counting_repo(2, fn ->
  assert {:error, {:batch_owner_failed, detail}} =
           Rindle.erase_batch_owner_erasure([owner1, owner2])

  assert length(detail.partial_report.owners) == 1
  refute Repo.get(MediaAttachment, attachment1.id)
  assert Repo.get(MediaAttachment, attachment2.id)
end)
```

**CLI adaptation:** wrap `Task.run(["--owners-file", path, "--execute"])` inside the same `with_counting_repo(2, ...)`, assert `catch_exit(...) == {:shutdown, 1}` and Mix shell messages.

## Pattern: Mix task failure exit

**Source:** `test/rindle/batch_owner_erasure_task_test.exs` (existing)

```elixir
assert catch_exit(Task.run([])) == {:shutdown, 1}
assert_received {:mix_shell, :error, [msg]}
```

## Pattern: Mix shell setup

**Source:** `test/rindle/batch_owner_erasure_task_test.exs` setup block

```elixir
setup do
  previous_shell = Mix.shell()
  Mix.shell(Mix.Shell.Process)
  on_exit(fn -> Mix.shell(previous_shell) end)
  :ok
end
```

## Pattern: Error copy contract

**Source:** `test/rindle/owner_erasure_batch_error_test.exs`

```elixir
assert message =~ "1 owner(s) completed"
assert message =~ "partial_report"
```

## PATTERN MAPPING COMPLETE
