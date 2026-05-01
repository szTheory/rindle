---
phase: 19-convenience-api-additions
reviewed: 2026-05-01T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - CHANGELOG.md
  - lib/rindle.ex
  - lib/rindle/error.ex
  - mix.exs
  - test/rindle/api_surface_boundary_test.exs
  - test/rindle/convenience_api_test.exs
findings:
  critical: 0
  warning: 3
  info: 5
  total: 8
status: issues_found
---

# Phase 19: Code Review Report

**Reviewed:** 2026-05-01
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 19 introduces the `Rindle.Error` exception module and seven new public
helpers on the `Rindle` facade (`attachment_for/2,3`, `ready_variants_for/1`,
`attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4`), plus the
ExDoc Facade group and `[Unreleased]` CHANGELOG entries. The implementation is
mostly clean, well-documented, and idiomatic.

The review found three correctness/contract issues that should be resolved
before this lands in a tagged release: the bang variants for delivery
(`url!/3` and `variant_url!/4`) advertise re-raising adapter exceptions but
their `:storage_adapter_exception` clauses are unreachable because the
`Rindle.Delivery` layer never wraps adapter exceptions. `attach!/4` is the
only bang variant that does not raise `Ecto.InvalidChangesetError` for
changeset reasons — this is documented but is an unexpected asymmetry across
the bang surface. Several smaller polish items are listed under Info.

No security issues, data-loss risks, or crashes were found.

## Warnings

### WR-01: `url!/3` and `variant_url!/4` claim to re-raise storage-adapter exceptions, but the `:storage_adapter_exception` clause is unreachable

**File:** `lib/rindle.ex:460-474` (`url!/3`) and `lib/rindle.ex:498-512` (`variant_url!/4`)

**Issue:** Both bangs include a clause:

```elixir
{:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
  raise exception
```

…and both `@doc`s (lines 457 and 495) advertise: "re-raises the original
exception for storage adapter exceptions."

However, `Rindle.url/3` and `Rindle.variant_url/4` delegate to
`Rindle.Delivery.url/3` and `Rindle.Delivery.variant_url/4`, neither of
which wraps adapter calls in `try/rescue` (see `lib/rindle/delivery.ex:97-117`
and `:189-195`). The `{:storage_adapter_exception, _}` shape is only
produced by `Rindle.invoke_storage/3` (line 667-676), which is **not**
on the call path for `url/3` or `variant_url/4`.

In practice, when `adapter.url/2` raises, the exception bubbles directly out
of `Rindle.url/3` (and therefore `Rindle.url!/3`) without ever entering the
`case` statement. The clause is dead code, and the documented contract
("the bang re-raises adapter exceptions") is misleading: the bang is not
involved at all — the raw exception simply propagates because the non-bang
also fails to convert it into a tagged `{:error, _}`.

This is a real inconsistency relative to `upload!/3` (which goes through
`store/4` → `invoke_storage/3` and therefore *does* see
`{:error, {:storage_adapter_exception, _}}`), and the test suite does not
cover the adapter-raise path for `url!/3` or `variant_url!/4` (see
`test/rindle/convenience_api_test.exs:265-307`), so the gap is silent.

**Fix (pick one):**

1. Either route delivery URL calls through `invoke_storage/3` so adapter
   raises become tagged errors and the bang's clause is actually exercised:

   ```elixir
   def url(profile, key, opts \\ []) do
     # Wrap adapter exceptions consistently with the rest of the facade.
     try do
       Rindle.Delivery.url(profile, key, opts)
     rescue
       e -> {:error, {:storage_adapter_exception, e}}
     end
   end
   ```

