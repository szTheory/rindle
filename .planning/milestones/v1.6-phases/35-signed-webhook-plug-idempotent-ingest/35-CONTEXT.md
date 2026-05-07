# Phase 35: Signed-Webhook Plug + Idempotent Ingest — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Research-driven one-shot. Per `STATE.md` Decision-Making Preference and the user feedback memo (`memory/feedback_research_driven_one_shot.md`), three parallel research subagents ran in parallel on (A) mountable Plug + raw-body cache, (B) Oban worker contract + race handling + `runtime_status` extension, (C) Mux event catalog + test signing + fixture payloads. Their findings are folded in as locked decisions below; nothing was asked of the user that didn't qualify as VERY impactful (semver / public-API / security).

<domain>
## Phase Boundary

Webhooks become the **primary readiness signal** for Mux-driven streaming. The
Plug verifies Mux's HMAC signature, enforces a Stripe-parity replay window,
loops a multi-secret rotation list, and Oban-defers ingest to a worker that
mutates `media_provider_assets` rows and broadcasts PubSub events. This phase
is the highest-fidelity in v1.6 — raw-body cache, multi-secret rotation,
replay protection, and idempotency all land here.

In scope:
- `Rindle.Delivery.WebhookPlug` — mountable provider-aware Plug; adopters
  mount via `forward "/webhooks/rindle/mux", Rindle.Delivery.WebhookPlug,
  provider: ..., secrets: ...` in their router. Single mount per provider
  (Stripe.WebhookPlug parity).
- `Rindle.Delivery.WebhookBodyReader` — raw body cache via `Plug.Parsers`
  `body_reader: {Mod, :fun, opts}` MFA. Stores body in `conn.assigns[:raw_body]`
  as a list of binaries (matches Mux/Plaid/Stripe canonical pattern).
- `Rindle.Workers.IngestProviderWebhook` — Oban worker on `:rindle_provider`
  queue, `max_attempts: 5`, `timeout: 30_000` ms, unique on Mux event UUID
  for 24h. Dispatches on event type, mutates `media_provider_assets`,
  broadcasts `:provider_asset_*` PubSub.
- Provider-internal telemetry inside `Rindle.Streaming.Provider.Mux.verify_webhook/3`
  for SDK-reason ops introspection (additive — Phase 33 behaviour contract
  unchanged).
- `Rindle.Streaming.Provider.Mux.Event.normalize/1` extension — typed branch
  for `video.upload.asset_created` (Phase 37 forward-compat; fixes a silent
  data-corruption risk where `data.id` is the upload-id, not the asset-id).
- `Rindle.Streaming.Provider.@type provider_event` extension — additive
  `upload_id` optional field (Phase 33 typespec, additive only).
- `mix rindle.runtime_status --provider-stuck` filter extending the v1.5
  surface with a `provider_assets` report section.
- `test/support/mux_webhook_fixtures.ex` — Rindle test helper wrapping
  `Mux.Webhooks.TestUtils.generate_signature/2` to add a `:timestamp`
  override (required for replay-attack tests).
- ExUnit fixtures: `webhook_video_asset_deleted.json` and
  `webhook_video_upload_asset_created.json` (new); existing
  `webhook_video_asset_{ready,errored,created}.json` get realistic 36-char
  Mux asset IDs.
- ExUnit suite proving: bypass-driven post of fixture `video.asset.ready`
  with real HMAC drives the worker → row flips to `:ready` → PubSub fires;
  duplicate post is no-op (Oban unique); replay (600s old) returns 400;
  signature mismatch returns 400; multi-secret rotation accepts both
  current and rotating secret.

Out of scope (explicit deferrals):
- `Rindle.Profile.Presets.MuxWeb`, `mix rindle.doctor` streaming validation,
  `guides/streaming_providers.md`, generated-app `mux-enabled` proof lane —
  Phase 36.
- `Rindle.Streaming.Provider.Mux.create_direct_upload/2` and the
  `:provider_asset_created` PubSub event for direct-creator-uploads —
  Phase 37 / v1.7.
- `Rindle.LiveView.subscribe(:provider_asset, id)` extension — Phase 37
  (MUX-23). Phase 35 broadcasts on the locked topic shape so Phase 37 needs
  zero observability refactor.
- Webhook event replay tooling (`mix rindle.webhook.replay`) — v1.7+.
- Configurable telemetry redaction — v1.7+ (Phase 35 hardcodes last-4-char
  `provider_asset_id` redaction in metadata).
- Map-keyed error variants (`{:provider_webhook_invalid, %{...}}`) — v1.7+
  if real adopter feedback proves the need; Phase 33 shipped bare atoms,
  Phase 35 keeps that.
- `:dash` playback kind — v1.7+.
- Configurable webhook body-size limit — Phase 35 hardcodes 1 MiB (100×
  headroom over real Mux payloads); make configurable in v1.7+ if real
  adopter need surfaces.

</domain>

<decisions>
## Implementation Decisions

All decisions below are LOCKED. Source: candidate memo
`.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` (§5.3, §7, §8.4) +
Phase 34 CONTEXT.md (D-10..D-12 verify_webhook contract, D-29 config)
+ three parallel research subagents' findings (Plug shape /
worker contract / Mux event surface). Section refs: memo §X means the
candidate memo; CONTEXT-34 §Y means Phase 34 CONTEXT.md.

### Mountable Plug Shape (MUX-09)

- **D-01:** **Mountable Plug, one `forward` per provider** (Stripe.WebhookPlug
  parity). Adopters mount via:
  ```elixir
  forward "/webhooks/rindle/mux", Rindle.Delivery.WebhookPlug,
    provider: Rindle.Streaming.Provider.Mux,
    secrets: {:application, :rindle, [Rindle.Streaming.Provider.Mux, :webhook_secrets]}
  ```
  v1.7 second provider = second `forward`. Do NOT ship a path-dispatching
  mega-Plug; provider-specific quirks (Mux's `t=...,v1=...` header vs
  Stripe's `Stripe-Signature` vs GitHub's `X-Hub-Signature-256`) leak into
  the dispatch table the moment you try to share. The behaviour seam is
  `verify_webhook/3` on the provider module.

- **D-02:** **Plug `init/1` opts:** `provider:` (module, required) +
  `secrets:` (resolver, required). `secrets:` resolver supports four shapes:
  ```elixir
  secrets ::
      [binary()]                                    # direct list (tests)
    | {:system, env_var :: String.t()}              # comma-split env var
    | {:application, app :: atom(), [atom()]}       # Application.get_env getter
    | (-> [binary()])                               # 0-arity fn
  ```
  Resolution happens at `call/2` time, NOT `init/1` time, so runtime
  config and rotation work without app restart. Adopter-facing canonical
  is `{:application, :rindle, [Rindle.Streaming.Provider.Mux, :webhook_secrets]}`
  (matches the existing Phase 34 config posture at
  `lib/rindle/streaming/provider/mux.ex:19-21`).

- **D-03:** **`init/1` validates** `Code.ensure_loaded?(provider) and
  function_exported?(provider, :verify_webhook, 3)` and raises
  `ArgumentError` if not. Surfaces missing-`:mux`-dep mistakes at adopter
  compile time, not at first webhook delivery (3am page). Mirrors
  `Rindle.Delivery.LocalPlug.init/1` raise pattern at line 35.

- **D-04:** **`call/2` enforces POST-only.** Non-POST returns `405 Method
  Not Allowed` + telemetry `reason: :method_not_allowed`. `405` is the
  correct HTTP semantic (Stripe uses 400; we deliberately diverge — `405`
  also defends against accidental health-check `GET` reaching the verify
  path with empty body and 400-ing as `:provider_webhook_invalid` —
  confusing telemetry).

- **D-05:** **Header normalization:** Plug.Conn already lowercases all
  request headers per HTTP/2 spec. The Plug builds the `headers` map for
  `verify_webhook/3` from `conn.req_headers` (already lowercase). The
  case-fork in existing `lib/rindle/streaming/provider/mux.ex:298-304`
  (`fetch_sig_header/1` checks both `mux-signature` and `Mux-Signature`)
  is redundant once headers come from the Plug — drop the dead branch
  in Phase 35 cleanup, keep only the lowercase lookup.

