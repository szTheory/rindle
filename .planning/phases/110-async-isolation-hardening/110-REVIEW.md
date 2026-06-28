---
phase: 110-async-isolation-hardening
reviewed: 2026-06-28T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - lib/rindle/config.ex
  - test/support/counting_failing_txn_repo.ex
  - test/async_safety_guard_test.exs
  - test/rindle/config/config_test.exs
  - test/rindle/config/repo_override_isolation_test.exs
  - test/rindle/batch_owner_erasure_task_test.exs
  - test/rindle/delivery/streaming_dispatch_test.exs
  - test/rindle/owner_erasure_batch_proof_test.exs
  - test/rindle/ops/upload_maintenance_test.exs
  - test/rindle/storage/local_tus_test.exs
  - test/rindle/upload/broker_test.exs
  - test/rindle/upload/lifecycle_integration_test.exs
  - test/rindle/upload/tus_local_backing_test.exs
  - test/rindle/upload/tus_plug_test.exs
  - test/rindle/workers/maintenance_workers_test.exs
  - test/adopter/canonical_app/lifecycle_test.exs
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 110: Code Review Report

**Reviewed:** 2026-06-28
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Phase 110 makes `Rindle.Config.repo/0` consult a process-dictionary repo override
(walking `self()` then the `$callers` chain) before the application-config fallback,
migrates the `CountingFailingTxnRepo` test double off the global `:rindle, :repo`
swap onto that process-local seam, and re-promotes several suites to `async: true`.
The production change in `lib/rindle/config.ex` ships as Hex 0.3.2, so it received
extra rigor.

I verified the load-bearing correctness claims empirically against the compiled
module:

- **Default no-override path is behavior-preserving.** With no override set,
  `repo()` returns `Rindle.Repo` (unset) / the configured app-env repo. The new
  `with nil <- repo_override(self())` adds a single `Process.get` returning `nil`
  before the unchanged `Application.get_env/3` — confirmed by running the real
  module.
- **`$callers` inheritance works.** A `Task.async` child resolves the override its
  parent set; an unrelated `spawn`ed process (no `$callers`) does not — the
  isolation property the milestone sells (and `RepoOverrideIsolationTest` locks).
- **`Enum.find_value` + the `caller != pid && repo_override(caller)` lambda is
  correct.** When the self-guard fails the lambda yields `false`, and `find_value`
  correctly treats `false` as falsy and keeps scanning — no premature short-circuit.
- **Dead/exited caller pids are safe.** `Process.info(pid, :dictionary)` on a dead
  pid returns `nil`, which the `_  -> nil` clause handles — no crash.
- **`self()` in the `process_get/2` guard is valid** and dispatches as intended.
- **The tuple-keyed read is correct.** `List.keyfind(dict, {Rindle.Config,
  :repo_override}, 0)` over the `Process.info(:dictionary)` pairs is the right tool
  (a tuple key cannot be read with `Keyword.get/3`).
- Clean `mix compile --warnings-as-errors`.

No BLOCKER-class defects were proven. The findings below are one genuine
infinite-recursion edge case (low practical reachability, hence WARNING not
BLOCKER), two `@spec`/contract mismatches on the new public-ish seam, and minor
quality items.

## Warnings

### WR-01: `$callers` cycle causes unbounded recursion in `repo/0`

**File:** `lib/rindle/config.ex:88-100`

**Issue:** `repo_override/1` recurses through the `$callers` chain with only a
single-level self-guard (`caller != pid`). That guard prevents a one-hop
self-reference but does NOT prevent a multi-pid cycle. If process A's `$callers`
contains B and B's `$callers` contains A (and neither holds an override), the walk
recurses A→B→A→B… forever. I reproduced this deterministically: building two live
processes with mutually-referential `$callers` and calling the resolver hangs (>3s,
killed). Because `repo/0` is on the hot path of every DB-touching production call
(`lib/rindle.ex`, every worker, `admin/queries.ex`, `delivery.ex`, etc.), a cyclic
`$callers` would wedge the calling process.

Practical reachability is low: OTP populates `$callers` monotonically with ancestor
pids and does not normally create cycles, and Rindle never writes `$callers` itself.
That is why this is a WARNING, not a BLOCKER. But the resolver reads *arbitrary*
process dictionaries it does not own, the function now ships to adopters in 0.3.2,
and the cost of a bounded walk is trivial — defense-in-depth is warranted for a
library primitive on the universal repo-resolution path.

**Fix:** Track visited pids (or simply bound the walk depth) so a cycle terminates:

```elixir
defp repo_override(pid), do: repo_override(pid, MapSet.new())

defp repo_override(pid, seen) do
  if MapSet.member?(seen, pid) do
    nil
  else
    case process_get(pid, @repo_override_key) do
      nil -> caller_repo_override(pid, MapSet.put(seen, pid))
      mod -> mod
    end
  end
end

defp caller_repo_override(pid, seen) do
  pid
  |> process_get(:"$callers")
  |> List.wrap()
  |> Enum.find_value(fn caller -> caller != pid && repo_override(caller, seen) end)
end
```

### WR-02: `put_repo_override/1` / `delete_repo_override/0` `@spec`s misdescribe their return values

**File:** `lib/rindle/config.ex:21-26`

**Issue:** Both seam functions delegate to `Process.put/2` and `Process.delete/1`,
whose return value is the *previous* value stored under the key, not the new value.

- `put_repo_override(mod)` is `@spec ... :: module() | nil` but returns whatever was
  previously stored (the *old* override or `nil`), never the `mod` just written. A
  caller reading the return value to confirm the new override would be wrong.
