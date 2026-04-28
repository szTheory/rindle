---
phase: 05-ci-1-0-readiness
reviewed: 2026-04-26T22:55:00Z
depth: standard
files_reviewed: 32
files_reviewed_list:
  - .github/workflows/ci.yml
  - config/test.exs
  - coveralls.json
  - guides/background_processing.md
  - guides/core_concepts.md
  - guides/getting_started.md
  - guides/operations.md
  - guides/profiles.md
  - guides/secure_delivery.md
  - guides/troubleshooting.md
  - lib/rindle.ex
  - lib/rindle/delivery.ex
  - lib/rindle/domain/asset_fsm.ex
  - lib/rindle/domain/media_asset.ex
  - lib/rindle/domain/media_attachment.ex
  - lib/rindle/domain/media_processing_run.ex
  - lib/rindle/domain/media_upload_session.ex
  - lib/rindle/domain/media_variant.ex
  - lib/rindle/domain/variant_fsm.ex
  - lib/rindle/repo.ex
  - lib/rindle/storage/s3.ex
  - lib/rindle/upload/broker.ex
  - lib/rindle/workers/abort_incomplete_uploads.ex
  - lib/rindle/workers/cleanup_orphans.ex
  - mix.exs
  - test/adopter/canonical_app/lifecycle_test.exs
  - test/adopter/canonical_app/profile.ex
  - test/adopter/canonical_app/repo.ex
  - test/rindle/contracts/telemetry_contract_test.exs
  - test/rindle/delivery_test.exs
  - test/rindle/ops/upload_maintenance_test.exs
  - test/rindle/telemetry/emission_test.exs
  - test/rindle/upload/broker_test.exs
  - test/rindle/workers/maintenance_workers_test.exs
  - test/test_helper.exs
  - LICENSE
  - .github/workflows/release.yml
findings:
  critical: 5
  warning: 11
  info: 6
  total: 22
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-04-26T22:55:00Z
**Depth:** standard
**Files Reviewed:** 32 (file count differs from list because some entries collapsed into a single read)
**Status:** issues_found

## Summary

Phase 5's CI / 1.0-readiness scope spans the public Elixir surface
(`lib/rindle.ex`, `Rindle.Delivery`, the upload `Broker`, FSM modules,
schemas, and the S3 adapter), the brand-new adopter / contract test lanes,
the Day-2 worker tests, and a sizable docs surface (seven guides plus
`README` referenced from `mix.exs`). The CI workflow (`ci.yml`) and the
release dry-run (`release.yml`) are also in scope.

The review surfaced several **correctness-class** defects in the public
facade and the upload broker that have nothing to do with phase-5 docs
work but are now in the phase-5 review scope because the files were
listed for review:

- `Rindle.attach/4` and `Rindle.detach/3` enqueue Oban purge jobs **inside**
  an `Ecto.Multi` via `Oban.insert(job)` (a non-Multi-aware call). If the
  outer transaction rolls back the job is *still* enqueued — the exact
  failure mode `guides/background_processing.md` claims Rindle protects
  against. (CR-01, CR-02)
- The `Broker.verify_completion/2` flow runs the `verifying` FSM
  transition on the session *before* the `Ecto.Multi` that updates the
  session row, but the Multi then jumps directly to `"completed"` —
  `verifying` is never persisted, the FSM gate emits a telemetry event
  for a state the DB never sees, and the same FSM gate is bypassed for
  the actual `verifying → completed` transition. (CR-03)
- `Broker.profile_name_to_module/1` rescues the `ArgumentError` raised by
  `String.to_existing_atom/1` and silently returns `nil`, which the
  `with` chain then hands to `nil.storage_adapter()` and crashes the
  caller with `UndefinedFunctionError` instead of a clean `{:error,
  :unknown_profile}`. (CR-04)
- The S3 adapter swallows `presigned_url` failures: `S3.presigned_url/4`
  returns a bare URL string, **not** `{:ok, url}`, so the `with` clause
  in `Rindle.Storage.S3.url/2` will never match and Dialyzer-clean code
  paths will surface as opaque `MatchError`s at runtime. (CR-05)