### Raw-Body Cache (MUX-09)

- **D-06:** **Body lives in `conn.assigns[:raw_body]` as a LIST of binaries**
  (most-recent first). Use `assigns`, not `private`. Mux's own README,
  Plaid Elixir, Stripe community examples all use `conn.assigns[:raw_body]`
  as a list (multipart-safe — `Plug.Parsers.MULTIPART` invokes the body
  reader per-part; chunked transfers may produce multiple `:more` reads).
  `WebhookBodyReader.raw_body(conn)` accessor returns the binary or nil.

- **D-07:** **`read_body/2` callable drains chunks itself before returning**
  `{:ok, body, conn}`. `Plug.Parsers.JSON.decode/3` does NOT loop on
  `{:more, _}` — it treats it as `{:error, :too_large, conn}`. Loop
  internally with `Enum.reduce_while`-style accumulator so adopters who
  tighten `:length` for memory hardening don't silently truncate payloads.

- **D-08:** **1 MiB max body guard inside `read_body/2`.** Mux webhooks are
  <10KB in practice; 1 MiB is 100× headroom and matches Stripe's documented
  recommendation. Over-limit returns `{:error, :too_large}`; `Plug.Parsers`
  raises `Plug.Parsers.RequestTooLargeError` which Phoenix's default error
  handler maps to `413`. Do NOT try to handle 413 inside `WebhookPlug` —
  too late, body reader fires before Plug.

- **D-09:** **Body reader installed globally in `endpoint.ex`** (NOT
  scoped to webhook paths). Stripe / Plaid / Mux's own examples all
  install globally. The `conn.assigns[:raw_body]` overhead is one
  prepended binary per request — negligible. Scoping to webhook-only
  routes via router pipeline runs AFTER `Plug.Parsers` has consumed the
  body — too late.

- **D-10:** **`WebhookBodyReader.raw_body/1` accessor** (public helper):
  - Returns the binary from `conn.assigns[:raw_body]` (handles list-of-binaries
    via `Enum.reverse |> IO.iodata_to_binary` for multi-chunk OR multipart cases;
    single-binary list returns `List.first` directly).
  - Returns `nil` when assign missing.
  - The Plug uses this; falls back to `Plug.Conn.read_body/2` if assign missing
    (covers the "plug mounted before parsers" case Stripe optimizes for).
  - Empty fallback (body drained by upstream parsers) → `500 server_misconfigured`
    + warning telemetry (D-16). Adopter wiring bug, not a malformed webhook —
    surface clearly, don't 400.

### Verification, Enqueue, Response (MUX-10, MUX-11, MUX-12)

- **D-11:** **`call/2` invokes `provider.verify_webhook/3` inside `try/rescue`**
  to defend against future provider modules raising. On rescue:
  `400 :provider_webhook_invalid` + telemetry `reason: :provider_callback_raised,
  error: Exception.message(e)`. The current `Rindle.Streaming.Provider.Mux.verify_webhook/3`
  only returns `:ok | :error` tuples — defensive rescue is one `try` frame
  per webhook (microseconds).

- **D-12:** **Empty `:secrets` resolution → `400 :provider_webhook_invalid`**
  + telemetry `reason: :no_secrets_configured`. Adopter forgot to set
  `RINDLE_MUX_WEBHOOK_SECRETS`; treating as 4xx (signal-to-Mux-to-stop-retrying)
  is correct — retrying won't fix a missing config.

- **D-13:** **Happy path response:** `202 Accepted`, empty body, `halt()`.
  Mux ignores response body; cares only about status. Empty body simplifies
  cassette assertions.

- **D-14:** **Invalid signature OR replay window failure → `400`,**
  body `"provider_webhook_invalid"` (plain text, no JSON wrapping). Single
  error atom matches the locked v1.6 vocabulary (memo §8.2). Telemetry
  metadata distinguishes: `reason: :sig_mismatch | :replay_window |
  :missing_header` — operators who need the distinction subscribe to the
  `[:rindle, :provider, :webhook, :rejected]` event.

- **D-15:** **Oban DB failure during enqueue → `503 Service Unavailable`**
  (NOT `500`). 503 is the correct HTTP semantic for "transient downstream
  failure, please retry" — Mux retries non-2xx for 24h with exponential
  backoff. `Oban.insert/1` wrapped in `try/rescue` for Postgres pool
  exhaustion.

- **D-16:** **Missing body reader assign + empty `Plug.Conn.read_body/2`
  fallback → `500 server_misconfigured`** + warning telemetry
  `reason: :body_reader_missing`. Adopter wiring bug; surface loudly,
  don't 400 (which would imply Mux did something wrong).

- **D-17:** **`Rindle.Streaming.Provider.verify_webhook/3` callback contract
  is UNCHANGED** (`{:ok, provider_event()} | {:error, :provider_webhook_invalid}`).
  Phase 33 typespec stays. The Mux provider module's internal
  `verify_webhook/3` ALSO emits `[:rindle, :provider, :mux, :webhook_attempt,
  :rejected]` telemetry inside the function with the SDK-specific reason
  string for ops introspection — this is provider-INTERNAL telemetry,
  additive, and does not touch the public behaviour contract. Operators
  needing to distinguish "secret rotation forgot to update Rindle config"
  from "Mux is sending stale events because of queue lag" subscribe to
  the provider-internal event.

### Worker — `IngestProviderWebhook` (MUX-12, MUX-13)

- **D-18:** **Worker:** `Rindle.Workers.IngestProviderWebhook`,
  `use Oban.Worker, queue: :rindle_provider, max_attempts: 5`,
  `c:Oban.Worker.timeout/1 -> 30_000` (memo §7). `:rindle_provider` queue
  was added in Phase 34 (CONTEXT-34 §D-14); no new queue.

- **D-19:** **Worker arg shape** (the Plug enqueues exactly this; do NOT
  drift):
  ```elixir
  %{
    "event_id"   => uuid,                # top-level for Oban unique constraint
    "provider"   => "mux",
    "event_type" => "video.asset.ready", # raw Mux type for filtering + dispatch
    "event"      => normalized_event_map # output of Mux.Event.normalize/1
  }
  ```
  - `event_id` MUST be top-level for Oban `unique` to key on it via
    `keys: [:event_id]`.
  - `event_type` raw string is duplicated at top-level (in addition to
    `event["type"]` atom) so Oban operators can `EXPLAIN`-filter by
    `args->>'event_type'` without atom decoding gymnastics. Mirrors
    `process_variant.ex:175` idiom.
  - **NO `raw_body` in args.** The Plug-side verification is the trust
    boundary; the worker trusts upstream verification. Avoids Oban
    payload bloat. (Mux payloads are small but the principle matters
    for Cloudflare/Bunny in v1.7+.)
  - `Mux.Event.normalize/1` already returns the locked `provider_event`
    shape; decoding twice is wasteful. Plug normalizes ONCE so it can
    return `400 :provider_webhook_invalid` synchronously on malformed
    payloads (matches MUX-12). Worker does NOT re-normalize.

- **D-20:** **Oban unique opts:**
  ```elixir
  unique: [
    fields: [:args],
    keys: [:event_id],
    states: [:scheduled, :executing, :retryable],
    period: 86_400
  ]
  ```
  Keyed on Mux event UUID for re-delivery idempotency. Re-delivery during
  Mux outage = no-op. 24h covers Mux's 72h retry window for the relevant
  attempt span.

