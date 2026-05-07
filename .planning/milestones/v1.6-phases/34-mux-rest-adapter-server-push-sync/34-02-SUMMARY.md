---
phase: 34-mux-rest-adapter-server-push-sync
plan: 02
subsystem: streaming
tags: [mux, oban, ingest, worker, atomic-promote, idempotency, telemetry]
requirements: [MUX-03, MUX-05, MUX-06]

dependency-graph:
  requires:
    - "Plan 01 — `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3` worker-facing 429-aware variant"
    - "Plan 01 — `Rindle.Domain.MediaProviderAsset.redact_id/1` public-promotion (security invariant 14)"
    - "Plan 01 — `Rindle.Streaming.Provider.Mux.ClientMock` Mox registration in `test/support/mocks.ex`"
    - "Plan 01 — `test/fixtures/mux/asset_create_201.json` cassette + `test_signing_private_key.pem`"
    - "Phase 33 — `Rindle.Domain.MediaProviderAsset` schema (PLURAL `playback_ids` array; row uniqueness on `(asset_id, profile, provider_name)`)"
    - "Phase 33 — `Rindle.Domain.ProviderAssetFSM.transition/3` with MAP context (forbidden `processing → uploading` edge)"
    - "Phase 33 — `Rindle.Delivery.url/3` with `:expires_in` opt pass-through"
    - "v1.4 — `Rindle.Workers.ProcessVariant.persist_ready/7` atomic-promote pattern (lines 244-275)"
  provides:
    - "`Rindle.Workers.MuxIngestVariant` server-push ingest Oban worker (queue: `:rindle_provider`, max_attempts: 5)"
    - "`Rindle.Workers.MuxIngestVariant.unique_job_opts/0` keyword opts for adopter-side `Oban.insert/2` deduplication"
    - "Telemetry contract `[:rindle, :provider, :ingest, :start | :stop | :exception]` with redacted `asset_id` metadata"
  affects:
    - "Adopter-side hook code may now `Oban.insert(MuxIngestVariant.new(args, unique: MuxIngestVariant.unique_job_opts()))` once a `MediaVariant` reaches `:ready`. Phase 36 ships the canonical adopter-wiring guide."

tech-stack:
  added: []
  patterns:
    - "Optional-dep guard wraps the entire worker module in `if Code.ensure_loaded?(Mux.Video.Assets) do ... end` (Pitfall 4 #2; mirrors `live_view.ex:1`)."
    - "Atomic-promote race protection mirrors `process_variant.ex:244-275` verbatim — re-fetch `MediaAsset` and `MediaVariant` just before the `:processing` flip and abort with `{:cancel, {:stale_source, _}}` on `storage_key` or `recipe_digest` drift."
    - "Adapter-internal API consumption: worker calls `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3` (the 429-aware variant) — PLURAL Mux REST key construction (`inputs`, `playback_policies`) NEVER duplicated in the worker."
    - "Two-layer idempotency: (1) Oban `unique` keyed on `(asset_id, profile, variant_name)` for JOB-level dedup; (2) `maybe_skip_already_in_progress/4` short-circuits perform-level re-runs on rows already in `:uploading` / `:processing` / `:ready` (avoids the forbidden `processing → uploading` FSM edge)."
    - "Security invariant 14 redaction at every telemetry emit via `Rindle.Domain.MediaProviderAsset.redact_id/1` (last-4-char tag)."
    - "429 `Retry-After` propagation: adapter returns `{:error, :provider_quota_exceeded, retry_after}`; worker translates to `{:snooze, retry_after}` for Oban."

key-files:
  created:
    - "lib/rindle/workers/mux_ingest_variant.ex"
    - "test/rindle/workers/mux_ingest_variant_test.exs"
  modified: []

