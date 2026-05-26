# User Flows & Jobs To Be Done

This is the map. The other guides go deep on one area each; this one steps back and shows
the whole territory — *what you can actually get done with Rindle*, organized by the job
you're trying to do rather than by the module that does it.

If you've just arrived, read [Getting Started](getting_started.html) first to wire up the
basics, then come back here to see the breadth. If you're evaluating Rindle, start here.

## The mental model in one paragraph

Rindle owns everything that happens **after** the upload button. You keep your controllers,
your LiveViews, your schemas, your auth. Rindle takes over the durable, easy-to-get-wrong
middle: handing out direct-to-storage upload tickets, verifying the bytes really landed,
modeling each asset and its derivatives as queryable database rows, generating variants in
the background, serving private signed URLs, and cleaning up after itself. It is a **library,
not a platform** — it doesn't run a daemon, replace your CDN, or become a streaming service.
It makes media a normal, observable part of your Phoenix app.

## The cast

Four kinds of people show up to Rindle. You're probably the first one.

| Who | What they come for |
|---|---|
| **App developer** *(you, most days)* | Attach media to a schema, take an upload safely, render a responsive or private URL. |
| **Platform / senior engineer** | Set media policy per use case, swap storage backends, extend the processing pipeline. |
| **Operator / SRE** | See what's stuck, repair stale or missing media, keep storage spend bounded. |
| **Security / compliance** | Trust that untrusted files are handled safely and delivery is restricted by default. |

## Find your job

Scan for the row that sounds like your sentence, then jump to the story or guide.

