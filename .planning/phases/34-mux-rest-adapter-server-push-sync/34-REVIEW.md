---
phase: 34-mux-rest-adapter-server-push-sync
reviewed: 2026-05-06T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - mix.exs
  - lib/rindle/streaming/provider/mux.ex
  - lib/rindle/streaming/provider/mux/client.ex
  - lib/rindle/streaming/provider/mux/http.ex
  - lib/rindle/streaming/provider/mux/event.ex
  - lib/rindle/domain/media_provider_asset.ex
  - lib/rindle/workers/mux_ingest_variant.ex
  - lib/rindle/workers/mux_sync_coordinator.ex
  - lib/rindle/workers/mux_sync_provider_asset.ex
  - test/support/mocks.ex
  - test/rindle/streaming/provider/mux/optional_dep_test.exs
  - test/rindle/streaming/provider/mux/mux_test.exs
  - test/rindle/streaming/provider/mux/signed_playback_url_test.exs
  - test/rindle/streaming/provider/mux/telemetry_test.exs
  - test/rindle/workers/mux_ingest_variant_test.exs
  - test/rindle/workers/mux_sync_coordinator_test.exs
  - test/rindle/workers/mux_sync_provider_asset_test.exs
  - .dialyzer_ignore.exs
findings:
  blocker: 4
  warning: 9
  info: 3
  total: 16
status: issues_found
---

# Phase 34: Code Review Report

**Reviewed:** 2026-05-06T00:00:00Z
**Depth:** standard
**Files Reviewed:** 17 (16 source + 1 dialyzer ignore)
**Status:** issues_found

## Summary

The Phase 34 Mux REST adapter ships its core contract correctly: PLURAL SDK keys
(`inputs`, `playback_policies`) at the SDK boundary, the explicit `:expiration`
guard against the 7-day Mux SDK default, atomic-promote race protection in the
ingest worker, and consistent telemetry redaction via
`MediaProviderAsset.redact_id/1`. The optional-dep guard pattern is applied
uniformly to every Mux-touching lib module.

However, several real defects were found that should block ship as-is:

1. **Orphaned Mux asset on atomic-promote stale rejection** (BL-01) — when the
   re-fetch in `persist_provider_processing` detects drift AFTER the Mux REST
   call already created the asset, the worker returns `{:cancel, _}` without
   deleting the just-created Mux asset OR reverting the row state. The Mux
   asset is silently abandoned (cost + lifecycle leak) and the row is stuck in
   `:uploading` until the sync coordinator's 2-hour stuck threshold fires.

2. **Re-ingest from `:errored` state silently fails** (BL-02) —
   `maybe_skip_already_in_progress/4` lets `:errored` rows fall through to
   `transition_uploading/4`, but the FSM does NOT permit `errored → uploading`
   (only `errored → processing`). The `:errored` re-entry edge promised in
   `provider_asset_fsm.ex:14` is broken for the ingest path.

3. **`Event.extract_playback_ids/1` crashes on explicit `null`** (BL-03) — Mux
   webhooks sending `"playback_ids": null` (legitimate for `video.asset.created`
   before transcoding completes) cause `Enum.map(nil, ...)` to raise. This
   takes down `verify_webhook/3` for an event class that exists in the wild.

4. **Behaviour callback type spec violated** (BL-04) — `@callback get_asset`
   declares `state: provider_state()` (atoms `:processing | :ready | …`) but
   the Mux adapter returns string states (`"processing"`, `"ready"`). Either
   the behaviour spec or the implementation is wrong; downstream callers (e.g.
   `MuxSyncProviderAsset.sync_with_provider/2`) silently rely on strings.

The remaining items are robustness gaps (missing config validation, brittle
header-case lookups, unbounded coordinator scan) and minor maintainability
concerns. None of the security-invariant-14 redaction sites leak raw IDs that
I could find, and the phase-gate telemetry test enforces this.

---

## Blockers