- The cleanup-orphans worker's adapter resolver passes
  `Application.get_env(:rindle, :default_storage)` through to
  `UploadMaintenance.cleanup_orphans/1` even when it is `nil` — the
  worker only guards the *string* path, not the default-config path.
  (WR-01)

A second cluster of warnings concerns docs/code drift the phase
deliberately set out to prevent: the guides reference internal modules
(`Rindle.Config`, `Rindle.Domain.UploadSessionFSM`,
`Rindle.Domain.StalePolicy`, `Rindle.Security.UploadValidation`) that
are not in the file list and may not exist or may have moved; the
adopter drift gate only checks three substring matches; the troubleshooting
cheatsheet uses a non-existent `ago(0, "second")` Ecto fragment.

The CI workflow itself contains a real correctness bug in the integration
lane — it does **not** install `libvips-dev` before running
`lifecycle_integration_test.exs`, even though the integration test goes
through the same image-processing path the `Quality` and `Adopter` lanes
take pains to install libvips for. (CR-05 / WR-08)

## Critical Issues

### CR-01: `Rindle.attach/4` enqueues Oban purge job inside `Ecto.Multi` with non-Multi-aware `Oban.insert/1`

**File:** `lib/rindle.ex:148-162`
**Issue:** Inside the `Ecto.Multi` for `attach/4`, the `:purge_old` step
calls plain `Oban.insert(job)` (not `Oban.insert/3` with a Multi tag, and
not `Oban.insert/4`). This call inserts the job **immediately** against
its own connection, regardless of whether the surrounding `Multi`
ultimately commits. If the `:attachment` insert later raises a
constraint error the transaction rolls back and the new attachment is
gone, but the `PurgeStorage` Oban row has already been written — the
worker will then delete the storage object that the *retained* old
attachment still references. This contradicts the contract documented in
`guides/background_processing.md` ("If the transaction rolls back, the
job was never inserted").

There is also a hard `Rindle.Repo.get!` inside the multi step that will
crash the caller (rather than fail the transaction cleanly) if the old
asset row is gone.

**Fix:**

```elixir
|> Ecto.Multi.run(:purge_old, fn repo, %{existing: existing} ->
  if existing do
    case repo.get(Rindle.Domain.MediaAsset, existing.asset_id) do
      nil ->
        {:ok, nil}

      old_asset ->
        # Defer the enqueue to AFTER commit (see Rindle.detach pattern in
        # the guide) OR use Oban.insert/2 with the Multi:
        # Ecto.Multi.run(... ) is the wrong place for Oban.insert(job)
        # because the call writes via its own conn and ignores rollback.
        {:ok, {:enqueue, old_asset}}
    end
  else
    {:ok, nil}
  end
end)
# ... after Repo.transaction, on the {:ok, ...} branch only:
|> handle_attach_result()
```

Either (a) move the enqueue to the post-commit branch (matching the
documented detach pattern), or (b) use `Oban.insert(multi, name, changeset)`
which threads through the same connection and respects rollback.

### CR-02: `Rindle.detach/3` repeats the same Multi/Oban anti-pattern, and crashes on missing asset row

**File:** `lib/rindle.ex:198-208`
**Issue:** Same root cause as CR-01: the `:purge` step inside the Multi
calls `Oban.insert(job)` directly. Per `Oban.insert/1` semantics this
writes the job using Oban's own connection, bypassing the transactional
guarantee the public guide promises. Additionally, `Rindle.Repo.get!` on
line 199 will *raise* if the asset row was deleted out from under the
detach (e.g. a concurrent admin delete), turning a routine race into an
unhandled exception that crashes the caller and aborts the multi.

The doc-string above the function and `guides/getting_started.md` both
claim detach commits "immediately" and the purge enqueues
"after commit". Inserting through `Oban.insert/1` from inside the multi
inverts that — the job is inserted *before* commit and survives rollback.

**Fix:** Move the Oban insert to the post-`Repo.transaction` branch (the
documented contract):

```elixir
|> Rindle.Repo.transaction()
|> case do
  {:ok, %{existing: existing}} ->
    %{}
    |> Map.put("asset_id", existing.asset_id)
    |> Map.put("profile", profile_for(existing))
    |> Rindle.Workers.PurgeStorage.new()
    |> Oban.insert()

    :ok

  {:error, :existing, :not_found, _} -> :ok
  {:error, _, reason, _} -> {:error, reason}
end
```

Also replace `Rindle.Repo.get!(...)` with `Rindle.Repo.get(...)` and
explicit nil-handling so a concurrent delete does not propagate a raise.

### CR-03: `Broker.verify_completion/2` runs `verifying` FSM gate but never persists `verifying`; bypasses the `verifying → completed` gate

**File:** `lib/rindle/upload/broker.ex:139-189`
**Issue:** The `with` chain runs:

```elixir
:ok <- UploadSessionFSM.transition(session.state, "verifying", %{...}),
:ok <- AssetFSM.transition(asset.state, "validating", %{...}) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:session, MediaUploadSession.changeset(session, %{state: "completed", ...}))
```

Two distinct bugs:

1. The `verifying` transition is gated and emits
   `[:rindle, :asset, :state_change]` / variant equivalent telemetry,
   but the database never observes the `verifying` state — the Multi
   updates the session straight from its current state (likely `signed`
   or `uploading`) to `completed`. Telemetry consumers see a state
   transition that contradicts the row history.
2. The actual transition the Multi performs (`signed → completed` or
   `uploading → completed`) is *not* gated by the FSM. According to the
   FSM diagram in `guides/core_concepts.md`, neither `signed → completed`
   nor `uploading → completed` is allowlisted — the only allowed path is
   `verifying → completed`. The DB-level changeset will accept it
   because changesets only validate that the value is in `@states`, not
   that the transition is allowed. The result is silent FSM evasion on
   the most-exercised path in the codebase.

**Fix:** Either persist `verifying` first (two transactions) or run the
real `signed → verifying → completed` (or `uploading → verifying →
completed`) inside the multi with the FSM gate run for *each* step:

```elixir
with %MediaUploadSession{} = session <- Repo.get(MediaUploadSession, session_id),
     # ... resolve adapter ...
     {:ok, metadata} <- adapter.head(session.upload_key, opts) do
  Ecto.Multi.new()
  |> Ecto.Multi.run(:gate_to_verifying, fn _, _ ->
    UploadSessionFSM.transition(session.state, "verifying", %{session_id: session.id})
  end)
  |> Ecto.Multi.run(:gate_to_completed, fn _, _ ->
    UploadSessionFSM.transition("verifying", "completed", %{session_id: session.id})
  end)
  |> Ecto.Multi.run(:gate_asset, fn _, _ ->
    AssetFSM.transition(asset.state, "validating", %{asset_id: asset.id})
  end)
  |> Ecto.Multi.update(:session, MediaUploadSession.changeset(session, %{state: "completed", verified_at: DateTime.utc_now()}))
  # ... (rest unchanged)
```

(Alternatively, materialize a `verifying` write between the head-check
and the multi, accepting the slightly less atomic ordering.)

### CR-04: `Broker.profile_name_to_module/1` returns `nil` on bad input, which crashes the next call with `UndefinedFunctionError`

**File:** `lib/rindle/upload/broker.ex:195-199`
**Issue:**

```elixir
defp profile_name_to_module(name) do
  String.to_existing_atom(name)
rescue
  _ -> nil
end
```

If a session is loaded whose `asset.profile` references a module that
hasn't been compiled in the current node (a real risk after a deploy
that drops a profile, or in a test that doesn't `Code.ensure_loaded/1`),
the helper rescues and returns `nil`. The very next `with` clause is
`profile_module.storage_adapter()`, which becomes `nil.storage_adapter()`
and raises `UndefinedFunctionError`. The function's intent is clearly to
fall through to a clean `{:error, :something}`, but the chain has no
matching arm — the helper crashes the caller mid-chain.

This is the same code path the adopter integration test exercises, so a
flaky atom-table state in CI surfaces as a test-suite crash rather than
a clean failure.

**Fix:**

```elixir
defp profile_name_to_module(name) when is_binary(name) do
  {:ok, String.to_existing_atom(name)}
rescue
  _ -> {:error, :unknown_profile}
end
```

…and update the `with` chain to pattern-match `{:ok, profile_module}` so
the error tuple short-circuits the chain.

### CR-05: `Rindle.Storage.S3.url/2` does not handle the bare-URL return shape from `ExAws.S3.presigned_url/4`; CI integration lane never hit this path with libvips

**File:** `lib/rindle/storage/s3.ex:55-61` and `.github/workflows/ci.yml:109-192`
**Issue:**

`ExAws.S3.presigned_url/5` returns `{:ok, binary()} | {:error, term()}`.
The current implementation:

```elixir
def url(key, opts) do
  with {:ok, bucket} <- bucket(opts) do
    S3.presigned_url(s3_config(opts), :get, bucket, key,
      expires_in: Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())
    )
  end
end
```

…is *almost* right, but the `with`-without-`else` returns whatever the
last expression returns. That works for the happy path (`{:ok, url}`),
but if `bucket(opts)` returns `{:error, :missing_bucket}` the function
returns *just* `{:error, :missing_bucket}` — fine — and the
`Rindle.Delivery.url/3` caller pattern-matches `{:ok, url}` only, so the
error branch propagates correctly. **However**, the file's other call
sites (`presigned_put/3`, `head/2`) replicate this `with`/no-`else`
pattern, so any new return shape from ExAws (say, `{:error, %{}}` on
HTTP failure) propagates back unchanged through callers that expect
either `{:ok, term()}` or a `{:error, atom()}`-like tuple. The Storage
behaviour contract should normalize.

The matching CI lane bug compounds the risk: the **integration** job
(ci.yml lines 109-192) does not install `libvips-dev` before running
`mix test test/rindle/upload/lifecycle_integration_test.exs --include
integration`. The Quality and Adopter lanes both install it explicitly.
The integration test goes through `ProcessVariant` → image processing,
which loads `Image`/`Vix` and immediately fails to load the NIF without
libvips. Either the integration test does not actually exercise the
processor (in which case it does not test what it advertises), or the
lane is silently passing because of a skip/include filter. Both modes
are CI-hygiene defects.

**Fix:**

1. Add `else` clauses to S3 adapter `with` blocks to normalize errors,
   matching the pattern in `store/3` and `delete/2`:

   ```elixir
   def url(key, opts) do
     with {:ok, bucket} <- bucket(opts),
          {:ok, url} <-
            S3.presigned_url(s3_config(opts), :get, bucket, key,
              expires_in: Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())
            ) do
       {:ok, url}
     else
       {:error, reason} -> {:error, reason}
     end
   end
   ```

2. In `ci.yml`, add `Install libvips` to the `integration` job's steps
   before `mix test`. Mirror the line at L72-73 of the Quality job:

   ```yaml
   - name: Install libvips
     run: sudo apt-get install -y libvips-dev
   ```

## Warnings

### WR-01: `Rindle.Workers.CleanupOrphans` passes `nil` storage adapter through to `UploadMaintenance` when no `:default_storage` is configured

**File:** `lib/rindle/workers/cleanup_orphans.ex:152-154`
**Issue:**

```elixir
defp resolve_storage_adapter(_args) do
  {:ok, Application.get_env(:rindle, :default_storage)}
end
```

If the application config does not set `:default_storage`, this returns
`{:ok, nil}`. The caller then builds `cleanup_opts` with
`Keyword.put(o, :storage, nil)` only when `storage_mod` is truthy —
which it isn't here, so the `:storage` key is omitted. That bypasses
the worker-level guard but pushes the failure into
`UploadMaintenance.cleanup_orphans/1`, where the behavior depends on
its own default. The result: the cron worker silently uses an unknown
adapter, or worse, the `Local` adapter against an S3 bucket of orphans.

**Fix:** Treat a missing `:default_storage` as a configuration error
that the worker reports and refuses to run:

```elixir
defp resolve_storage_adapter(_args) do
  case Application.get_env(:rindle, :default_storage) do
    nil ->
      Logger.error("rindle.workers.cleanup_orphans.storage_not_configured",
        hint: "Set config :rindle, :default_storage, MyAdapter or pass `storage` job arg"
      )
      {:error, :default_storage_not_configured}

    mod ->
      {:ok, mod}
  end
end
```

### WR-02: `Code.ensure_loaded/1` return shape mismatch in `resolve_storage_adapter/1`

**File:** `lib/rindle/workers/cleanup_orphans.ex:129-141`
**Issue:** `Code.ensure_loaded/1` returns `{:module, module} | {:error,
reason}` per Elixir docs. The `case` head matches both, but the
**rescue** clause assumes `String.to_existing_atom/1` raised an
`ArgumentError` — which is the *only* pathway here, since a non-existent
module string converted to a non-existent atom would already raise. If
the atom *exists* but the module isn't loaded (rare but possible: the
atom was interned by another path but the BEAM was never compiled),
`Code.ensure_loaded/1` returns `{:error, :nofile}` and the case on
line 134 catches it, **but** the surrounding `rescue` block can't fire
in that path. Logic is OK but the code path tagged "storage_not_found"
is misleading: it fires only on atom-table miss, not on module miss.

