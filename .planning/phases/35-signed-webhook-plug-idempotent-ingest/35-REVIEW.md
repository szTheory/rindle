---
phase: 35-signed-webhook-plug-idempotent-ingest
reviewed: 2026-05-06T00:00:00Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - lib/mix/tasks/rindle.runtime_status.ex
  - lib/rindle/delivery/webhook_body_reader.ex
  - lib/rindle/delivery/webhook_plug.ex
  - lib/rindle/ops/runtime_status.ex
  - lib/rindle/streaming/provider.ex
  - lib/rindle/streaming/provider/mux.ex
  - lib/rindle/streaming/provider/mux/event.ex
  - lib/rindle/workers/ingest_provider_webhook.ex
  - test/fixtures/mux/webhook_video_asset_created.json
  - test/fixtures/mux/webhook_video_asset_deleted.json
  - test/fixtures/mux/webhook_video_asset_errored.json
  - test/fixtures/mux/webhook_video_asset_ready.json
  - test/fixtures/mux/webhook_video_upload_asset_created.json
  - test/rindle/delivery/webhook_body_reader_test.exs
  - test/rindle/delivery/webhook_plug_test.exs
  - test/rindle/ops/runtime_status_test.exs
  - test/rindle/runtime_status_task_test.exs
  - test/rindle/streaming/provider/mux/event_test.exs
  - test/rindle/streaming/provider/mux/mux_test.exs
  - test/rindle/test/mux_webhook_fixtures_test.exs
  - test/rindle/workers/ingest_provider_webhook_test.exs
  - test/support/mux_webhook_fixtures.ex
findings:
  critical: 0
  warning: 6
  info: 7
  total: 13
status: issues_found
---

# Phase 35: Code Review Report

**Reviewed:** 2026-05-06
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Phase 35 ships a security-sensitive webhook ingest pipeline. The HMAC verification path is sound — it delegates to the Mux SDK, which uses constant-time comparison (`Mux.Webhooks.secure_compare/3`) for signatures. The trust boundary is correctly drawn at the Plug edge, with the worker explicitly NOT re-verifying. The 1 MiB body cap is enforced correctly on the documented body-reader path, and Oban uniqueness keys (`event_id`) are mirrored between Plug and worker. PubSub payloads correctly omit `provider_asset_id` (security invariant 14), and telemetry routes through `MediaProviderAsset.redact_id/1`.

No CRITICAL findings. Six WARNING-level issues center on three themes:
1. **Defense-in-depth gap in the body-cap fallback** — `Plug.Conn.read_body/2` is called without a `:length` cap, so a misconfigured adopter (no `body_reader` plug) silently allows ~8 MB bodies, defeating the documented 1 MiB cap.
2. **Coupling between Plug and worker** — the unique-job opts are duplicated inline in the Plug rather than calling `IngestProviderWebhook.unique_job_opts/0`, creating a drift hazard for the very idempotency invariant the worker docstring underscores.
3. **Resolver hardening gaps** — empty `:application` paths and `nil` `webhook_tolerance_seconds` crash at first webhook delivery instead of failing at boot.

Several INFO items document Mux-SDK behavior (one-sided timestamp window) and minor code-quality items (sort tiebreaker on `inspect/1`, FSM idempotency on stuck retransmits, atom table growth on dynamic `provider_atom`).

## Warnings

### WR-01: Body-cap fallback bypasses 1 MiB limit (defense-in-depth gap)

**File:** `lib/rindle/delivery/webhook_plug.ex:223-237`

**Issue:** `fetch_raw_body/1`'s fallback path calls `Plug.Conn.read_body(conn)` with no options when the `:raw_body` assign is missing. `Plug.Conn.read_body/2` defaults to `:length` of 8 MB (per `deps/plug/lib/plug/conn.ex:1163-1164`), eight times the documented 1 MiB cap (`@max_body_bytes` in `WebhookBodyReader`). If an adopter forgets to wire `Plug.Parsers, body_reader: {Rindle.Delivery.WebhookBodyReader, :read_body, []}`, the Plug silently accepts bodies up to ~8 MB:

* attacker sends a Mux-signed 7 MB payload
* signature verifies (Mux signs whatever they sign)
* Oban inserts a job whose `args` jsonb column carries the entire payload
* a malicious provider that compromises the secret can balloon Postgres storage / amplify retries

The module's own docstring (line 44, "Body reader assign missing AND fallback empty") implies the fallback is intentional but does NOT mention that the fallback is uncapped. Cap the fallback to match the body-reader path.

**Fix:**
```elixir
defp fetch_raw_body(conn) do
  case Rindle.Delivery.WebhookBodyReader.raw_body(conn) do
    binary when is_binary(binary) and byte_size(binary) > 0 ->
      {:ok, binary, conn}

    _ ->
      # Cap the fallback to the same 1 MiB ceiling as the body reader so a
      # missing :body_reader hook cannot silently accept 8 MB bodies.
      case Plug.Conn.read_body(conn, length: 1_048_576) do
        {:ok, body, conn} when byte_size(body) > 0 -> {:ok, body, conn}
        {:more, _partial, _conn} -> {:error, :body_missing}
        _ -> {:error, :body_missing}
      end
  end
end
```

---

### WR-02: Plug duplicates `unique_job_opts/0` inline; drift will silently break idempotency

**File:** `lib/rindle/delivery/webhook_plug.ex:175-185`

**Issue:** The Plug constructs its own `unique_opts` keyword list inline rather than calling `Rindle.Workers.IngestProviderWebhook.unique_job_opts/0` (which exists at `lib/rindle/workers/ingest_provider_webhook.ex:93-100` for exactly this purpose). The comment at line 175 — "Mirror Rindle.Workers.IngestProviderWebhook.unique_job_opts/0 (D-20)" — explicitly acknowledges the coupling. Any future change to the worker's idempotency window (e.g. shrinking `period: 86_400` to 3600, or removing `:available` from `states`) will break dedup at the Plug edge until the inline copy is also updated. This is the central correctness invariant the worker's race-snooze logic depends on.

`unique_job_opts/0` is already public (`@spec` exposed) and called by the worker test (`test/rindle/workers/ingest_provider_webhook_test.exs:136-142`). The Plug should call the same accessor.

**Fix:**
```elixir
:dispatch ->
  try do
    args = %{
      "event_id" => event_id,
      "provider" => provider_atom_string(provider),
      "event_type" => event_type,
      "event" => stringify_event(event)
    }

    {:ok, _job} =
      args
      |> Rindle.Workers.IngestProviderWebhook.new(
        unique: Rindle.Workers.IngestProviderWebhook.unique_job_opts()
      )
      |> Oban.insert()
    # ... rest unchanged
```

---

### WR-03: `{:application, _, []}` resolver passes `init/1` validation but crashes at first delivery

**File:** `lib/rindle/delivery/webhook_plug.ex:246, 282-284`

**Issue:** `valid_secrets_resolver?({:application, app, path}) when is_atom(app) and is_list(path)` accepts an empty `path` list. But `resolve_secrets({:application, app, [key | rest]})` requires the path to be non-empty (head/tail destructure). Calling `init/1` with `secrets: {:application, :rindle, []}` succeeds; the FIRST webhook delivery raises `FunctionClauseError` (no clause matches `{:application, :rindle, []}` — falls through to the `_` clause that returns `[]`, so no crash actually — it returns `[]` which then triggers `:no_secrets_configured`).

Wait — re-tracing: an empty path falls to `defp resolve_secrets(_), do: []`, so the request gets a `:no_secrets_configured` 400 response rather than a crash. That's actually safe but misleading: the deployment-time validator promises to surface misconfigurations at boot ("Raises ArgumentError for misconfigurations so deployment-time mistakes surface immediately, not at first webhook delivery" — line 81 docstring), yet `{:application, :rindle, []}` survives `init/1` and only manifests at runtime as a generic 400. Either reject empty paths in the validator OR document that an empty path is treated as "no secrets".

**Fix:** Reject empty path in the validator to honor the documented contract:
```elixir
defp valid_secrets_resolver?({:application, app, path})
     when is_atom(app) and is_list(path) and path != [],
     do: Enum.all?(path, &is_atom/1)
```

---

### WR-04: `webhook_tolerance_seconds: nil` crashes the verify path with ArithmeticError