### BL-01: Orphaned Mux asset when atomic-promote rejects after Mux REST call

**File:** `lib/rindle/workers/mux_ingest_variant.ex:107-176, 302-350`
**Issue:** The ingest worker calls `Adapter.create_asset_with_retry_hint/3`
(line 114) — which actually creates an asset on Mux's side — BEFORE the
second freshness re-check in `persist_provider_processing/4` (lines 313-318).
If `expected_storage_key` / `expected_recipe_digest` have drifted between the
first check and the post-create check, the worker returns
`{:cancel, {:stale_source, _}}` but:

  1. The Mux asset created at step (114) is NOT deleted — it remains a paid
     asset on Mux's side until manual cleanup. There is no hook in this code
     or the deferred-items list that compensates for this.
  2. The row is left in `:uploading` (set by `transition_uploading/4` at line
     113). Because Oban honors `:cancel`, the job will not retry. The row
     stays in `:uploading` until `MuxSyncCoordinator` picks it up after the
     stuck threshold (default 7200s) and only then transitions it to
     `:errored` — at which point the Mux asset is already orphaned.

This is qualitatively worse than the `process_variant.ex:244-275` pattern it
mirrors, because storage objects are cheap and Mux assets are billed.

**Fix:** Either (a) move the second freshness re-check to BEFORE the Mux REST
call so the worker never creates an asset whose row will be cancelled, or
(b) on `{:cancel, _}` in `persist_provider_processing/4`, call
`Adapter.delete_asset(mux_response.provider_asset_id)` and revert the row to
`:errored` (or `:pending`) before returning. Option (a) is simpler:

```elixir
# In perform/1, reorder so the post-create freshness check happens before the
# adapter call, OR add a compensating delete in persist_provider_processing/4:

cond do
  current_asset.storage_key != args["expected_storage_key"] ->
    _ = Adapter.delete_asset(mux_response.provider_asset_id)
    _ = revert_row_to_errored(repo, row, "stale source after mux create")
    {:cancel, {:stale_source, :asset_changed}}

  current_variant.recipe_digest != args["expected_recipe_digest"] ->
    _ = Adapter.delete_asset(mux_response.provider_asset_id)
    _ = revert_row_to_errored(repo, row, "stale recipe after mux create")
    {:cancel, {:stale_source, :recipe_changed}}

  true ->
    # ... existing happy path
end
```

---

### BL-02: Re-ingest from `:errored` state breaks FSM (silent failure)

**File:** `lib/rindle/workers/mux_ingest_variant.ex:269-282, 284-298`
**Issue:** `maybe_skip_already_in_progress/4` returns `{:cont, row}` for any
state outside `["uploading", "processing", "ready", "pending"]`. That includes
`"errored"` (and `"deleted"`). The next step in `perform/1` is
`transition_uploading/4`, which calls
`ProviderAssetFSM.transition(row.state, "uploading", _)`.

`provider_asset_fsm.ex:9-16` allowlists:
```elixir
"errored" => ["deleted", "processing"]   # NOT "uploading"
```

