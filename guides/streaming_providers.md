# Streaming Providers

Rindle ships a single optional streaming provider for v1.6: **Mux**. This
guide walks you through enabling signed HLS streaming end-to-end —
dependencies, signing-key creation, profile configuration, webhook plug
wiring, scheduled sync, local development, secret rotation, the
`mix rindle.doctor --streaming` smoke check, an operator runbook for
stuck assets, and a performance footgun note.

> Adopters who only need progressive AV download stay on
> `Rindle.Profile.Presets.Web` — streaming is opt-in. The runtime cost
> of `:mux` and `:jose` is zero unless you opt a profile in.

This guide covers:

- Why a streaming provider, and when not to opt in
- Adding `:mux` and `:jose` as optional deps
- Creating your Mux signing key out-of-band
- Configuring a profile via `Rindle.Profile.Presets.MuxWeb`
- Configuring browser direct upload via `Rindle.Profile.Presets.MuxDirectUploadWeb`
- Wiring the webhook plug end-to-end
- Scheduling the sync coordinator cron worker
- Local development with a webhook tunnel
- Webhook secret rotation workflow
- Running `mix rindle.doctor --streaming` smoke checks
- Operator runbook for stuck provider assets
- A performance note on high-throughput JWT signing

For the canonical AV-progressive-download path that does NOT require a
streaming provider, see [Secure Delivery](secure_delivery.md).

## 1. Why a Streaming Provider?

Rindle's default delivery is **progressive download via signed storage URL**:
adopters call `Rindle.url/3`, the storage adapter signs a time-limited URL,
and the browser plays an MP4 directly off S3 / R2 / GCS. This works well
for short clips, posters, and "click to play" flows.

