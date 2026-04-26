---
phase: 04-day-2-operations
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - lib/mix/tasks/rindle.abort_incomplete_uploads.ex
  - lib/mix/tasks/rindle.backfill_metadata.ex
  - lib/mix/tasks/rindle.cleanup_orphans.ex
  - lib/mix/tasks/rindle.regenerate_variants.ex
  - lib/mix/tasks/rindle.verify_storage.ex
  - lib/rindle/ops/metadata_backfill.ex
  - lib/rindle/ops/upload_maintenance.ex
  - lib/rindle/ops/variant_maintenance.ex
  - lib/rindle/workers/abort_incomplete_uploads.ex
  - lib/rindle/workers/cleanup_orphans.ex
  - test/rindle/ops/metadata_backfill_test.exs
  - test/rindle/ops/upload_maintenance_test.exs
  - test/rindle/ops/variant_maintenance_test.exs
  - test/rindle/workers/maintenance_workers_test.exs
findings:
  critical: 8
  warning: 9
  info: 5
  total: 22
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Phase 04 implements operator-facing maintenance tooling (Mix tasks, Oban workers, and a shared `Rindle.Ops` service layer) for upload cleanup, variant regeneration/verification, and metadata backfill. Functional happy paths are reasonable and the test suite exercises the obvious dry-run/live distinctions, but the destructive lanes contain several real correctness, idempotency, and contract-violation defects that contradict the phase's own threat-model mitigations (T-04-01, T-04-04, T-04-08, T-04-09).

The most serious issues are:

1. **Cleanup loses recovery information.** `UploadMaintenance` deletes the DB row *before* attempting storage delete; a transient storage failure produces an orphan object with no DB pointer left to retry from.
2. **Dangerous default in the destructive Mix task.** `mix rindle.cleanup_orphans` (no flags) runs in destructive mode while the underlying service and the Oban worker both default to dry-run. This inverts the safer default in the operator-facing CLI, contradicting T-04-01 and the docstring's claim of "safe two-step cleanup."
3. **Worker idempotency is broken.** `regenerate_variants` enqueues `ProcessVariant` jobs with no Oban uniqueness; back-to-back cron runs duplicate work — the explicit T-04-08 mitigation ("workers must stay idempotent") is unmet.
4. **Exit-code contract violations.** `mix rindle.regenerate_variants` and `mix rindle.verify_storage` document non-zero exits on insertion / connection failures; both currently exit 0 in those cases. CI/cron will silently swallow the failures.
5. **FSM bypass.** Both `expire_session/2` and `mark_missing/1` apply state transitions without consulting `UploadSessionFSM` / `VariantFSM`, eroding the invariants those modules exist to protect.
6. **Atom DoS via CLI.** Two Mix tasks call `String.to_atom/1` on operator-supplied module strings, leaking memory per invocation.

## Critical Issues

### CR-01: Cleanup deletes DB row before storage object — orphans on transient storage failure