**File:** `lib/rindle/streaming/provider/mux.ex:276`

**Issue:** `tolerance = config(:webhook_tolerance_seconds, 300)` — `config/2` uses `Keyword.get/3`, which returns `nil` (NOT the default) when the key is present with an explicit `nil` value. The Mux SDK's `Mux.Webhooks.verify_header/4` then reaches `check_timestamp(timestamp, nil)` (`deps/mux/lib/mux/webhooks.ex:65-72`), which executes `now - nil` and raises `ArithmeticError`. The Plug's `safe_verify/4` rescues this into `{:error, :callback_raised, message}` and responds 400, but the 500 contract for misconfiguration is bypassed AND telemetry conflates a genuine signature failure with a config bug.

A boot-time validator on the Mux adapter config OR a runtime guard in `verify_webhook/3` would surface this cleanly.

**Fix:**
```elixir
tolerance =
  case config(:webhook_tolerance_seconds, 300) do
    n when is_integer(n) and n > 0 -> n
    _ -> 300
  end
```

---

### WR-05: Plug emits `event_id: nil` to telemetry / Oban when `raw["id"]` is absent

**File:** `lib/rindle/delivery/webhook_plug.ex:152-153, 167-173`

**Issue:** `event_id = Map.get(raw, "id")` returns `nil` if the verified payload lacks a top-level `"id"` field. This nil is then:

1. Used as the Oban unique key (`"event_id" => nil`). Oban's unique constraint groups all `event_id: nil` entries together, so two unrelated webhook events lacking an `id` would dedupe against each other — silent data loss for the second.
2. Emitted in `[:rindle, :provider, :webhook, :verified]` telemetry as `event_id: nil`.

Mux always sends a top-level `id` in production, but the contract `Rindle.Streaming.Provider.@type provider_event` does NOT require `raw["id"]` to be present. Defensive validation + reject (or pass to Oban without `unique` when nil) prevents the cross-event collision.

**Fix:**
```elixir
defp dispatch_event(conn, provider, event) do
  raw = Map.get(event, :raw, %{})
  event_id = Map.get(raw, "id")
  event_type = Map.get(raw, "type")

  cond do
    is_nil(event_id) ->
      emit_rejected(:missing_event_id, %{
        provider: provider_atom(provider),
        event_type: event_type
      })

      send_invalid(conn)

    true ->
      case provider.dispatch_kind(event_type) do
        # ... unchanged
      end
  end
end
```

---

### WR-06: `runtime_status/1` re-runs every sub-report twice per call

**File:** `lib/rindle/ops/runtime_status.ex:227-249`

**Issue:** `recommendations/3` calls `runtime_checks_report/3`, `variant_report/3`, `upload_session_report/3`, and `provider_assets_report/2` AGAIN solely to harvest finding classes (lines 229, 233, 237, 241). All four reports already ran in `runtime_status/1` (lines 46-50). Each report executes 1-3 ECTO queries plus row classification work. The `--provider-stuck` query in particular runs twice on a `provider_stuck: true` invocation. While performance is out of v1 review scope, this is a logic-duplication defect: future fixes to one call site (e.g. classification rules drift) won't apply to the other.

The straightforward fix is to capture the four sub-reports once and pass their findings into `recommendations/1`.

**Fix:**
```elixir
def runtime_status(opts \\ []) do
  with {:ok, filters} <- normalize_filters(opts) do
    now = DateTime.utc_now()
    cutoff = older_than_cutoff(now, filters.older_than)

    runtime_checks = runtime_checks_report(filters, cutoff, now)
    variants = variant_report(filters, cutoff, now)
    upload_sessions = upload_session_report(filters, cutoff, now)
    provider_assets = provider_assets_report(filters, now)

    {:ok,
     %{
       generated_at: now,
       filters: filters,
       runtime_checks: runtime_checks,
       assets: asset_report(filters),
       variants: variants,
       upload_sessions: upload_sessions,
       provider_assets: provider_assets,
       recommendations:
         build_recommendations(runtime_checks, variants, upload_sessions, provider_assets)
     }}
  else
    {:error, reason} = error ->
      emit_runtime_refusal(reason)
      error
  end
end

defp build_recommendations(runtime_checks, variants, upload_sessions, provider_assets) do
  classes =
    Enum.map(runtime_checks.findings, & &1.class) ++
      Enum.map(variants.findings, & &1.class) ++
      Enum.map(provider_assets.findings, & &1.class)

  upload_states = Enum.map(upload_sessions.findings, & &1.state)

  classes
  |> Enum.uniq()
  |> Enum.map(&recommendation_for_class/1)
  |> Enum.reject(&is_nil/1)
  |> Kernel.++(upload_recommendations(upload_states))
end
```