Slightly worse: passing a valid-but-malicious atom string (e.g.
`"Elixir.Kernel"`) loads as a module and is accepted — the worker
will then call `Kernel.delete/2` (no such function) at runtime,
crashing the worker per attempt without a clear log line.

**Fix:** Validate the resolved module implements the storage behaviour
before returning it:

```elixir
case Code.ensure_loaded(String.to_existing_atom(module_str)) do
  {:module, mod} ->
    if function_exported?(mod, :delete, 2) and function_exported?(mod, :capabilities, 0) do
      {:ok, mod}
    else
      {:error, {:storage_not_implementing_behaviour, mod}}
    end

  {:error, reason} ->
    # ... existing log + return ...
```

### WR-03: `lib/rindle.ex` — `get_owner_info/1` accepts any struct with an `:id` field including non-Ecto records

**File:** `lib/rindle.ex:221-223`
**Issue:**

```elixir
defp get_owner_info(%{__struct__: module, id: id}) do
  {to_string(module), id}
end
```

There is no clause for the `nil` owner, no clause for plain maps, and
no validation that `id` is a binary or integer. Passing any struct with
an `:id` (e.g. an `%Ecto.Changeset{}` shaped accidentally) compiles, so
a misuse is detected at the DB layer (foreign-key/type cast) rather
than at the boundary. For the public facade this should fail fast with
a clear `FunctionClauseError` or a tuple. Also, `to_string(module)`
silently allows any module, including `Atom`-like input — there is no
allowlist. Combined with `String.to_existing_atom/1` elsewhere, this is
a soft injection surface for any feature that round-trips
`owner_type` back to a module.