- **D-21:** **Race-snooze for missing `media_provider_assets` row:**
  ```
  attempt 1 → 5s,  attempt 2 → 15s,  attempt 3 → 45s,  attempt 4 → 90s
  attempt ≥ 5 → {:cancel, :provider_asset_row_missing}
  ```
  Cumulative ~155s budget. Race exists because `MuxIngestVariant` (Phase 34)
  inserts the row in `:uploading` and only flips to `:processing` AFTER
  the Mux REST call returns; webhook for `video.asset.ready` can fire
  before Repo commit visibility. Snoozes do NOT consume `attempt`,
  preserving `max_attempts: 5` budget for genuine errors. Stripe
  documented pattern. Rejected alternatives: pending-event sidecar table
  (disproportionate complexity for ms-scale race) and log-and-drop
  (loses the event; idempotency-on-event_id only protects against
  RE-DELIVERY, not one-shot loss).

- **D-22:** **State transitions: NO `SELECT ... FOR UPDATE`.**
  `Rindle.Domain.ProviderAssetFSM.transition/3` (Phase 33) is a pure
  validator with NO DB writes (confirmed `provider_asset_fsm.ex:21-27`).
  Worker pattern:
  ```elixir
  with :ok <- ProviderAssetFSM.transition(row.state, target, ctx),
       {:ok, _updated} <- row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
    :ok
  end
  ```
  Postgres MVCC + FSM allowlist provides correctness. Mirrors Phase 34
  `mux_ingest_variant.ex:314-328` verbatim. Webhook IS source of truth
  for provider state — no `expected_*` atomic-promote args needed.

- **D-23:** **FSM rejection `{:error, {:invalid_transition, from, to}}`
  → `{:cancel, ...}`.** Illegal state can't fix itself; the Phase 34
  `MuxSyncProviderAsset` polling backstop reconciles if a row is genuinely
  stuck. Out-of-order webhooks (e.g., `video.asset.ready` arrives at a
  `:uploading` row before `MuxIngestVariant` flipped to `:processing`)
  fall under this case — FSM rejects `:uploading → :ready`; worker
  cancels; sync-poll fixes.

- **D-24:** **Repo error during update → `raise`** (let Oban retry;
  standard exponential backoff up to `max_attempts: 5`). Mirrors
  `process_variant.ex` and `mux_ingest_variant.ex` posture.

- **D-25:** **Unknown `event.type` → `:ok` no-op + bump `last_event_at`**
  + telemetry `:ignored kind: :unknown_event`. Mux ships new event types
  regularly; library should not crash on novelty (MUX-13).

- **D-26:** **Worker telemetry namespace:**
  ```
  [:rindle, :provider, :webhook, :processed]   # successful state transition
  [:rindle, :provider, :webhook, :ignored]     # no-op (unknown / out-of-order / deferred / dropped)
  [:rindle, :provider, :webhook, :exception]   # raised / FSM-rejected / cancel
  ```
  Distinct from PLUG events `:verified | :rejected | :secret_used`.
  Operators see both signals — `:verified` proves edge works, `:processed`
  proves queue drains. **Metadata schema** (security invariant 14):
  ```elixir
  %{
    provider: :mux,
    event_type: "video.asset.ready",        # raw Mux type for filtering
    asset_id: MediaProviderAsset.redact_id(provider_asset_id),  # last-4 tag
    profile: "MyApp.Profiles.Web",
    from_state: "processing",                # nil if no transition
    to_state: "ready",
    kind: nil                                # :out_of_order | :unknown_event | :deferred_to_phase_37 | :error | :invalid_transition | :race_snooze | :dropped
  }
  ```
  CRITICAL: `asset_id` is the REDACTED tag from
  `MediaProviderAsset.redact_id/1`. NEVER the raw Mux `provider_asset_id`.

### Mux Event Dispatch Table (MUX-13)

- **D-27:** **Phase 35 worker dispatches:**

  | Mux event | Worker action | PubSub broadcast |
  |---|---|---|
  | `video.asset.ready` | FSM `* → :ready`; persist `playback_ids[].id`, `duration`, `aspect_ratio`, clear `last_sync_error` | `:provider_asset_ready` |
  | `video.asset.errored` | FSM `* → :errored`; populate `last_sync_error` from `data.errors.{type,messages}` | `:provider_asset_errored` |
  | `video.asset.deleted` | FSM `* → :deleted` | `:provider_asset_deleted` |
  | `video.asset.created` | FSM `:uploading → :processing` (Mux says `status: "preparing"`); bump `last_event_at` | **NONE** — `:provider_asset_created` is Phase 37 / MUX-23 |
  | `video.upload.asset_created` | No-op + bump `last_event_at` IF row matches `provider_asset_id`; otherwise drop with debug log | NONE — Phase 37 |
  | `:unknown` (any other type) | No-op + bump `last_event_at` IF row matches; otherwise drop | NONE |

- **D-28:** **Plug-side DROP table** (200 OK, no enqueue, debug log)
  for events Rindle v1.6 does not care about, per the Mux 2026 catalog:
  - `video.asset.updated`, `video.asset.warning`, `video.asset.non_standard_input_detected`
  - `video.asset.master.{ready,preparing,deleted,errored}` (master file access not exposed)
  - `video.asset.track.{created,ready,errored,deleted}` (subtitle/audio tracks ride on asset envelope)
  - `video.asset.static_rendition.*` (mp4_support: "none" by default)
  - `video.asset.live_stream_completed` (no live surface)
  - `video.upload.{created,cancelled,errored}` (direct uploads are Phase 37)
  - `video.live_stream.*` (out of scope)

  DROP returns `200 OK` with empty body (NOT `204` — Mux historically had
  quirks with 204 interpreted as "no acknowledgment"). Telemetry emits
  `[:rindle, :provider, :webhook, :verified]` with metadata
  `kind: :dropped, event_type: <type>` so operators see them in dashboards
  but no Oban work happens.

  **Implementation:** the Plug knows the DROP set via a small allowlist
  on the provider module (e.g., `Rindle.Streaming.Provider.Mux.dispatch_kind/1
  -> :dispatch | :drop`). Provider owns the table; Plug stays generic.

### `Event.normalize/1` Extension — `video.upload.asset_created` Branch (MUX-13 forward-compat)

- **D-29:** **Add typed branch in `Rindle.Streaming.Provider.Mux.Event.normalize/1`**
  for `video.upload.asset_created`:
  ```elixir
  def normalize(%{"type" => "video.upload.asset_created", "data" => data} = raw) do
    {:ok, %{
      type: :upload_asset_created,
      provider_asset_id: Map.get(data, "asset_id"),  # NB: NOT data["id"]
      upload_id: Map.get(data, "id"),
      playback_ids: [],
      state: nil,
      occurred_at: parse_occurred_at(Map.get(raw, "created_at")),
      raw: raw
    }}
  end
  ```
  Add `:upload_asset_created` to `normalize_type/1` clauses.

  **Rationale:** Mux's `video.upload.asset_created` ships `data.id` as the
  UPLOAD-id and `data.asset_id` as the asset-id. The current generic
  branch (`event.ex:17-29`) does `Map.get(data, "id")` and assigns to
  `provider_asset_id` — a silent data-corruption risk in Phase 37 if Phase 35
  ships without the typed branch and Phase 37 starts dispatching upload
  events later. Land the branch in Phase 35 as forward-compat; Phase 35
  worker handles it as no-op (D-27).

- **D-30:** **Extend `Rindle.Streaming.Provider.@type provider_event`**
  with optional `upload_id`:
  ```elixir
  @type provider_event :: %{
    required(:event_id) => String.t(),
    required(:event_type) => String.t(),
    required(:provider_asset_id) => provider_asset_id() | nil,
    required(:occurred_at) => DateTime.t(),
    required(:raw) => map(),
    optional(:upload_id) => String.t() | nil   # added v1.6 Phase 35
  }
  ```
  Additive Phase 33 typespec extension. Not a behaviour break — every
  existing call site continues to compile and runtime-match. Document in
  Phase 35 inline `@moduledoc` and the v1.6 upgrade notes (Phase 36
  guide will surface it).

### PubSub Broadcast Contract (locked for Phase 37 forward-compat) (MUX-13)