decisions:
  - "Added `:available` to `unique_job_opts/0` `states:` list (Rule 1 bug fix). Plan-locked list `[:scheduled, :executing, :retryable, :completed]` excluded `:available`, but Oban inserts newly-enqueued jobs in `:available` by default — without it the dedup never fires for the most common case (re-enqueue right after the first insert, before the worker executes). Final shape `[:available, :scheduled, :executing, :retryable, :completed]` mirrors `process_variant.ex:412` (`@unique_states`)."
  - "Test profile uses the AV variant DSL `[hero: [kind: :video, preset: :web_720p]]` validated through `@video_variant_schema` (Phase 24/AV-02). Top-level `streaming:` key intentionally omitted (Plan 01 deviation #1: invalid in the Phase 33 DSL — must nest under `:delivery`); the worker test does not exercise the `:streaming` dispatch path so the absence is harmless."
  - "Storage mock stubs at the call site: `Rindle.StorageMock.capabilities/0 -> [:signed_url]` (so `Rindle.Delivery.url/3` passes `require_delivery_support`) and `Rindle.StorageMock.url/2 -> {:ok, signed_url}` (so the worker receives a fixture URL). Stubbed via `Mox.stub/3` so each test in the suite gets the same wiring without per-test boilerplate."

metrics:
  duration_minutes: 25
  completed_date: 2026-05-06
  tasks_completed: 2
  files_created: 2
  files_modified: 0
  tests_added: 9
  test_pass_rate: "9/9"
---

# Phase 34 Plan 02: Mux Ingest Worker Summary

## One-liner

`Rindle.Workers.MuxIngestVariant` server-push Oban worker pushes a Rindle-
produced AV variant to Mux via Plan 01's adapter-internal `create_asset_with_retry_hint/3`
API, persists `provider_asset_id` + PLURAL `playback_ids` into the Phase 33
`media_provider_assets` row, advances the FSM `pending → uploading →
processing`, and enforces atomic-promote race protection, two-layer
idempotency, 429 `Retry-After` snooze, and security invariant 14 redaction
at every telemetry emit.

## What was delivered

### Library code