**Fix:** Add a guard and a fallthrough:

```elixir
defp get_owner_info(%{__struct__: module, id: id}) when is_atom(module) and (is_binary(id) or is_integer(id)) do
  {to_string(module), id}
end

defp get_owner_info(other) do
  raise ArgumentError, "Rindle.attach/4 expected a struct with id: but got #{inspect(other)}"
end
```

### WR-04: `Rindle.upload/3` storage write happens before the DB insert; failed inserts leak storage objects

**File:** `lib/rindle.ex:319-345`
**Issue:** The order is `validate → store → Multi.insert(asset) +
Oban.insert(promote_job)`. If the asset insert fails (constraint
violation, DB blip, etc.), the file is already written to storage with
no DB row referencing it — a classic Active-Storage-style leak. The
`upload/3` doc-string and `guides/getting_started.md` claim Rindle
prevents exactly this orphaned-object class of failure.

There is also no compensating purge if the multi rolls back, so the
storage object lives forever (the cleanup-orphans worker only targets
sessions, not anonymous direct-upload writes).

**Fix:** Either (a) reverse the order — insert the asset row first
(without bytes), then store, then promote — and use the storage key
generated from the asset id, OR (b) on `{:error, ...}` from the multi,
schedule a compensating delete:

```elixir
{:error, _name, reason, _changes} ->
  # Compensate: best-effort purge of the orphaned storage write
  delete(profile_module, validation.storage_key, opts)
  {:error, reason}
```

