# Browser → Mux Direct Creator Upload (MUX-20..23) — Locked Recommendation

**Date:** 2026-05-22
**Author:** deep technical research pass for v1.8 candidate slicing
**Verified against:** shipped v1.6 Mux provider source (read in full), `mux 3.2.2`
SDK source in `deps/`, live Mux Direct Uploads docs (2026-05).
**Confidence:** HIGH on scope, code-fit, and security posture (the hard parts
already shipped in v1.6). MEDIUM only on the "ship it standalone vs. bundle with
tus" sequencing call — resolved below.

---

## 0. TL;DR (the locked verdict)

**Do it. Ship MUX-20..23 in v1.8 — but as a small additive slice bundled into
the tus milestone, not as a milestone of its own.** It is genuinely ~1–1.5 days
of net-new code on top of primitives v1.6 already shipped, it is LOW risk, and
it is disproportionately high-DX-value for the AV/streaming wedge Rindle is
betting on. The reserved callback, the FSM edges, the `video.upload.asset_created`
webhook branch, the PubSub topics, the capability atom, and the redaction
machinery are **all already in the tree** waiting for exactly this. The PROJECT.md
"~1 day, LOW risk" estimate is essentially correct; my code audit pushes it to
~1.5 days only because of one genuinely new concern (the LiveView `:external`
uploader wiring + UpChunk DX surface) that the v1.6 memo under-weighted.

It should **not** be its own milestone because a single-callback + one-endpoint
slice is too thin to justify a milestone's planning/audit overhead, and it pairs
naturally with tus: both are "browser does the heavy upload, server brokers a
credential" stories. Bundle it as the last slice of the tus milestone (or
whichever larger core lands next), with a hard "drop it if the milestone runs
long" rule — exactly the discipline v1.6 used to defer it cleanly.

---

## 1. The reserved callback — verified from source

`lib/rindle/streaming/provider.ex` (lines 116–129) reserves the callback
**exactly** as follows. This is the contract MUX-20 must implement; the shape is
already locked, so there is zero behaviour-design work left:

```elixir
@doc """
OPTIONAL: Mint a direct-creator upload URL the browser can PUT to. Reserved
for Phase 37 / v1.7; no v1.6 adapter implements this callback.
"""
@callback create_direct_upload(profile :: module(), opts :: keyword()) ::
            {:ok,
             %{
               upload_url: String.t(),
               upload_id: String.t(),
               provider_asset_id: provider_asset_id() | nil
             }}
            | {:error, term()}

@optional_callbacks [create_direct_upload: 2]
```

Key facts the rest of this memo builds on:

- It is **arity 2** (`create_direct_upload/2`), `(profile, opts)`. NOTE: the v1.6
  candidate memo's prose said `create_direct_upload/2` returning
  `%{upload_url, upload_id, asset_id}`, but the **actual locked key is
  `provider_asset_id`, not `asset_id`** — and it is `| nil` because Mux does not
  know the asset id at upload-create time (the asset is created only when the
  browser finishes the PUT and Mux fires `video.upload.asset_created`). MUX-20
  MUST return `provider_asset_id: nil` at create time. Any plan text saying
  `asset_id` is stale and should be corrected to `provider_asset_id`.
- It is in `@optional_callbacks`, so the v1.6 Mux adapter compiles today without
  it. Adding it is purely additive — no breaking change, no semver concern.
- `upload_url` and `upload_id` are both bearer secrets under invariant 14
  (the one-time signed PUT URL is a capability grant; the upload id is a
  provider-internal identifier). They must be redacted everywhere except the
  single hop where `upload_url` reaches the browser (see §6).

---

## 2. What v1.6 already shipped (this is why the slice is tiny)

I read every relevant module. The direct-upload path converges into machinery
that **already exists and is exercised in CI**:

| Primitive | Status | File | Relevance to direct upload |
|---|---|---|---|
| `create_direct_upload/2` callback + `:direct_creator_upload` capability atom | Reserved | `streaming/provider.ex`, `streaming/capabilities.ex:18-24` | Implement + advertise. |
| `provider_event` `:upload_id` optional key | Shipped | `streaming/provider.ex:57-65` | Carries upload→asset link. |
| `video.upload.asset_created` event normalization (typed branch, D-29) | Shipped | `streaming/provider/mux/event.ex:27-40` | Correctly maps `data.id`=upload id, `data.asset_id`=asset id. **Already avoids the silent-corruption footgun.** |
| `video.upload.asset_created` dispatch (`:dispatch`, not `:drop`) | Shipped | `streaming/provider/mux.ex:359` | Webhook reaches the worker. |
| `video.upload.asset_created` worker handler | Shipped as **no-op stub** | `workers/ingest_provider_webhook.ex:115-124, 265-283` | Currently just bumps `last_event_at`; MUX-21 turns it into the upload→asset linker. **This is the single most material change.** |
| `media_provider_assets` table + FSM | Shipped | `domain/media_provider_asset.ex`, `domain/provider_asset_fsm.ex` | Direct upload creates a `pending` row; FSM already has `pending → uploading → processing → ready`. |
| `ingest_mode: :direct_creator_upload` DSL value | Shipped (validated) | `profile/validator.ex:73-76` | Profile DSL already accepts it. |
| Signed playback after ready | Shipped | `streaming/provider/mux.ex:265-286` | Identical to server-push; no change. |
| `streaming_url/3` `:ready` dispatch | Shipped | `delivery.ex:275-303` | Direct-upload assets resolve identically once ready. |
| `MuxSyncProviderAsset` defensive poll | Shipped | `workers/mux_sync_provider_asset.ex` | Backstop if the webhook is missed. |
| Telemetry redaction (`redact_id/1`), Inspect redaction | Shipped | `domain/media_provider_asset.ex:88-129` | Reuse verbatim for `upload_id`/`upload_url`. |
| PubSub two-topic broadcast | Shipped | `workers/ingest_provider_webhook.ex:355-373` | `:provider_asset_created` topic+event RESERVED for exactly this (D-33). |
| `Mux.Video.Uploads.create/2` in SDK | Shipped (in `deps/mux`) | `deps/mux/lib/mux/video/uploads.ex` | The SDK function MUX-20 calls. |

**The honest read:** v1.6 didn't just "leave room" for this — it pre-wired the
event normalizer, the webhook dispatch table, the FSM edge, the PubSub
vocabulary, and the capability atom *specifically as forward-compat for this
slice* (the source comments literally say "deferred to Phase 37 / MUX-23"). The
only genuinely new code is: one adapter callback, one HTTP-client function, one
upgrade of a no-op worker branch, and one browser-facing endpoint + UpChunk
docs.

---

## 3. Mux Direct Uploads API + SDK — verified

### 3.1 The API (verified against Mux docs, 2026-05)

`POST /video/v1/uploads` creates a direct upload. Request body:

- `cors_origin` (string) — **required for browser use**; the origin the browser
  will PUT from. Must match the page origin or the PUT fails CORS. `"*"` works
  for dev but should be the real origin in prod (§7).