- `delete_repo_override/0` is `@spec ... :: module() | nil` and happens to return the
  prior value — but the doc/intent reads as if it returns the cleared module; the
  spec is coincidentally satisfiable yet semantically misleading.

Additionally, `@spec put_repo_override(module())` excludes `nil`, but
`Process.put(key, nil)` is a no-op-equivalent that leaves `repo()` resolving via app
config (verified). The contract should either forbid `nil` explicitly or document
that passing `nil` does not install an override.

**Fix:** Either correct the specs to reflect "returns the previously-stored
override" or have the functions return `:ok` to signal the side-effecting,
fire-and-forget intent the test double actually relies on:

```elixir
@spec put_repo_override(module()) :: :ok
def put_repo_override(mod) when is_atom(mod) and not is_nil(mod) do
  Process.put(@repo_override_key, mod)
  :ok
end

@spec delete_repo_override() :: :ok
def delete_repo_override do
  Process.delete(@repo_override_key)
  :ok
end
```

### WR-03: `with nil <- repo_override(self())` silently re-runs app-config fallback if an override resolves to `nil`-equivalent

**File:** `lib/rindle/config.ex:12-16`

**Issue:** `repo/0` uses `with nil <- repo_override(self()) do Application.get_env(...) end`.
The `with` returns the resolved override only when it is a non-`nil` truthy term.
This is correct today because `caller_repo_override/1` uses `Enum.find_value`, which
returns `nil` when no caller matches. But the contract is fragile: if a future
caller ever installs `false` as an override value (e.g. via a refactor that stores a
boolean flag, or `put_repo_override(false)` — not blocked by the spec), `with nil <-`
would NOT match `false`, so `repo/0` would return `false` as the "repo" and the next
`repo().get(...)` would raise `UndefinedFunctionError` on `false`. The resolver only
guarantees `nil`-or-module today, but nothing enforces it at the `repo/0` boundary.

**Fix:** Make the boundary explicit so only a real module short-circuits the fallback:

```elixir
def repo do
  case repo_override(self()) do
    mod when is_atom(mod) and not is_nil(mod) -> mod
    _ -> Application.get_env(:rindle, :repo, Rindle.Repo)
  end
end
```

This also future-proofs WR-02's `nil`/non-module inputs.

## Info

### IN-01: `fail_reason` config branch in the counting double is dead

**File:** `test/support/counting_failing_txn_repo.ex:9, 88-91`

**Issue:** `with_counting_repo/2` stores only `fail_after: fail_after` in
`@config_key`. `fail_reason/0` reads `Keyword.get(@config_key_contents, :fail_reason,
:forced_batch_failure)` but `:fail_reason` is never written by any caller (grep of
`test/` finds no `fail_reason:` producer), so the force-fail tuple's reason is always
`:forced_batch_failure`. The configurability is unreachable.

**Fix:** Either expose `fail_reason` through `with_counting_repo/3` (and the callers
that want a specific reason), or drop `fail_reason/0` and inline the constant to
remove the dead branch.

### IN-02: `transaction(multi)` / `transaction(multi, opts)` clauses are unguarded catch-alls

**File:** `test/support/counting_failing_txn_repo.ex:32-38, 48-54`

**Issue:** The double defines `transaction(fun) when is_function(fun, 0)` followed by
`transaction(multi)` with no guard, and the same for the arity-2 pair. The unguarded
clauses are intended for `%Ecto.Multi{}` but will match *anything* that is not a
0-arity function (e.g. a function of the wrong arity, an atom, a struct), silently
forwarding it to `Rindle.Repo.transaction/1`. This is acceptable for a test double
that mirrors `Ecto.Repo`'s own loose contract, but a typo'd call would be masked
rather than surfaced.

**Fix (optional hardening):** Guard the Multi clauses with
`when is_struct(multi, Ecto.Multi)` so an unexpected argument fails loudly instead of
being counted-and-forwarded.

### IN-03: Comment in `repo_override_isolation_test.exs` overstates concurrency

**File:** `test/rindle/config/repo_override_isolation_test.exs:31-66`

**Issue:** The test narrative repeatedly says process B runs its real transaction
"concurrently" / "WHILE A's window is open." In fact `with_counting_repo/2` runs its
callback **inline in the test process**, and B is a bare `spawn` that blocks on `:go`
sent from inside that callback; the `assert_receive` then blocks the test process
until B replies. The interleaving is cooperative, not a contended race — the test
proves *isolation of resolution* (B sees `Rindle.Repo`, not the double), which is the
correct and sufficient property, but the "concurrent" framing could mislead a future
maintainer into thinking it exercises a data race it does not. Documentation-only;
the assertion itself is sound.

**Fix:** Soften the comments to "B resolves the repo while A's override is installed"
rather than implying parallel transaction execution.

### IN-04: `async_safety_guard_test.exs` magic thresholds will drift

**File:** `test/async_safety_guard_test.exs:81-86`

**Issue:** The meta-guard asserts `length(files) > 100` and `length(modules) >= 60`.
These hardcoded counts are coupled to the current size of the test tree and will
silently mis-fire (or need churny edits) as the suite grows or shrinks — a flaky-by-
construction tripwire of the kind this milestone is otherwise trying to eliminate.
They are floors (`>`/`>=`) so they fail only on large shrinkage, but the `>= 60`
async-module floor is close enough to the live count to be brittle if a few modules
are converted back to `async: false`.

**Fix:** Either derive the expected floor from a computed inventory, or relax the
assertion to a structural invariant (e.g. "the guard sees itself and at least one
known async module") rather than a numeric threshold that encodes today's headcount.

---

_Reviewed: 2026-06-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