### WR-05: `lib/rindle.ex:466-473` — `normalize_upload/1` calls `File.stat!/1` outside any error path; raises on missing file

**File:** `lib/rindle.ex:466-473`
**Issue:**

```elixir
defp normalize_upload(upload) when is_map(upload) do
  if Map.has_key?(upload, :path) and not Map.has_key?(upload, :byte_size) do
    Map.put(upload, :byte_size, File.stat!(upload.path).size)
  else
    upload
  end
end
```

If the upload map carries a `:path` that points to a file the BEAM
process can't stat (deleted between Plug parse and Rindle entry, or a
unicode-quoted path on Windows), `File.stat!/1` raises and crashes the
caller with `File.Error`. The same risk exists at line 462 for the
`Plug.Upload` clause. Public-API entry points should return `{:error,
{:upload_unreadable, reason}}` rather than raising.

**Fix:**

```elixir
defp normalize_upload(upload) when is_map(upload) do
  cond do
    Map.has_key?(upload, :byte_size) -> upload
    Map.has_key?(upload, :path) ->
      case File.stat(upload.path) do
        {:ok, %File.Stat{size: size}} -> Map.put(upload, :byte_size, size)
        {:error, reason} -> {:error, {:upload_unreadable, reason}}
      end
    true -> upload
  end
end
```