---

## Info

### IN-01: Mux SDK timestamp check is one-sided (no upper-bound on future timestamps)

**File:** `lib/rindle/streaming/provider/mux.ex:285` (delegates to `deps/mux/lib/mux/webhooks.ex:65-72`)

**Issue:** `Mux.Webhooks.check_timestamp/2` only rejects `timestamp < now - tolerance`. A signed payload with a future timestamp (e.g. `now + 86_400`) verifies indefinitely. Exploitation requires possession of the secret AND a captured-or-forged future-dated header, so the practical risk is low: an attacker with the secret can already mint arbitrary signatures. But for clock-skew defense and stricter Stripe-parity, an upper bound `timestamp > now + tolerance` SHOULD be enforced.

This is an SDK behavior, not a Rindle bug — but Rindle could wrap `Mux.Webhooks.verify_header/4` with a pre-check that bounds the timestamp on both sides, or document the gap so adopters running clocks that drift forward don't silently inherit unbounded signature lifetime.

**Fix:** No code change required for v1.6. Consider a wrapper in Phase 36+ if Mux upstream doesn't add an upper bound. Alternative: parse `t=` from the header before calling SDK and reject ahead-of-time.

---

### IN-02: `Enum.find_value` continues iterating after JSON parse failure on a verified secret

**File:** `lib/rindle/streaming/provider/mux.ex:282-309`

**Issue:** When a secret matches HMAC verification but `Jason.decode/1` or `Event.normalize/1` fails on the body, the `:ok` branch returns `nil` — `Enum.find_value` then continues to the next secret. Each subsequent secret runs another constant-time HMAC and emits another `:rejected` telemetry event. This wastes CPU and produces misleading telemetry (signature DID match the first secret).

In practice this triggers only if Mux sends invalid JSON, which would be a Mux outage. Low impact, but a more direct shape would short-circuit JSON failures:

**Fix:**
```elixir
result =
  Enum.reduce_while(Enum.with_index(secrets), {:error, :provider_webhook_invalid}, fn
    {secret, index}, _acc ->
      case Mux.Webhooks.verify_header(raw_body, sig_header, secret, tolerance) do
        :ok ->
          :telemetry.execute(
            [:rindle, :provider, :mux, :webhook_attempt, :secret_used],
            %{system_time: System.system_time()},
            %{secret_index: index}
          )

          # Halt on signature match — JSON failure is its own terminal error.
          case Jason.decode(raw_body) do
            {:ok, decoded} ->
              case Event.normalize(decoded) do
                {:ok, evt} -> {:halt, {:ok, evt}}
                err -> {:halt, err}
              end

            err ->
              {:halt, err}
          end

        {:error, sdk_reason} ->
          # ... unchanged telemetry
          {:cont, {:error, :provider_webhook_invalid}}
      end
  end)
```

---

### IN-03: `provider_atom/1` uses `String.to_atom/1` (unsafe) on Module.split tail

**File:** `lib/rindle/delivery/webhook_plug.ex:328-334`

**Issue:** For non-Mux providers, `provider_atom/1` calls `String.to_atom/1` (NOT `String.to_existing_atom/1`). Each new provider module that flows through this code path creates a new atom. Phase 35 only ships Mux (with an explicit clause), so production atom growth is bounded. Future test fixtures or dynamic provider modules could leak atoms.

**Fix:** Either require an explicit clause per provider (locked enum) or use `String.to_existing_atom/1` and rescue:
```elixir
defp provider_atom(other) when is_atom(other) do
  name = other |> Module.split() |> List.last() |> String.downcase()

  try do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> :unknown_provider
  end
end
```

---

### IN-04: `Enum.sort_by` tiebreaker on `inspect/1` is fragile