- `new_asset_settings` (object) — the asset config applied when the upload
  completes:
  - `playback_policies`: `["signed"]` or `["public"]` (PLURAL — matches the
    adapter's existing `build_create_params/2` convention).
  - `passthrough`: string ≤255 chars — **the correlation key** (§5).
  - (also `video_quality`, `mp4_support`, `max_resolution_tier`, `meta`, etc.)
- `timeout` (integer) — seconds the signed PUT URL stays valid. Default 3600,
  min 60, max 604800 (7 days).
- `test` (boolean) — marks the asset as a test asset (free, watermarked,
  auto-deleted after 24h). Useful for the soak lane.

Response object: `{ id, url, status, timeout, cors_origin, new_asset_settings,
asset_id? }`. `url` is the one-time signed PUT URL; `id` is the upload id;
`asset_id` is **absent at create time** and only populated later.

Upload `status` lifecycle: `waiting` → `asset_created` (success) | `errored` |
`cancelled` | `timed_out`. The `video.upload.asset_created` webhook fires on the
`waiting → asset_created` transition and carries both the upload id and the new
asset id — this is the reconciliation event.

### 3.2 The SDK (verified from `deps/mux/lib/mux/video/uploads.ex`)

`mux 3.2.2` (current on Hex, 2024-07-02 — same pin already in `mix.exs:68`)
ships `Mux.Video.Uploads`:

```elixir
Mux.Video.Uploads.create(client, params)   # => {:ok, upload, %Tesla.Client{}}
Mux.Video.Uploads.get(client, upload_id)    # => {:ok, upload, %Tesla.Env{}}
Mux.Video.Uploads.cancel(client, upload_id) # => {:ok, %Tesla.Env{}}
Mux.Video.Uploads.list(client, params)      # => {:ok, uploads, %Tesla.Env{}}
```

The SDK function exists and is current. **No dependency change is required** —
`{:mux, "~> 3.2", optional: true}` already covers it.

> SDK quirk worth a code-review note: `Uploads.create/2`'s docstring shows it
> returning `{:ok, upload, %Tesla.Client{}}` (the *client*, not `%Tesla.Env{}`)
> on success, while `get`/`cancel` return `%Tesla.Env{}`. This is harmless for
> the adapter (it only reads the body on success and the env on error), but the
> `Mux.Video.Provider.Mux.HTTP` wrapper should follow the existing pattern of
> dropping the 3rd element on `:ok` and preserving it on `{:error, msg, env}` so
> 429/4xx Retry-After handling matches `create_asset` (mux/http.ex:24-31).

---

## 4. Idiomatic Elixir/Phoenix/Ecto/LiveView shape

### 4.1 Adapter: `create_direct_upload/2` (MUX-20)

Add to `Rindle.Streaming.Provider.Mux`, mirroring `create_asset/3`'s structure
exactly (param-build helper → http_client → normalize errors to the existing
atom set). Param construction lives ONLY in a private helper (same discipline as
`build_create_params/2`):

```elixir
@impl Rindle.Streaming.Provider
def create_direct_upload(profile, opts \\ []) when is_atom(profile) and is_list(opts) do
  policy_atom = Keyword.get(opts, :playback_policy, :signed)
  params = build_upload_params(policy_atom, opts)   # PLURAL keys, cors_origin, passthrough

  case http_client().create_upload(params) do
    {:ok, %{"id" => upload_id, "url" => upload_url}} ->
      {:ok, %{upload_url: upload_url, upload_id: upload_id, provider_asset_id: nil}}

    {:error, _msg, %{status: 429}} -> {:error, :provider_quota_exceeded}
    {:error, _msg, %{status: s}} when s in 400..599 -> {:error, :provider_sync_failed}
    {:error, reason} -> {:error, reason}
  end
end

defp build_upload_params(policy_atom, opts) do
  new_asset_settings =
    %{"playback_policies" => [Atom.to_string(policy_atom)]}
    |> maybe_put("passthrough", Keyword.get(opts, :passthrough))

  %{"new_asset_settings" => new_asset_settings, "cors_origin" => Keyword.fetch!(opts, :cors_origin)}
  |> maybe_put("timeout", Keyword.get(opts, :timeout))
  |> maybe_put("test", Keyword.get(opts, :test))
end
```

And `capabilities/0` adds `:direct_creator_upload`:
```elixir
def capabilities, do: [:signed_playback, :webhook_ingest, :server_push_ingest, :direct_creator_upload]
```

The HTTP wrapper (`mux/http.ex`) gains `create_upload/1` delegating to
`Mux.Video.Uploads.create/2`; the client behaviour (`mux/client.ex`) gains the
matching `@callback create_upload(params) :: ...` so the Mox mock target stays
valid (the behaviour is intentionally NOT optional-dep-guarded — Pitfall 4).

### 4.2 Broker entrypoint — yes, it gets a row, NOT a `MediaUploadSession`

**Decision: direct-creator-upload does NOT reuse `Rindle.Upload.Broker`'s
`MediaUploadSession` lifecycle.** That broker is storage-adapter-shaped
(presigned PUT / multipart / GCS-resumable into the adopter's *own* bucket, then
`verify_completion` → `PromoteAsset` → the normal `media_assets` FSM). A
browser→Mux direct upload bypasses adopter storage entirely — the bytes go
straight to Mux, and the durable record is a `media_provider_assets` row, not a
`MediaUploadSession`. Forcing it through the storage broker would mean inventing
a fake storage key and a verify-completion step that has nothing to verify.

Instead, ship a thin broker-style entrypoint on the **streaming** side. Cleanest
home is a new public function (e.g. `Rindle.Streaming.create_direct_upload/2` or
extending `Rindle.Delivery`), which:

1. Resolves the profile's `streaming` config; requires
   `ingest_mode == :direct_creator_upload` and the adapter to advertise the
   `:direct_creator_upload` capability (capability gate = MUX-22).
2. Creates a `media_provider_assets` row in `"pending"` with
   `ingest_mode: "direct_creator_upload"`, `playback_policy` from the profile,
   `provider_name: "mux"`, and a freshly-generated `media_assets` id (or links
   to an existing staged asset — see §4.4).
3. Calls `adapter.create_direct_upload(profile, cors_origin: ..., passthrough: rindle_correlation_token, playback_policy: ...)`.
4. Persists nothing secret beyond the row; returns ONLY
   `%{upload_url, asset_id}` to the caller where `asset_id` is the **Rindle**
   media asset id (public-side correlation handle) — never the Mux upload id.
   The `upload_url` is passed straight to the browser and not persisted.

> Capability-gate reuse: `Rindle.Streaming.Capabilities.supports?/2` already
> exists (`capabilities.ex:42-43`). MUX-22 is `supports?(adapter,
> :direct_creator_upload)` — no new module needed; the v1.6 memo's proposed
> `require_streaming/2` helper is optional sugar, not required.

### 4.3 How the upload URL reaches the browser — LiveView `:external` uploader

This is the **one genuinely new DX surface** and where the bulk of the 1.5-day
estimate goes (it is more than "0 lines" because `Rindle.LiveView.allow_upload/4`
today is hardwired to the presigned-PUT-to-storage path via
`Broker.sign_url/1`). Two clean options, both idiomatic:

**(a) Controller/JSON endpoint (lowest surprise, recommended as primary):**
The adopter exposes one POST action; UpChunk's `endpoint` option can take a
function that fetches the URL:

```elixir
# adopter controller
def create(conn, %{"filename" => name}) do
  {:ok, %{upload_url: url, asset_id: asset_id}} =
    Rindle.Streaming.create_direct_upload(MyApp.Streaming, cors_origin: origin(conn))
  json(conn, %{endpoint: url, asset_id: asset_id})
end
```
```js
// browser
import * as UpChunk from '@mux/upchunk';
const { endpoint, asset_id } = await fetch('/uploads/mux', {method:'POST', body: ...}).then(r=>r.json());
const upload = UpChunk.createUpload({ endpoint, file, chunkSize: 30720 });
upload.on('success', () => /* asset_id is your handle; LiveView PubSub tells you when ready */);
```

**(b) LiveView `:external` uploader (best DX for LiveView-first adopters):**
Extend `Rindle.LiveView` with `allow_direct_upload/4` that sets `:external` to a
function returning `{:ok, %{uploader: "UpChunk", endpoint: url, asset_id: id}, socket}`.
This mirrors the existing `allow_upload/4` shape (live_view.ex:84-91) but routes
to `create_direct_upload` instead of `Broker.sign_url`, and ships a tiny JS
hook that wires UpChunk to LiveView's external-upload entries metadata. Phoenix
LiveView's external-upload contract is the documented, idiomatic path for exactly
this "browser PUTs to a third party with a server-minted URL" case.

**Recommendation:** ship (a) as the documented baseline (works for any frontend,
zero JS-hook coupling) and (b) as the LiveView convenience. If time is tight,
ship only (a) and document (b) as a recipe — (a) is the load-bearing 80%.

### 4.4 Closing the loop — MUX-21 (the one material worker change)

Today `IngestProviderWebhook` handles `video.upload.asset_created` as a no-op
(`ingest_provider_webhook.ex:265-283`, plus the `nil`-row branch at 115-124 that
emits `:deferred_to_phase_37`). MUX-21 turns it into the linker:

1. On `video.upload.asset_created`, the normalized event carries `upload_id`
   (= `data.id`) and `provider_asset_id` (= `data.asset_id`) — already correct
   per the D-29 typed branch in `event.ex:27-40`.
2. The worker looks up the `media_provider_assets` row. **The lookup key is the
   open question the no-op stub left:** the row was created at upload-create time
   with `provider_asset_id: nil` (Mux didn't know it yet), so the existing
   `get_by(provider_asset_id:)` lookup (line 141) returns `nil`. Two clean
   resolutions:
   - **(preferred) Correlate via `passthrough`.** Set `passthrough` =
     the Rindle `media_provider_assets.id` (or the `media_assets.id`) at
     upload-create time; persist it on the row (add a nullable
     `upload_id` or reuse `last_event_id`/a new `passthrough` column). The
     `video.upload.asset_created` raw payload echoes the asset's `passthrough`,
     so the worker can `get_by(id:)`. This is the canonical Mux correlation
     pattern and is robust to the nil-provider_asset_id window.
   - **(alt) Correlate via `upload_id`.** Persist `upload_id` on the row at
     create time; the `video.upload.asset_created` event carries `data.id` =
     upload id. Look up by `upload_id`, then **stamp `provider_asset_id`** from
     `data.asset_id` and transition `pending|uploading → processing` (or stay
     and let the subsequent `video.asset.ready` flip to ready).
3. After linking, the worker broadcasts `:provider_asset_created` on the two
   PubSub topics (the event name is **already reserved** for this at
   ingest_provider_webhook.ex:65 / D-33) so LiveView clients learn the asset id
   landed. The subsequent `video.asset.ready` flips to `ready` via the
   already-shipped handler (lines 173-191) and broadcasts `:provider_asset_ready`.

**Schema delta (additive):** add one nullable column to `media_provider_assets`
to hold the upload-side correlation handle — recommend `passthrough` (string,
the value Rindle stamps) and/or `upload_id` (string, Mux's id, redacted in
Inspect/telemetry like `provider_asset_id`). One additive migration; no change to
existing columns. Update the custom `Inspect` impl (media_provider_asset.ex:119-129)
to redact the new secret-bearing column.

> Race note: the existing race-snooze machinery (D-21, the `[5,15,45,90]` curve)
> was built for "webhook arrives before the ingest worker's row commit is
> visible." For direct upload the row is committed *before* the browser even
> starts uploading, so the `video.upload.asset_created` webhook will essentially
> always find its row — the race is the *inverse* of server-push and is benign.
> Keep the snooze curve; it costs nothing and covers replica lag.

### 4.5 Capability + DSL (MUX-22)

- `:direct_creator_upload` atom already in `Capabilities.@known` — just have the
  adapter advertise it (§4.1).
- DSL `ingest_mode: :direct_creator_upload` already validates
  (validator.ex:73-76). No DSL change. The capability gate at
  `create_direct_upload` entry rejects profiles whose adapter doesn't advertise
  it with the existing `:streaming_not_configured`/a new tagged atom (prefer
  reusing the existing vocabulary; see §5 error table).

### 4.6 LiveView PubSub (MUX-23)

`Rindle.LiveView.subscribe/2` (live_view.ex:99-102) supports `:variant`,
`:asset`, `:upload_session`. The worker already broadcasts on
`"rindle:asset:#{id}"` AND `"rindle:provider_asset:#{id}"`. MUX-23 adds a
`subscribe(:provider_asset, id)` clause + `topic_for(:provider_asset, id)` so
LiveView adopters can listen on the provider-asset topic specifically. The
`:provider_asset_created | :provider_asset_ready | :provider_asset_errored`
event vocabulary is already broadcast by the worker — MUX-23 is just the
subscribe-side sugar + doc.

---

## 5. DX / least surprise + error vocabulary

**Minimal adopter wiring (the whole story):**
1. Profile uses `ingest_mode: :direct_creator_upload` (or a new
   `Rindle.Profile.Presets.MuxDirectUpload` preset — nice-to-have, mirrors
   `MuxWeb`).
2. One server endpoint (controller action OR `Rindle.LiveView.allow_direct_upload/4`).
3. One UpChunk snippet in the browser.
4. The **same** webhook plug, sync coordinator, signed-playback, and doctor
   config they already set up for server-push. **Zero new infra.**

**Error vocabulary — reuse, do not expand.** The v1.6 five-atom set already
covers everything:
- `:provider_quota_exceeded` — 429 on upload-create.
- `:provider_sync_failed` — other 4xx/5xx on upload-create, or errored row.
- `:provider_asset_not_ready` — `streaming_url/3` while still pending/uploading/
  processing (identical to server-push).
- `:streaming_provider_requires_asset_struct` — unchanged.
- For "profile asks for direct upload but adapter can't" prefer reusing
  `:streaming_not_configured` (the capability gate's natural error) rather than
  minting a new atom — keeps the public vocabulary frozen, matching the v1.4/v1.6
  freeze discipline. If a distinct signal is judged necessary, ONE atom
  (`:direct_upload_unsupported`) — but I recommend against expanding.

**Docs shape:** extend `guides/streaming_providers.md` with a new section
"Browser → Mux direct upload" slotted after §4 (profile config) and before §5
(webhook plug), reusing the existing copy-paste-and-keep-in-sync `<!-- source -->`
anchor convention the guide already uses. It must state plainly: the upload URL
is one-time and secret; never log it; never put it in a template attribute that
gets re-rendered into a cache.

---

## 6. Security — invariant 14 compliance

Invariant 14 (PROJECT.md:256-263, restated in provider.ex:10-16) makes the
one-time upload URL and the upload id **bearer secrets**. The slice complies by
construction because it reuses the v1.6 redaction machinery:

| Concern | Mitigation | Already shipped? |
|---|---|---|
| `upload_url` in logs/telemetry/Inspect | NEVER persisted to the row; flows through exactly one hop (adapter → caller → browser). Telemetry emits redact via `redact_id/1`; the URL is never put in metadata. | Redaction helper shipped; new emit sites must follow it. |
| `upload_id` leakage | Persist on row only if used as correlation key; redact in `Inspect` (extend the existing `defimpl Inspect`) and in all telemetry (`redact_id/1`). | Redaction shipped; extend Inspect for the new column. |
| `provider_asset_id` (post-link) | Already redacted everywhere (v1.6). | Yes. |
| `cors_origin` pinning | `cors_origin` is a **required** param of `create_direct_upload`; default to the request origin, never `"*"` in prod. Doctor/guide must call this out. Mis-set CORS = silent browser PUT failure (Mux issue #17 is exactly this footgun). | New guidance. |
| Signed playback after ready | Identical to server-push: `signed_playback_url/3` with explicit `:expiration` (mux.ex:265-286). | Yes. |
| No raw provider IDs across adopter boundary | Caller receives only the **Rindle** `asset_id` + the transient `upload_url`. The Mux upload id and asset id never cross out. | Enforced by the entrypoint return shape. |
| Untrusted client bytes | Mux owns ingest validation/transcode; Rindle never touches the bytes (invariant 1/2 satisfied — readiness gated on `:ready` state, same as server-push). | Yes. |

**One new security guidance item for the guide/doctor:** the `timeout` on the
upload URL should be short (minutes, not the 7-day max) to bound the bearer-secret
window. Default to ~3600s; document tightening it.

---

## 7. Lessons from peers — DO / AVOID

**Mux's own docs & UpChunk (the canonical pairing):**
- DO use `@mux/upchunk` as the browser client. It chunks (multiples of 256KB),
  PUTs each chunk with `Content-Range`, retries chunks, and emits
  `progress`/`success`/`error` — i.e. it gives resumable-ish reliability for
  free over the one signed PUT URL. This is what every Mux adopter ships.
- DO set `cors_origin` to the real origin. The single most common direct-upload
  failure (Mux python issue #17, countless forum posts) is a CORS error on the
  browser PUT because `cors_origin` didn't match. Default it from the request,
  document it loudly.
- DO use `passthrough` to correlate. Mux explicitly designed `passthrough`
  (≤255 chars, echoed on every asset/upload webhook) as the customer
  correlation key. Use it for the Rindle row id (§4.4). AVOID trying to
  correlate purely on the upload id across the nil-provider_asset_id window.
- AVOID `Mux Uploader` (the `<mux-uploader>` web component) as the *required*
  client. It's great for zero-JS demos, but coupling Rindle's DX to a Mux web
  component is heavier than UpChunk and harder to theme. Mention it as an
  alternative; standardize on UpChunk in docs.
- AVOID parsing the upload status by polling as the primary path. The
  `video.upload.asset_created` webhook is the signal; `Uploads.get/2` polling is
  the backstop (which the existing `MuxSyncProviderAsset` already provides for
  the asset side — extend the coordinator to also reap stale `pending`/
  `uploading` direct-upload rows whose upload likely `timed_out`).

**Cloudflare Stream (contrast oracle):** CF Stream's direct-creator-upload uses
tus, not a single signed PUT. This is why the v1.6 behaviour was designed
provider-agnostic: a future CF adapter would implement the **same**
`create_direct_upload/2` callback but return a tus endpoint. Keep the callback
return shape provider-neutral (`upload_url` is opaque to core) — do NOT leak
"this is a single PUT" assumptions into the contract. (Validates the existing
reserved shape.)

**Active Storage / Shrine:** both learned to keep the "direct upload completed"
signal as a first-class verified state, not an implicit trust of the client.
Rindle already does this — readiness is gated on the `:ready` FSM state driven by
verified webhooks, never on the browser claiming success. Keep it.

---

## 8. Scope: IN vs. DEFERRED

**IN scope (MUX-20..23):**
- MUX-20: `create_direct_upload/2` on the Mux adapter + `create_upload/1` on
  HTTP wrapper + behaviour callback + advertise `:direct_creator_upload`.
- MUX-21: upgrade the `video.upload.asset_created` worker branch from no-op to
  upload→asset linker (passthrough correlation) + additive migration for the
  correlation column + `:provider_asset_created` broadcast + Inspect/telemetry
  redaction of the new column.
- MUX-22: capability gate via existing `Capabilities.supports?/2`; broker-style
  public entrypoint (`Rindle.Streaming.create_direct_upload/2`) that creates the
  `pending` row, stamps passthrough, and returns `%{upload_url, asset_id}`.
- MUX-23: `Rindle.LiveView.subscribe(:provider_asset, id)` + `:external`
  uploader helper (`allow_direct_upload/4`) + UpChunk JS hook + guide section +
  optional `MuxDirectUpload` preset.
- Tests: cassette-driven adapter test for upload-create; webhook fixture test
  for `video.upload.asset_created` linking; end-to-end LiveView/PubSub test
  (create upload → simulate `video.upload.asset_created` + `video.asset.ready` →
  assert both PubSub events) — the v1.6 memo's stated success criterion.

**DEFERRED:**
- Resumable/tus direct upload to providers (CF Stream) — needs a second adapter;
  the callback shape already accommodates it.
- `Uploads.cancel/2` exposure (`cancel_direct_upload/1`) — nice-to-have; Mux
  auto-`timed_out` covers most cases. Defer unless an adopter asks.
- Upload-timeout reaping of stale `pending` direct-upload rows — small follow-up;
  extend `MuxSyncCoordinator`'s query. Could ride in MUX-21 if cheap.
- `<mux-uploader>` web-component recipe — docs-only, post-ship.

---

## 9. Effort estimate — validated against code

| Item | Effort | Risk | Why |
|---|---|---|---|
| MUX-20 adapter callback + HTTP wrapper + behaviour `@callback` impl + capability | 0.25d | LOW | Pure mirror of `create_asset/3`; SDK function exists. |
| MUX-21 worker linker + additive migration + redaction + broadcast | 0.5d | LOW-MED | The no-op stub already routes the event; this is the only place with real logic (correlation choice + migration). |
| MUX-22 entrypoint + capability gate + `pending` row creation | 0.25d | LOW | Reuses `supports?/2`, FSM, schema. |
| MUX-23 LiveView `:external` helper + UpChunk JS hook + subscribe clause + guide | 0.5d | MED | The genuinely new DX surface; JS hook + guide writing is the long pole. |
| Tests (cassette + webhook fixture + e2e PubSub) | 0.25-0.5d | LOW | Patterns exist in the v1.6 test suite. |

**Total: ~1.5–2.0 days**, LOW overall risk. The PROJECT.md/STATE.md "~1 day,
LOW risk" is *almost* right — it slightly under-counts the LiveView `:external` +
UpChunk DX work (MUX-23), which the v1.6 memo scored at "0 lines / pure additive."
Everything server-side is genuinely ~1 day; the browser-facing DX adds the half-
to-full day. **The estimate holds; the slice is small.**

---

## 10. Locked recommendation

**Ship MUX-20..23 in v1.8, bundled as the final slice of the tus milestone (or
the next larger core), under a strict "drop if the milestone runs long" rule.**

Rationale:
1. **It's nearly free.** v1.6 deliberately pre-built the event normalizer, the
   webhook dispatch entry, the FSM edge, the PubSub vocabulary, the capability
   atom, and the redaction machinery for exactly this. Net-new code is one
   callback, one HTTP function, one worker-branch upgrade, one migration, one
   browser endpoint + UpChunk docs. ~1.5–2 days, LOW risk.
2. **It's high-DX-leverage for the wedge.** "Let the browser upload huge video
   straight to Mux, server only brokers a URL" is the headline ask for the
   AV/streaming adopter Rindle is courting. It removes server egress/ingest cost
   and is the pattern every Mux adopter expects. It punches above its size.
3. **It's not milestone-worthy alone.** A one-callback slice doesn't justify the
   planning/audit/CI-lane overhead of a standalone milestone. Bundling it with
   tus is coherent: both are "browser does the upload, server brokers a
   short-lived credential" stories, both touch the LiveView `:external`/UpChunk
   surface, and both want the same "drop if over budget" discipline that worked
   for v1.6's deferral.
4. **The contract is already locked**, so there's no abstraction risk — the
   reserved callback was designed against Cloudflare Stream's tus path as a
   contrast oracle, so a second provider won't force a breaking change.

**Two corrections to carry into the plan:**
- The callback's third return key is `provider_asset_id` (not `asset_id`), and it
  MUST be `nil` at create time — the v1.6 memo's prose used the wrong key.
- Correlate via Mux `passthrough` (stamped with the Rindle row/asset id), not via
  the upload id alone, because the row is created with `provider_asset_id: nil`
  and the `video.upload.asset_created` payload's `data.id` is the upload id while
  `data.asset_id` is the asset id (the typed branch in `event.ex` already gets
  this right; the worker linker must use it).

---

## Sources

### Local (read in full this pass, 2026-05-22)
- `/Users/jon/projects/rindle/.planning/PROJECT.md`
- `/Users/jon/projects/rindle/.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md`
- `/Users/jon/projects/rindle/.planning/research/v1.8-MUX-SDK-BOUNDARY.md`
- `/Users/jon/projects/rindle/lib/rindle/streaming/provider.ex` (reserved callback verified, lines 116-129)
- `/Users/jon/projects/rindle/lib/rindle/streaming/provider/mux.ex`
- `/Users/jon/projects/rindle/lib/rindle/streaming/provider/mux/client.ex`
- `/Users/jon/projects/rindle/lib/rindle/streaming/provider/mux/http.ex`
- `/Users/jon/projects/rindle/lib/rindle/streaming/provider/mux/event.ex` (D-29 typed branch)
- `/Users/jon/projects/rindle/lib/rindle/streaming/capabilities.ex`
- `/Users/jon/projects/rindle/lib/rindle/workers/ingest_provider_webhook.ex` (no-op stub at 115-124, 265-283)
- `/Users/jon/projects/rindle/lib/rindle/workers/mux_ingest_variant.ex`
- `/Users/jon/projects/rindle/lib/rindle/workers/mux_sync_provider_asset.ex`
- `/Users/jon/projects/rindle/lib/rindle/domain/media_provider_asset.ex` (Inspect/redact_id)
- `/Users/jon/projects/rindle/lib/rindle/domain/provider_asset_fsm.ex` (FSM edges)
- `/Users/jon/projects/rindle/lib/rindle/delivery.ex` (streaming_url dispatch, 244-347)
- `/Users/jon/projects/rindle/lib/rindle/delivery/webhook_plug.ex`
- `/Users/jon/projects/rindle/lib/rindle/profile/validator.ex` (streaming/ingest_mode schema)
- `/Users/jon/projects/rindle/lib/rindle/upload/broker.ex`
- `/Users/jon/projects/rindle/lib/rindle/live_view.ex` (allow_upload/subscribe)
- `/Users/jon/projects/rindle/lib/rindle/profile/presets/mux_web.ex`
- `/Users/jon/projects/rindle/guides/streaming_providers.md`
- `/Users/jon/projects/rindle/deps/mux/lib/mux/video/uploads.ex` (SDK `Uploads.create/2` verified)
- `/Users/jon/projects/rindle/deps/mux/lib/mux/token.ex`, `deps/mux/lib/mux/base.ex`
- `/Users/jon/projects/rindle/mix.exs` (`{:mux, "~> 3.2", optional: true}`)

### Web (verified 2026-05-22)
- Mux create direct upload API: https://www.mux.com/docs/api-reference/video/direct-uploads/create-direct-upload
- Mux upload files directly guide: https://www.mux.com/docs/guides/upload-files-directly
- Mux get direct upload (status values): https://www.mux.com/docs/api-reference/video/direct-uploads/get-direct-upload
- UpChunk (browser client): https://github.com/muxinc/upchunk — https://www.npmjs.com/package/@mux/upchunk
- Mux direct uploads with upload button (passthrough/cors patterns): https://www.mux.com/blog/direct-uploads-with-mux-upload-button
- Mux Uploader web component (alternative client): https://www.mux.com/docs/guides/mux-uploader
- CORS footgun precedent: https://github.com/muxinc/mux-python/issues/17
- Phoenix LiveView external uploads (the `:external` uploader contract): https://hexdocs.pm/phoenix_live_view/external-uploads.html
- mux Hex package (3.2.2, current): https://hex.pm/packages/mux
</content>
</invoke>