When a profile opts into a streaming provider — by setting
`delivery: [streaming: %{provider: ...}]` (or via `Rindle.Profile.Presets.MuxWeb`,
which sets it for you) — the same `Rindle.Delivery.streaming_url/3` call
resolves the playback URL via the provider instead of via signed storage.
For Mux, that means signed HLS playback URLs with adaptive bitrate, captions,
and global delivery; the source media still lives in your storage adapter
(Phase 33's "your bucket, our streaming" posture).

## 2. Add Mux to Your Dependencies

```elixir
# mix.exs
defp deps do
  [
    # ... your existing deps ...
    {:rindle, "~> 0.1"},
    {:mux, "~> 3.2", optional: true},
    {:jose, "~> 1.11", optional: true}
  ]
end
```

Both deps are `optional: true` so adopters who never opt a profile into
streaming pay zero transitive runtime cost.

Configure the runtime block (matches the Phase 34 D-29 layout exactly):

```elixir
# config/runtime.exs
config :rindle, Rindle.Streaming.Provider.Mux,
  token_id: System.get_env("RINDLE_MUX_TOKEN_ID"),
  token_secret: System.get_env("RINDLE_MUX_TOKEN_SECRET"),
  signing_key_id: System.get_env("RINDLE_MUX_SIGNING_KEY_ID"),
  signing_private_key: System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY"),
  webhook_secrets:
    System.get_env("RINDLE_MUX_WEBHOOK_SECRETS", "")
    |> String.split(",", trim: true)
```

Five environment variables; all required when `MuxWeb` is wired into a
profile. Configuration is read at the call site, not cached, so runtime
rotation works without a release restart.

## 3. Create Your Mux Signing Key

Signing keys are an out-of-band operation in Mux's dashboard. Rindle
never auto-creates them — the adopter owns key custody.

1. Sign in to your Mux dashboard.
2. Navigate to **Settings → Signing Keys → Create Signing Key**.
3. Mux returns the key id (public) and an RSA private key (PEM-encoded).
4. **Download the private key once** — Mux does not let you re-download
   it. If you lose it, you must rotate.
5. Store the private key in your secrets manager. Rindle reads it from
   `RINDLE_MUX_SIGNING_PRIVATE_KEY` at runtime.

The signing key id is non-sensitive and can live in non-secret config; the
private key is secret-grade and MUST live in your secrets manager (AWS
Secrets Manager, GCP Secret Manager, HashiCorp Vault, Fly secrets, etc.).

## 4. Configure Your Profile with `MuxWeb`

`Rindle.Profile.Presets.MuxWeb` is the streaming-on twin of
`Rindle.Profile.Presets.Web`. It inherits the canonical `web_720p` + `poster`
variants and locks the `delivery.streaming` block to Mux:

```elixir
defmodule MyApp.Streaming do
  use Rindle.Profile.Presets.MuxWeb,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 524_288_000
end
```

`MuxWeb` is a thin wrapper — same opts as `Web` (`:storage`, `:allow_mime`,
`:max_bytes`), same variant set (`web_720p` + `poster`), plus a locked
`:delivery` block:

```elixir
delivery: [
  streaming: %{
    provider: Rindle.Streaming.Provider.Mux,
    playback_policy: :signed,
    ingest_mode: :server_push,
    source_variant: :web_720p
  }
]
```

There is no `:scrub_strip` opt-in for `MuxWeb` — streaming-enabled profiles
are signed-playback by definition. Mux requires the source MP4 to be
publicly fetchable for server-push ingest; Rindle generates a one-time
signed source URL via `Rindle.Delivery.streaming_url/3` source-variant
resolution and hands it to Mux's create-asset call.

## 4.1 Browser Direct Upload to Mux

Phase 45 adds the sibling preset `Rindle.Profile.Presets.MuxDirectUploadWeb`.
It keeps the same Mux signed-playback posture but locks
`ingest_mode: :direct_creator_upload` instead of `:server_push`.

```elixir
defmodule MyApp.DirectStreaming do
  use Rindle.Profile.Presets.MuxDirectUploadWeb,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 524_288_000
end
```

Controller/JSON is the baseline integration:

```elixir
def create(conn, %{"filename" => filename}) do
  {:ok, %{upload_url: upload_url, asset_id: asset_id}} =
    Rindle.Streaming.create_direct_upload(MyApp.DirectStreaming,
      filename: filename,
      cors_origin: "#{conn.scheme}://#{conn.host}"
    )

  json(conn, %{endpoint: upload_url, asset_id: asset_id})
end
```

The browser must receive only the one-time `endpoint` and the durable
Rindle `asset_id`. Never surface raw Mux ids in your JSON or templates.
Each upload needs a fresh URL; do not reuse one after a failed or completed
attempt.

`Rindle.LiveView.allow_direct_upload/4` is the convenience wrapper over the
same contract. It configures a LiveView `:external` upload and returns
browser-safe metadata for an UpChunk-style client.

Visible state copy is locked:

- `Requesting upload URL...`
- `Uploading to Mux...`
- `Upload received. Linking provider asset...`
- `Asset linked. Preparing playback...`

Provider readiness is webhook-driven. A successful browser PUT does not mean
the asset is playable yet; subscribe to `:provider_asset` / `:asset` PubSub
events or poll the same state model until `:provider_asset_ready` arrives.

## 5. Wire the Webhook Plug

Mux notifies Rindle of asset readiness via signed webhook deliveries. The
mountable `Rindle.Delivery.WebhookPlug` verifies HMAC signatures and
enqueues an Oban worker for asynchronous processing.

<!-- source: lib/rindle/delivery/webhook_plug.ex @moduledoc — keep in sync -->

Step 1 — install the body reader globally in `endpoint.ex` (BEFORE `Plug.Parsers`):

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  body_reader: {Rindle.Delivery.WebhookBodyReader, :read_body, []},
  json_decoder: Jason
```

Step 2 — mount the Plug in `router.ex`, one `forward` per provider:

```elixir
forward "/webhooks/rindle/mux", Rindle.Delivery.WebhookPlug,
  provider: Rindle.Streaming.Provider.Mux,
  secrets: {:application, :rindle, [Rindle.Streaming.Provider.Mux, :webhook_secrets]}
```

Step 3 — set `RINDLE_MUX_WEBHOOK_SECRETS` (comma-separated) in your runtime
config, and configure your Mux dashboard webhook to POST to
`https://yourapp.example.com/webhooks/rindle/mux`.

<!-- /source -->

The Plug returns:

| Status | Body | When |
|--------|------|------|
| 202 Accepted | empty | Verified + enqueued. |
| 200 OK | empty | Verified but dropped (event not in adapter dispatch table). |
| 400 Bad Request | `provider_webhook_invalid` | Signature mismatch, replay-window failure, missing secrets, callback raised. |
| 405 Method Not Allowed | `method not allowed` | Non-POST request. |
| 500 Internal Server Error | `server_misconfigured` | Body reader assign missing AND fallback empty. |
| 503 Service Unavailable | empty | Oban enqueue raised (transient downstream failure — Mux retries). |

## 6. Schedule the Sync Coordinator

Webhooks can be lost or delayed; Rindle ships a per-row reconciliation
coordinator as a backstop. Schedule the coordinator from your Oban cron
config; you do not need Rindle to supervise Oban.

<!-- source: lib/rindle/workers/mux_sync_coordinator.ex @moduledoc — keep in sync -->

```elixir
config :my_app, Oban,
  queues: [rindle_provider: 4],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", Rindle.Workers.MuxSyncCoordinator}
     ]}
  ]
```

Cron resolution is 1 minute. The coordinator's internal query enforces a
`provider_polling_floor_seconds: 30` floor so rows that were just touched
by a webhook are not redundantly polled.

<!-- /source -->

The coordinator fans out per-row sync jobs only for `media_provider_assets`
rows in (`processing`, `uploading`) state older than the floor. Per-row
unique constraint dedupes within the 60s window so back-to-back cron ticks
don't double-fan-out the same row.

## 7. Local Development with a Webhook Tunnel

To exercise the full webhook path locally, expose `localhost:4000` to
the public internet.

```bash
cloudflared tunnel --url http://localhost:4000
```

Cloudflare's TryCloudflare quick tunnel is signup-free and adequate for
Mux webhook volume. See
[TryCloudflare docs](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/).
ngrok is a popular alternative; note that as of 2026 it requires account
signup before a tunnel will start (see
[ngrok pricing](https://ngrok.com/pricing)). Update your Mux dashboard
webhook URL to the tunnel-issued hostname while testing.

## 8. Webhook Secret Rotation Workflow

`RINDLE_MUX_WEBHOOK_SECRETS` is comma-separated for exactly this reason —
multiple secrets verify in parallel during rotation.

1. **Add** the new secret to the front of the comma-separated list:
   `RINDLE_MUX_WEBHOOK_SECRETS=whsec_NEW,whsec_OLD`.
2. Rotate the corresponding secret in your Mux dashboard.
3. **Watch telemetry.** Every verified webhook emits the
   `[:rindle, :provider, :webhook, :verified]` event with metadata
   `%{provider, event_type, event_id, kind}`; the provider-internal
   `[:rindle, :provider, :mux, :webhook_attempt, :secret_used]` event
   carries `secret_index` (0-based offset into the secrets list). Subscribe
   to confirm new secrets are in active use before retiring the old one.
4. **Wait 24 hours** as a grace window for in-flight retries from Mux.
5. **Retire** the old secret by removing it from the list:
   `RINDLE_MUX_WEBHOOK_SECRETS=whsec_NEW`.

The grace window is a recommendation, not a contract — if you have
high webhook volume and observable telemetry, you can shorten it to
match your actual retry tail (Mux retries up to 24h with exponential
backoff for 5xx responses).

## 9. Run `mix rindle.doctor --streaming`

The doctor task includes four streaming-aware checks. Without
`--streaming`, the smoke-ping check skips (offline-friendly default).
With `--streaming`, the doctor performs a 5-second smoke ping against
`api.mux.com`.

```bash
mix rindle.doctor --streaming
```

Expected PASS output:

```
[ok] doctor.streaming_credentials: All five RINDLE_MUX_* credentials are set.
[ok] doctor.streaming_signing_key: RINDLE_MUX_SIGNING_PRIVATE_KEY parses as a valid JOSE JWK.
[ok] doctor.streaming_webhook_secrets: RINDLE_MUX_WEBHOOK_SECRETS has 1 secret(s), all ≥ 32 chars.
[ok] doctor.streaming_smoke_ping: Mux.Video.Assets.list/1 returned 200 (smoke ping OK).
```

Failure-mode taxonomy for `doctor.streaming_smoke_ping`:

| Result | Fix |
|--------|-----|
| HTTP 200 | OK — no action needed. |
| HTTP 401 / 403 | Verify `RINDLE_MUX_TOKEN_ID` and `RINDLE_MUX_TOKEN_SECRET` in your runtime config. |
| HTTP 429 | Mux rate-limited the smoke ping; retry in a few seconds. |
| Timeout / connection error | Could not reach `api.mux.com` within 5s; check network / proxy / DNS. |
| Other 4xx / 5xx | Fix references the response status; consult Mux status page. |

If no profile in the application opts into streaming, all four checks
return `ok` with summary `"No streaming-enabled profiles discovered."` —
mirrors the vacuous-OK posture of `doctor.local_playback`.

## 10. Operator Runbook: Stuck Assets

Mux occasionally drops a webhook; the sync coordinator reconciles. When
neither the webhook nor the cron has cleared a row within the configured
threshold (`provider_stuck_threshold_seconds: 7200` default, 2 hours),
the row is considered stuck.

Inspect stuck assets:

```bash
mix rindle.runtime_status --provider-stuck
```

The report enumerates `media_provider_assets` rows in (`processing`,
`uploading`) state older than the threshold, with `provider_asset_id`
redacted to last-4 chars per security invariant 14. From there you can
manually re-fetch from Mux or cancel.

To cancel stuck `IngestProviderWebhook` jobs in Oban:

```elixir
# In an IEx console:
Oban.cancel_jobs(Rindle.Workers.IngestProviderWebhook)
```

A higher-level `Rindle.cancel_provider_ingest/1` API is planned for v0.3+;
until then, use Oban's job-cancellation surface directly.

## 11. Performance Note: High-Throughput JWT Signing

For adopters above ~1,000 playback URLs/sec, `JOSE.JWK.from_pem/1` becomes
a hot path because Rindle re-parses the PEM on every signed-URL call. The
recommended optimization is a `:persistent_term` cache keyed by signing
key id; an in-library cache ships in v0.3+. Until then, you can patch the
cache yourself by wrapping `Rindle.Streaming.Provider.Mux.sign_playback_id/2`
in your application.

For most adopters (<100 playback URLs/sec) this is below the noise floor
and no action is needed.

## Quick Reference

Telemetry events you can subscribe to from your application:

| Event | Payload | When |
|-------|---------|------|
| `[:rindle, :provider, :webhook, :verified]` | `%{provider, event_type, event_id, kind}` (`kind: :enqueued | :dropped`) | Successful HMAC verification. |
| `[:rindle, :provider, :webhook, :rejected]` | `%{provider, reason}` (`reason: :sig_mismatch | :no_secrets_configured | :body_reader_missing | :provider_callback_raised | :method_not_allowed | :oban_unavailable`) | Verification or pre-verify check failed. |
| `[:rindle, :provider, :mux, :webhook_attempt, :secret_used]` | `%{secret_index}` | HMAC verification succeeded for the given secret offset. |
| `[:rindle, :provider, :mux, :webhook_attempt, :rejected]` | `%{secret_index, sdk_reason}` | HMAC verification failed for the given secret offset. |

Configuration reference:

| Goal | Configuration |
|------|---------------|
| Enable Mux streaming on a profile | `use Rindle.Profile.Presets.MuxWeb, storage: ..., allow_mime: [...], max_bytes: ...` |
| Multi-secret rotation | `RINDLE_MUX_WEBHOOK_SECRETS=whsec_NEW,whsec_OLD` |
| Adjust polling floor | `config :rindle, Rindle.Streaming.Provider.Mux, provider_polling_floor_seconds: 30` |
| Adjust stuck threshold | `config :rindle, Rindle.Streaming.Provider.Mux, provider_stuck_threshold_seconds: 7200` |
| Local webhook tunnel | `cloudflared tunnel --url http://localhost:4000` |
| Smoke check before deploy | `mix rindle.doctor --streaming` |