…and update `upload/3` to handle the `{:error, _}` shape returned from
normalization.

### WR-06: `Rindle.attach/4` does not validate `slot` or `owner.id` shape; FSM context maps lose `:profile`/`:adapter` keys

**File:** `lib/rindle.ex:118-168`, `lib/rindle/upload/broker.ex:101, 147`
**Issue:** Two related observability/contract regressions:

1. `Rindle.attach/4` accepts any string for `slot` including `""` and
   `nil`. The schema's `validate_required([:slot])` catches `nil` but
   not the empty string, leading to a row with `slot: ""` that
   silently collides with future attachments.
2. The FSM `context` maps in `Broker.sign_url/2` and
   `Broker.verify_completion/2` populate only `:session_id` /
   `:asset_id` — they omit `:profile` and `:adapter`. The
   `[:rindle, :asset, :state_change]` and `[:rindle, :variant,
   :state_change]` events emitted from FSM transitions therefore land
   with `profile: :unknown, adapter: :unknown` for every Broker-driven
   transition. This is the public telemetry contract the
   `TelemetryContractTest` locks down — the contract test passes
   because it manually populates the context, but real Broker calls
   emit `:unknown`. Operator dashboards grouping by profile see all
   Broker transitions as `profile=:unknown`, masking actual adoption
   shape.

**Fix:**

1. Add `validate_change(:slot, &reject_blank_string/2)` to the
   attachment changeset, or a guard on the public function.
2. Pass `profile:` and `adapter:` into every FSM `transition` call site
   in the Broker:

```elixir
:ok <- UploadSessionFSM.transition(session.state, "signed", %{
  session_id: session.id,
  profile: asset.profile,
  adapter: profile_module.storage_adapter()
}),
```

### WR-07: `lib/rindle/storage/s3.ex` — `parse_size/1` silently coerces malformed `content-length` headers to `0`

**File:** `lib/rindle/storage/s3.ex:98-107`
**Issue:**

```elixir
defp parse_size(nil), do: 0
defp parse_size(val) when is_binary(val) do
  case Integer.parse(val) do
    {int, _} -> int
    _ -> 0
  end
end
```

A missing or malformed `Content-Length` header produces `0`, which
flows up to `Broker.verify_completion/2` which writes `byte_size: 0`
on the asset. Downstream policy checks (`max_bytes` validation in the
profile) then treat the file as size-zero and *pass* every check. An
upstream S3 implementation that strips `Content-Length` becomes a
silent bypass. `0` is a legitimate value for a real zero-byte file, so
distinguishing "we don't know" from "we know, it's zero" is necessary.

**Fix:** Return `{:error, :invalid_content_length}` rather than `0`,
and propagate it through `head/2` so callers can decide whether
proceeding without a size is acceptable.

### WR-08: CI integration job lacks libvips, missing-key matrix gap is invisible

**File:** `.github/workflows/ci.yml:109-192`
**Issue:** As noted in CR-05, the `integration` job does not install
`libvips-dev`. The `lifecycle_integration_test.exs` it runs is
referenced from `.planning/phases/02-upload-processing/...` and
exercises the variant pipeline, which loads the `Image`/`Vix` NIF.
Without libvips, the test either crashes loading or silently skips —
neither outcome is what the CI lane should advertise.