- **D-31:** **Two-topic broadcast** per provider-asset event (mirrors
  `process_variant.ex:478` two-topic idiom):
  ```
  "rindle:provider_asset:#{media_asset_id}"   # NEW — Phase 37 will subscribe here
  "rindle:asset:#{media_asset_id}"            # EXISTING (v1.4) — backward-compat
  ```
  Topic key is `MediaAsset.id` (NOT `MediaProviderAsset.id`, NOT
  `provider_asset_id`). Adopters subscribe in `mount/3` with
  `Rindle.LiveView.subscribe(:provider_asset, asset.id)` — `asset.id` is
  the natural key they're rendering. Forcing `MediaProviderAsset.id`
  lookup adds round-trips and couples to internal schema layout.
  `provider_asset_id` is FORBIDDEN in topic names (security invariant 14
  — topic names appear in PubSub-tracer logs and adopter telemetry
  handlers).

- **D-32:** **Payload shape:**
  ```elixir
  {:rindle_event, event_type, %{
    asset_id:     binary_id,            # MediaAsset.id — natural adopter key
    playback_ids: [String.t()],         # PUBLIC playback ids (safe to expose)
    profile:      String.t(),           # profile module name as string
    provider:     :mux,                 # provider atom
    state:        String.t()            # the new MediaProviderAsset.state
  }}
  ```
  CRITICAL: `provider_asset_id` is NEVER in `payload` (security invariant 14).
  `playback_ids` ARE allowed (public-side identifier; `MediaProviderAsset`
  Inspect impl confirms `playback_ids` is unredacted while
  `provider_asset_id` and `raw_provider_metadata` are redacted).

- **D-33:** **Phase 35 broadcasts:** `:provider_asset_ready`,
  `:provider_asset_errored`, `:provider_asset_deleted`.
  `:provider_asset_created` is RESERVED for Phase 37 / MUX-23 (firing it
  now creates an orphan event with no `Rindle.LiveView.subscribe(:provider_asset, id)`
  consumer). Phase 35 broadcasts on the `"rindle:provider_asset:..."`
  topic before any code subscribes — Phoenix.PubSub silently drops
  broadcasts to topics with no subscribers (zero-cost), and freezing
  the topic name now prevents Phase 37 observability rippling.

### Test Surface (MUX-09..14 verification)

- **D-34:** **Test signing — adopt `Mux.Webhooks.TestUtils.generate_signature/2`**
  for happy-path tests; wrap it in `Rindle.Test.MuxWebhookFixtures.sign_header/3`
  for replay-attack tests. The SDK helper is public, documented, and lives
  at `deps/mux/lib/mux/webhooks/test_utils.ex:30-43`. The Rindle wrapper
  exists ONLY because the SDK helper hardcodes `System.system_time(:second)`
  and offers no `:timestamp` override — required for forging stale signatures.
  Replace the handrolled HMAC at `test/rindle/streaming/provider/mux/mux_test.exs:174-181`
  with a thin call to the wrapper.

- **D-35:** **HMAC recipe:**
  ```elixir
  :crypto.mac(:hmac, :sha256, secret, "#{ts}.#{raw_body}")
  |> Base.encode16(case: :lower)
  ```
  Verified against SDK source. Header format: `t=<unix_ts>,v1=<hex>`,
  multiple `v1=` schemes supported (Mux ships rotating signatures during
  internal rotations).

- **D-36:** **Test fixtures** under `test/fixtures/mux/`:
  - **Existing** (Phase 34): `webhook_video_asset_{ready,errored,created}.json`.
    Update to use realistic Mux asset IDs (36-char base32 style:
    `00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKcqj017A`).
  - **New** (Phase 35): `webhook_video_asset_deleted.json` (sparse — `data`
    is `{id, status}`); `webhook_video_upload_asset_created.json` (data has
    BOTH `id` for upload-id AND `asset_id` — exercises D-29 typed branch).
  - Tests assert on SPECIFIC keys (`assert %{type: :ready, state: "ready"} = evt`),
    NEVER on the full `data` map (Mux ships new fields regularly; full-map
    asserts trip on every Mux schema update).