**File:** `lib/rindle/ops/runtime_status.ex:476, 492`

**Issue:** `sorted = Enum.sort_by(rows, &{-&1.age_seconds, inspect(&1.sample)})` — using `inspect/1` as a deterministic-order tiebreaker depends on Inspect protocol output, which is documented as not guaranteed stable across Elixir versions. For the test suite this works because `inspect/1` on the sample maps is deterministic in the current runtime, but a future Elixir change to map iteration / inspect formatting could silently shuffle which sample appears first when ages tie. Replace with a stable field-based tiebreaker (e.g. `asset_id` or `variant_name`).

**Fix:**
```elixir
sorted = Enum.sort_by(rows, &{-&1.age_seconds, &1.sample.asset_id})
```

---

### IN-05: Worker FSM rejection on idempotent retransmits cancels the job (not a no-op)

**File:** `lib/rindle/workers/ingest_provider_webhook.ex:232-262, 310-343`

**Issue:** If the same `video.asset.created` event re-delivers AFTER the 24h Oban unique window has expired AND the row already advanced to `:processing`, `ProviderAssetFSM.transition("processing", "processing", _)` rejects (the FSM allowlist has no `processing -> processing` self-loop). The worker then returns `{:cancel, fsm_err}` and emits `[:rindle, :provider, :webhook, :exception]` with `kind: :invalid_transition`. Operationally indistinguishable from a real FSM violation in metrics. Same applies to `video.asset.deleted` against an already-deleted row.

This is a known consequence of the locked transition table — there's no clean fix without a "no-op if already in target state" semantic at the FSM layer (which would be a behavior change). Document as accepted; consider an `:idempotent_retransmit` telemetry kind if operators flag it.

**Fix:** No code change for v1.6. If operators report alarm fatigue from this:
```elixir
defp dispatch(repo, row, %{"event_type" => "video.asset.deleted"} = args) when row.state == "deleted" do
  emit(:ignored, args, %{kind: :idempotent_retransmit, from_state: row.state, to_state: row.state})
  :ok
end
```

---

### IN-06: `last_sync_error` from provider may surface in operator-facing reports

**File:** `lib/rindle/ops/runtime_status.ex:221, lib/rindle/workers/ingest_provider_webhook.ex:196`

**Issue:** `provider_asset_sample/2` includes the raw `last_sync_error` string in the `runtime_status` report (text and JSON). The error string is populated from Mux's `data.errors.messages` — operationally a low-trust string. If Mux ever includes URLs (signed input URLs) in error messages, those URLs land in `last_sync_error`, which then renders in the Mix task output and `Rindle.runtime_status/1` JSON. Out of Rindle's direct control (Mux owns the format), but worth a length cap or scrub regex if PII surfaces.

The schema validation at `Rindle.Domain.MediaProviderAsset.changeset/2` enforces `validate_length(:last_sync_error, max: 4096)` (line 110), so unbounded growth is prevented. Content sensitivity is the open concern.

**Fix:** No code change required. Track in deferred-items if Mux's error format changes.

---

### IN-07: `stringify_event/1` does not recursively stringify nested atom-keyed maps

**File:** `lib/rindle/delivery/webhook_plug.ex:314-321`

**Issue:** `stringify_event/1` only stringifies top-level atom keys. The current `Event.normalize/1` produces `raw: %{"type" => ..., "data" => ...}` (string keys throughout, since it comes from `Jason.decode/1`), so this works. But if a future provider returns a `provider_event` with nested atom-keyed maps (e.g. `:metadata` field with atom keys), Oban's Jason encoder would still serialize them, BUT round-tripping through Postgres jsonb stringifies all keys — meaning the worker's reads `event["metadata"]["some_key"]` rather than `[:some_key]`. The asymmetry is fragile for future adapters.

Document the contract OR make `stringify_event/1` recursive. The behaviour callback contract (`Rindle.Streaming.Provider.@type provider_event`) does not currently require nested values to be JSON-friendly.

**Fix:** No code change required for v1.6 since only Mux ships in Phase 35. Annotate the typespec or constrain via `behaviour` checks before adding a second adapter.

---

_Reviewed: 2026-05-06_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