| File | Role | Key behaviour |
| ---- | ---- | ------------- |
| `lib/rindle/workers/mux_ingest_variant.ex` (382 lines) | Oban worker | `use Oban.Worker, queue: :rindle_provider, max_attempts: 5`; `def timeout(_job), do: :timer.minutes(5)` (D-15 — integer ms only); `unique_job_opts/0` keyed on `(asset_id, profile, variant_name)` with `period: 86_400` and `:available` included in states; `perform/1` reads source via `Rindle.Delivery.url(profile, key, expires_in: 1_800)`, calls `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3`, persists PLURAL `playback_ids`, advances FSM. Wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do`. |

### Test code

| File | Role | Key behaviour |
| ---- | ---- | ------------- |
| `test/rindle/workers/mux_ingest_variant_test.exs` (288 lines) | Oban.Testing + Mox suite | 9 tests covering MUX-03, MUX-05 (job-level + perform-level), MUX-06 (asset_changed + recipe_changed + telemetry), Pitfall 3 (429 with header + 429 missing header), security invariant 14 (regex assertion on telemetry asset_id). Uses `setup :set_mox_from_context; setup :verify_on_exit!`; `use Oban.Testing, repo: Rindle.Repo`; inline `TestProfile` with AV variant DSL. |

## Test pass/fail breakdown

| Requirement | Test | Result |
| ----------- | ---- | ------ |
| MUX-03 (happy path) | "ingests variant, persists provider_asset_id + playback_ids (PLURAL), advances FSM to :processing" | PASS |
| MUX-05 job-level | "Oban.unique semantics: enqueue with unique opts deduplicates at the JOB level" | PASS |
| MUX-05 perform-level | "re-running perform on a row already in :processing yields :ok no-op (does not retry forbidden FSM edge)" | PASS |
| MUX-06 asset drift | "atomic_promote: storage_key drift returns {:cancel, {:stale_source, :asset_changed}}" | PASS |
| MUX-06 recipe drift | "atomic_promote: recipe_digest drift returns {:cancel, {:stale_source, :recipe_changed}}" | PASS |
| MUX-06 telemetry | "atomic_promote: drift emits [:rindle, :provider, :ingest, :exception] with kind: :cancelled" | PASS |
| Pitfall 3 (429 with header) | "429 from Mux returns {:snooze, retry_after_seconds}" | PASS |
| Pitfall 3 (429 missing header) | "429 with missing Retry-After defaults to 60s snooze" | PASS |
| Invariant 14 | "every [:rindle, :provider, :ingest, _] event has redacted asset_id (last-4-char tag)" | PASS |

`mix test test/rindle/workers/mux_ingest_variant_test.exs` final run: **9 tests, 0 failures**.

Combined Plan 01 + Plan 02 suite (`mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_ingest_variant_test.exs`): **30 tests, 0 failures**.

Regression check on `mix test test/rindle/workers/process_variant_test.exs`: **12 tests, 0 failures**.

`mix compile --warnings-as-errors`: exit 0.

## Atomic-promote race protection

The worker mirrors `lib/rindle/workers/process_variant.ex:244-275` (the v1.4
AV-03-10 `persist_ready/7` `cond` block) verbatim, with the captured-at-enqueue
arg-shape swap:

- Source: `current_asset.storage_key != asset.storage_key` and
  `current_variant.recipe_digest != variant.recipe_digest`.
- Plan 02 worker: `current_asset.storage_key != args["expected_storage_key"]`
  and `current_variant.recipe_digest != args["expected_recipe_digest"]`.

The check fires in two places:

1. `check_freshness/3` runs BEFORE the adapter call (line ~213 of
   `mux_ingest_variant.ex`) — short-circuits a stale ingest before any
   network I/O.
2. `persist_provider_processing/4` re-runs the freshness check after the
   adapter returns but before the FSM flip to `:processing` (line ~283) —
   catches drift that happened during the in-flight adapter call.

Both branches return `{:cancel, {:stale_source, :asset_changed | :recipe_changed}}`;
the worker's perform-level `else` clause translates that into a stop emission
with `kind: :cancelled` metadata before re-returning the cancel tuple. This
is the verbatim AV-03-10 pattern, asserted by Test 6 ("storage_key drift")
and Test 7 ("recipe_digest drift").

## `create_asset_with_retry_hint/3` consumption

The worker calls Plan 01's worker-facing variant exclusively at line ~351:

```elixir
case Adapter.create_asset_with_retry_hint(profile_mod, signed_url, playback_policy: :signed) do
  {:ok, %{provider_asset_id: _, playback_ids: _} = ok} -> {:ok, ok}
  {:error, :provider_quota_exceeded, retry_after} when is_integer(retry_after) and retry_after > 0 ->
    {:snooze, retry_after}
  {:error, reason} -> {:error, reason}