- **D-37:** **Plug test pattern:** `Plug.Test.conn(:post, "/", body) |>
  assign(:raw_body, [body])` — manually pre-populate the raw_body assign
  (synthetic test conns don't invoke the body reader). The
  `signed_conn/4` helper bakes this in. Real HTTP integration via Bypass
  or `Phoenix.ConnTest` with a router DOES invoke the body reader.

- **D-38:** **Phase 35 needs ZERO new Mox expectations.** The Plug is
  pure verify-and-enqueue. The worker reads/writes Repo and broadcasts
  PubSub but does NOT call back into the Mux SDK. The
  `Rindle.Streaming.Provider.Mux.ClientMock` (Phase 34) remains unused
  for the Phase 35 happy path.

### `mix rindle.runtime_status --provider-stuck` Extension (MUX-14)

- **D-39:** **`Rindle.runtime_status/1` opts gain `:provider_stuck`**
  (boolean). Threshold defaults to `Application.get_env(:rindle,
  Rindle.Streaming.Provider.Mux, [])[:provider_stuck_threshold_seconds] || 7200`
  (7200s = 4× v1.4 max-duration cap; matches Phase 34 D-29 default).
  `--older-than-sec`, when both supplied, OVERRIDES the app-config default
  (operator wins).

- **D-40:** **New `provider_assets` report section** in
  `Rindle.runtime_status/1` return:
  ```elixir
  %{
    counts: %{state => count, total: integer()},
    threshold_seconds: integer(),
    findings: [
      %{
        class: :provider_stuck,
        count: integer(),
        oldest_age_seconds: integer(),
        samples: [
          %{
            asset_id: binary_id,                                 # MediaAsset.id (full UUID — operator needs this)
            provider_asset_id: MediaProviderAsset.redact_id(...), # last-4 tag (security invariant 14)
            profile: String.t(),
            provider: String.t(),
            state: String.t(),
            updated_at: DateTime.t(),
            last_event_at: DateTime.t() | nil,
            last_sync_error: String.t() | nil,
            reason: String.t()
          }
        ]
      }
    ]
  }
  ```
  Query: `MediaProviderAsset` rows in `("uploading", "processing")` whose
  `updated_at < now() - threshold`. New recommendation handler for class
  `:provider_stuck` (action: `:resync`, surface: `Rindle.Workers.MuxSyncProviderAsset`
  / operator dashboard).

- **D-41:** **Mix task changes:** `lib/mix/tasks/rindle.runtime_status.ex`
  gains `--provider-stuck` boolean flag in `OptionParser` strict opts;
  `format_provider_findings/1` text helper modeled on `format_findings/1`;
  appended to `format_text_report/1` output.

### Configuration (no new env vars; reuses Phase 34's)

- **D-42:** All config under existing `config :rindle, Rindle.Streaming.Provider.Mux`
  block — `:webhook_secrets` (list, comma-split from env in
  `config/runtime.exs`), `:webhook_tolerance_seconds` (default 300, bounds
  60..900). NO new keys for Phase 35. The `:provider_stuck_threshold_seconds`
  default (7200) lives in the same block (Phase 34 D-29 already documents
  it). All configuration is read at the call site (no caching) per
  Phase 34 D-30.

### Module Layout

- **D-43:** **Files added in Phase 35:**
  - `lib/rindle/delivery/webhook_plug.ex` — mountable Plug (PUBLIC)
  - `lib/rindle/delivery/webhook_body_reader.ex` — raw body reader (PUBLIC)
  - `lib/rindle/workers/ingest_provider_webhook.ex` — Oban worker (PUBLIC — adopter sees it in dashboards)
  - `test/support/mux_webhook_fixtures.ex` — `Rindle.Test.MuxWebhookFixtures` test signing helper (test-only)
  - `test/fixtures/mux/webhook_video_asset_deleted.json`
  - `test/fixtures/mux/webhook_video_upload_asset_created.json`
  - `test/rindle/delivery/webhook_plug_test.exs`
  - `test/rindle/delivery/webhook_body_reader_test.exs`
  - `test/rindle/workers/ingest_provider_webhook_test.exs`
  - `test/rindle/streaming/provider/mux/event_test.exs` (extended for D-29 branch)

- **D-44:** **Files modified in Phase 35:**
  - `lib/rindle/streaming/provider/mux/event.ex` — add `video.upload.asset_created`
    typed branch + `:upload_asset_created` `normalize_type/1` clause (D-29)
  - `lib/rindle/streaming/provider.ex` — add `upload_id` optional field
    to `@type provider_event` (D-30)
  - `lib/rindle/streaming/provider/mux.ex` — drop dead case-fork at
    `fetch_sig_header/1` lines 298-304 (D-05); add provider-internal
    telemetry inside `verify_webhook/3` for SDK reason ops introspection
    (D-17); add `dispatch_kind/1` allowlist for Plug-side DROP table (D-28)
  - `lib/rindle/ops/runtime_status.ex` — add `provider_assets_report/2`;
    wire into `runtime_status/1` return; add `:provider_stuck` filter
    handling; add stuck recommendation handler (D-39, D-40)
  - `lib/mix/tasks/rindle.runtime_status.ex` — add `--provider-stuck` flag
    + `format_provider_findings/1` text helper (D-41)
  - existing `test/fixtures/mux/webhook_video_asset_{ready,errored,created}.json`
    — realistic 36-char Mux asset IDs (D-36)
  - `test/rindle/streaming/provider/mux/mux_test.exs:174-181` — replace
    handrolled HMAC with `Rindle.Test.MuxWebhookFixtures.sign_header/3`
    (D-34)

### Documentation Touch (Minimal — Phase 36 Owns Adopter Onboarding)

- **D-45:** **Phase 35 ships only inline `@moduledoc`** on `WebhookPlug`,
  `WebhookBodyReader`, and `IngestProviderWebhook`. Each `@moduledoc`
  includes the canonical adopter `endpoint.ex` + `router.ex` snippets
  copy-pasteable. **NO** `guides/streaming_providers.md` (that's
  Phase 36 / MUX-17). **NO** README updates (Phase 36 / MUX-19).
  CHANGELOG / runtime release notes only as needed.

### Decision-Making Preference

- **D-46:** Per `STATE.md` Decision-Making Preference and
  `memory/feedback_research_driven_one_shot.md`: planner / executor /
  verifier decide by default and produce coherent recommendation sets.
  Escalate ONLY for genuinely high-blast-radius decisions
  (semver-significant public API reshapes, destructive or irreversible
  operations, security/compliance boundary changes). The contract
  surface for Phase 35 is locked above; downstream agents do not
  re-litigate.

### Claude's Discretion (Planner / Executor)

The decisions above lock the contract surface. The items below are
implementation choices the planner / executor should make autonomously
without asking the user, so long as the locked decisions are preserved.

- Exact internal helper layout for `WebhookPlug` (single-file vs split
  body-acquisition / verify / enqueue / response helpers); planner picks
  for cohesion
- Whether to inline the body-reader retrieval logic in the Plug or call
  `WebhookBodyReader.raw_body/1` as a helper — both work; D-10 expresses
  a recommendation, planner picks
- Exact race-snooze backoff curve — `5/15/45/90s` is the locked baseline;
  planner may tune (`5/15/30/60s`, `5/30/60/120s`) if benchmarks or
  adopter feedback warrant
- Telemetry metadata granularity (e.g., should `kind: :race_snooze`
  metadata also carry the attempt number?); planner picks defaults that
  match existing Rindle conventions
- Whether the worker's `bump_last_event/3` for `:created` ALSO persists
  `playback_ids` if Mux included them in the event payload — Phase 35
  default is NO (single source of truth = `:ready` populates `playback_ids`);
  Phase 37 may revisit if LiveView UI needs eager `playback_ids` for
  "ingest in progress" indicators
- Format details of `format_provider_findings/1` text output (column
  widths, indentation) — planner matches existing `format_findings/1`
  style
- Internal ordering of `dispatch_kind/1` allowlist clauses
  (alphabetical vs by frequency); planner picks
- Test file organization for `webhook_plug_test.exs` (`describe` block
  granularity); planner mirrors `local_plug_test.exs` style
- Whether to expose `Rindle.Test.MuxWebhookFixtures` as a public module
  (so adopter test suites can use it for their own webhook-driven
  integration tests) or keep `@moduledoc false` for now — planner picks;
  default to `@moduledoc false` until Phase 36 documents it
- Cassette JSON file structure (one per fixture vs grouped); D-36
  expresses one-per-fixture default

</decisions>

<specifics>
## Specific Ideas

- **The single most important Phase 35 invariant: `provider_asset_id`
  never crosses into PubSub payloads, telemetry metadata, or runtime_status
  output.** The redacted last-4-char tag is the only form. Three layers
  enforce it: schema Inspect impl (Phase 33), telemetry metadata
  redaction (Phase 35 worker), and runtime_status sample shape
  (Phase 35 D-40). The `MediaProviderAsset.redact_id/1` helper from
  Phase 33 is the single source of truth for the redaction recipe.

- **The `video.upload.asset_created` data-corruption risk is the most
  important silent footgun this phase prevents.** Mux ships `data.id`
  as the UPLOAD-id (NOT the asset-id) for this event; the asset-id
  lives in `data.asset_id`. The current generic `Event.normalize/1`
  branch mis-attributes — Phase 37 would silently corrupt
  `media_provider_assets.provider_asset_id` for direct-creator-uploads
  if Phase 35 doesn't land the typed branch (D-29). The branch is a
  10-line addition with zero v1.6 runtime impact (the worker still
  no-ops on `:upload_asset_created` per D-27); pure forward-compat.

- **The Plug does NOT re-implement HMAC.** `Mux.Webhooks.verify_header/4`
  is the SDK function; constant-time, multi-`v1=` parser, replay-window
  check. Rindle's job is the SHAPE around it (raw-body cache, multi-secret
  rotation loop, Oban enqueue, response codes). Don't roll your own
  HMAC; SDK Issue #42 (429 Retry-After swallowed) demonstrates that
  going around the SDK introduces drift.

- **The Stripe parity is intentional and load-bearing.** `300s` tolerance
  default, `400` on signature failure (single error atom), `202` on
  success, `503` on transient downstream failure, mountable Plug-per-provider,
  multi-secret rotation list with first-match-wins — every one of these
  is the convention adopters already know from Stripe's `Stripe.WebhookPlug`.
  Phase 35's only deliberate divergence is `405` for non-POST (Stripe
  uses 400 — we pick 405 because it's HTTP-correct and avoids GET
  health-check confusion).

- **The two-topic PubSub broadcast (`"rindle:provider_asset:..."` AND
  `"rindle:asset:..."`) mirrors `process_variant.ex:478` exactly.** Phase 35
  reuses the proven idiom; Phase 37's `Rindle.LiveView.subscribe(:provider_asset, id)`
  extension is a one-line addition to `live_view.ex:209-211`'s
  `topic_for/2` table.

- **The `runtime_status --provider-stuck` extension reuses the v1.5
  `Rindle.runtime_status/1` Mix wrapper pattern verbatim** — new filter
  flag, new report section, new sample shape with redacted
  `provider_asset_id`. Operators get `mix rindle.runtime_status
  --provider-stuck --format json` with the same mental model they
  already use for `--older-than-sec`.

- **The race-snooze posture (D-21) means the Phase 35 worker is the
  only Rindle worker that uses `{:snooze, n}`.** All other workers
  (`ProcessVariant`, `MuxIngestVariant`, `MuxSyncProviderAsset`) treat
  retryable errors via `raise` + Oban exponential backoff. The snooze
  is justified here because the race window is data-visibility (not
  computation); snoozes preserve the `max_attempts: 5` budget for
  GENUINE errors. Document the divergence in the worker's `@moduledoc`.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before
planning or implementing.**

