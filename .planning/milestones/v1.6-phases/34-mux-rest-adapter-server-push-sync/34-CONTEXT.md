# Phase 34: Mux REST Adapter + Server-Push Sync — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Research-driven one-shot. Locked decisions per `STATE.md` Decision-Making Preference and the user feedback memo "research-driven one-shot recommendations". Two parallel research subagents ran on Mux SDK 3.2.x and Oban patterns; their findings are folded in below as "verified" or "memo correction".

<domain>
## Phase Boundary

Ship the **first real streaming-provider adapter** against the Phase 33 contract.
Server pushes a finished mp4 (already produced by `Rindle.Processor.AV`) to Mux
from server context using a private signed storage URL; durable provider state
persists Mux `provider_asset_id` + `playback_id`; signed HLS playback URLs work
via `Mux.Token.sign_playback_id/2` with TTL bound to v1.4's
`signed_url_ttl_seconds` profile policy.

In scope:
- `{:mux, "~> 3.2", optional: true}` and `{:jose, "~> 1.11", optional: true}`
  added to `mix.exs`; adopters not enabling streaming pay zero transitive cost.
- `Rindle.Streaming.Provider.Mux` — the reference adapter implementing every
  Phase 33 behaviour callback (capabilities, create/get/delete asset, signed
  playback URL, webhook verify). Module wrapped in
  `if Code.ensure_loaded?(Mux.Video.Assets) do ... end` per the locked Rindle
  optional-dep convention.
- Internal HTTP-client behaviour `Rindle.Streaming.Provider.Mux.Client` (`@moduledoc false`) +
  real `Mux.Client.HTTP` impl + `Rindle.Streaming.Provider.Mux.ClientMock`
  Mox mock — Mox-and-behaviour testing pattern matching the existing repo
  convention (`Rindle.StorageMock`, `Rindle.ProcessorMock` in
  `test/support/mocks.ex`).
- `Rindle.Workers.MuxIngestVariant` Oban worker — reads source variant via
  `Rindle.Delivery.url/3` (private signed URL, TTL ≥ 30 min), calls
  `Mux.Video.Assets.create/2`, persists `provider_asset_id` + `playback_id`,
  advances FSM `pending → uploading → processing`. Idempotent under unique
  `(asset_id, profile, variant_name)`. Atomic-promote on flip-to-`:ready`
  mirrors `process_variant.ex:244-275` verbatim.
- `Rindle.Workers.MuxSyncCoordinator` — cron-driven coordinator (per locked
  research finding — see Decisions below); scans `media_provider_assets` rows
  in `(processing, uploading)` whose `updated_at` is older than
  `provider_polling_floor_seconds`, fans out per-row sibling jobs.
- `Rindle.Workers.MuxSyncProviderAsset` — per-row defensive sync; calls
  `provider.get_asset/1`, advances FSM accordingly, transitions to `:errored`
  with reason `:provider_asset_stuck` past `provider_stuck_threshold_seconds`.
- Telemetry events `[:rindle, :provider, :ingest, :start | :stop | :exception]`
  and `[:rindle, :provider, :sync, :resolved | :stuck]` with locked
  measurement / metadata schemas.
- Cassette/Mox-driven ExUnit suite proving (a) 720p mp4 sample drives through
  `MuxIngestVariant` and produces a `:ready` row, (b) `streaming_url/3`
  returns a Mux-signed JWT verifiable against a test signing-key fixture,
  (c) idempotency under re-enqueue, (d) atomic-promote aborts on
  `recipe_digest` / `storage_key` drift.

Out of scope (deferred to later phases):
- `Rindle.Delivery.WebhookPlug`, `Rindle.Delivery.WebhookBodyReader`, signature
  verification routing, multi-secret rotation, replay window — Phase 35.
- `Rindle.Workers.IngestProviderWebhook` — Phase 35.
- `Rindle.Profile.Presets.MuxWeb`, `mix rindle.doctor` streaming validation,
  `guides/streaming_providers.md`, generated-app `mux-enabled` package-consumer
  lane — Phase 36.
- `Rindle.Streaming.Provider.Mux.create_direct_upload/2` implementation
  (callback exists in Phase 33 behaviour as `@optional_callbacks`, but the
  v1.6 Mux adapter does **not** implement it) — Phase 37 / v1.7.
- Replacing or modifying `Rindle.Processor.AV` — Mux is additive; the
  FFmpeg-driven progressive path stays the safety-net fallback.
- Webhook event replay tooling, `cancel_provider_ingest/1`, configurable
  telemetry redaction — explicitly deferred to v1.7+ per memo §13.

</domain>

<decisions>
## Implementation Decisions

All decisions below are LOCKED. Source: candidate memo
`.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` (§4, §5, §6, §7, §8) +
parallel research findings (Mux SDK 3.2.x verified against
`https://github.com/muxinc/mux-elixir`; Oban 2.21+ verified against
`https://hexdocs.pm/oban`). Section refs below point at the memo unless noted.

### Optional Dependencies (MUX-01)

- **D-01:** `mix.exs` adds `{:mux, "~> 3.2", optional: true}` and
  `{:jose, "~> 1.11", optional: true}`. Both are `optional: true` — adopters
  who do not configure streaming pay zero transitive cost (`tesla` and JOSE
  do not become hard deps).
- **D-02:** `mix.exs` `dialyzer.plt_add_apps` adds `:mux` and `:jose` so
  Dialyzer can type-check the adapter module body. (PLT only — does not
  change adopter-runtime posture.)

### Mux SDK Surface (MUX-02, MUX-03, MUX-04) — verified against SDK 3.2.2

- **D-03:** Build the Mux client at request time via
  `Mux.Base.new(token_id, token_secret)`. This returns a `%Tesla.Client{}`
  configured with `Tesla.Middleware.BasicAuth`. Auth is **per-call via the
  client struct**, not global `Application.put_env`. The adapter resolves
  credentials from `Application.get_env(:rindle, Rindle.Streaming.Provider.Mux)`
  on each call (cheap; no cache).