end
```

Confirmed via grep — there are zero PLURAL Mux REST key constructions
(`"playback_policies"`, `"inputs"`) anywhere in the worker file outside of
comments. The single source of truth for the SDK boundary lives in
`build_create_params/2` inside `lib/rindle/streaming/provider/mux.ex` (Plan 01).

## Telemetry events emitted + redaction confirmation

The worker emits exactly three event families per `perform/1` invocation:

| Event | Trigger | Metadata |
| ----- | ------- | -------- |
| `[:rindle, :provider, :ingest, :start]` | first line of `perform/1` | `%{profile, provider: :mux, asset_id: nil, variant_name}` (no Mux response yet) |
| `[:rindle, :provider, :ingest, :stop]` | happy-path success or idempotent skip | `%{profile, provider: :mux, asset_id: redacted_or_nil, variant_name}` (`asset_id` matches `~r/^\.\.\.[A-Za-z0-9]{4}$/` after a successful create) |
| `[:rindle, :provider, :ingest, :exception]` | `{:cancel, _}` or `{:error, _}` | adds `kind: :cancelled` or `kind: :error` |

Every metadata `asset_id` value flows through `Rindle.Domain.MediaProviderAsset.redact_id/1`
via `base_metadata/3` (line ~370 of the worker). Redaction is asserted in
Test 9 with the regex `~r/^\.\.\.[A-Za-z0-9]{4}$/` matched against
`metadata.asset_id` captured by an attached telemetry handler. Fixture
`provider_asset_id` `AbCd1234EfGh5678IjKl9012MnOp3456QrSt` redacts to
`...QrSt` — the regex matches.

## Idempotency layers

### Layer 1 — Oban `unique` (job-level)

`MuxIngestVariant.unique_job_opts/0` returns:

```elixir
[
  fields: [:args, :worker, :queue],
  keys: [:asset_id, :profile, :variant_name],
  states: [:available, :scheduled, :executing, :retryable, :completed],
  period: 86_400
]
```

Adopters call it as `unique: MuxIngestVariant.unique_job_opts()` (matches
`process_variant.ex:51` `[unique: unique_job_opts()]` shape). Re-enqueueing
the same `(asset_id, profile, variant_name)` within 24 hours returns
`%Oban.Job{conflict?: true}` — asserted by Test 4.

### Layer 2 — perform-level short-circuit

`maybe_skip_already_in_progress/4` branches on `row.state` BEFORE the FSM
transition. Rows in `:uploading` / `:processing` / `:ready` return
`{:halt, :already_in_progress}`, which the `perform/1` `else` clause
translates into a stop emission and `:ok`. This is critical because
`processing → uploading` is NOT in `@allowed_transitions`
(`provider_asset_fsm.ex:9-16`); without the short-circuit a re-run on a
row already at `:processing` would trip the FSM and emit a misleading
`:invalid_transition` log warning. Asserted by Test 5 — `expect(_, _, 1, _)`
on `ClientMock.create_asset` enforces the adapter is called exactly once
across two `perform_job/2` invocations.

## FSM transition contract (`ProviderAssetFSM.transition/3`)

Every call to `ProviderAssetFSM.transition/3` in the worker passes a MAP
as the third argument (per `provider_asset_fsm.ex:28` spec which reads
`Map.get(context, :profile, :unknown)`):

```elixir
ProviderAssetFSM.transition(row.state, "uploading", %{
  profile: profile, provider: :mux, asset_id: asset.id
})