2. Or drop the dead `{:storage_adapter_exception, _}` clause from `url!/3`
   and `variant_url!/4` and remove the misleading sentence from each `@doc`.
   The raw exception will still propagate (which matches today's behavior).

Option 1 is the more consistent choice — the rest of the facade (`store/4`,
`download/4`, `delete/3`, `head/3`, `presigned_put/4`, `upload/3`) already
normalizes adapter raises into `{:error, {:storage_adapter_exception, _}}`,
so adopters reasonably expect `url/3` and `variant_url/4` to do the same.

Either fix should add a regression test mirroring
`test/rindle/convenience_api_test.exs:239-262` (the `upload!/3` adapter-raise
case) for `url!/3` and `variant_url!/4`.

---

### WR-02: `attach!/4` is the only bang variant that does not raise `Ecto.InvalidChangesetError` for changeset failures

**File:** `lib/rindle.ex:285-299`

**Issue:** Compare the case clauses across the bang variants:

| Bang | Has `%Ecto.Changeset{}` clause? |
| --- | --- |
| `attach!/4` (line 288) | **No** |
| `detach!/3` (line 304) | Yes (line 309) |
| `upload!/3` (line 582) | Yes (line 587) |
| `url!/3` (line 460) | Yes (line 465) |
| `variant_url!/4` (line 498) | Yes (line 503) |

`attach/4` *can* return `{:error, %Ecto.Changeset{}}` — the `Ecto.Multi.insert(:attachment, ...)`
step on line 196-204 propagates a changeset on FK or unique-constraint
violations (see `MediaAttachment.changeset/2:53-54`). Today, that changeset
falls through `attach!/4`'s catch-all (line 296) and is wrapped in
`Rindle.Error{action: :attach, reason: %Ecto.Changeset{...}}`.

The behavior is documented (`lib/rindle.ex:285` — "Database constraint
failures (e.g., foreign-key violations) surface as `Rindle.Error` with the
underlying changeset as the reason"), and the test at
`test/rindle/convenience_api_test.exs:192-199` locks it in. So the
asymmetry is intentional, not accidental.

However:

1. Adopters following the standard Elixir bang convention (and the pattern
   of every *other* `Rindle.*!` function) will be surprised. The whole point
   of `Ecto.InvalidChangesetError` is that `Phoenix.Endpoint`'s default
   `Plug.Exception` rescuer renders it as a 422; wrapping it in
   `Rindle.Error` defeats that.
2. `Rindle.Error.message/1`'s catch-all will `inspect/1` the entire
   changeset, producing a multi-line, near-unreadable error message in
   logs and HTTP 500 pages.
3. The `@doc` claim that this is changeset-as-reason "for FK violations"
   undersells the issue — it covers *all* changeset failures from
   `attach/4`, including unique-constraint violations from concurrent
   attaches.

**Fix:** Add a `%Ecto.Changeset{} = cs ->` clause to `attach!/4`, matching
the other four bang variants:

```elixir
def attach!(asset_or_id, owner, slot, opts \\ []) do
  case attach(asset_or_id, owner, slot, opts) do
    {:ok, attachment} ->
      attachment

    {:error, %Ecto.Changeset{} = cs} ->
      raise Ecto.InvalidChangesetError, action: :insert, changeset: cs

    {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
      raise exception

    {:error, reason} ->
      raise Error, action: :attach, reason: reason
  end
end
```

Then update the `@doc` (line 285) to drop the "with the underlying changeset
as the reason" sentence and update the test on line 192-199 to assert
`assert_raise Ecto.InvalidChangesetError`.

If the asymmetry is *deliberate* (e.g., upstream phase decision), the
divergence and rationale should be called out prominently in
`Rindle.Error`'s `@moduledoc` and in the CHANGELOG entry, not buried in a
single `attach!/4` `@doc` line.

---

### WR-03: Public-facade `@doc` strings on bang variants are written as one-line strings, not multi-line `@doc """ ... """` blocks

**File:** `lib/rindle.ex:285, 301, 457, 495, 579`

**Issue:** Every other public function on `Rindle` documents itself via a
multi-line `@doc """ ... """` block with an `## Examples` section (see
`url/3` at line 439, `variant_url/4` at line 476, `upload/3` at line 514).
The bang variants added in Phase 19 break that pattern — they use a
single-line `@doc "Same as `…` but raises..."` form with no `## Examples`,
no expanded contract, and no description of the success-shape return.

This matters for two reasons specific to this codebase:

1. The Phase 19 CONTEXT calls `mix doctor --raise` mandatory in CI with
   95% spec / 100% module-doc thresholds. While `mix doctor` will accept
   single-line docstrings, it does not validate quality — adopters reading
   HexDocs will see a stub paragraph next to fully-documented siblings.
2. The deprecated/legacy `verify_upload/2` (line 105-125) and the
   `log_variant_processing_failure/3` shim (line 660-665) both have
   richer docs than the brand-new public bangs.

**Fix:** Convert each one-line `@doc` to a multi-line block with a
`## Examples` section, e.g.:

```elixir
@doc """
Same as `attach/4` but raises on failure.

Raises:

  * `Rindle.Error` for non-changeset, non-adapter-exception failures
  * the original exception for storage-adapter raises
  * (after WR-02 fix) `Ecto.InvalidChangesetError` for changeset failures

## Examples

    iex> %MediaAttachment{} = Rindle.attach!(asset, %MyApp.User{id: id}, "avatar")

"""
```

Apply the same treatment to `detach!/3`, `upload!/3`, `url!/3`, and
`variant_url!/4`.

## Info

### IN-01: `attachment_for/3` raises an opaque error when `preload: nil` is passed

**File:** `lib/rindle.ex:349-364`

**Issue:** `Keyword.get(opts, :preload, [:asset])` returns `nil` (not the
default) when the caller explicitly passes `preload: nil`. `repo.preload(attachment, nil)`
then raises `FunctionClauseError` from deep inside Ecto. Adopters who think
they're disabling preloading by passing `nil` will get a confusing
stacktrace.

**Fix:** Either normalize `nil` to `[]`, or document that `preload: []`
(not `preload: nil`) disables preloading:

```elixir
preloads = Keyword.get(opts, :preload, [:asset]) || []
```

The docstring already says to pass `preload: []` to disable, so this is a
defensive improvement, not a contract change.

---

### IN-02: `Rindle.Error.t()` permits `nil` action / `nil` reason but `message/1` produces gibberish for them

**File:** `lib/rindle/error.ex:27-54`

**Issue:** `defexception [:action, :reason]` defaults both fields to `nil`.
Calling `raise Rindle.Error` with no args (or only one of the two) yields
`message: "could not : nil"`. The `@type t` permits this state.

**Fix:** Either declare `@enforce_keys [:action, :reason]` on the
exception (forces all callers to set both), or guard `message/1` against
the nil case:

```elixir
defexception [:action, :reason]
@enforce_keys [:action, :reason]
```

`@enforce_keys` cannot be combined with `defexception` defaults directly,
so the cleaner option is a guard:

```elixir
def message(%{action: nil, reason: reason}),
  do: "Rindle.Error: #{inspect(reason)}"
```

---

### IN-03: `attach!/4` doc-string mentions "Database constraint failures … surface as `Rindle.Error` with the underlying changeset as the reason" — but `Rindle.Error.message/1` will inspect-print the whole changeset

**File:** `lib/rindle/error.ex:52-54` interacting with `lib/rindle.ex:296`

**Issue:** Independent of WR-02 (which proposes converting attach!'s
changeset path to `Ecto.InvalidChangesetError`), if the current behavior is
kept, `Rindle.Error.message/1`'s catch-all branch calls `inspect(reason)`
on a full `%Ecto.Changeset{}` struct. That produces a 30+ line message
including the cast attrs, validations, action, repo, etc. — unreadable in
logs and 500-page bodies.

**Fix:** Add a dedicated branch to `Rindle.Error.message/1` for the
changeset case:

```elixir
def message(%{action: action, reason: %Ecto.Changeset{} = cs}) do
  errors =
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)

  "could not #{action}: #{inspect(errors)}"
end
```

This is moot if WR-02 is accepted (the changeset never reaches `Rindle.Error`
in that case).

---

### IN-04: `get_owner_info/1` silently accepts `id: nil` structs

**File:** `lib/rindle.ex:403-405`

**Issue:** `defp get_owner_info(%{__struct__: _, id: id}), do: {to_string(module), id}`
matches any struct with an `:id` field, including not-yet-persisted ones
where `id` is `nil`. `attachment_for/3` then runs a query with
`owner_id == nil`, which the database evaluates as `NULL = NULL → unknown`
and silently returns `nil`. Same hazard for `attach/4` and `detach/3`.

This is pre-existing behavior, not introduced in Phase 19, but `attachment_for`
inherits it. Worth noting because it interacts with `Phoenix.LiveView`
patterns where unsaved structs can sneak in.

**Fix (optional, defensive):**

```elixir
defp get_owner_info(%{__struct__: _, id: nil}),
  do: raise ArgumentError, "owner struct must have a non-nil :id"
defp get_owner_info(%{__struct__: module, id: id}),
  do: {to_string(module), id}
```

---

### IN-05: `defp get_asset_id/1` and `defp get_owner_info/1` are placed mid-file between public functions

**File:** `lib/rindle.ex:400-405`

**Issue:** These two private helpers are defined on lines 400-405,
sandwiched between `ready_variants_for/1` and `download/4`. The Elixir
convention is to group all `defp`s at the bottom of the module
(`invoke_storage/3`, `normalize_storage_result/1`, `normalize_upload/1` on
lines 667-698 follow this).

This is pre-existing — Phase 19 added new public functions around this
block but didn't introduce the placement. It is, however, a good time to
move them, since the diff is already touching the area.

**Fix:** Move `get_asset_id/1` and `get_owner_info/1` down to the bottom of
the module alongside the other private helpers.

---

_Reviewed: 2026-05-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