Additionally, the matrix for the Quality job covers Elixir 1.15/OTP 26
and 1.17/OTP 27 but skips 1.16/OTP 26 (currently the most common
production combination per Hex stats). With only two matrix rows, a
regression on 1.16 lands on `main` undetected.

**Fix:**

```yaml
- name: Install libvips
  run: sudo apt-get install -y libvips-dev
```

…added to the integration job's steps.

Consider adding 1.16/OTP 26 to the matrix for production parity.

### WR-09: `coveralls.json` — `treat_no_relevant_lines_as_covered: true` masks empty / dead modules

**File:** `coveralls.json:4`
**Issue:** With this flag set, a module that has no executable lines
(e.g. a stubbed-out behavior wrapper) reports as 100% covered. Combined
with the 80% minimum, this lets ghost modules accumulate without
review. The flag is documented in excoveralls but is generally
considered a pragmatic exception, not a default.

**Fix:** If the flag is set to bypass coverage failures for genuinely
empty modules (e.g. behaviour stubs), document the rationale inline:

```json
{
  "coverage_options": {
    "minimum_coverage": 80,
    "//": "treat_no_relevant_lines_as_covered allows empty behaviour stubs",
    "treat_no_relevant_lines_as_covered": true
  },
  ...
}
```

Or remove the flag and convert stub modules to use `@compile {:no_warn_undefined, ...}`
so coverage tooling reflects them honestly.

### WR-10: Adopter lane drift gate uses substring match — false positives in comments and doc-strings

**File:** `.github/workflows/ci.yml:332-351`
**Issue:** The drift-gate step greps `guides/getting_started.md` for
the strings `Broker\.initiate_session`, `Broker\.verify_completion`,
and `Rindle\.Delivery\.url`. The file currently has comments and
doc-string references that mention these symbols outside the canonical
snippet. A future edit that *removes* the canonical snippet but leaves
a doc-string mentioning the function names would still satisfy the
grep — drift undetected.

**Fix:** Tighten the grep to require the exact ` ` (space) or `(` form
the canonical snippet uses:

```bash
MATCHES=$(grep -nE "Broker\.initiate_session\(|Broker\.verify_completion\(|Rindle\.Delivery\.url\(" "$GUIDE" | wc -l)
```

…and emit each matching line in the success log to make drift visible
on the action's log page.

### WR-11: `mix.exs` package files clause omits `priv/repo/migrations` when `priv/` is empty

**File:** `mix.exs:153`
**Issue:**

```elixir
files: ~w(lib priv/repo/migrations mix.exs README.md LICENSE)
```

If `priv/repo/migrations` does not exist on disk at the time of
`mix hex.build` (e.g. on a fresh checkout that has not generated any
migrations), Hex emits a warning and skips that path silently. The
release lane (`release.yml`) currently asserts only **prohibited**
paths, not **required** paths beyond the four it lists. A future state
where migrations are removed leaves the release lane green even though
adopters need them.

**Fix:** Add a positive assertion in `.github/workflows/release.yml`
after the existing `Assert required paths present` step:

```bash
test -d rindle-*/priv/repo/migrations || { echo "FAIL: migrations missing from tarball"; exit 1; }
test -n "$(ls -A rindle-*/priv/repo/migrations 2>/dev/null)" || { echo "FAIL: migrations directory empty"; exit 1; }
```

## Info

### IN-01: `guides/troubleshooting.md` — `ago(0, "second")` is not a valid Ecto fragment

**File:** `guides/troubleshooting.md:215`
**Issue:**

```elixir
where: s.state in ["signed", "uploading"] and s.expires_at < ago(0, "second"),
```

`Ecto.Query.API.ago/2` requires a positive integer offset; `0` is
accepted by the macro but the resulting SQL collapses to
`expires_at < NOW()` which is what the example wants — but readers
will copy `ago(0, "second")` into their own code. Use `^DateTime.utc_now()`
to avoid the inscrutable Ecto-fragment idiom for "now".

**Fix:**

```elixir
where: s.state in ["signed", "uploading"] and s.expires_at < ^DateTime.utc_now(),
```