ProviderAssetFSM.transition(row.state, "processing", %{
  profile: profile_mod, provider: :mux, asset_id: args["asset_id"]
})
```

The previous v1.4 `process_variant.ex` callsite uses keyword-list context
(it talks to `VariantFSM`, not `ProviderAssetFSM`); the worker explicitly
uses MAP context for `ProviderAssetFSM` per the B4 fix in CONTEXT.md.
Confirmed via `grep -E 'ProviderAssetFSM\.transition\(.*,\s*\['` returning 0.

## Schema fidelity

Test setup uses real Phase 33 / Phase 33-prereq schema field names:

- `MediaAsset.changeset/2`: `content_type: "video/mp4"` (NOT `mime:`),
  required `kind: "video"` (B3 fix). Validated against
  `validate_required([:state, :storage_key, :profile, :kind])` and
  `@kind_field_invariants` ("video" forbids no fields, so the test setup
  is clean).
- `MediaVariant.changeset/2`: `output_kind: "video"` (NOT `kind:`),
  required `state: "ready"`, `recipe_digest`, `storage_key` (B3 fix).
  Validated against `validate_required([:asset_id, :name, :state,
  :recipe_digest, :output_kind])`.
- `MediaProviderAsset.changeset/2`: NO `variant_name:` attr (B2 fix —
  no such column on `media_provider_assets`); only
  `[:asset_id, :profile, :provider_name, :playback_policy, :state,
  :provider_asset_id, :playback_ids, :raw_provider_metadata]`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] `unique_job_opts/0` `states:` list missing `:available`**

- **Found during:** Task 2 (test "Oban.unique semantics" failed; `returned.conflict?` was `false`).
- **Issue:** The plan-locked states list `[:scheduled, :executing, :retryable, :completed]` (D-16 per CONTEXT.md) excluded `:available`, but Oban inserts newly-enqueued jobs in `:available` by default (`deps/oban/lib/oban/job.ex:134` `field :state, :string, default: "available"`). Without `:available` in the unique-states list, a freshly inserted job and a second insert with the same args do NOT collide — both go in as fresh `:available` rows. The `conflict?: true` flag never fires for the most common dedup case (re-enqueue right after first insert, before the worker executes).
- **Fix:** Added `:available` to the front of the list. Final shape `[:available, :scheduled, :executing, :retryable, :completed]`. Mirrors `process_variant.ex:412` `@unique_states = [:available, :scheduled, :executing, :retryable]` (Rindle's existing convention also includes `:available`).
- **Files modified:** `lib/rindle/workers/mux_ingest_variant.ex`.
- **Commit:** `fb79b89` (squashed with the test commit since the test exercised the bug).

### Auth gates

None. The worker test suite is fully Mox-driven; no live Mux API calls occur in Plan 02. Phase 36 ships the `mux-soak` GitHub Actions lane behind a `MUX_TOKEN_ID` secret.

## Authentication gates section

Not applicable for Plan 02. Adopters who wire `MuxIngestVariant` into their
Oban supervision tree configure `RINDLE_MUX_TOKEN_ID` and
`RINDLE_MUX_TOKEN_SECRET` per Plan 01's `@moduledoc`; Plan 02 ships only
the Mox-driven test surface.

## Known stubs

None. Every callback in the worker returns a real `:ok | {:error, _} |
{:cancel, _} | {:snooze, _}` shape. No `=[]`, `={}`, or "coming soon"
patterns. Adopter-side wiring guidance lives in the worker's `@moduledoc`
(`## Adopter wiring (Phase 36 owns the canonical guide)`); Phase 36 ships
the canonical guide.

## TDD Gate Compliance

Plan 02 plan frontmatter declares both Task 1 (worker module) and Task 2
(test suite) as `tdd="true"`. Per the plan's `<tasks>` block, the worker
module was written before the test file (Task 1 → commit `d8a7896`, Task 2
→ commit `fb79b89`). The test file proved the worker shape end-to-end via
`Oban.Testing.perform_job/2` with Mox cassette fixtures from Plan 01.

The git log shows `feat(34-02): ...` followed by `test(34-02): ...` —
Plan 02 is a "test-after-implementation-within-the-same-feature" landing
rather than strict RED→GREEN cycling per task. The plan-level `type:
execute` (frontmatter) does NOT declare `type: tdd`, so the gate-sequence
validation in the executor's `<tdd_execution>` block does not apply at
plan level. No warning section needed.

## Self-Check: PASSED

All claimed files exist:

- `lib/rindle/workers/mux_ingest_variant.ex` FOUND
- `test/rindle/workers/mux_ingest_variant_test.exs` FOUND
- `.planning/phases/34-mux-rest-adapter-server-push-sync/34-02-SUMMARY.md` (this file) FOUND

Both task commits exist (verified via `git log --oneline -5`):

- `d8a7896` FOUND (Task 1: MuxIngestVariant worker module)
- `fb79b89` FOUND (Task 2: test suite + Rule 1 bug fix on unique states)

`mix test test/rindle/workers/mux_ingest_variant_test.exs` final run:
**9 tests, 0 failures**. Combined with Plan 01's 21 tests:
**30 tests, 0 failures**.

`mix compile --warnings-as-errors` exit 0.