### Source of truth (locked recommendation)
- `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` — the locked
  recommendation memo. **Section index for Phase 35:** §2 MUX-09..14
  Phase 35 requirements (line 73); §5.3 Mountable webhook plug shape
  (line 274); §7 Oban + webhook ingestion contract (line 339, **most
  important Phase 35 reference**); §8.1 locked behavioral rules
  (line 363); §8.2 failure-mode vocabulary (line 372); §8.4 telemetry
  events (line 405); §9 security invariants (invariant 14 still binding).
  **Corrections / additions in this CONTEXT.md (D-29 upload typed branch,
  D-30 typespec extension, D-21 race-snooze posture, D-26 worker telemetry
  namespace) supersede the memo at conflicts.**

### Phase scope and milestone constraints
- `.planning/ROADMAP.md` (lines 148-189) — Phase 35 goal, 5 success
  criteria, plan-count guidance (4 plans)
- `.planning/REQUIREMENTS.md` (lines 87-112) — MUX-09..14 phase-35
  requirements
- `.planning/PROJECT.md` — current milestone posture, security invariant
  14 (provider_asset_id redaction), adopter-first runtime ownership
- `.planning/STATE.md` — Decision-Making Preference (decide-by-default,
  escalate-only-impactful)
- `.planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md` —
  Phase 34 contract decisions Phase 35 must consume verbatim:
  - **D-10** `verify_webhook/3` is single-secret SDK; multi-secret loop
    in caller (already shipped in `mux.ex:272-296`)
  - **D-11** the loop shape (Phase 34 shipped this; Phase 35 wires the
    Plug around it)
  - **D-12** tolerance default 300s, bounds 60..900
  - **D-29** complete Mux config block under
    `config :rindle, Rindle.Streaming.Provider.Mux`
  - **D-30** call-site config reading (no caching)
- `.planning/phases/34-mux-rest-adapter-server-push-sync/34-VERIFICATION.md` —
  what Phase 34 shipped (sanity-check: `verify_webhook/3` exists,
  Event normalizer exists, telemetry redaction parity test enforces
  invariant 14)
- `.planning/phases/33-provider-boundary-state-schema/33-CONTEXT.md` —
  Phase 33 schema + FSM contract; Phase 35 worker drives FSM via
  `transition/3` and writes through `MediaProviderAsset.changeset/2`

### Existing code seams Phase 35 must extend / consume
- `lib/rindle/delivery/local_plug.ex` — **the existing Rindle Plug
  pattern**: `init/1` raise on misconfiguration (line 35),
  `forbidden/1` plain-text response (line 239), `halt()`-after-send_resp,
  `@behaviour Plug` declaration. Phase 35 `WebhookPlug` mirrors this
  exact shape.
- `lib/rindle/streaming/provider/mux.ex` — **`verify_webhook/3` already
  shipped** at lines 272-296; multi-secret loop and tolerance config
  already in place. Phase 35 calls it from the Plug. Drop the dead
  `fetch_sig_header/1` case-fork at lines 298-304 (D-05). Add
  provider-internal telemetry inside `verify_webhook/3` for SDK reason
  ops introspection (D-17). Add `dispatch_kind/1` allowlist for
  Plug-side DROP table (D-28).
- `lib/rindle/streaming/provider/mux/event.ex` — **`normalize/1` already
  shipped** at lines 17-29 with BL-03 `playback_ids: nil` defense. Phase 35
  adds the typed branch for `video.upload.asset_created` (D-29) and
  the `:upload_asset_created` normalize_type clause.
- `lib/rindle/streaming/provider.ex` — Phase 33 behaviour. Phase 35
  adds `upload_id` optional field to `@type provider_event` (D-30).
  `verify_webhook/3` callback contract is UNCHANGED (D-17).
- `lib/rindle/streaming/capabilities.ex` — Phase 33 closed vocabulary;
  no new capabilities for Phase 35 (`:webhook_ingest` was Phase 33).
- `lib/rindle/domain/media_provider_asset.ex` — Phase 33 schema; Phase 35
  worker inserts/updates rows; `MediaProviderAsset.redact_id/1` is THE
  redaction helper for security invariant 14.
- `lib/rindle/domain/provider_asset_fsm.ex` — Phase 33 FSM; Phase 35
  worker calls `transition/3` and respects the allowlist
  (`provider_asset_fsm.ex:9-16`). FSM is a pure validator; caller
  (Phase 35 worker) owns persistence.
- `lib/rindle/workers/process_variant.ex` (lines 465-500) — **the
  PubSub broadcast pattern Phase 35 mirrors verbatim**: two-topic
  `[asset, variant/provider_asset]` broadcast, `{:rindle_event, event_type,
  payload}` tuple, `pubsub_server/0` helper at line 498, `Rindle.PubSub`
  default.
- `lib/rindle/workers/mux_ingest_variant.ex` — **the FSM call-site
  pattern Phase 35 mirrors**: `with :ok <- ProviderAssetFSM.transition(...),
  {:ok, _} <- changeset |> Repo.update()` (lines 314-328); telemetry
  event shape; `MediaProviderAsset.redact_id/1` usage at line 464;
  `Config.repo()` call at line 97.
- `lib/rindle/workers/mux_sync_provider_asset.ex` — Phase 34 polling
  worker that backstops missed/out-of-order webhooks (Phase 35 D-23
  cancel path relies on this).
- `lib/rindle/error.ex` — `Rindle.Error.message/1` clause for
  `:provider_webhook_invalid` (already shipped Phase 33). Phase 35
  reuses; no new atoms.
- `lib/rindle/application.ex` (line 15) — `Rindle.PubSub` is the
  application's PubSub server name; Phase 35 PubSub broadcasts target it.
- `lib/rindle/live_view.ex` (lines 209-211) — `topic_for/2` table for
  `:asset` topic shape; Phase 37 will extend with `:provider_asset`
  topic mirroring this pattern (D-31 freezes topic name now).
- `lib/rindle/ops/runtime_status.ex` — the v1.5 module Phase 35 extends
  (D-39, D-40). Phase 35 adds `provider_assets_report/2` modeled on
  `variant_report/3`.
- `lib/mix/tasks/rindle.runtime_status.ex` — the v1.5 Mix task Phase 35
  extends (D-41). Adds `--provider-stuck` flag and text formatter.
- `test/support/mocks.ex` — Phase 34 Mox patterns; Phase 35 adds NO new
  mocks (D-38).
- `test/rindle/streaming/provider/mux/mux_test.exs:174-181` — the
  handrolled HMAC Phase 35 replaces with the SDK helper (D-34).
- `deps/mux/lib/mux/webhooks.ex` — SDK signature verifier (Phase 35
  Plug delegates to `Mux.Webhooks.verify_header/4` via the provider).
- `deps/mux/lib/mux/webhooks/test_utils.ex` — SDK test signing helper
  (Phase 35 wraps in `Rindle.Test.MuxWebhookFixtures`).

### Mux SDK references (verified 2026-05-06)
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/webhooks.ex` —
  `verify_header/4` single-secret + multi-`v1=` parsing; constant-time
  compare via `secure_equals?/2`
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/webhooks/test_utils.ex` —
  `generate_signature/2` SDK test helper; HMAC recipe verified at lines 30-43
- `https://github.com/muxinc/mux-elixir/blob/master/README.md` — Phoenix
  raw-body cache pattern reference

### Mux REST API references
- `https://www.mux.com/docs/core/listen-for-webhooks` — webhook delivery
  contract (5s timeout, 24h retry, 2xx required, out-of-order possible)
- `https://www.mux.com/docs/webhook-reference` — event catalog (D-27, D-28)
- `https://www.mux.com/docs/core/verify-webhook-signatures` — `t=...,v1=...`
  header format, signed_payload shape (`"#{ts}.#{raw_body}"`)
- `https://mux-webhook-payload-explorer.onrender.com/` — fixture payload
  reference for D-36

### Plug / Phoenix references
- `https://hexdocs.pm/plug/Plug.Parsers.html` — `body_reader:` MFA option
  (D-06, D-07)
- `https://hexdocs.pm/plug/Plug.Conn.html#read_body/2` — chunked read
  semantics, `{:more, ...}` handling (D-07)