### IN-02: `guides/core_concepts.md` — references `Rindle.Domain.UploadSessionFSM` but the file list contains no such module

**File:** `guides/core_concepts.md:155`, `guides/troubleshooting.md:228-230`
**Issue:** Both guides reference `Rindle.Domain.UploadSessionFSM` as
the canonical reference for upload session transitions. That module
is not in the file list reviewed for this phase, and a quick search
of the project tree shows it exists (good) — but the asset/variant
FSMs co-located in this review do **not** match the upload-session FSM
naming pattern (which appears to live elsewhere). If the upload-session
FSM module ever moves or renames, the guides drift silently — there is
no equivalent of the adopter drift-gate for the FSM module names.

**Fix:** Add a CI step that asserts the modules referenced in the
guides exist (an `iex -S mix --eval 'Code.ensure_loaded!(Rindle.Domain.UploadSessionFSM)'`
or a small `Mix.Task` that walks the guides for `Rindle.X.Y` patterns
and compiles them).

### IN-03: `lib/rindle/domain/asset_fsm.ex` and `variant_fsm.ex` — duplicated transition+telemetry logic

**File:** `lib/rindle/domain/asset_fsm.ex:32-52`, `lib/rindle/domain/variant_fsm.ex:21-39`
**Issue:** Both modules implement identical transition/telemetry/log
logic with only the event-name and (in AssetFSM) the failure-log
differing. A future contract change — e.g. adding `:profile` validation
to the context map — must be applied twice. `VariantFSM.transition/3`
also lacks the `log_transition_failure/3` helper that `AssetFSM` has,
so failed variant transitions emit no log line at all. This is an
observability gap that could be papered over with a shared helper.

**Fix:** Extract a `Rindle.Domain.FSMHelper.transition_with_telemetry/4`
that both modules call, and add the missing failure log to
`VariantFSM`.

### IN-04: `lib/rindle/upload/broker.ex` — typo / misleading comment "Pitfall 5"

**File:** `lib/rindle/upload/broker.ex:144`
**Issue:** The inline comment `# Check storage for object existence
(Pitfall 5)` references an out-of-band document ("Pitfall 5") that
isn't in the codebase or guides surface. Comments should be
self-explanatory or reference a stable identifier. Same pattern at
line 348 of `lib/rindle.ex` ("Pitfall 2").

**Fix:** Replace the comment with a self-contained explanation:
"Verify the storage object exists *before* mutating session/asset
state, so a missing PUT does not leave the session in `verifying`."

### IN-05: `test/test_helper.exs` — `Code.require_file` workaround for mocks is brittle

**File:** `test/test_helper.exs:6-8`
**Issue:**

```elixir
unless Code.ensure_loaded?(Rindle.StorageMock) do
  Code.require_file("support/mocks.ex", __DIR__)
end
```

The `unless Code.ensure_loaded?` guard means the mocks file is loaded
during the *first* test run but not subsequent runs in the same VM if
a test sets up a different mock. With Mox specifically the mock is a
module, so this works, but the pattern hides a config issue:
`elixirc_paths(:test)` already includes `"test/support"` in `mix.exs`
line 41. The mocks should be discovered via the standard compile path
without the require shim.

**Fix:** Remove the require block and rely on the `elixirc_paths`
already declared in `mix.exs`:

```elixir
{:ok, _} = Rindle.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Rindle.Repo, :manual)
{:ok, _} = Oban.start_link(repo: Rindle.Repo, queues: false, testing: :manual)
ExUnit.start(exclude: [:integration, :minio, :contract, :adopter])
```

### IN-06: `test/rindle/upload/broker_test.exs:32-33` — trailing-whitespace lines flagged by `mix format` strict mode

**File:** `test/rindle/upload/broker_test.exs:28, 56-57, 73, 86, 98, 106, 109`
**Issue:** Several lines in the broker test have trailing whitespace
visible at the line endings (e.g. `      ` after the closing `}`).
The CI `Check formatting` step (`mix format --check-formatted`) will
flag these — a precommit format pass before the phase-5 commit would
be fine. Not a correctness bug, but it will fail the lane.

**Fix:** Run `mix format` on the file before committing.

---

_Reviewed: 2026-04-26T22:55:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