So an `:errored → :uploading` transition fails with
`{:error, {:invalid_transition, "errored", "uploading"}}`. The worker's `with`
chain returns this as `{:error, _}` from `perform/1`, the row stays in
`:errored`, and Oban retries up to `max_attempts: 5` — every attempt fails
identically. The comment at lines 277-278 ("`transition_uploading will fail
safely if the FSM rejects it`") is misleading: the failure is not safe — it
burns retry budget and produces no useful state change.

The `errored → processing` re-entry edge documented in
`provider_asset_fsm.ex:14` requires the worker to flip directly to
`:processing` (not via `:uploading`) on re-ingest, OR to first transition
through `:errored → :processing` and skip the `:uploading` stage entirely.

**Fix:** Either remove the fall-through case for `:errored` (treat it as a
job-level error: caller must re-enqueue with explicit reset semantics), or
implement a re-entry path:

```elixir
defp maybe_skip_already_in_progress(row, _profile, _args, _start_time) do
  case row.state do
    "pending" -> {:cont, row}
    state when state in ["uploading", "processing", "ready"] ->
      {:halt, :already_in_progress}
    "errored" ->
      # Explicit re-entry: caller must reset the row before re-ingest, OR
      # we need a dedicated "errored -> uploading via reset" edge.
      {:halt, {:error, :requires_reset}}
    "deleted" ->
      {:halt, {:error, :row_deleted}}
  end
end
```

The current code provides no test coverage for the `:errored` path either —
the test suite never exercises this branch, hence the silent breakage.

---

### BL-03: `Event.extract_playback_ids/1` crashes when payload has explicit `null`

**File:** `lib/rindle/streaming/provider/mux/event.ex:44-52`
**Issue:** `Map.get(data, "playback_ids", [])` returns `nil` (NOT the default)
when `data` contains the key with an explicit null value, e.g.,
`%{"playback_ids" => nil}`. The subsequent `Enum.map(nil, _)` raises
`Protocol.UndefinedError: protocol Enumerable not implemented for nil`.

Mux webhooks DO send `"playback_ids": null` for asset lifecycle events that
fire before playback IDs are minted (e.g., `video.asset.created` — the very
first webhook event). This means `verify_webhook/3` will crash on a real Mux
webhook payload, causing the calling plug to 500.

The adapter's own `extract_playback_id_strings/1` correctly guards against
this with a `_, do: []` fallback (mux.ex:323) — Event.normalize must do the
same.

**Fix:**

```elixir
defp extract_playback_ids(data) do
  case Map.get(data, "playback_ids") do
    list when is_list(list) ->
      list
      |> Enum.map(fn
        %{"id" => id} -> id
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    _ ->
      []
  end
end
```

There is also no test in `mux_test.exs` exercising a `null` or missing
`playback_ids` webhook payload. Add a fixture for the
`video.asset.created` shape and a regression test.

---

### BL-04: Behaviour callback `get_asset/1` violates declared `provider_state` type

**File:** `lib/rindle/streaming/provider.ex:31-33, 67-75` /
`lib/rindle/streaming/provider/mux.ex:210-240, 306-311`
**Issue:** The behaviour declares:

```elixir
@type provider_state ::
        :pending | :uploading | :processing | :ready | :errored | :deleted

@callback get_asset(provider_asset_id()) ::
            {:ok, %{state: provider_state(), playback_ids: [playback_id()], raw: map()}}
            | {:error, term()}
```

The Mux adapter returns string states from `normalize_state/1`:
```elixir
defp normalize_state("preparing"), do: "processing"
defp normalize_state("ready"), do: "ready"
# ...
```

So `get_asset/1` returns `{:ok, %{state: "processing", ...}}` (string), not
`:processing` (atom). This violates the behaviour spec. Dialyzer with
`plt_add_apps: [:mix, :ex_unit, :mux, :jose]` should flag this in the next PLT
regen — the `.dialyzer_ignore.exs` diff in this phase only mentions
pre-existing pattern_match warnings.

Downstream, `MuxSyncProviderAsset.sync_with_provider/2` and
`apply_state_transition/4` compare strings (`live_state == row.state`,
`row.state in ["processing", "uploading"]`) — which works because the schema
column is `:string`, but is incoherent with the behaviour's atom-typed
contract.

The `provider_event` type also declares `state: provider_state() | nil`
(atoms), and `Rindle.Streaming.Provider.Mux.Event.normalize/1` likewise
returns strings. Same violation across the surface.

**Fix:** Pick one and fix the other. The schema column is `:string`, the FSM
allowlist keys are strings, and adopters' code already operates on strings —
the cheaper fix is to update the behaviour types:

```elixir
@type provider_state :: String.t()  # one of @states from MediaProviderAsset

@callback get_asset(provider_asset_id()) ::
            {:ok, %{state: String.t(), playback_ids: [playback_id()], raw: map()}}
            | {:error, term()}
```

…and update `provider_event.state` accordingly. If the team prefers atoms at
the boundary, the adapter must convert at every emit site instead.

---

## Warnings

### WR-01: Missing config raises `KeyError` instead of returning `{:error, _}`

**File:** `lib/rindle/streaming/provider/mux/http.ex:49-52`
**Issue:** `build_client/0` calls `Keyword.fetch!(cfg, :token_id)` and
`Keyword.fetch!(cfg, :token_secret)`. If an adopter forgets to set these (or
sets `nil`), the function raises `KeyError` mid-request. The adapter's case
clauses (`{:error, msg, env}`, `{:error, reason}`) do not catch raises, so
the worker crashes and Oban retries the same misconfiguration up to
`max_attempts: 5`.

Same issue in `signed_playback_url/3`: if `:signing_key_id` or
`:signing_private_key` is missing, `Mux.Token.sign_playback_id/2` will
eventually crash inside JOSE with a less obvious error.

**Fix:** Validate config at adapter entry and return a clean error tuple:

```elixir
defp build_client do
  cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
  with {:ok, token_id} <- fetch_required(cfg, :token_id),
       {:ok, token_secret} <- fetch_required(cfg, :token_secret) do
    {:ok, Mux.Base.new(token_id, token_secret)}
  end
end

defp fetch_required(cfg, key) do
  case Keyword.get(cfg, key) do
    v when is_binary(v) and v != "" -> {:ok, v}
    _ -> {:error, {:missing_config, key}}
  end
end
```

…and propagate `{:error, _}` from each callback. Same for signing config.

---

### WR-02: `fetch_sig_header/1` only handles two header casings

**File:** `lib/rindle/streaming/provider/mux.ex:298-304`
**Issue:** The header lookup hardcodes `"mux-signature"` (lowercase) and
`"Mux-Signature"` (title case). HTTP header names are case-insensitive
(RFC 7230); Plug normalizes to lowercase, but adopter wrappers, edge
proxies, or future libraries may pass other casings (e.g., `MUX-SIGNATURE`,
`Mux-signature`). Any unexpected casing yields `:error → {:error,
:provider_webhook_invalid}` even when the signature is valid.

**Fix:** Normalize the entire map once:

```elixir
defp fetch_sig_header(headers) do
  downcased = Map.new(headers, fn {k, v} -> {String.downcase(to_string(k)), v} end)
  case Map.fetch(downcased, "mux-signature") do
    {:ok, sig} -> {:ok, sig}
    :error -> :error
  end
end
```

Add a test exercising mixed-case headers.

---

### WR-03: Sync no-op path emits `:resolved` with stale `age_ms`

**File:** `lib/rindle/workers/mux_sync_provider_asset.ex:155-163, 193-205`
**Issue:** When `live_state == row.state` the worker emits `:resolved` with
`age_ms: age_ms(row.updated_at)`. But the row's `updated_at` is from BEFORE
this sync attempt (no DB write happened), so `age_ms` reflects "time since
last actual change" rather than "time since last sync attempt." Adopters
building dashboards on `age_ms` will see this metric balloon while syncs are
working perfectly — they just observe nothing changing.

This is contradictory with the `:stuck` semantics where `age_ms` is the
threshold-driving metric. Two events with the same metric name carry two
different semantics.

**Fix:** Either (a) document this explicitly in the moduledoc telemetry
contract, or (b) emit `last_synced_at_ms` separately when the row has not
changed:

```elixir
defp emit_sync_event(stage, row, profile, opts \\ []) do
  measurements =
    %{system_time: System.system_time()}
    |> Map.merge(Keyword.get(opts, :measurements, %{}))

  metadata = %{
    profile: profile,
    provider: :mux,
    asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),
    provider_state: row.state,
    age_ms: age_ms(row.updated_at),
    no_change: Keyword.get(opts, :no_change, false)
  }

  :telemetry.execute([:rindle, :provider, :sync, stage], measurements, metadata)
end
```

---

### WR-04: FSM rejection in `apply_state_transition/4` produces noisy retries

**File:** `lib/rindle/workers/mux_sync_provider_asset.ex:155-187`
**Issue:** When the live state does not match the row state and the FSM
rejects the transition (e.g., `:processing → :uploading`, or any forbidden
edge), `ProviderAssetFSM.transition/3` returns `{:error, {:invalid_transition,
_, _}}`. The `with` chain propagates this as `{:error, _}` from `perform/1`,
which Oban retries up to `max_attempts: 3`. Every retry will see the same
state and fail identically. The job ultimately exhausts retries with no
useful state change.

The forbidden-transition case is much more likely than expected because Mux
states (e.g., `"errored"`) can appear unexpectedly relative to local row
state.

**Fix:** Catch `{:error, {:invalid_transition, _, _}}` explicitly and decide
between `:cancel` (no retry) or transitioning to `:errored` with a
descriptive reason:

```elixir
case ProviderAssetFSM.transition(row.state, live_state, ctx) do
  :ok ->
    # ... normal write path

  {:error, {:invalid_transition, from, to}} ->
    # Force-resolve to :errored with a diagnostic reason rather than
    # burning retry budget on a structurally impossible transition.
    reconcile_to_errored(repo, row, "live state #{to} not reachable from #{from}")
end
```

---

### WR-05: `normalize_state/1` passes unknown statuses through as-is

**File:** `lib/rindle/streaming/provider/mux.ex:307-311` /
`lib/rindle/streaming/provider/mux/event.ex:38-42`
**Issue:** The fall-through clause:

```elixir
defp normalize_state(other) when is_binary(other), do: other
```

returns any unrecognized Mux status verbatim (e.g., a hypothetical
`"transcoding"` or future status). This non-allowlisted string then flows
into `MuxSyncProviderAsset.apply_state_transition/4` which calls
`ProviderAssetFSM.transition(row.state, "transcoding", _)` — the FSM rejects
it, retries burn (per WR-04), and adopters see opaque
`{:invalid_transition, _, "transcoding"}` errors.

The Event module is stricter (`_ → nil`) but then `nil` flows into
`provider_event.state`, which downstream code may not expect either.

**Fix:** Add an explicit allowlist + telemetry on the unknown branch so
operators learn about new Mux statuses promptly:

```elixir
@known_states ~w(preparing ready errored)

defp normalize_state(s) when s in @known_states, do: do_normalize(s)
defp normalize_state(other) when is_binary(other) do
  Logger.warning("rindle.mux.unknown_status", status: other)
  nil
end
defp normalize_state(_), do: nil
```

…and have downstream code treat `nil` as "ignore this update" rather than
flowing it into the FSM.

---

### WR-06: `sync_with_provider/2` does not write `last_sync_error` on adapter failures

**File:** `lib/rindle/workers/mux_sync_provider_asset.ex:148-150`
**Issue:** When `Adapter.get_asset/1` returns `{:error, reason}` (any reason
other than `:not_found`), the worker simply propagates `{:error, reason}` to
Oban without recording WHY the sync failed in the row's `last_sync_error`
column. After `max_attempts: 3` exhausts, the row has no operator-visible
diagnostic — it just reverts to its previous state with no breadcrumb.

Compare with `mark_stuck/2` which DOES write `last_sync_error: reason`.

**Fix:** On adapter error, persist the error reason before returning:

```elixir
{:error, reason} ->
  reason_string =
    cond do
      is_binary(reason) -> reason
      true -> inspect(reason)
    end
    |> String.slice(0, 4096)

  _ =
    row
    |> MediaProviderAsset.changeset(%{last_sync_error: reason_string})
    |> repo.update()

  {:error, reason}
```

(Note `validate_length(:last_sync_error, max: 4096)` enforces the cap.)

---

### WR-07: Coordinator scan is unbounded and unordered

**File:** `lib/rindle/workers/mux_sync_coordinator.ex:85-94`
**Issue:** The query
```elixir
from r in MediaProviderAsset,
  where: r.state in ["processing", "uploading"] and r.updated_at < ^cutoff and
    not is_nil(r.provider_asset_id),
  select: r.provider_asset_id
```
has no `LIMIT` and no `ORDER BY`. At scale (>10k stuck rows during an outage)
this fetches all IDs into memory, builds 10k Oban inserts, and blocks the
cron tick. The moduledoc acknowledges this ("Phase 34 ships unbounded scan;
if real-world adopter feedback shows queue floods (>1k stuck rows), add a
`LIMIT` cap in v1.7") — however waiting for adopter pain is a poor mitigation
strategy when the fix is one line.

There is also no chunking of `Oban.insert/1` calls; each is a separate
transaction.

**Fix:** Add a configurable cap with a sane default (e.g., 1000 per tick) and
order by `updated_at ASC` so oldest rows are addressed first:

```elixir
limit = config(:provider_polling_batch_size, 1_000)

provider_asset_ids =
  repo.all(
    from r in MediaProviderAsset,
      where: r.state in ["processing", "uploading"] and r.updated_at < ^cutoff and
        not is_nil(r.provider_asset_id),
      order_by: [asc: r.updated_at],
      limit: ^limit,
      select: r.provider_asset_id
  )
```

This is an out-of-scope perf concern only if you accept the documented
deferral; otherwise it is a real robustness gap.

---

### WR-08: Coordinator silently swallows individual `Oban.insert/1` failures

**File:** `lib/rindle/workers/mux_sync_coordinator.ex:95-104`
**Issue:** The `Enum.map / Enum.count(&match?({:ok, _}, &1))` pipeline counts
successful inserts and discards everything else — failures (e.g., DB
connection timeouts, Oban table contention) are silently dropped, and the
log line at lines 106-110 reports `jobs_enqueued < rows_scanned` with no
explanation. Operators see "10 of 50 enqueued" with no signal about whether
the other 40 are dedup'd via `unique:` or genuinely failed.

**Fix:** Distinguish the three outcomes (`{:ok, _}` fresh, `{:ok, %{conflict?:
true}}` dedup'd, `{:error, _}` failed) and log all three:

```elixir
{ok_fresh, ok_conflict, errors} =
  provider_asset_ids
  |> Enum.reduce({0, 0, []}, fn id, {f, c, errs} ->
    case Oban.insert(MuxSyncProviderAsset.new(...)) do
      {:ok, %{conflict?: true}} -> {f, c + 1, errs}
      {:ok, _} -> {f + 1, c, errs}
      {:error, reason} -> {f, c, [reason | errs]}
    end
  end)

if errors != [], do: Logger.warning("rindle.workers.mux_sync_coordinator.errors", count: length(errors))
```

---

### WR-09: `:exception` event metadata may carry unredacted error reasons

**File:** `lib/rindle/workers/mux_ingest_variant.ex:163-175`
**Issue:** On the `{:error, reason}` exception path, the worker does:

```elixir
base_metadata(profile_mod, args["variant_name"], nil)
|> Map.put(:kind, :error)
|> Map.put(:reason, reason)
```

`reason` is whatever `call_mux_create/2` propagates. Today that's a sanitized
atom (e.g., `:provider_sync_failed`), but the adapter has a fall-through
`{:error, reason} -> {:error, reason}` branch (mux.ex:139, 193) that lets
arbitrary terms (e.g., `%Tesla.Env{body: "<html>...500 page from CloudFront
mentioning the asset id...</html>"}`) bleed through. If a future error path
returns a struct or string containing the `provider_asset_id`, this leaks
into telemetry metadata and bypasses the security-invariant-14 redaction
discipline.

**Fix:** Whitelist the reason atoms and inspect-truncate everything else:

```elixir
defp safe_reason(reason) when is_atom(reason), do: reason
defp safe_reason(reason), do: reason |> inspect() |> String.slice(0, 200)

# usage
|> Map.put(:reason, safe_reason(reason))
```

…or stop propagating raw error reasons in telemetry metadata altogether (the
`kind: :error` flag is enough for routing).

---

## Info

### IN-01: `Event.parse_occurred_at/1` does not cover Mux's Unix-string `created_at`

**File:** `lib/rindle/streaming/provider/mux/event.ex:54-63` /
`test/fixtures/mux/asset_create_201.json:13`
**Issue:** The fixture `asset_create_201.json` carries
`"created_at": "1700000000"` — a Unix timestamp as a string, which is what
the Mux REST API actually returns on the asset object. `parse_occurred_at/1`
only handles ISO8601 strings via `DateTime.from_iso8601/1`. For Unix-style
strings the parser silently returns `nil`. Webhook payloads do use ISO8601
(per the webhook fixture), so this only matters when other code paths feed
Mux REST `created_at` values into Event normalization. Today no caller does,
but the asymmetry is a footgun.

**Fix:** Add an `Integer.parse/1` fallback:

```elixir
defp parse_occurred_at(iso) when is_binary(iso) do
  case DateTime.from_iso8601(iso) do
    {:ok, dt, _} -> dt
    _ ->
      case Integer.parse(iso) do
        {seconds, ""} -> DateTime.from_unix!(seconds, :second)
        _ -> nil
      end
  end
end
```

---

### IN-02: Test setup mutates app env without `Keyword.merge`

**File:** `test/rindle/workers/mux_sync_coordinator_test.exs:55-57, 89-91, 108-110`
**Issue:** Each `Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
provider_polling_floor_seconds: 30)` REPLACES the entire env keyword list
with a single key. The outer `setup` block at lines 8-12 saves and restores
`prev`, so cross-test leakage is bounded — but within a single test, code
that depends on other config keys (e.g., `:http_client` if
`MuxSyncProviderAsset` ever runs against the mock from this test) would see
those keys missing.

This is fine today because the coordinator test only exercises fan-out and
never invokes the per-row worker, but it's a fragile pattern. The other
tests (`mux_test.exs`, `mux_ingest_variant_test.exs`,
`signed_playback_url_test.exs`) use `Keyword.merge(prev, ...)` correctly.

**Fix:** Use `Keyword.merge(prev, ...)` consistently:

```elixir
Application.put_env(
  :rindle,
  Rindle.Streaming.Provider.Mux,
  Keyword.merge(prev, provider_polling_floor_seconds: 30)
)
```

(`prev` here would need to be captured per-test or hoisted out.)

---

### IN-03: `signed_playback_url/3` interpolates `playback_id` into the URL without escaping

**File:** `lib/rindle/streaming/provider/mux.ex:266`
**Issue:** `url = "https://stream.mux.com/#{playback_id}.m3u8?token=#{jwt}"`
interpolates the `playback_id` directly. Mux playback IDs are documented as
URL-safe alphanumeric strings, so in practice this is fine. However, no input
validation enforces the assumption — an adopter passing a malicious or
malformed playback_id (e.g., one containing `?`, `#`, or `/`) could craft a
URL that is opened on a different path. Belt-and-suspenders: validate the
playback_id format or `URI.encode_www_form/1` it.

The JWT itself uses base64url-safe characters (`[A-Za-z0-9_\-\.]`) so JWT
interpolation is safe.

**Fix (low-priority):**

```elixir
unless String.match?(playback_id, ~r/^[A-Za-z0-9_-]+$/),
  do: raise ArgumentError, "invalid playback_id format"
```

…or `URI.encode/1` the path segment defensively.

---

_Reviewed: 2026-05-06T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