- **D-04:** **MEMO CORRECTION** — Mux REST API uses **`playback_policy`**
  (singular, string list), NOT `playback_policies` (plural, atom list).
  `Mux.Video.Assets.create/2` params shape:
  ```elixir
  %{
    "input" => signed_storage_url,
    "playback_policy" => ["signed"],   # OR ["public"] — string list, not atoms
    "mp4_support" => "standard",       # safe default; not exposed in DSL
    "max_resolution_tier" => "1080p"   # safe default; not exposed in DSL
  }
  ```
  The locked DSL key is `:playback_policy` (atom `:signed | :public`); the
  adapter translates atom → string at the SDK boundary.
  (Source: https://github.com/muxinc/mux-elixir/blob/master/lib/mux/video/assets.ex
  + Mux REST API docs.)
- **D-05:** Successful `Mux.Video.Assets.create/2` returns
  `{:ok, asset_map, %Tesla.Env{}}` — three-tuple. Asset map shape:
  `%{"id" => provider_asset_id, "playback_ids" => [%{"id" => playback_id, "policy" => "signed"}, ...], ...}`.
  Adapter reshapes to the Phase 33 contract:
  `{:ok, %{provider_asset_id: asset_id, playback_ids: [first_id]}}`.
- **D-06:** **MEMO CORRECTION** — `Mux.Token.sign_playback_id/2` is current;
  `Mux.Token.sign/2` is **deprecated** in the SDK docstring. Use
  `sign_playback_id/2`. Returns a JWT string (no `{:ok, _}` wrap). Default
  `:expiration` is **604_800 seconds (7 days)** — Rindle MUST pass
  `:expiration` explicitly from `signed_url_ttl_seconds(profile)`. Never
  rely on the SDK default. (Source:
  https://github.com/muxinc/mux-elixir/blob/master/lib/mux/token.ex.)
- **D-07:** `:expiration` is passed as **integer seconds-from-now**, NOT an
  absolute Unix timestamp. The SDK adds it to `DateTime.utc_now() |> DateTime.to_unix()`
  internally. Test fixtures must respect this — passing an absolute
  timestamp produces a JWT with a year-2095 expiration.
- **D-08:** Sign-call shape:
  ```elixir
  Mux.Token.sign_playback_id(playback_id,
    type: :video,                                       # → aud claim "v"
    expiration: signed_url_ttl_seconds(profile),       # seconds-from-now
    token_id: signing_key_id,                           # → kid header
    token_secret: signing_private_key                   # PEM string
  )
  ```
  Returns the JWT; the adapter wraps it as
  `https://stream.mux.com/{playback_id}.m3u8?token={jwt}` and returns
  `{:ok, %{url: url, kind: :hls, mime: "application/vnd.apple.mpegurl"}}`
  to satisfy the Phase 33 contract.
- **D-09:** **JOSE PEM caching footgun** — `Mux.Token.sign_playback_id/2`
  calls `JOSE.JWK.from_pem/1` on every invocation; for high-throughput
  signing, cache the parsed JWK in `:persistent_term` keyed by the
  signing-key id. v1.6 ships **without** this cache (premature
  optimization for v1; adopter-side perf is dominated by Oban worker
  latency, not URL minting); document the optimization in
  `guides/streaming_providers.md` (Phase 36) for high-volume adopters.

### Webhook Verification (MUX-02 callback only — wire-up in Phase 35)

- **D-10:** **MEMO CORRECTION** — `Mux.Webhooks.verify_header/4` accepts a
  **single secret**, not a list. Multi-secret rotation must be done **in the
  caller** by looping the secrets list and OR-ing the results. The SDK does
  parse multiple `v1=` schemes inside one header correctly (constant-time
  compare via `secure_equals?/2`). (Source:
  https://github.com/muxinc/mux-elixir/blob/master/lib/mux/webhooks.ex.)
- **D-11:** `Rindle.Streaming.Provider.Mux.verify_webhook/3` (Phase 34)
  implements the loop:
  ```elixir
  def verify_webhook(raw_body, headers, secrets) when is_list(secrets) do
    sig_header = Map.fetch!(headers, "mux-signature")
    Enum.find_value(secrets, {:error, :provider_webhook_invalid}, fn secret ->
      case Mux.Webhooks.verify_header(raw_body, sig_header, secret, tolerance()) do
        :ok -> {:ok, normalize_event(raw_body)}
        {:error, _} -> nil
      end
    end)
  end
  ```
  Phase 35 wires this into `Rindle.Delivery.WebhookPlug` and adds the
  `secret_used` telemetry. Phase 34 ships only the callback + unit test
  proving signature parity.
- **D-12:** Tolerance default is `300` seconds (config:
  `:webhook_tolerance_seconds`, range `60..900`). Phase 34 reads it from
  `Application.get_env(:rindle, Rindle.Streaming.Provider.Mux)` with the
  300s default; Phase 35 owns the bounds-check and surfaces it through the
  Plug.

### Worker — `MuxIngestVariant` (MUX-03, MUX-05, MUX-06)

- **D-13:** Worker module: `Rindle.Workers.MuxIngestVariant`. `@moduledoc`
  describes the contract; `use Oban.Worker, queue: :rindle_provider, max_attempts: 5`.
- **D-14:** `:rindle_provider` is a **new queue** for v1.6. Verified unused
  in current codebase (existing queues: `:rindle_process`, `:rindle_promote`,
  `:rindle_purge`, `:rindle_maintenance`, `:rindle_media`). Adopter sizes it
  per the Phase 36 onboarding guide; recommended default in docs is
  `rindle_provider: 4` (Mux REST is bursty; one in-flight ingest per CPU
  core is fine).
- **D-15:** `c:Oban.Worker.timeout/1` returns **integer milliseconds only**
  (`:timer.minutes(5) == 300_000`); Oban 2.21 does NOT accept tuple form.
  Worker shape:
  ```elixir
  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)
  ```
- **D-16:** `unique` keyed on `(asset_id, profile, variant_name)`:
  ```elixir
  unique: [
    fields: [:args, :worker, :queue],
    keys: [:asset_id, :profile, :variant_name],
    period: 86_400,
    states: [:scheduled, :executing, :retryable, :completed]
  ]
  ```
  Mirrors the existing `Rindle.Workers.ProcessVariant.unique_job_opts/0`
  pattern (line 408-415) but with `period: 86_400` (memo §7) instead of
  `:infinity` because re-ingest must be possible after a 24h cooldown.
- **D-17:** Worker `args` shape (passed at enqueue, validated at perform):
  ```elixir
  %{
    "asset_id" => asset_id,
    "profile" => profile_module_string,
    "variant_name" => variant_name,
    "expected_storage_key" => storage_key_at_enqueue,
    "expected_recipe_digest" => recipe_digest_at_enqueue
  }
  ```
  The two `expected_*` fields are the captured-at-enqueue values used by
  the atomic-promote race protection (D-19).
- **D-18:** Source URL acquisition — call
  `Rindle.Delivery.url(profile, variant.storage_key, ttl: 1_800)` to obtain
  a private signed URL with **30-minute** TTL (memo §2 MUX-03 floor; longer
  than typical Mux ingest queue depth). The Mux side fetches the URL
  asynchronously; once `Mux.Video.Assets.create/2` returns `{:ok, _, _}`,
  Mux holds the bytes server-side and the signed URL can expire safely.
- **D-19:** **Atomic-promote pattern — mirrors `process_variant.ex:244-275`
  verbatim.** Before transitioning the `media_provider_assets` row to
  `:processing` (after `Mux.Video.Assets.create/2` succeeds), re-fetch the
  source `MediaAsset` and `MediaVariant`, compare against
  `expected_storage_key` and `expected_recipe_digest` from worker args,
  and abort with `{:cancel, {:stale_source, :asset_changed}}` /
  `{:cancel, {:stale_source, :recipe_changed}}` if they drifted. The
  `:cancel` tuple stops Oban retries cleanly. Telemetry emits
  `[:rindle, :provider, :ingest, :exception]` with `kind: :cancelled`.
- **D-20:** Failure normalization — Mux SDK errors come back as
  `{:error, msg, %Tesla.Env{}}`. Adapter reshapes:
  - `{:error, _, %{status: 429}}` → `{:error, :provider_quota_exceeded}`;
    Oban retries via standard exponential backoff. **Mux SDK Issue #42**
    (https://github.com/muxinc/mux-elixir/issues/42) confirms 429
    `Retry-After` is swallowed by `simplify_response/1`; the adapter
    reads `env.headers` directly and returns `Retry-After`-aware backoff
    via Oban's per-job `snooze` (`{:snooze, retry_after_seconds}`).
  - `{:error, _, %{status: status}}` when `status in 500..599` →
    standard Oban retry (raise or `{:error, :provider_sync_failed}`).
  - `{:error, _, %{status: status}}` when `status in 400..499` (excl. 429) →
    persist `last_sync_error` (truncated 4096), transition to `:errored`,
    return `{:error, :provider_sync_failed}` (no Oban retry — bad request
    won't fix itself). Oban respects this via `discard` semantics if max
    attempts exceeded.

### Worker — `MuxSyncCoordinator` + `MuxSyncProviderAsset` (MUX-07)

- **D-21:** **MEMO ADDITION** — Phase 34 adds a **coordinator worker**
  (`Rindle.Workers.MuxSyncCoordinator`) on top of the candidate memo's
  `Rindle.Workers.MuxSyncProviderAsset`. Reason: the memo specifies
  `unique: [period: 60]` keyed on `provider_asset_id` for the per-row
  worker but does not specify who *enqueues* per-row jobs. The coordinator
  is the cron-driven enqueuer; per-row workers are the per-row workers.
  This mirrors Rindle's existing convention at `cleanup_orphans.ex` and
  `abort_incomplete_uploads.ex`.
- **D-22:** Coordinator is cron-driven, with adopter wiring exactly like
  the v1.5 maintenance workers:
  ```elixir
  config :my_app, Oban,
    queues: [rindle_provider: 4],
    plugins: [
      {Oban.Plugins.Cron,
       crontab: [
         {"* * * * *", Rindle.Workers.MuxSyncCoordinator},
         # ... existing entries ...
       ]}
    ]
  ```
  Cron resolution is 1 minute (Oban.Plugins.Cron docs); the coordinator's
  internal query enforces the `provider_polling_floor_seconds: 30` floor.
- **D-23:** Coordinator implementation shape:
  ```elixir
  defmodule Rindle.Workers.MuxSyncCoordinator do
    use Oban.Worker, queue: :rindle_provider, max_attempts: 1
    @impl true
    def perform(_job) do
      floor = config(:provider_polling_floor_seconds, 30)
      cutoff = DateTime.add(DateTime.utc_now(), -floor, :second)
      Repo.all(
        from r in MediaProviderAsset,
          where: r.state in ["processing", "uploading"]
            and r.updated_at < ^cutoff,
          select: r.provider_asset_id
      )
      |> Enum.each(fn provider_asset_id ->
        Rindle.Workers.MuxSyncProviderAsset.new(
          %{"provider_asset_id" => provider_asset_id},
          unique: [fields: [:args, :worker], period: 60, keys: [:provider_asset_id]]
        )
        |> Oban.insert()
      end)
      :ok
    end
  end
  ```
  Coordinator has `max_attempts: 1` because retrying a fan-out is cheaper
  to skip and re-run on the next cron tick than to rerun mid-fanout.
- **D-24:** Per-row worker `Rindle.Workers.MuxSyncProviderAsset` calls
  `Mux.Video.Assets.get/2` via `Rindle.Streaming.Provider.Mux.get_asset/1`,
  advances the FSM to match the live provider state, and:
  - If row's `updated_at` exceeds `provider_stuck_threshold_seconds`
    (default 7200), transitions to `:errored` with `last_sync_error:
    "stuck in :processing past threshold"` and emits
    `[:rindle, :provider, :sync, :stuck]` telemetry. Default threshold
    matches memo §8.6: 4× v1.4 max-duration cap to allow Mux queue depth.
  - Otherwise, `[:rindle, :provider, :sync, :resolved]` with `provider_state`
    metadata reflecting the live transition.
- **D-25:** Per-row worker `unique: [fields: [:args, :worker], period: 60,
  keys: [:provider_asset_id]]`. Concurrency 1 in queue config recommended
  by adopter docs (memo §7).

### Telemetry (MUX-08)

- **D-26:** Three additive event families, exact shapes locked from memo
  §8.5:
  ```
  [:rindle, :provider, :ingest, :start | :stop | :exception]
    measurements: %{system_time, duration?}
    metadata: %{profile, provider, asset_id, variant_name, kind?}

  [:rindle, :provider, :sync, :resolved | :stuck]
    measurements: %{system_time}
    metadata: %{profile, provider, asset_id, provider_state, age_ms}

  # Phase 35 will add :webhook events; Phase 34 does not emit them.
  ```
  `kind: :error | :cancelled` is added on `:exception` events to
  distinguish failure modes.
- **D-27:** **Security invariant 14 — telemetry redaction.**
  `provider_asset_id` in metadata is the **last-4-char tag**
  (`"...abcd"`), never the raw id. The Inspect impl on
  `Rindle.Domain.MediaProviderAsset` (Phase 33) provides the redaction
  helper; Phase 34 reuses it as `MediaProviderAsset.redact_id/1` (extract
  to a public-internal helper if not already exposed).
- **D-28:** `[:rindle, :delivery, :streaming, :resolved]` (the v1.4-frozen
  event) fires with `kind: :hls` when Phase 34's adapter signs a playback
  URL (already wired in Phase 33's `dispatch_streaming/4`). No new event
  on this path; the metadata extension is already documented as the
  single deliberate v1.4-contract extension (memo §8.4 final paragraph).

### Configuration (MUX-02)

- **D-29:** All credentials and tunables live under
  `config :rindle, Rindle.Streaming.Provider.Mux`:
  ```elixir
  config :rindle, Rindle.Streaming.Provider.Mux,
    token_id: System.get_env("RINDLE_MUX_TOKEN_ID"),
    token_secret: System.get_env("RINDLE_MUX_TOKEN_SECRET"),
    signing_key_id: System.get_env("RINDLE_MUX_SIGNING_KEY_ID"),
    signing_private_key: System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY"),
    webhook_secrets:
      System.get_env("RINDLE_MUX_WEBHOOK_SECRETS", "") |> String.split(",", trim: true),
    webhook_tolerance_seconds: 300,
    provider_polling_floor_seconds: 30,
    provider_stuck_threshold_seconds: 7200
  ```
  Five env vars + three optional tunables. Phase 34 ships the config-key
  documentation; Phase 36 adds `mix rindle.doctor` validation.
- **D-30:** Configuration is read at the **call site** (no caching).
  Adopters using runtime config (`config/runtime.exs`) are unaffected.
  `Application.get_env/3` with module-keyed config is the locked Rindle
  convention.

### Optional-Dep Guard

- **D-31:** **Locked Rindle pattern — wrap entire module in
  `if Code.ensure_loaded?(Mux.Video.Assets) do ... end`.** Mirrors
  `lib/rindle/live_view.ex:1` (`Phoenix.LiveView` optional-dep guard) and
  `lib/rindle/html.ex:1`. When `:mux` is absent, the module simply does
  not exist; the dispatch tree at `lib/rindle/delivery.ex:244-303`
  detects via `Code.ensure_loaded?(Rindle.Streaming.Provider.Mux)` and
  surfaces `:streaming_not_configured` if absent.
- **D-32:** Document the guard at the top of the file with a comment:
  ```elixir
  # Compiled only when {:mux, ~> 3.2} is loaded.
  # Adopters who do not configure streaming pay zero transitive cost.
  if Code.ensure_loaded?(Mux.Video.Assets) do
    defmodule Rindle.Streaming.Provider.Mux do
      ...
    end
  end
  ```
- **D-33:** `mix rindle.doctor` (Phase 36, NOT Phase 34) emits a
  PASS/FAIL on `Code.ensure_loaded?(Rindle.Streaming.Provider.Mux)` so
  adopters who try to use streaming without `{:mux, ...}` in their deps
  get a clear error. Phase 34 ships a smoke-test inside ExUnit asserting
  `function_exported?(Rindle.Streaming.Provider.Mux, :create_asset, 3) == true`
  in the test environment (where `:mux` is loaded).

### Test Strategy

- **D-34:** **Locked test pattern — Mox + behaviour wrapper.** Define
  `Rindle.Streaming.Provider.Mux.Client` (`@moduledoc false`) as an
  internal HTTP-client behaviour with callbacks `create_asset/2`,
  `get_asset/1`, `delete_asset/1`. Real impl `Rindle.Streaming.Provider.Mux.HTTP`
  delegates to the Mux SDK; test impl is `Rindle.Streaming.Provider.Mux.ClientMock`
  defined in `test/support/mocks.ex`:
  ```elixir
  Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock,
    for: Rindle.Streaming.Provider.Mux.Client)
  ```
  Mirrors the existing repo pattern (`Rindle.StorageMock`, `Rindle.ProcessorMock`).
  Process-local Mox expectations work inside Oban's
  `Oban.Testing.perform_job/2` because the test process IS the worker
  process.
- **D-35:** **Rationale (rejected alternatives):**
  - **Tesla.Mock** rejected — configures via `Application.put_env`,
    process-local; brittle when Oban's job process differs from the test
    process.
  - **Bypass** rejected for Mux unit tests — Mux SDK base URL is hard-coded
    (`https://api.mux.com`); cannot redirect to localhost without
    monkey-patching. Bypass remains the right tool for upload integration
    tests against MinIO/S3 (existing repo pattern at
    `test/rindle/storage/`).
  - **ExVCR** rejected — record/replay drift; tests pass when the live API
    has changed. Adopters of `mux` SDK test idiomatically with hand-rolled
    fixtures + Tesla.Mock or Mox.
- **D-36:** **Cassette fixtures** — JSON files at
  `test/fixtures/mux/asset_create_201.json`,
  `test/fixtures/mux/asset_get_processing.json`,
  `test/fixtures/mux/asset_get_ready.json`,
  `test/fixtures/mux/webhook_video_asset_ready.json`,
  `test/fixtures/mux/webhook_video_asset_errored.json`. Loaded by Mox
  expectations. Captured from real Mux (or hand-derived from
  https://docs.mux.com/api-reference) and committed verbatim.
- **D-37:** **Signing-key fixtures** — `test/fixtures/mux/test_signing_private_key.pem`
  is a fresh RSA-2048 keypair generated for tests only; the public half
  used to verify signed JWTs in tests. Generate via `openssl genrsa -out
  ... 2048` once and commit.
- **D-38:** **Soak lane** — Phase 34 ships only cassette tests. Phase 36
  adds the `mux-soak` GitHub Actions lane behind a `MUX_TOKEN_ID` secret
  (memo §1 #11; mirrors v1.2 protected-publish lane discipline).

### Module Layout

- **D-39:** Files added in Phase 34:
  - `lib/rindle/streaming/provider/mux.ex` — main adapter module (entire
    file wrapped in optional-dep guard)
  - `lib/rindle/streaming/provider/mux/client.ex` — internal HTTP client
    behaviour (`@moduledoc false`)
  - `lib/rindle/streaming/provider/mux/http.ex` — real impl
    (`@moduledoc false`, also wrapped in optional-dep guard)
  - `lib/rindle/streaming/provider/mux/event.ex` — webhook event
    normalizer (`@moduledoc false`)
  - `lib/rindle/workers/mux_ingest_variant.ex`
  - `lib/rindle/workers/mux_sync_coordinator.ex`
  - `lib/rindle/workers/mux_sync_provider_asset.ex`
  - Test counterparts under `test/rindle/streaming/provider/mux/` and
    `test/rindle/workers/`
  - `test/support/mocks.ex` extension: add `Rindle.Streaming.Provider.Mux.ClientMock`
  - `test/fixtures/mux/*.json` + `test_signing_private_key.pem`
- **D-40:** Files modified in Phase 34:
  - `mix.exs` — add `:mux`, `:jose` optional deps; PLT add_apps
  - `test/support/mocks.ex` — add ClientMock
  - `test/test_helper.exs` — `Mox.defmock` registration if not already
    auto-loaded

### Documentation Touch (Minimal — Phase 36 Owns Adopter Onboarding)

- **D-41:** Phase 34 does **NOT** add `guides/streaming_providers.md` —
  that is Phase 36 / MUX-17. Phase 34 adds inline `@moduledoc` blocks on
  the new modules (cause→action style mirroring AV-04/AV-05) and
  CHANGELOG / runtime release notes only as needed.
- **D-42:** No README updates in Phase 34. README "Streaming with Mux"
  subsection is Phase 36 / MUX-19.

### Decision-Making Preference

- **D-43:** Reinforce: per `STATE.md` and the user feedback memo
  (`memory/feedback_research_driven_one_shot.md`), downstream researchers,
  planners, and executors decide by default and produce a coherent
  recommendation set. Escalate only for genuinely high-blast-radius
  decisions (semver-significant public API reshapes, destructive or
  irreversible operations, security/compliance boundary changes).

### Claude's Discretion (Planner / Executor)

The candidate memo + this CONTEXT lock the contract surface; the items
below are implementation choices the planner / executor should make
autonomously without asking the user, so long as the locked decisions
above are preserved.

- Exact internal signature for `Rindle.Streaming.Provider.Mux.Client`
  behaviour (callback names + arities), so long as it abstracts every
  Mux SDK call the adapter makes
- File-vs-folder organization for the `Rindle.Streaming.Provider.Mux.*`
  sub-modules (single file with multiple `defmodule`s vs separate
  files); D-39 expresses a recommendation but the planner may
  consolidate if it improves cohesion
- Exact wording of Mux-specific error messages routed through the new
  `Rindle.Error.message/1` clauses (the atom set is locked at Phase 33;
  per-call wrapping is implementation detail)
- Whether to inline the Mux base URL constant or read from
  `Application.get_env(:mux, :api_url, "https://api.mux.com")`
- Cassette JSON file structure (one file per fixture vs one big map);
  default to one file per fixture per D-36 unless the planner sees a
  reason otherwise
- Whether `Rindle.Workers.MuxSyncCoordinator` queries the rows itself
  vs delegates to a `Rindle.Streaming.Sync` service module; either is
  fine
- Internal queue-config defaults documented in the Phase 34 inline
  `@moduledoc` blocks (the cron snippet wording is owned by Phase 36's
  guide; Phase 34 ships the worker shape only)
- Test file organization for the new workers (one file per worker mirrors
  `test/rindle/workers/process_variant_test.exs`); planner picks
- Whether `Mux.Token.sign_playback_id/2` calls happen synchronously in
  the request-response of `streaming_url/3` or are pre-cached (D-09 says
  no cache for v1.6; planner may revisit if benchmarks show >10ms p99)
- Whether the `expected_storage_key`/`expected_recipe_digest` args use
  string-keyed maps (Oban's idiomatic shape) or atom-keyed; Oban's
  serialization picks the answer (string-keyed)

</decisions>

<specifics>
## Specific Ideas

- The single most important Phase 34 invariant: **`provider_asset_id`
  never crosses into adopter-facing paths.** Telemetry, log lines,
  `inspect/2`, and URLs all see only `playback_id` (public-side) or the
  last-4-char redacted tag for the provider id. Phase 33's Inspect impl
  on `Rindle.Domain.MediaProviderAsset` enforces this at the schema layer;
  Phase 34's worker code re-asserts it at every telemetry emit.
- The atomic-promote race in `MuxIngestVariant` is the most operationally
  important novel piece. The pattern is locked verbatim from
  `lib/rindle/workers/process_variant.ex:244-275` (`persist_ready/7` —
  `cond` block comparing `current_asset.storage_key` to
  `asset.storage_key` and `current_variant.recipe_digest` to
  `variant.recipe_digest`). Mux's adapter mirrors this against the
  `expected_*` worker args.
- The Mux SDK's **default 7-day expiration** on `sign_playback_id` is the
  highest-risk silent footgun. v1.6 Phase 34 must `pass :expiration`
  explicitly on every signed-URL call. Test the failure mode (omitted
  `:expiration` → assertion catches ~604_800-second JWT exp claim) so the
  drift cannot land silently.
- The Mux SDK Issue #42 (429 swallowed) is real — Phase 34's adapter
  reads `%Tesla.Env{}.headers` directly to extract `Retry-After`; the
  Oban worker uses `{:snooze, retry_after_seconds}` for rate-limit
  backoff so subsequent retries respect Mux's pacing.
- The Mox + behaviour test pattern is the same shape as Rindle's
  existing `Rindle.StorageMock` and `Rindle.ProcessorMock` — adding
  `Rindle.Streaming.Provider.Mux.ClientMock` is a one-line entry in
  `test/support/mocks.ex`; the behaviour shape is already determined by
  the SDK calls the adapter makes.
- The `Rindle.Workers.MuxSyncCoordinator` + per-row `MuxSyncProviderAsset`
  pair extends the existing Rindle Oban convention
  (`Rindle.Workers.CleanupOrphans`, `AbortIncompleteUploads` are
  cron-driven; new pair adds the per-row fan-out shape that v1.6 needs).
  Adopter-facing wiring is one new cron entry per the Phase 36 guide.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before
planning or implementing.**

### Source of truth (locked recommendation)
- `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` — the locked
  recommendation memo. Section index for Phase 34: §2 MUX-01..08
  phase-34 requirements (line 58); §4 behaviour with @callback signatures
  (Phase 33 contract; Phase 34 implements); §5.1 dispatch rule (Phase 33
  shipped; Phase 34 wires step 5 via the Mux adapter); §6 Ecto migration
  (Phase 33 shipped); §7 Oban contract (line ~339, **most important
  reference for Phase 34**); §8.4 telemetry; §8.6 configuration; §9
  security invariants (invariant 14 still binding). **This memo is the
  highest-priority reference; corrections in this CONTEXT.md (D-04,
  D-06, D-10, D-21) supersede the memo at conflicts.**

### Phase scope and milestone constraints
- `.planning/ROADMAP.md` (lines 97-142) — Phase 34 goal, success criteria,
  v1.6 phase summary
- `.planning/REQUIREMENTS.md` (lines 56-83) — MUX-01..08 phase-34
  requirements
- `.planning/PROJECT.md` — current milestone posture, adopter-first runtime
  ownership, security invariants 1-14 (invariant 14 directly applies)
- `.planning/STATE.md` — Decision-Making Preference (decide-by-default,
  escalate-only-impactful)
- `.planning/phases/33-provider-boundary-state-schema/33-CONTEXT.md` —
  Phase 33 contract decisions Phase 34 must consume verbatim (D-04..D-08
  the behaviour callback set; D-09..D-14 the schema+FSM; D-19..D-24 the
  dispatch rule that Phase 34's adapter satisfies on step 5)
- `.planning/phases/33-provider-boundary-state-schema/33-VERIFICATION.md` —
  what Phase 33 actually shipped (sanity-check: contract is what Phase 34
  expects)

### Existing code seams Phase 34 must extend / consume
- `lib/rindle/streaming/provider.ex` — the Phase 33 behaviour Phase 34
  implements (every callback returns `:ok`-tuple or `:error`-tuple; no
  raises on happy path)
- `lib/rindle/streaming/capabilities.ex` — Phase 33 closed vocabulary;
  the Mux adapter's `capabilities/0` returns
  `[:signed_playback, :webhook_ingest, :server_push_ingest]` (NOT
  `:public_playback` or `:direct_creator_upload` for v1.6)
- `lib/rindle/domain/media_provider_asset.ex` — Phase 33 schema; Phase
  34 inserts/updates rows on this schema; respects the custom Inspect
  impl (D-14 of Phase 33) for security invariant 14
- `lib/rindle/domain/provider_asset_fsm.ex` — Phase 33 FSM; Phase 34
  worker calls `transition/3` with telemetry contract preserved
- `lib/rindle/delivery.ex` (lines 244-303 `dispatch_streaming/4`) —
  Phase 33 dispatch already calls
  `streaming_config.provider.signed_playback_url(profile, playback_id, opts)`;
  Phase 34's `Rindle.Streaming.Provider.Mux.signed_playback_url/3`
  satisfies this call
- `lib/rindle/workers/process_variant.ex` — **THE atomic-promote race
  pattern Phase 34 mirrors verbatim** (`persist_ready/7` lines ~244-275,
  `unique_job_opts/0` lines ~408-415); also the queue-naming and
  `c:Oban.Worker.timeout/1` shape
- `lib/rindle/workers/cleanup_orphans.ex` and
  `lib/rindle/workers/abort_incomplete_uploads.ex` — cron-driven worker
  pattern Phase 34's `MuxSyncCoordinator` mirrors (`Oban.Plugins.Cron`
  config snippet shape, adopter-owned supervision)
- `lib/rindle/live_view.ex` — **the optional-dep guard pattern Phase 34
  mirrors** (top-of-file `if Code.ensure_loaded?(...) do ... end`
  wrapping the entire `defmodule`); also `lib/rindle/html.ex` for the
  same pattern
- `lib/rindle/error.ex` — the `Rindle.Error.message/1` clause pattern
  Phase 34 follows when wrapping Mux-side errors into the locked atom
  set from Phase 33 (`:provider_quota_exceeded`,
  `:provider_asset_not_ready`, `:provider_sync_failed`)
- `lib/rindle/profile/validator.ex` (lines 55-82, `@streaming_schema`) —
  Phase 33 DSL; Phase 34 reads
  `profile.delivery_policy().streaming.source_variant` to determine
  which variant feeds Mux ingest
- `test/support/mocks.ex` — existing Mox+behaviour pattern Phase 34
  extends with `Rindle.Streaming.Provider.Mux.ClientMock`
- `test/rindle/workers/process_variant_test.exs` — the test shape Phase
  34's worker tests follow

### Mux Elixir SDK references (verified 2026-05-06)
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/video/assets.ex`
  — `create/2` and `get/2` signatures (D-03..D-05)
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/token.ex` —
  `sign_playback_id/2` (D-06..D-09); 7-day default expiration footgun
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/webhooks.ex`
  — `verify_header/4` single-secret + multi-`v1=` parsing (D-10..D-12)
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/base.ex` —
  `Mux.Base.new/2` Tesla client construction (D-03)
- `https://github.com/muxinc/mux-elixir/issues/42` — 429 `Retry-After`
  swallowed footgun (D-20)
- `https://hex.pm/packages/mux` — version pin verification
  (`mux 3.2.2`, 2024-07-02)

### Mux REST API references
- `https://www.mux.com/docs/guides/secure-video-playback` — signed
  playback flow; JWT claims expected by playback-time verification
- `https://www.mux.com/docs/core/listen-for-webhooks` — webhook event
  catalog Phase 35 will dispatch on
- `https://docs.mux.com/api-reference` — `playback_policy` (singular,
  string list) confirmation; `mp4_support`, `max_resolution_tier`
  param defaults

### Oban references (verified 2026-05-06)
- `https://hexdocs.pm/oban/Oban.Worker.html#c:timeout/1` — timeout/1
  signature returns ms only, not tuple (D-15)
- `https://hexdocs.pm/oban/Oban.Plugins.Cron.html` — cron-driven enqueue
  pattern Phase 34's `MuxSyncCoordinator` follows (D-22)
- `https://hexdocs.pm/oban/Oban.Worker.html#unique` — unique job options
  (D-16, D-25)
- `https://hexdocs.pm/oban/Oban.Worker.html#snooze` — `{:snooze, seconds}`
  return for rate-limit backoff (D-20)

### Test framework references
- `https://hexdocs.pm/mox/Mox.html` — Mox + behaviour pattern (D-34)
- `https://hexdocs.pm/oban/Oban.Testing.html` — `perform_job/2` for
  testing workers in test process (D-34 process-locality argument)
- `https://hexdocs.pm/elixir/Code.html#ensure_loaded?/1` — optional-dep
  guard (D-31)

### JOSE / Crypto references
- `https://hexdocs.pm/jose/JOSE.JWK.html#from_pem/1` — PEM parsing in
  `Mux.Token.sign_playback_id/2` (D-09 perf footgun)
- `https://hex.pm/packages/jose` — version pin (`jose 1.11.12`, 2025-11-20)

### Prior milestone references (read-only, supports decisions)
- `.planning/milestones/v1.4-phases/25-av-processor/25-CONTEXT.md` — the
  AV-03-10 atomic-promote race pattern Phase 34 mirrors (the v1.4 source
  of the `persist_ready/7` pattern in `process_variant.ex`)
- `.planning/milestones/v1.5-phases/29-package-consumer-proof/29-CONTEXT.md`
  — adopter-owned Oban supervision posture Phase 34 honors

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/rindle/workers/process_variant.ex` — **direct template for
  `MuxIngestVariant`**: `use Oban.Worker, queue: ..., max_attempts: 5`,
  `c:timeout/1` callback (line ~35), atomic-promote `persist_ready/7`
  (lines ~244-275), `unique_job_opts/0` (lines ~408-415),
  `:telemetry.execute` for transcode-stage events (lines ~461-463),
  PubSub broadcast pattern (lines ~465-483). Phase 34's `MuxIngestVariant`
  adopts this shape with `:provider` instead of `:transcode` events.
- `lib/rindle/workers/cleanup_orphans.ex` and
  `lib/rindle/workers/abort_incomplete_uploads.ex` — **direct template
  for `MuxSyncCoordinator`**: cron-driven worker with documented adopter
  cron snippet, `max_attempts: 1`, fan-out via `Oban.insert/2` per row.
- `lib/rindle/live_view.ex` (line 1) and `lib/rindle/html.ex` (line 1) —
  **the optional-dep guard pattern**: `if Code.ensure_loaded?(...) do`
  wrapping the entire `defmodule`. Phase 34's `Rindle.Streaming.Provider.Mux`
  follows this exactly.
- `test/support/mocks.ex` — existing `Mox.defmock` registrations for
  `Rindle.StorageMock`, `Rindle.ProcessorMock`. Phase 34 adds one line
  for `Rindle.Streaming.Provider.Mux.ClientMock`.
- `lib/rindle/error.ex` (line 195+ for `:streaming_not_configured`,
  Phase 33 additions for `:provider_quota_exceeded` etc.) — the
  `def message(%{reason: <atom>})` clause pattern.
- `lib/rindle/domain/media_provider_asset.ex` (Phase 33) — the schema
  Phase 34 inserts/updates; the Inspect impl provides
  `redact_id/1`-equivalent helper.
- `lib/rindle/domain/provider_asset_fsm.ex` (Phase 33) — the FSM Phase
  34's worker drives via `transition/3`.
- `lib/rindle/delivery.ex` (lines 244-303 `dispatch_streaming/4`) —
  Phase 33's call site for `provider.signed_playback_url(profile, playback_id, opts)`.

### Established Patterns
- **Adopter-owned Oban supervision:** Rindle ships worker modules and
  documented cron-config snippets; the adopter wires `Oban.Plugins.Cron`
  and queue config in their app. Phase 34's `MuxSyncCoordinator` follows
  this; no Rindle-side Oban supervisor.
- **Atomic-promote on flip-to-`:ready`:** re-fetch the source row(s),
  compare captured-at-enqueue values, abort with `{:cancel, ...}` on
  drift. Locked by AV-03-10; mirrored in Phase 34.
- **Optional-dep guards via `Code.ensure_loaded?`:** wrap the entire
  module in the guard at the top of the file. The dispatch tree detects
  module presence at runtime.
- **Mox + behaviour for external integrations:** every Rindle integration
  with an external system uses a thin internal behaviour + a Mox-defined
  test mock (Storage, Processor, Analyzer, Scanner, Authorizer). Phase 34
  adds the Mux client behaviour to this set.
- **Telemetry contract is a public API:** every event family has
  documented measurements + metadata; new events are additive only.
- **Security invariant 14 (provider id redaction)** is enforced at three
  layers: schema Inspect impl (Phase 33), telemetry metadata redaction
  (Phase 34), and URL minting (only `playback_id` crosses into URLs).
- **Capability vocabulary is closed:** `Rindle.Streaming.Capabilities.@known`
  is the entire universe; adapter `capabilities/0` is filtered through
  `safe/1`.

### Integration Points
- `Rindle.Delivery.streaming_url/3` — Phase 33's dispatch tree calls
  Phase 34's `signed_playback_url/3` on Branch 5 (state `:ready`,
  playback_id present).
- `Rindle.Workers.MuxIngestVariant` — enqueued by an adopter-side hook
  after `Rindle.Workers.ProcessVariant` flips a variant to `:ready` (the
  variant named in the profile's `:streaming.source_variant`).
  **Phase 34 ships the worker only**; Phase 36 ships the documented
  adopter wiring. The integration shape is `Oban.insert/2` from the
  adopter's hook callback.
- `Rindle.Workers.MuxSyncCoordinator` — adopter wires via
  `Oban.Plugins.Cron` cron entry. Documented in
  `lib/rindle/workers/mux_sync_coordinator.ex` `@moduledoc`.
- `Rindle.Capability.report/0` — extended by the Mux adapter being
  loaded; the streaming providers entry under `streaming.providers`
  reflects the Mux capability set.

### Operational Boundaries Phase 34 Must Not Cross
- **No webhook plug, no raw-body cache, no signature-verification
  routing.** All arrives in Phase 35. Phase 34's `verify_webhook/3`
  callback is implemented as a pure function but not yet wired.
- **No `Rindle.Profile.Presets.MuxWeb`, no doctor streaming smoke, no
  `guides/streaming_providers.md`.** All arrives in Phase 36.
- **No `create_direct_upload/2` impl.** Reserved for Phase 37 / v1.7.
- **No changes to `Rindle.Processor.AV` or the FFmpeg-driven progressive
  path.** Mux is additive; Branch 6 of Phase 33's dispatch tree
  (progressive fallback) is unchanged.
- **No changes to `media_assets` or `media_variants` schema.** Phase 34
  reads these but does not modify them.
- **No new public modules outside `Rindle.Streaming.Provider.Mux`,
  `Rindle.Workers.MuxIngestVariant`, `Rindle.Workers.MuxSyncCoordinator`,
  `Rindle.Workers.MuxSyncProviderAsset`.** Internal helpers are
  `@moduledoc false`.

</code_context>

<deferred>
## Deferred Ideas

- **Direct creator upload** — `Rindle.Streaming.Provider.Mux.create_direct_upload/2`
  implementation. Behaviour callback exists from Phase 33 with
  `@optional_callbacks`. Phase 37 / v1.7 ships the impl.
- **Webhook plug, raw-body cache, multi-secret rotation routing** —
  Phase 35 (MUX-09..14).
- **`mix rindle.doctor` streaming validation** — Phase 36 (MUX-16).
- **`Rindle.Profile.Presets.MuxWeb` and adopter onboarding guide** —
  Phase 36 (MUX-15, MUX-17, MUX-19).
- **Generated-app `mux-enabled` package-consumer proof lane** — Phase 36
  (MUX-18). Includes the `mux-soak` GitHub Actions lane behind a
  `MUX_TOKEN_ID` secret.
- **Cached `JOSE.JWK.from_pem/1` parse via `:persistent_term`** — D-09
  notes the SDK re-parses on every call; Phase 34 ships without the
  cache (premature optimization for v1). Document in Phase 36's guide
  for high-throughput adopters; revisit if benchmarks show >10ms p99.
- **Webhook event replay tooling (`mix rindle.webhook.replay`)** —
  v1.7+ per memo §13. Durable `media_provider_assets` row is the
  primary recovery surface in v1.6.
- **Configurable telemetry redaction** — v1.7+ per memo §13. v1.6
  hardcodes last-4-char redaction in metadata.
- **`cancel_provider_ingest/1` cancellation surface** — v1.7+ per memo
  §13. Oban's `cancel_jobs/1` covers most of the need in v1.6.
- **Map-keyed error variants** (e.g.
  `{:provider_quota_exceeded, %{provider, retry_after}}`) — Phase 33
  shipped bare-atom forms; richer variants extend additively in v1.7+
  if real adopter feedback proves a need.
- **DASH support (`kind: :dash`)** — explicitly deferred to v1.7+ per
  memo §4.
- **Second provider** (Cloudflare Stream / Bunny Stream / Cloudinary
  Video) — v1.7+ per memo §13. v1.6 ships single-provider scope.

</deferred>

---

*Phase: 34-mux-rest-adapter-server-push-sync*
*Context gathered: 2026-05-06*
*Source of truth: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` + this CONTEXT.md (the latter supersedes at the four flagged memo corrections D-04, D-06, D-10, D-21).*