**File:** `lib/rindle/ops/upload_maintenance.ex:179-217`
**Issue:** `delete_session_and_object/3` deletes the `MediaUploadSession` row first and only then calls `storage_mod.delete(session.upload_key, [])`. The session row is the *only* record carrying `upload_key`. If the storage call fails for any reason (network blip, IAM hiccup, throttling), the row is already gone and the `Logger.warning` is the sole record of the orphan. Subsequent `cleanup_orphans` runs will never see this object again. This silently leaks storage and contradicts the entire premise of the cleanup lane (T-04-02: "Batch work and return tagged errors so a single broken session does not silently short-circuit the entire cleanup lane" — the work isn't short-circuited, but recovery information is destroyed).

The current flow also makes the `storage_errors` counter misleading: an operator sees the count but has no way to find the affected `upload_key`s without scraping logs.

**Fix:** Reverse the order, or stage the deletes so DB removal only happens after the storage call returns `{:ok, _}` or an explicitly retriable error. A safer pattern:

```elixir
defp delete_session_and_object(session, acc, storage_mod) do
  case delete_staged_object_first(session, storage_mod) do
    :ok_or_skipped ->
      delete_db_row(session, acc)
    :transient_error ->
      # leave DB row in place so the next cron run retries
      Logger.warning("rindle.upload_maintenance.object_delete_failed",
        session_id: session.id, upload_key: session.upload_key, ...)
      Map.update!(acc, :storage_errors, &(&1 + 1))
  end
end
```

Alternatively, if the design must keep DB-first ordering, persist a tombstone (e.g., a separate `pending_object_deletions` table) before removing the session row so the orphan can be reaped on the next cycle.

---

### CR-02: `mix rindle.cleanup_orphans` defaults to destructive run; service and worker default to dry-run

**File:** `lib/mix/tasks/rindle.cleanup_orphans.ex:58`
**Issue:** The CLI sets `dry_run? = Keyword.get(opts, :dry_run, false)` while `Rindle.Ops.UploadMaintenance.cleanup_orphans/1` defaults `:dry_run` to `true` (`upload_maintenance.ex:68`) and `Rindle.Workers.CleanupOrphans` also defaults to `true` (`cleanup_orphans.ex:54`). An operator who runs `mix rindle.cleanup_orphans` with no flags — a very plausible first invocation — performs a destructive deletion.

This directly contradicts the threat-model mitigation T-04-01: "Keep dry-run separate from destructive execution and verify TTL/state before deleting anything." The safest default in any UX layer must be the non-destructive one, and the rule must be uniform across CLI/worker/service.

**Fix:** Default the CLI to dry-run and require an explicit opt-in flag for destructive mode. For example:

```elixir
strict: [dry_run: :boolean, live: :boolean, storage: :string]
...
dry_run? = not Keyword.get(opts, :live, false)
```

Or invert the existing flag semantics to `--apply`/`--execute`. Update the moduledoc to reflect that destructive runs require an explicit flag, and update the worker to share the same default.

---

### CR-03: `regenerate_variants` enqueues duplicate jobs — cron idempotency is broken

**File:** `lib/rindle/ops/variant_maintenance.ex:167-171`
**Issue:** `enqueue_job/2` calls `ProcessVariant.new/1 |> Oban.insert/1` with no `unique:` opts, and `Rindle.Workers.ProcessVariant` itself declares no uniqueness on `use Oban.Worker` (`lib/rindle/workers/process_variant.ex:6`). Two back-to-back runs of `mix rindle.regenerate_variants` (or two cron firings) will enqueue duplicate `ProcessVariant` jobs for every stale/missing variant, doubling the storage I/O and competing for the same DB row.

The plan asserts this is mitigated (T-04-08: "workers must stay idempotent and return structured results"), but the operation that *creates* worker jobs is not idempotent.

**Fix:** Add a uniqueness constraint scoped to `asset_id + variant_name` (and probably state):

```elixir
defp enqueue_job(asset_id, variant_name) do
  %{"asset_id" => asset_id, "variant_name" => variant_name}
  |> ProcessVariant.new(
    unique: [
      fields: [:args, :worker, :queue],
      keys: [:asset_id, :variant_name],
      states: [:available, :scheduled, :executing, :retryable],
      period: :infinity
    ]
  )
  |> Oban.insert()
end
```

Add a regression test in `variant_maintenance_test.exs` that calls `regenerate_variants/1` twice and asserts only one job is enqueued per variant.

---

### CR-04: `mix rindle.regenerate_variants` exits 0 on Oban insertion failure (contract violation)

**File:** `lib/rindle/ops/variant_maintenance.ex:75-80` and `lib/mix/tasks/rindle.regenerate_variants.ex:79-88`
**Issue:** The task's documented contract: "Exit codes: 1 — Query or job-insertion error." But `regenerate_variants` collapses `Oban.insert/1` failures into the `skipped` counter (`{:error, _reason} -> {enq, skip + 1}`). The Mix task only halts non-zero on the outer `{:error, reason}` from the function — which never fires for per-job insertion failures. Operators and CI pipelines will see "skipped: 5" and exit 0 even when 5 jobs failed to enqueue.

This is also confused semantics: "skipped" at the variant level means "variant wasn't eligible for regeneration." Mixing it with "Oban couldn't accept the job" hides real failures from observability.

**Fix:** Track insertion errors separately:

```elixir
{enqueued, errors} =
  Enum.reduce(rows, {0, 0}, fn {_id, name, asset_id, _state}, {enq, err} ->
    case enqueue_job(asset_id, name) do
      {:ok, _job} -> {enq + 1, err}
      {:error, reason} ->
        Logger.error("rindle.variant_maintenance.enqueue_failed",
          asset_id: asset_id, variant_name: name, reason: inspect(reason))
        {enq, err + 1}
    end
  end)

{:ok, %{enqueued: enqueued, skipped: existing_skip_count, errors: errors}}
```

And in the Mix task, exit non-zero when `result.errors > 0`.

---

### CR-05: `mix rindle.verify_storage` exits 0 even when storage connection fails (contract violation)

**File:** `lib/rindle/ops/variant_maintenance.ex:140-186` and `lib/mix/tasks/rindle.verify_storage.ex:89-100`
**Issue:** Documented contract: "Exit codes: 1 — Query or storage connection failure." But `check_object/1` swallows every non-`{:error, :not_found}` storage error into the `errors` counter and returns `{:ok, %{...}}`. The Mix task then prints the summary and exits 0 — even when *every* HEAD call returned `{:error, :connection_refused}`.

Cron pipelines that rely on the exit code to alert on storage outages will be silently broken.

**Fix:** Either (a) propagate `errors > 0` as a non-zero exit in the Mix task — the simpler change that matches the documented behaviour:

```elixir
{:ok, %{checked: c, present: p, missing: m, errors: e}} = result
print_summary(c, p, m, e)
if e > 0 do
  Mix.shell().error("#{e} storage error(s) during verification")
  System.halt(1)
end
```

Or (b) revise the moduledoc to admit that storage errors do not affect exit code (and explain how operators should detect them) — but per the parent review brief ("Error handling on cleanup paths must surface non-zero exits") option (a) is required.

---

### CR-06: `MetadataBackfill` `String.to_atom` enables atom-table DoS from CLI

**File:** `lib/mix/tasks/rindle.backfill_metadata.ex:115` and `lib/mix/tasks/rindle.cleanup_orphans.ex:88`
**Issue:** Both Mix tasks accept `--storage MODULE` / `--analyzer MODULE` strings and pass them through `String.to_atom/1`. Atoms are not garbage collected; an attacker (or an automated script with bad inputs) feeding distinct module strings can exhaust the atom table over time. The threat model explicitly lists "Shell / CI cron → Mix task | Untrusted operator input" as a trust boundary (04-01-PLAN.md:140) and T-04-09 promises that "arguments cannot bypass the analyzer or persistence rules" — uncontrolled atom creation is exactly such a bypass vector.

Note that `Rindle.Workers.CleanupOrphans.resolve_storage_adapter/1` (`cleanup_orphans.ex:91`) does this correctly with `String.to_existing_atom/1` plus an `ArgumentError` rescue — the same pattern should appear in the Mix tasks.

**Fix:** Use `String.to_existing_atom/1` and rescue `ArgumentError`:

```elixir
module_str ->
  try do
    mod = String.to_existing_atom(module_str)
    case Code.ensure_loaded(mod) do
      {:module, mod} -> mod
      {:error, reason} -> abort_load_error(module_str, reason)
    end
  rescue
    ArgumentError -> abort_load_error(module_str, :unknown_atom)
  end
```

Apply to both `rindle.backfill_metadata.ex:115` and `rindle.cleanup_orphans.ex:88`.

---

### CR-07: `expire_session/2` and `mark_missing/1` bypass the FSM

**File:** `lib/rindle/ops/upload_maintenance.ex:231-251` and `lib/rindle/ops/variant_maintenance.ex:196-199`
**Issue:** Two destructive transitions go around the domain FSMs:

1. `UploadMaintenance.expire_session/2` builds `MediaUploadSession.changeset(session, %{state: "expired"})` and persists it without first calling `Rindle.Domain.UploadSessionFSM.transition(session.state, "expired", ...)`. The FSM (`upload_session_fsm.ex:16`) declares `"expired" => []` — a terminal state — but also explicitly *omits* transitions like `"uploaded" -> "expired"` and `"verifying" -> "expired"`. The query is currently scoped to `["signed", "uploading"]`, both of which the FSM allows expiring, so today the bug is latent — but the code asserts the invariant in the domain layer and the maintenance lane is the wrong place to silently re-derive it. Any future query expansion (e.g., expiring `uploaded` sessions whose verification stalled) will silently violate the FSM with no test catching it.

2. `VariantMaintenance.mark_missing/1` runs `Repo.update_all(set: [state: "missing"])` directly. The FSM allows `"ready" -> "missing"` but not `"failed" -> "missing"` (`variant_fsm.ex:13`: `"failed" => ["queued", "purged"]`). The verifier query *includes* `"failed"` (`@verifiable_states ["ready", "stale", "missing", "failed"]`) — so a `failed` variant whose object goes missing will be silently flipped to `missing`, a transition the FSM forbids. Likewise `update_all` skips changeset validation entirely (no `validate_inclusion`), so a typo in the constant `"missing"` would go undetected.

**Fix:**
- For uploads: gate the changeset on `UploadSessionFSM.transition(session.state, "expired", %{session_id: session.id})`; if the FSM rejects, increment `:abort_errors` and log.
- For variants: replace `Repo.update_all` with a per-row changeset-based update that calls `VariantFSM.transition/3` first, or add `"failed"` (and any other intended sources) to the FSM's allowed transitions and use a real changeset so validation runs. Either way, write a test that asserts a `failed` variant is *not* silently flipped to `missing` without an FSM-allowed transition.

---

### CR-08: `expires_at < now` filter on already-expired sessions blocks cleanup of administratively-expired rows

**File:** `lib/rindle/ops/upload_maintenance.ex:121-136`
**Issue:** `fetch_expired_sessions/0` filters `where: s.state == "expired" and s.expires_at < ^now`. If a session is administratively transitioned to `expired` before its `expires_at` (e.g., by a future upload-cancellation feature, or by `expire_session/2` itself if `expires_at` is somehow in the future), it will sit in the `expired` state forever and never be cleaned up. The `expires_at` check is redundant (the state already encodes the lifecycle decision) and actively dangerous.

**Fix:** Drop the `expires_at` predicate — the state column is the source of truth for cleanup eligibility:

```elixir
query =
  from(s in MediaUploadSession,
    where: s.state == "expired",
    select: s
  )
```

Add a regression test creating a session in `expired` state with `expires_at` in the future and assert it is included in cleanup.

---

## Warnings

### WR-01: Tmp files leak when analyzer raises (vs. returns `{:error, _}`)

**File:** `lib/rindle/ops/metadata_backfill.ex:143-167`
**Issue:** `backfill_asset/4` uses `with` for the happy path and `cleanup_temp(tmp_path)` is called after the `with` returns. If `analyzer_mod.analyze/1` *raises* (rather than returning `{:error, _}`) — e.g., an ImageMagick segfault wrapper or a `File.Error` — the exception propagates *through* the `Enum.reduce`, aborting the rest of the run AND skipping `cleanup_temp/1`. The moduledoc claims "per-asset failures are accumulated and surfaced in the report rather than aborting the entire run" (`metadata_backfill.ex:16-17`); raised exceptions break that promise.

**Fix:** Wrap the per-asset work in a `try/rescue/after`:

```elixir
defp backfill_asset(asset, storage_mod, analyzer_mod, acc) do
  tmp_path = Path.join(System.tmp_dir!(), "rindle_backfill_#{Ecto.UUID.generate()}")

  try do
    result = ... # current with/else
    apply_result(result, acc)
  rescue
    e ->
      Logger.warning("rindle.metadata_backfill.asset_raised",
        asset_id: asset.id, kind: e.__struct__, message: Exception.message(e))
      Map.update!(acc, :failures, &(&1 + 1))
  after
    cleanup_temp(tmp_path)
  end
end
```

---

### WR-02: `Mix.Tasks.Rindle.BackfillMetadata.run/1` lacks `{:error, _}` clause — service contract drift will crash the task

**File:** `lib/mix/tasks/rindle.backfill_metadata.ex:98-103`
**Issue:** `MetadataBackfill.backfill_metadata/1` is currently typespecced as `{:ok, backfill_report()}` only, and the Mix task pattern-matches just `{:ok, report}`. If the service is ever extended to return `{:error, reason}` (e.g., to surface the catastrophic query failure that's currently swallowed at `metadata_backfill.ex:111-115` — see IN-02), the Mix task will raise `MatchError` rather than print a clean operator-facing error.

**Fix:** Add the `{:error, _}` clause defensively now:

```elixir
case MetadataBackfill.backfill_metadata(backfill_opts) do
  {:ok, report} -> ...
  {:error, reason} ->
    Mix.shell().error("Backfill failed: #{inspect(reason)}")
    exit({:shutdown, 1})
end
```

---

### WR-03: `cleanup_orphans` silently no-ops when storage adapter is `nil`

**File:** `lib/rindle/ops/upload_maintenance.ex:198-201` and `lib/mix/tasks/rindle.cleanup_orphans.ex:65`
**Issue:** When no `--storage` flag is passed and `Application.get_env(:rindle, :default_storage)` returns `nil`, the cleanup lane deletes DB rows but `delete_staged_object/3` matches the `nil` storage_mod clause and returns `acc` untouched. `objects_deleted` stays 0, `storage_errors` stays 0, and the operator sees "0 objects deleted" with no warning — even though every storage object remains orphaned.

**Fix:** Either (a) refuse to run when storage adapter is `nil` and exit non-zero with a clear message, or (b) emit a `Logger.warning` and add a `storage_skipped` counter to the report so the operator sees that storage cleanup was bypassed.

---

### WR-04: `RegenerateVariants` skipped tally is computed in a way that double-counts and can lose enqueue work

**File:** `lib/rindle/ops/variant_maintenance.ex:73-96`
**Issue:** Two problems:

1. **Side-effect-after-error.** The `with {:ok, [existing_skip_count]} <- safe_all(skipped_query)` is nested inside the outer `with`, *after* `Oban.insert/1` calls have already executed. If the second query fails, the function returns `{:error, reason}` even though jobs are already in the queue. The Mix task then halts with `System.halt(1)` and the operator believes nothing happened.
2. **Over-counts when filters narrow the set.** `skipped_query` filters by profile and variant_name but the comment promises it counts "ready/processing/queued" — the constant is `state not in @regeneration_states` (i.e., `not in ["stale", "missing"]`), which also includes `"planned"`, `"failed"`, `"purged"`. A `purged` variant that was never going to be regenerated counts as "skipped," inflating the number that operators interpret as "things that didn't need work."

**Fix:** Compute the skipped count from the *first* query result set (variants in `@regeneration_states` whose `enqueue` was a no-op due to filters not matching) plus an explicit count of operationally-relevant ineligible variants (`"queued" | "processing" | "ready"`). Restrict `skipped_query` to those exact states. And run the skipped count *before* the enqueue loop so a failed query doesn't strand half the work in Oban.

---

### WR-05: `Mix.Tasks.Rindle.AbortIncompleteUploads` and `BackfillMetadata` exit non-zero only on per-row errors, not query errors

**File:** `lib/mix/tasks/rindle.abort_incomplete_uploads.ex:54-57` and `lib/rindle/ops/upload_maintenance.ex:108-114`
**Issue:** When `fetch_incomplete_timed_out_sessions/0` rescues a DB error and returns `{:error, e}`, the Mix task's `{:error, reason}` clause halts with exit 1 — good. But the rescue captures *any* exception including programming errors (e.g., schema mismatches, missing migrations). Inspecting the raw exception via `inspect(reason)` and logging `reason: inspect(e)` exposes implementation details (table names, column names, error structs) to operator output; no specific guidance on how to recover. This is more a UX warning than a security one, but combined with similar `inspect/1` calls in `MetadataBackfill.fetch_eligible_assets/1` (which then returns `[]` and proceeds as though there were no assets — see IN-02), the overall error surface is inconsistent.

**Fix:** Distinguish between recoverable failure modes (where the report should reflect "0 found / 0 done") and infrastructure failures (where the task should refuse to claim "complete"). At minimum, in `MetadataBackfill.fetch_eligible_assets/1` propagate the error rather than collapsing to `[]`, then handle it explicitly in the Mix task.

---

### WR-06: Worker `CleanupOrphans` does not emit the documented `failed` log when adapter resolution errors

**File:** `lib/rindle/workers/cleanup_orphans.ex:53-84`
**Issue:** The moduledoc lists `Logger.error("rindle.workers.cleanup_orphans.failed", ...)` as the failure observability event. But when `resolve_storage_adapter/1` returns `{:error, ...}`, the `with` short-circuits and the worker returns `{:error, ...}` *without* calling the worker-level `Logger.error`. The helper logs `rindle.workers.cleanup_orphans.storage_load_failed`, but operators who set up alerts on the documented `…failed` event will miss adapter-load failures.

**Fix:** Either log the documented `…failed` event in the `with`'s `else` branch, or update the moduledoc's observability section to list both event names explicitly.

---

### WR-07: `Mix.Task.run("app.start")` invoked at runtime instead of via `@requirements`

**File:** `lib/mix/tasks/rindle.regenerate_variants.ex:65` and `lib/mix/tasks/rindle.verify_storage.ex:75`
**Issue:** Two of the five Mix tasks call `Mix.Task.run("app.start")` from inside `run/1` while the other three use `@requirements ["app.start"]`. The `@requirements` form is preferred (it runs before option parsing, integrates with Mix's task graph, and is the documented Elixir 1.14+ idiom). The runtime call also runs *after* `OptionParser.parse/2`, so any option-parsing bug raises before the app is started, producing confusing error messages.

**Fix:** Use `@requirements ["app.start"]` consistently:

```elixir
use Mix.Task

@requirements ["app.start"]

@impl Mix.Task
def run(args) do
  # remove Mix.Task.run("app.start")
  ...
end
```

---

### WR-08: `regenerate_variants` accepts unknown filter keys silently

**File:** `lib/rindle/ops/variant_maintenance.ex:62-71` and `:155-165`
**Issue:** `maybe_filter_profile` and `maybe_filter_variant_name` only match known keys; passing `%{prof: "X"}` (typo) or `%{variant: "thumb"}` (wrong key — the API takes `:variant_name`) is silently accepted as "no filter" and the task happily regenerates every variant in the system. Filter typos in a destructive lane should be loud.

**Fix:** Validate the filter map up front:

```elixir
@allowed_filter_keys ~w(profile variant_name)a

def regenerate_variants(filters) when is_map(filters) do
  case Map.keys(filters) -- @allowed_filter_keys do
    [] -> do_regenerate(filters)
    unknown -> {:error, {:unknown_filters, unknown}}
  end
end
```

The Mix task already constrains CLI flags via `OptionParser`, but a callers-from-Elixir API needs the same guard.

---

### WR-09: `resolve_storage_adapter/1` raises a string-interpolated message that exposes profile name to logs/exception trace

**File:** `lib/rindle/ops/variant_maintenance.ex:189-194`
**Issue:** `rescue _e -> raise "Cannot resolve storage adapter for profile: #{profile_string}"` interpolates an unsanitized profile string into a `RuntimeError` message. Profile strings come from the DB but were originally written by user code at `attach`/`store` time. Beyond the safety concern, this `rescue _` swallows the original error (could be `ArgumentError` for a bad atom OR `UndefinedFunctionError` for a missing `storage_adapter/0` callback) — operators lose the actual cause.

This also makes `verify_storage` partially fail: the raise occurs inside the `Enum.reduce`, aborting the entire walk on the first malformed profile string. One bad asset prevents verification of every other asset.

**Fix:** Catch specific errors, return `:error` to bump the `errors` counter, and don't crash the run:

```elixir
defp resolve_storage_adapter(profile_string) when is_binary(profile_string) do
  try do
    mod = String.to_existing_atom(profile_string)
    if function_exported?(mod, :storage_adapter, 0), do: {:ok, mod.storage_adapter()}, else: {:error, :no_callback}
  rescue
    ArgumentError -> {:error, :unknown_profile}
  end
end
```

And have `check_object/1` map any `{:error, _}` from this resolver into the `:error` counter rather than raising.

---

## Info

### IN-01: Misleading test name — `"returns error tuple when repo raises"` doesn't exercise an error path

**File:** `test/rindle/ops/upload_maintenance_test.exs:201-207`
**Issue:** The test name promises an error path but the body just calls the success path and asserts the return *shape*. There is no test that actually causes `Repo.all` to raise and verifies the `{:error, e}` branch of `safe_all`/`fetch_incomplete_timed_out_sessions` (`upload_maintenance.ex:140-155`). Combined with the same gap in `metadata_backfill.ex:109-115` (the `rescue` returns `[]`), the rescue branches are entirely uncovered.

**Fix:** Either delete the misleading test or replace it with a real one (e.g., use a mock repo, or temporarily revoke a sandbox checkout to force a `DBConnection.OwnershipError`). At minimum, rename so the name matches the assertions.

---

### IN-02: `MetadataBackfill.fetch_eligible_assets/1` swallows query errors and returns `[]`

**File:** `lib/rindle/ops/metadata_backfill.ex:106-137`
**Issue:** On a `Repo.all` failure (DB outage, missing migration, table renamed), the function logs and returns `[]`. The caller then reports `assets_found: 0, assets_updated: 0, failures: 0` and the Mix task exits **0** with the message "Metadata backfill complete." Operators have no signal that the backfill silently did nothing on a broken database.

**Fix:** Return `{:error, reason}` from the helper, propagate it from `backfill_metadata/1`, and let the Mix task halt non-zero — matching the explicit behaviour in `UploadMaintenance` (which returns `{:error, _}` on query failure).

---

### IN-03: Worker examples in moduledoc list the wrong cron order

**File:** `lib/rindle/workers/cleanup_orphans.ex:11-22`
**Issue:** The example crontab in `CleanupOrphans` lists itself first (`"0 2 * * *"`) and `AbortIncompleteUploads` second (`"0 1 * * *"`) — but the abort step must run *first* (1 AM) so that the cleanup run (2 AM) finds the newly-expired sessions. The times are correct, but the ordering inside the keyword list reads top-to-bottom and may mislead operators copy-pasting the example. `AbortIncompleteUploads` shows the correct order. Make them match.

**Fix:** Reorder the example list in `cleanup_orphans.ex:18-21` so `AbortIncompleteUploads` appears first.

---

### IN-04: `cleanup_temp/1` ignores `File.rm/1` return value silently

**File:** `lib/rindle/ops/metadata_backfill.ex:184-187`
**Issue:** `File.rm(path)` returns `:ok | {:error, posix}`. The current code discards the result and unconditionally returns `:ok`. A cleanup failure (file-system full, permission change between `File.write!` and `File.rm`) is invisible — over many runs in a long-lived host this can accumulate. Combined with WR-01 (raises bypass cleanup entirely), tmp-dir hygiene is fragile.

**Fix:** Pattern-match and emit a `Logger.debug` (not warning, since this is benign) on failure:

```elixir
defp cleanup_temp(path) do
  case File.rm(path) do
    :ok -> :ok
    {:error, :enoent} -> :ok
    {:error, reason} ->
      Logger.debug("rindle.metadata_backfill.tmp_cleanup_failed",
        path: path, reason: reason)
      :ok
  end
end
```

---

### IN-05: Test fixtures use forbidden `state: "initialized"` value alongside `validate_required([:asset_id, :state, :upload_key, :expires_at])` only — but the schema's `@states` includes `"initialized"`, so this is OK; just noting that `"initialized"` is conspicuously absent from any FSM source state in `UploadSessionFSM` *for transitions inbound* — i.e., it can only be the *origin* state. Tests creating sessions in `state: "initialized"` then expecting them to be untouched by abort/cleanup are correct, but a future change that adds `"initialized"` to the abort scope would silently include freshly-created in-flight uploads with no `expires_at < now` issue. Worth a code comment in `fetch_incomplete_timed_out_sessions/0` that the `["signed", "uploading"]` list is intentional and `"initialized"` is excluded because the user has not yet been issued a presigned URL.

**File:** `lib/rindle/ops/upload_maintenance.ex:138-155`
**Fix:** Add a one-line comment above the query explaining the intentional state set.

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