| When you want to… | You reach for… | Go deeper |
|---|---|---|
| Upload straight to storage, bytes never touching your server | `Rindle.initiate_upload/2` → `Rindle.Upload.Broker.sign_url/2` → `Rindle.verify_completion/2` | [Avatar in five calls](#story-1-avatar-in-five-calls) |
| Take an upload server-side, simply | `Rindle.upload/3` | [Getting Started](getting_started.html) |
| Upload a multi-GB file in parts | `Rindle.initiate_multipart_upload/2` + `sign_multipart_part/3` + `complete_multipart_upload/3` | [The 4 GB upload from a moving train](#story-3-the-4-gb-upload-from-a-moving-train) |
| Let a phone resume after the signal drops | `Rindle.initiate_resumable_session/2` + `resumable_session_status/2` | [Storage (GCS)](storage_gcs.html) |
| Attach an asset to one of your schemas | `Rindle.attach/4` | [Avatar in five calls](#story-1-avatar-in-five-calls) |
| Replace media and auto-clean the old file | `Rindle.attach/4` (idempotent replace) | [Replace, detach, forget](#story-5-replace-detach-forget) |
| Detach + purge when a record is deleted | `Rindle.detach/3` | [Replace, detach, forget](#story-5-replace-detach-forget) |
| Read the current attachment in a template | `Rindle.attachment_for/3` | [Replace, detach, forget](#story-5-replace-detach-forget) |
| Make thumbnails / resized variants | `Rindle.Profile` `variants:` + `Rindle.Processor.Image` | [Profiles](profiles.html) |
| Render a responsive `<picture>` | `Rindle.HTML.picture_tag/3` | [Avatar in five calls](#story-1-avatar-in-five-calls) |
| Transcode video/audio + poster | `Rindle.Profile.Presets.Web`, `Rindle.Processor.AV` | [The creator uploads a lesson](#story-2-the-creator-uploads-a-lesson) |
| Stream video via Mux with signed playback | `Rindle.Profile.Presets.MuxWeb`, `Rindle.Delivery.streaming_url/3` | [Streaming Providers](streaming_providers.html) |
| Serve private, expiring URLs by default | `Rindle.url/3`, `variant_url/4` | [Secure Delivery](secure_delivery.html) |
| Gate delivery on your own auth | `Rindle.Authorizer` behaviour | [Secure Delivery](secure_delivery.html) |
| Wire uploads into LiveView with live progress | `Rindle.LiveView.allow_upload/4` + `consume_uploaded_entries/3` + `subscribe/2` | [LiveView, reactively](#story-4-liveview-reactively) |
| Run on S3 / R2 / MinIO, GCS, or local disk | `Rindle.Storage.{S3,GCS,Local}` | [Storage Capabilities](storage_capabilities.html) |
| Plug in your own analyzer / processor / scanner | `Rindle.Analyzer`, `Rindle.Processor`, `Rindle.Scanner` | [Profiles](profiles.html) |
| Fix bad metadata, retry failed variants, cancel work | `Rindle.reprobe/1`, `requeue_variants/2`, `cancel_processing/1` | [Friday, 5 p.m., something is stuck](#story-6-friday-5-pm-something-is-stuck) |
| See what's stuck and repair it | `Rindle.runtime_status/1`, `mix rindle.doctor`, the `mix rindle.*` ops tasks | [Operations](operations.html) |

## The flows, told as stories

These six cover the surface most apps touch. Each uses one running example — **Cohort**, a
hypothetical course-and-community SaaS that needs avatars, post images, and lesson videos.
Swap the names for yours; the shape is the point.

### Story 1: Avatar in five calls

A member uploads a profile photo. You never want the image bytes flowing through your app
server, so you hand the browser a presigned ticket and let it talk to S3 directly.

First, declare the policy once. A profile is the single source of truth for one kind of media:

```elixir
defmodule Cohort.AvatarProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    allow_mime: ["image/png", "image/jpeg", "image/webp"],
    max_bytes: 8_000_000,
    delivery: [public: false, signed_url_ttl_seconds: 900],
    variants: [
      thumb: [mode: :fit, width: 128, height: 128],
      large: [mode: :fit, width: 1024, height: 1024]
    ]
end
```

Then the five-call dance — three on the way up, two to verify and link:

```elixir
# 1. Mint a staged asset + upload session
{:ok, session} = Rindle.initiate_upload(Cohort.AvatarProfile, filename: "me.jpg")

# 2. Get a presigned PUT the browser can use directly
{:ok, %{presigned: put}} = Rindle.Upload.Broker.sign_url(session.id)
#    -> hand put.url / put.headers to the client; it PUTs the bytes to S3

# 3. After the client's PUT succeeds, confirm the object really landed
{:ok, %{asset: asset}} = Rindle.verify_completion(session.id)
#    -> asset is now "validating"; Rindle promotes it and builds variants in the background

# 4. Link it to the member at a named slot ("avatar")
{:ok, _attachment} = Rindle.attach(asset.id, current_user, "avatar")
```

Rendering is the fifth call — and it doesn't care whether the variants finished yet, because
`picture_tag/3` falls back to the original automatically:

```heex
<%= Rindle.HTML.picture_tag(Cohort.AvatarProfile, @asset,
      variants: [{:thumb, "(max-width: 480px)"}, {:large, nil}],
      alt: "Member avatar"
    ) %>
```

That's the spine of almost every flow: **initiate → sign → verify → attach → render.**

### Story 2: The creator uploads a lesson

Now a course creator uploads a 12-minute lesson video. You want a web-friendly 720p
rendition and a poster frame, and you'd rather not hand-write FFmpeg flags. The `Web` preset
declares both outputs for you:

```elixir
defmodule Cohort.LessonVideo do
  use Rindle.Profile.Presets.Web,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime"],
    max_bytes: 2_000_000_000
  # gives you a :web_720p video variant and a :poster image variant
end
```

The upload path is identical to Story 1 (`initiate → sign → verify`). Once the bytes land,
Rindle probes the file with FFprobe, transcodes `:web_720p` and extracts `:poster` on
background workers, and flips each variant to `"ready"` when it's done. You render:

```heex
<%= Rindle.HTML.video_tag(Cohort.LessonVideo, @asset,
      variants: [:web_720p],
      poster: :poster,
      controls: true
    ) %>
```

When Cohort outgrows progressive MP4 and wants adaptive streaming, the jump is small: switch
the profile to `Rindle.Profile.Presets.MuxWeb`, and ask for a playback URL through the same
delivery surface instead of a static one:

```elixir
{:ok, playback_url} = Rindle.Delivery.streaming_url(Cohort.LessonVideo, asset)
```

Rindle pushes the asset to Mux in the background, listens for the readiness webhook, and mints
a signed playback URL — no template churn. The full setup lives in
[Streaming Providers](streaming_providers.html).

### Story 3: The 4 GB upload from a moving train

A creator records a long workshop and uploads it from a laptop on spotty WiFi. A single PUT
would fail halfway and start over. Two flows fix this, and your storage backend decides which
one is available — Rindle won't offer a capability the adapter can't honor (see
[Storage Capabilities](storage_capabilities.html)).

**Multipart (S3-family):** split into parts, sign each, complete:

```elixir
{:ok, %{session: session}} = Rindle.initiate_multipart_upload(Cohort.LessonVideo)

# for each part the client wants to send:
{:ok, part_put} = Rindle.sign_multipart_part(session.id, part_number)

# once all parts are uploaded, hand back the part etags:
{:ok, %{asset: asset}} = Rindle.complete_multipart_upload(session.id, parts)
```

**Resumable (GCS):** open a session the client can keep PATCHing into, and poll its progress:

```elixir
{:ok, %{session: session}} = Rindle.initiate_resumable_session(Cohort.LessonVideo)
{:ok, status} = Rindle.resumable_session_status(session.id)   # committed bytes, state
```

Both funnel back into the same `verify_completion/2` → promotion → processing pipeline as
every other upload. The session URI in a resumable flow is a bearer credential, so Rindle
keeps it out of logs, telemetry, and `inspect/2` — you don't have to remember to redact it.

### Story 4: LiveView, reactively

Cohort's settings page is a LiveView, and you want the avatar to upload and show progress
without a full round trip. Rindle wraps Phoenix's external-upload mechanism:

```elixir
def mount(_params, _session, socket) do
  {:ok, Rindle.LiveView.allow_upload(socket, :avatar, Cohort.AvatarProfile)}
end

def handle_event("save", _params, socket) do
  Rindle.LiveView.consume_uploaded_entries(socket, :avatar, fn _entry, meta ->
    {:ok, attachment} = Rindle.attach(meta.asset_id, socket.assigns.current_user, "avatar")
    {:ok, attachment}
  end)
  {:noreply, socket}
end
```

Want a live "processing… ready" badge? Subscribe to the asset and handle the broadcasts:

```elixir
Rindle.LiveView.subscribe(:asset, asset_id)

def handle_info({:rindle_event, type, payload}, socket) do
  # type is :variant_ready, :state_change, ...
  {:noreply, assign(socket, :media_state, payload.state)}
end
```

### Story 5: Replace, detach, forget

A member swaps their avatar. You don't orphan the old file — `attach/4` to an occupied slot
replaces the link and schedules the previous asset's storage purge **after** the database
commit, so you never leave a half-deleted object behind:

```elixir
{:ok, _} = Rindle.attach(new_asset.id, current_user, "avatar")  # old one purged async
```

A member deletes a post that had a hero image. Detach is idempotent — safe to call whether
or not anything was attached:

```elixir
:ok = Rindle.detach(post, "hero")
```

And in any render path, read the current attachment without side effects (the asset is
preloaded by default):

```elixir
case Rindle.attachment_for(current_user, "avatar") do
  nil -> render_default_avatar()
  attachment -> render_avatar(attachment.asset)
end
```

Need to delete an account without guessing which media survives? Use the
owner/account erasure facade instead of teaching a detach loop:

```elixir
{:ok, preview} = Rindle.preview_owner_erasure(current_user)

# preview.attachments_to_detach  -> Rindle-managed associations removed now
# preview.assets_to_purge        -> newly orphaned assets queued for purge later
# preview.retained_shared_assets -> shared assets kept because another attachment survives

{:ok, report} = Rindle.erase_owner(current_user)
```

`Rindle.preview_owner_erasure/2` is the dry run and `Rindle.erase_owner/2` is
the execute lane. The report keeps three semantic buckets stable:
`attachments_to_detach`, `assets_to_purge`, and `retained_shared_assets`.

Rindle only erases Rindle-managed associations for that owner. It does not
delete your adopter-owned account row. Execute semantics stay honest: detach now, purge later.
Newly orphaned assets are enqueued for async cleanup, while retained shared assets stay
in storage whenever another live attachment survives.

`mix rindle.cleanup_orphans` remains maintenance-only upload-residue cleanup,
not the supported account-deletion API. Admin UI, bulk orchestration, and
force-delete policy for still-shared assets remain deferred.

### Story 6: Friday, 5 p.m., something is stuck

An operator notices a few lesson videos that never went "ready." Rindle is built so this is a
two-minute investigation, not an archaeology dig — because every asset, variant, and session
is a queryable row with explicit state, never hidden in a filename.

```bash
mix rindle.doctor            # is FFmpeg present? storage reachable? streaming wired?
mix rindle.runtime_status    # bounded report: stuck work, upload residue, lifecycle drift
```

From there the repair surfaces are explicit and asset-scoped — no Oban spelunking required:

```elixir
Rindle.reprobe(asset_id)                                  # re-detect mime/dimensions/duration
Rindle.requeue_variants(asset_id, variant_names: ["web_720p"])  # retry only the failures
Rindle.cancel_processing(asset_id)                        # stop in-flight work
```

And the scheduled-task family keeps storage honest over time:
`mix rindle.regenerate_variants`, `mix rindle.verify_storage` (DB vs. storage reconciliation),
`mix rindle.cleanup_orphans`, `mix rindle.abort_incomplete_uploads`. See
[Operations](operations.html).

## What you inherit for free

You don't have to ask for these — they're the defaults, and they're the reason Rindle exists
instead of a folder of glue code:

- **No bytes through your app.** Presigned/direct upload is the primary path.
- **Files are validated by content, not by their claimed name.** Magic-byte sniffing plus
  allowlists; the `Rindle.Scanner` hook can quarantine before anything goes live.
- **Private by default.** Delivery is signed and expiring unless you opt a profile into public
  (CDN-cacheable) URLs — see [Secure Delivery](secure_delivery.html).
- **Cleanup never corrupts state.** Storage side effects happen *after* the DB commit, and
  purges are async, idempotent, and auditable.
- **Nothing is a black box.** Assets, variants, and sessions are first-class rows with explicit
  state machines you can query, filter, and repair — the model is in [Core Concepts](core_concepts.html).
- **Your dashboards won't break silently.** Telemetry event names and metadata are a public
  contract (see [Background Processing](background_processing.html)).

## Where Rindle is headed

Rindle already covers the full core lifecycle for images, video, and audio across S3-family,
GCS, and local storage. The near-term additions are about closing the last expected *upload*
flows and a couple of high-value conveniences:

- **tus resumable uploads** — first-class support for the de-facto browser standard
  (tus-js-client), so Local and S3 can advertise resumable uploads too.
- **Browser → Mux direct creator upload** — let creators upload straight to Mux from the
  browser, skipping server ingest cost, building on the streaming primitives already shipped.
Deliberately *out of scope*, by design: being a full HLS/DASH streaming platform, DRM,
AI/GPU processing, broad PDF/Office handling, an admin UI, or a CDN replacement. Rindle stays
a focused library; those belong to other tools.