- `https://github.com/elixir-plug/plug/blob/main/lib/plug/parsers/json.ex` —
  proves `Plug.Parsers.JSON.decode/3` does NOT loop on `{:more, ...}` (D-07)
- `https://github.com/elixir-plug/plug/issues/691` — canonical Phoenix
  raw-body discussion

### Stripe peer-library precedent
- `https://github.com/beam-community/stripity_stripe/blob/master/lib/stripe/webhook_plug.ex` —
  Stripe.WebhookPlug, the canonical Elixir-ecosystem mountable webhook
  Plug. Phase 35 Plug shape mirrors with deliberate Mux-specific
  divergences: `405` for non-POST (Stripe: 400); secret resolver supports
  `{:application, ...}` (Stripe: list / `{m,f,a}` / fn); `503` for Oban
  enqueue failure (Stripe doesn't have Oban-equivalent layer).
- `https://docs.stripe.com/webhooks/signatures` — Stripe-Signature
  header format precedent for Mux-Signature
- `https://www.pedroalonso.net/blog/stripe-webhooks-solving-race-conditions/` —
  race-condition handling precedent (D-21 snooze pattern)
- `https://hookdeck.com/webhooks/platforms/guide-to-stripe-webhooks-features-and-best-practices` —
  webhook ingest reliability patterns

### Plaid peer-library precedent
- `https://hexdocs.pm/elixir_plaid/webhooks.html` — `CacheBodyReader`
  pattern (Plaid Elixir uses identical `conn.assigns[:raw_body]` shape
  Phase 35 D-06 locks)

### Oban references (verified 2026-05-06)
- `https://hexdocs.pm/oban/Oban.Worker.html#c:timeout/1` — `timeout/1`
  signature returns ms only (D-18)
- `https://hexdocs.pm/oban/Oban.Worker.html#unique` — unique job options
  (D-20)
- `https://hexdocs.pm/oban/Oban.Worker.html#snooze` — `{:snooze, seconds}`
  return semantics (D-21)
- `https://hexdocs.pm/oban/Oban.Job.html` — `oban_jobs.args` jsonb
  storage (D-19 size-bound)
- `https://hexdocs.pm/oban/Oban.Testing.html` — `Oban.Testing.assert_enqueued/1`
  for Plug enqueue assertions

### Phoenix.PubSub references
- `https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html` — broadcast
  semantics (no-subscriber broadcasts are zero-cost, justifying Phase 37
  topic-name freeze in Phase 35)

### Prior milestone references (read-only, supports decisions)
- `.planning/milestones/v1.5-phases/29-package-consumer-proof/29-CONTEXT.md` —
  adopter-owned Oban supervision posture Phase 35 honors
- `.planning/milestones/v1.4-phases/26-delivery-telemetry/26-CONTEXT.md` —
  v1.4-frozen `[:rindle, :delivery, :streaming, :resolved]` event;
  Phase 35 telemetry is additive only

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/rindle/delivery/local_plug.ex` — **direct template for `WebhookPlug`**:
  `@behaviour Plug`, `init/1` opts validation (line 30-45), `init/1` raise
  on misconfiguration (line 35), `call/2` with `with` chain (line 47-61),
  `forbidden/1` / `not_found/1` plain-text response helpers (lines 237-247)
  with `halt()` — Phase 35 `send_400/1`, `send_500/1` mirror exactly.
- `lib/rindle/streaming/provider/mux.ex` (lines 272-296) — **`verify_webhook/3`
  already shipped**: multi-secret loop, tolerance from config, two-step
  pipeline (verify_header → Jason.decode → Event.normalize). Phase 35 calls
  this verbatim from the Plug.
- `lib/rindle/streaming/provider/mux/event.ex` — **`normalize/1` already
  shipped**: returns `provider_event` with `type/provider_asset_id/playback_ids/state/occurred_at/raw`.
  Phase 35 adds the `video.upload.asset_created` typed branch (D-29).
- `lib/rindle/workers/process_variant.ex` (lines 465-500) — **direct
  template for PubSub broadcast pattern**: `pubsub_server/0` helper
  (line 498), two-topic broadcast (line 478), `{:rindle_event, event_type,
  payload}` tuple shape. Phase 35 `IngestProviderWebhook.broadcast/2`
  mirrors verbatim.
- `lib/rindle/workers/mux_ingest_variant.ex` — **direct template for
  worker shape**: `use Oban.Worker, queue: :rindle_provider, max_attempts: 5`,
  `c:timeout/1`, `unique_job_opts/0` (lines 212-219), `Config.repo()`
  pattern (line 97), `redact_id/1` telemetry usage (line 464). Phase 35
  worker reuses queue, retry budget, and Config.repo() pattern.
- `lib/rindle/domain/provider_asset_fsm.ex` (lines 9-16) — **the FSM
  allowlist Phase 35 worker respects**: includes the `errored → processing`
  re-ingest edge so `video.asset.ready` after `video.asset.errored` works
  (Mux can re-ready a previously-errored asset post-reprocessing).
- `lib/rindle/domain/media_provider_asset.ex` — **`redact_id/1` helper**
  is THE source of truth for security invariant 14. Phase 35 worker
  telemetry, runtime_status samples, and any `provider_asset_id`-bearing
  output route through this.
- `lib/rindle/ops/runtime_status.ex` — **the report shape Phase 35
  extends**: `findings` schema (`class`, `count`, `oldest_age_seconds`,
  `samples`), `recommendations` shape (`class`, `action`, `surface`,
  `summary`), `summarize_findings/2` helper. Phase 35
  `provider_assets_report/2` mirrors `variant_report/3` exactly.
- `lib/mix/tasks/rindle.runtime_status.ex` — **the Mix task wrapper
  Phase 35 extends**: `OptionParser` strict opts (line 30-31),
  `format_findings/1` text helper (lines 92-101), `format_text_report/1`
  composition (lines 56-74). Phase 35 adds `provider_stuck: :boolean`
  and `format_provider_findings/1`.

### Established Patterns
- **Adopter-owned Phoenix integration:** Rindle ships mountable Plugs
  + documented snippets; the adopter wires `Plug.Parsers` and `forward`
  declarations in their `endpoint.ex` and `router.ex`. No Rindle-side
  endpoint or router. Phase 35 follows verbatim.
- **Adopter-owned Oban supervision:** Rindle ships worker modules with
  `@moduledoc`-documented queue config; the adopter wires queue + cron
  config in their app. Phase 35 worker `IngestProviderWebhook` follows
  this; no Rindle-side Oban supervisor.
- **Single trust boundary at the edge:** verify-and-enqueue at the Plug;
  worker trusts upstream verification. Mirrors the Phase 34 server-push
  ingest posture where `MuxIngestVariant` trusts that the source variant
  is `:ready` (the caller verified before enqueueing).
- **FSM-validate-then-changeset-update:** every state transition on
  `media_provider_assets` goes through `ProviderAssetFSM.transition/3`
  (pure validator) followed by `MediaProviderAsset.changeset/2 |>
  Repo.update/1`. No `SELECT ... FOR UPDATE`; Postgres MVCC + FSM
  allowlist provides correctness.
- **Two-topic PubSub broadcast** for adopter ergonomics: per-resource
  topic + per-parent topic, so consumers subscribed at either level
  pick up events without explicit cross-subscription.
- **Telemetry contract is a public API:** every event family has
  documented measurements + metadata; new events are additive only.
  Plug emits `:verified | :rejected | :secret_used`; worker emits
  `:processed | :ignored | :exception` — distinct namespaces for
  distinct lifecycle stages.
- **Security invariant 14 (provider_asset_id redaction)** is enforced
  at THREE Phase 35 layers: worker telemetry (D-26), PubSub payload
  (D-32), runtime_status sample (D-40). Never broadcast raw provider
  ids.
- **Capability vocabulary is closed:** no new capabilities Phase 35;
  `:webhook_ingest` was Phase 33; `:server_push_ingest` was Phase 34.

### Integration Points
- `Plug.Parsers` (in adopter `endpoint.ex`) — invokes
  `WebhookBodyReader.read_body/2` MFA, populates `conn.assigns[:raw_body]`,
  decodes JSON downstream.
- `WebhookPlug` (mounted in adopter `router.ex`) — reads
  `conn.assigns[:raw_body]` via `WebhookBodyReader.raw_body/1`, calls
  `provider.verify_webhook/3`, enqueues `IngestProviderWebhook`,
  responds.
- `Rindle.Streaming.Provider.Mux.verify_webhook/3` — already shipped
  Phase 34; Phase 35 calls verbatim from the Plug.
- `Rindle.Streaming.Provider.Mux.dispatch_kind/1` — NEW Phase 35
  helper; returns `:dispatch | :drop` for the Plug to decide whether
  to enqueue.
- `IngestProviderWebhook` worker — enqueued by `WebhookPlug` only.
  `Oban.insert/1` from the Plug context (no DB transaction wrapping,
  so this is fine — single statement INSERT).
- `Rindle.Domain.ProviderAssetFSM.transition/3` — called by
  `IngestProviderWebhook.transition_and_broadcast/3`.
- `Rindle.Domain.MediaProviderAsset.changeset/2` (and `redact_id/1`) —
  called by `IngestProviderWebhook` for state mutations and telemetry
  metadata respectively.
- `Phoenix.PubSub` (`Rindle.PubSub` server) — `IngestProviderWebhook`
  broadcasts `{:rindle_event, :provider_asset_*, payload}` on two
  topics per event.
- `Rindle.runtime_status/1` — `IngestProviderWebhook`-driven row
  staleness surfaces here via the new `:provider_stuck` filter and
  `provider_assets` report section.

### Operational Boundaries Phase 35 Must Not Cross
- **No `Rindle.Profile.Presets.MuxWeb`, no doctor streaming smoke, no
  `guides/streaming_providers.md`.** All Phase 36.
- **No `create_direct_upload/2` impl.** Phase 37.
- **No `:provider_asset_created` PubSub broadcast.** Reserved for
  Phase 37 / MUX-23.
- **No changes to `Rindle.Processor.AV` or the FFmpeg-driven progressive
  path.** Mux is additive; Branch 6 of Phase 33's dispatch tree
  (progressive fallback) is unchanged.
- **No changes to `media_assets` or `media_variants` schema.** Phase 35
  reads `media_provider_assets`; never touches the parent tables.
- **No changes to the Phase 33 `Rindle.Streaming.Provider` behaviour
  callbacks.** Only the `@type provider_event` typespec gains an
  optional `upload_id` field (D-30) — additive only, no callback shape
  change.
- **No new public modules outside `Rindle.Delivery.WebhookPlug`,
  `Rindle.Delivery.WebhookBodyReader`, `Rindle.Workers.IngestProviderWebhook`.**
  `Rindle.Test.MuxWebhookFixtures` is `@moduledoc false` test-only.
  `Rindle.Streaming.Provider.Mux.dispatch_kind/1` is `@moduledoc false`
  internal helper.
- **No new env vars.** Phase 35 reuses Phase 34's `RINDLE_MUX_WEBHOOK_SECRETS`
  and `:webhook_tolerance_seconds` config block.
- **No raw-body persistence.** The body lives in `conn.assigns[:raw_body]`
  for the request lifetime only; never persisted to disk, never written
  to Oban args, never logged.
- **No `Repo.transaction` wrapping in the worker.** Single-statement
  Repo.update; Postgres atomicity covers it.
- **No `SELECT ... FOR UPDATE` on `media_provider_assets`.** FSM
  allowlist + MVCC provides correctness.

</code_context>

<deferred>
## Deferred Ideas

- **`:provider_asset_created` PubSub broadcast** for `video.asset.created`
  events — Phase 37 / MUX-23 owns this when LiveView subscribe vocabulary
  extends. Phase 35 dispatches the FSM transition (`:uploading →
  :processing`) and bumps `last_event_at`, but does NOT broadcast.
- **`Rindle.LiveView.subscribe(:provider_asset, id)` extension** — Phase 37
  / MUX-23. Adds the topic-for table entry mirroring `live_view.ex:209-211`.
- **`Rindle.Streaming.Provider.Mux.create_direct_upload/2` implementation** —
  Phase 37. Behaviour callback exists Phase 33 with `@optional_callbacks`;
  Phase 37 implements; Phase 35 adds the `video.upload.asset_created`
  Event typed branch as forward-compat (D-29).
- **`mix rindle.doctor` streaming validation** (per-profile streaming PASS/FAIL,
  smoke ping to `Mux.Video.Assets.list/1`) — Phase 36 / MUX-16.
- **`Rindle.Profile.Presets.MuxWeb` and adopter onboarding guide** —
  Phase 36 / MUX-15, MUX-17, MUX-19.
- **Generated-app `mux-enabled` package-consumer proof lane** — Phase 36
  / MUX-18. Cassette-by-default; soak lane behind `MUX_TOKEN_ID` secret.
- **Webhook event replay tooling (`mix rindle.webhook.replay`)** — v1.7+
  per memo §13. Durable `media_provider_assets` row + Phase 35
  `last_event_id`/`last_event_at` is the primary recovery surface in v1.6.
- **Configurable telemetry redaction** — v1.7+ per memo §13. v1.6
  hardcodes last-4-char `provider_asset_id` redaction in metadata,
  PubSub payloads, and runtime_status output.
- **`cancel_provider_ingest/1` cancellation surface** — v1.7+ per memo
  §13. Oban's `cancel_jobs/1` covers most of the need in v1.6.
- **Map-keyed error variants** (e.g., `{:provider_webhook_invalid,
  %{provider, secret_index, sdk_reason}}`) — v1.7+ if real adopter
  feedback proves a need. Phase 33 shipped bare-atom forms; Phase 35
  surfaces SDK reason via provider-internal telemetry instead (D-17).
- **DASH support (`kind: :dash`)** — explicitly deferred to v1.7+ per
  memo §4.
- **Configurable webhook body-size limit** — Phase 35 hardcodes 1 MiB
  in `WebhookBodyReader` (D-08; 100× headroom over real Mux payloads).
  v1.7+ may surface as config if real adopter need warrants.
- **Path-dispatching mega-Plug for multi-provider mounts** — Phase 35
  locks one-`forward`-per-provider (D-01; Stripe parity). v1.7+ may
  revisit if 3+ providers ship and adopters complain about config
  verbosity, but the explicit-mount posture is the locked default.
- **Caching `Application.get_env` reads in `WebhookPlug.call/2`** —
  Phase 35 reads on every webhook (D-42 inheritance from Phase 34 D-30).
  Negligible overhead; revisit only if profiling shows it materializing
  in flame graphs.
- **Eager `playback_ids` persistence on `:created` events** — Phase 35
  default is single-source-of-truth (only `:ready` populates
  `playback_ids`). Phase 37 may revisit if LiveView "ingest in
  progress" UI needs eager display.
- **Pending-event sidecar table** for race window where webhook arrives
  before `MuxIngestVariant` commits — rejected for Phase 35 (D-21
  snooze is the locked posture). Reconsider only if Mux's webhook
  delivery latency materially degrades vs `MuxIngestVariant` REST
  call latency.
- **Re-verify signature in worker** for defense-in-depth — rejected
  for Phase 35 (D-19 trust boundary at the Plug). Reconsider if a
  multi-process deployment makes the trust boundary fuzzy.
- **Worker reads `Mux.Video.Assets.get/2` on `:ready` to backfill
  missing fields** — rejected (would defeat D-38 zero-Mox posture,
  add latency, race with deletion). Mux's `:ready` payload is rich
  enough.

</deferred>

---

*Phase: 35-signed-webhook-plug-idempotent-ingest*
*Context gathered: 2026-05-06*
*Source of truth: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` + this CONTEXT.md (the latter supersedes at the documented additions D-29 upload typed branch, D-30 typespec extension, D-21 race-snooze posture, D-26 worker telemetry namespace).*
