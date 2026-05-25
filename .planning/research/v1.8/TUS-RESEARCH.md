# v1.8 Research: tus Resumable Upload Protocol — Locked Recommendation

**Date:** 2026-05-22
**Author:** Deep technical research pass (one-shot, locked)
**Status:** LOCKED RECOMMENDATION. The maintainer asked for a decision, not options.
**Supersedes:** `.planning/research/v1.6-CANDIDATE-TUS.md` (LOCKED 2026-05-06, 6/10)
and `.planning/research/TUS-CANDIDATE-MEMO.md` (2026-05-05, 4/10). Both are now
**materially stale** because v1.7 shipped the resumable-session substrate they
assumed had to be built (see §1).

---

## TL;DR (the decision)

**YES, v1.8 should be tus — but NOT the shape the v1.6 candidate plan locked.**
The v1.6 plan was written before v1.7 shipped. v1.7 already built ~60% of what
that plan called "TUS Foundations" (the broker resumable lane, the
session-URI schema, the `"resuming"` FSM lane, the resumable telemetry, the
maintenance reaper, capability un-reservation). What remains is the **HTTP
protocol edge** and the **S3 multipart backing**.

Three locked overrides versus the v1.6 plan:

1. **Do NOT depend on `tussle`. Roll a bare-`Plug` tus endpoint.** Verified
   live 2026-05-22: tussle is 2 GitHub stars / 0 forks / 104 total downloads /
   4 downloads last 7 days, and — decisively — its `add_tus_routes/1` macro
   emits **Phoenix.Router** DSL, while Rindle has **no Phoenix dependency**
   (only `plug ~> 1.16`). Adopting tussle forces Phoenix into Rindle's core or
   forces Rindle to bypass tussle's only real value-add (the routes). The tus
   core protocol is ~6 HTTP verbs against state Rindle already persists. Rolling
   it as a `@behaviour Plug` (the WebhookPlug/LocalPlug idiom Rindle already
   ships) is less code than vendoring + adapting an unmaintained 2-star dep.
2. **Reuse `upload_strategy: "resumable"`, NOT a new `"tus"` strategy or
   `tus_*` columns.** v1.7's `session_uri` / `last_known_offset` / `"resuming"`
   model IS the resumable session. tus is a *wire protocol over that session*,
   not a new session family. Add at most one column (`upload_offset` is already
   covered by `last_known_offset`; a per-session HMAC binding goes in
   `session_uri` reuse, see §6).
3. **The S3 multipart-per-PATCH backing is the real, only large work item.**
   Everything else is edge/glue. This is where the milestone's weight actually
   sits, and where the v1.6 plan correctly identified the risk.

Bounded shape: **3 phases, ~9–11 plans, ~7–9 focused engineering days** — about
half the v1.6 plan's estimate, because v1.7 already paid the substrate cost.

Confidence: **HIGH** on architecture/scope (every seam is in-repo and verified);
**MEDIUM** on adopter demand (no in-repo evidence of a real adopter asking;
the case is inferred from the v1.4 AV wedge). The single biggest *strategic*
caveat is the IETF RUFH draft (§13) — tus 1.0 is a 2016 protocol now being
superseded by an HTTP-WG standard at draft-11 (April 2026). v1 tus is still
the right bet for *today's* clients, but Rindle should architect the edge so
RUFH is an additive second protocol version, not a rewrite.

---

## 0. What changed since the v1.6 candidate plan (read this first)

The v1.6 plan (`v1.6-CANDIDATE-TUS.md`) is an excellent document, but it was
written on 2026-05-06, **before v1.7 shipped on 2026-05-08**. v1.7 ("GCS
Resumable Adapter") did far more than add a GCS adapter — it built the entire
broker-owned resumable-session machinery. Verified by reading the live code:

| v1.6 plan assumed it would build (Phase 33) | Reality after v1.7 (already shipped) |
|---|---|
| `tussle ~> 0.3.1` runtime dep behind a capability gate | **Reject.** No tus dep exists; we should not add tussle (§3). |
| Migration adds `tus_*` columns + `upload_strategy: "tus"` | **Already have** `session_uri`, `session_uri_expires_at`, `last_known_offset`, `region_hint`, and `upload_strategy: "resumable"` on `media_upload_sessions` (`lib/rindle/domain/media_upload_session.ex:48-65`). |
| Broker `initiate_resumable_upload/2` + `cancel_resumable_upload/1` | **Already shipped** as `Rindle.Upload.Broker.initiate_resumable_session/2`, `resumable_session_status/2`, `cancel_resumable_session/2` (`lib/rindle/upload/broker.ex:182-398`). |
| Un-reserve `:resumable_upload` / `:resumable_upload_session` capability | **Already done.** `Rindle.Storage.GCS` advertises both today (`lib/rindle/storage/gcs.ex:141`); `Rindle.Storage.Capabilities` lists them as real, not reserved (`lib/rindle/storage/capabilities.ex:20-28`). |
| New `"resuming"` FSM lane | **Already shipped** (`lib/rindle/domain/upload_session_fsm.ex:9`; `signed → resuming → uploading`). |
| Resumable telemetry contract | **Already shipped** as `Rindle.Upload.ResumableTelemetry` with `[:rindle, :upload, :resumable, :status|:cancel]` events + redaction allowlist (`lib/rindle/upload/resumable_telemetry.ex`). |
| Oban reaper extended for resumable | **Already shipped.** `Rindle.Ops.UploadMaintenance` has full resumable abort/cancel/cleanup paths (`lib/rindle/ops/upload_maintenance.ex:413-555`), including idempotent adapter `cancel_resumable_upload`. |
| Security invariant 14 (session URIs as bearer creds, redacted in `Inspect`) | **Already shipped.** `MediaUploadSession` has a custom `Inspect` impl redacting `session_uri` (`media_upload_session.ex:104-113`); telemetry forbids `:session_uri`/`:upload_key` in metadata (`resumable_telemetry.ex:9`). |

**Net effect:** the v1.6 plan's Phase 33 ("TUS Foundations") is ~80% done, and
its Phases 36 (Oban/expiry/cancel) is ~70% done via the generic resumable lane.
What v1.7 did NOT build, and what v1.8 must build, is exactly:

- The **HTTP protocol edge** (HEAD/PATCH/OPTIONS/POST/DELETE with tus headers).
- The **S3 multipart-per-PATCH storage backing** (bytes flow through Rindle's
  BEAM into S3 `UploadPart`; today the only resumable adapter is GCS, where
  bytes flow client→GCS directly via the session URI and never touch the BEAM).
- The **`tus → broker session` binding + HMAC URL signing** for the in-BEAM path.
- DX/docs/CI proof for the protocol.

This is why the recommendation is "yes, but smaller and differently shaped."

---

## 1. The single most important architectural insight

**There are two fundamentally different "resumable upload" topologies, and
Rindle already ships one of them. tus is the other.**

### Topology A — "session URI" / client-direct (SHIPPED in v1.7)

The client uploads bytes **directly to the storage provider** using a
provider-issued session URI. Rindle issues the session, polls status, and
verifies completion — but **the upload bytes never pass through the BEAM**.

- GCS resumable upload: `POST` → session URI → client `PUT`s chunks to GCS.
- **Mux UpChunk** (verified 2026-05-22): chunked `PUT` with `Content-Range`
  headers, "should work with any server that supports resumable uploads in the
  same manner." Mux deliberately did **not** adopt tus.
- This is what `session_uri` + `last_known_offset` + `resumable_upload_status/3`
  model. It is cheap on the BEAM (no hot-path bytes) and is the natural fit for
  GCS and provider-native flows.

### Topology B — "tus protocol" / server-mediated (the v1.8 ask)

The client uploads bytes **to Rindle's own HTTP endpoint** via tus
`PATCH application/offset+octet-stream`. Rindle streams those bytes into storage
(local tmp, or S3 `UploadPart` per chunk). **The upload bytes pass through the
BEAM.** This is what the v1.6 memo correctly flagged as "Rindle becomes a server
that runs the upload hot path."

**The implication the v1.6 plan under-weighted:** these are not one capability
with two backends. They are two topologies. Rindle's `:resumable_upload`
capability today means Topology A (adapter issues a session URI; Broker polls
it). tus is Topology B (Rindle serves the protocol; storage adapter is a sink).
Conflating them under one capability atom would be a capability-honesty
violation (a core constraint). **tus needs its own capability atom** (§5).

This insight also resolves a latent contradiction in the v1.6 plan: it proposed
`:resumable_upload` mean both "GCS-native session URI" AND "S3 multipart per
PATCH." Post-v1.7 those are observably different adapter surfaces. Lock them
apart now.

---

## 2. Pros / cons / tradeoffs — specific to Rindle (post-v1.7)

### Pros (why tus is the right v1.8)

- **Completes the resumable story coherently.** v1.7 shipped Topology A
  (provider-direct). The honest gap is "what about adopters on S3 who want
  resumable, and adopters who must validate/mediate bytes server-side before
  storage sees them?" tus is precisely that path. Without it, Rindle's resumable
  support is "GCS only," which is a narrow and slightly arbitrary place to stop.
- **Killer case is real and already in-repo's wheelhouse.** Smartphone AV
  uploads (v1.4) over flaky LTE: 100MB–5GB videos that presigned PUT and even
  client-driven S3 multipart recover from poorly. tus + S3 multipart backing is
  the standard answer (Vimeo migrated to tus for exactly this; Cloudflare Stream
  uses tus).
- **Most of the substrate is paid for.** Broker lane, FSM, telemetry, reaper,
  redaction, capability machinery all exist. v1.8 is mostly an HTTP edge +
  one storage backing + glue.
- **The mountable-Plug idiom already exists in-repo.** `Rindle.Delivery.WebhookPlug`
  (`@behaviour Plug`, `init/1`+`call/2`, mounted via `forward`, raw-body reader,
  `Plug.Crypto` signing in `LocalPlug`) is a directly reusable template. tus is
  the same shape: a bare Plug doing protocol mechanics + HMAC verification +
  Oban handoff. No new architectural pattern.
- **`Plug.Crypto` HMAC primitives are already in use.** `LocalPlug` already
  signs/verifies bearer tokens with `Plug.Crypto.sign`/`verify` against
  `secret_key_base` (`local_plug.ex:66`). tus URL signing reuses this exact
  primitive — invariant 14 is enforceable with code that already exists.

### Cons / tradeoffs

- **Boundary expansion is real (but bounded).** tus puts upload bytes on the
  BEAM hot path. This is the largest such expansion in Rindle's history (even
  AV transcoding happens in subprocesses off the request thread; tus PATCH
  bodies are *in* the request). Bounding it: hard per-call `read_length`
  (1 MiB) and per-PATCH ceiling, S3 `UploadPart` flush so steady-state BEAM
  memory is one part, and explicit guidance that Bandit/Cowboy handle long
  PATCHes natively on the BEAM (no worker-tie-up the way Puma/Unicorn have —
  see tus-ruby-server's warning, §10).
- **Operational surface grows.** Adopters must learn `Plug.Parsers` `:pass`
  for `application/offset+octet-stream`, body-length config, proxy PATCH
  buffering behavior, CORS for browser clients, S3 5 MiB part minimum. The guide
  is non-trivial. This is inherent to tus, not to Rindle's implementation.
- **"Pulls Rindle toward being an upload server."** This is THE risk the
  maintainer named. Mitigation is to keep tus strictly **opt-in and additive**:
  `Rindle.upload/3` stays boring; tus requires an explicit Plug mount and an
  external JS client; the facade gains no tus sugar; the capability atom is
  separate so nothing silently routes through tus.
- **No in-repo demand signal.** The case is inferred from the AV wedge, not
  from an adopter ticket. This is the honest reason confidence on *demand*
  (not architecture) is MEDIUM. The bar to override the locked candidate is
  high (PROJECT.md names it leading), and architecture + the v1.7 substrate
  both lower the *cost* enough that the inferred demand clears the bar — but
  this should be revisited if adopter feedback points elsewhere first.

### How to bound the "upload server" risk (locked rules)

1. tus is a **separate capability** (`:tus_upload`), never auto-selected.
2. tus has **no facade sugar**. Only the Plug + a broker `initiate` entrypoint.
3. tus bytes are **streamed to storage per-PATCH**, never buffered whole on the
   BEAM (S3 `UploadPart`; local tmp append).
4. tus completion **converges into the existing `verify_completion/2` lane** —
   one promotion vocabulary, not two.
5. The endpoint is **adopter-mounted under their own auth pipeline**. Rindle
   does not own routing or auth; it owns protocol mechanics + session binding.

---

## 3. Idiomatic Elixir / Plug / Phoenix / Ecto shape (LOCKED)

### 3a. Roll a bare `Plug`. Do NOT depend on `tussle`. (LOCKED, overrides v1.6)

The v1.6 plan locked "in-process mountable Plug, vendored on top of
`tussle ~> 0.3` as a hard runtime dependency." **Override that.** Reasoning,
verified live 2026-05-22:

- **Adoption is near-zero.** tussle: **2 GitHub stars, 0 forks, 0 open issues,
  104 total downloads, 38 on the current version, 4 in the last 7 days.** This
  is not "the ecosystem is now ready" (the v1.6 plan's framing); it is a
  single-author project nobody uses. Bus factor is 1.
- **It forces Phoenix.** tussle's `mix.exs` declares only `plug ~> 1.3`, but its
  *only* real value-add — `Tussle.Routes.add_tus_routes/1` — emits
  **Phoenix.Router** macros (`options`, `post`, `patch`, `match`, `delete`) and
  "cannot be used in a plain `Plug.Router` without Phoenix's routing DSL"
  (verified at hexdocs.pm/tussle/Tussle.Routes.html). **Rindle has no Phoenix
  dependency** — `mix.exs` lists `plug ~> 1.16`, `phoenix_live_view` *optional*,
  and no `phoenix`. Adopting tussle's routes either (a) adds Phoenix to Rindle's
  required deps (a real regression: Rindle currently installs cleanly into any
  Plug app, and the WebhookPlug/LocalPlug are mounted via bare `forward`), or
  (b) bypasses the routes and uses tussle's lower-level controller — at which
  point we depend on an unmaintained 2-star lib for ~6 verbs of protocol logic.
- **Rindle already ships the idiom.** `WebhookPlug` and `LocalPlug` are
  `@behaviour Plug` modules with `init/1` + `call/2`, mounted via `forward` in
  the adopter's router (Phoenix *or* Plug.Router), no Phoenix coupling. tus is
  the same shape. A `Rindle.Upload.TusPlug` that pattern-matches on
  `conn.method` (`"OPTIONS"`/`"POST"`/`"HEAD"`/`"PATCH"`/`"DELETE"`) and the
  path suffix is a few hundred lines — comparable to `WebhookPlug` (345 lines).
- **The cache problem disappears.** tussle ships `Tussle.Cache.Memory` /
  `tus_cache_redis`; the v1.6 plan correctly said both are wrong for Rindle and
  Rindle must back the cache with the adopter Repo. If we roll our own Plug,
  there is no cache to replace — `media_upload_sessions` IS the state, read/written
  through `Config.repo()` exactly like the rest of the broker. The v1.6 plan's
  `Rindle.Upload.Tus.Cache.Ecto` (implementing tussle's `Tussle.Cache`
  behaviour) is eliminated entirely.
- **Protocol is small and frozen.** tus core 1.0.0 has been stable since
  2016-03-25. Creation/Expiration/Termination are a handful of headers each
  (§4). There is no moving target to track for v1; the moving target is RUFH
  (§13), which tussle does not implement either.

**Mount shape (LOCKED), matching the existing WebhookPlug `forward` idiom:**

```elixir
# In the adopter's router (Phoenix Router OR Plug.Router — Rindle does not care):
forward "/uploads/tus", Rindle.Upload.TusPlug,
  profile: MyApp.MediaProfile,
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
  max_size: 5_368_709_120
# pipe_through / plug the adopter's own auth BEFORE this forward.
```

This is exactly how `WebhookPlug` is mounted (`webhook_plug.ex:20-22`). No
router macro, no Phoenix requirement, no new dependency.

### 3b. How PATCH maps to S3 `UploadPart` (LOCKED)

This is the one genuinely new piece of storage code. It reuses the **existing
S3 multipart adapter callbacks** (`initiate_multipart_upload/3`,
`complete_multipart_upload/4`, `abort_multipart_upload/3` in
`lib/rindle/storage/s3.ex:72-127`) but adds one new adapter callback for
**server-side part upload from a stream** (the existing
`presigned_upload_part/5` is for *client*-direct part PUTs and is not usable
when bytes arrive at Rindle's PATCH endpoint).

- `initiate` (tus `POST`): Broker calls `adapter.initiate_multipart_upload/3`,
  stores the returned `upload_id` in `media_upload_sessions.multipart_upload_id`
  (reusing the existing multipart column). The tus session is **1:1 with an S3
  multipart upload.**
- Each tus `PATCH` whose body ≥ 5 MiB → one S3 `UploadPart`. The returned ETag
  is appended to `multipart_parts`. `last_known_offset` advances by the PATCH
  byte count.
- A PATCH < 5 MiB (legal only as the final chunk per S3 rules) buffers to a
  temp file under `Rindle.tmp/tus/<session_id>.part` (invariant 13: sweepable
  root) and is flushed as the final part on completion. This mirrors tusd's S3
  backend exactly (verified 2026-05-22: tusd "temporarily stored on disk ...
  to meet the minimum part size for an S3 multipart upload enforced by S3").
- tus completion (final PATCH lands, offset == length) → Broker calls
  `adapter.complete_multipart_upload/4` → **converges into `verify_completion/2`**
  (the existing trusted lane), which calls `adapter.head/2`, validates
  size/content_type against the profile, transitions the session to `completed`
  and the asset to `validating`, and enqueues `PromoteAsset` inside the same
  `Ecto.Multi` (`broker.ex:439-485`). **Zero new completion vocabulary.**

**New adapter callback required (additive to `Rindle.Storage` behaviour):**

```elixir
@callback upload_part_stream(
            key :: String.t(),
            upload_id :: String.t(),
            part_number :: pos_integer(),
            body :: iodata() | Enumerable.t(),
            opts :: keyword()
          ) :: {:ok, %{etag: String.t(), part_number: pos_integer()}} | {:error, term()}
@optional_callbacks upload_part_stream: 5
```

Gated behind a new `:tus_upload` capability so only adapters that implement it
advertise it (S3 in v1; Local via tmp-append; GCS does NOT — GCS uses its own
native resumable, Topology A).

### 3c. Local adapter backing (LOCKED)

`Rindle.Storage.Local` backs tus by **appending PATCH bytes to a tmp file**
under `Rindle.tmp/tus/<session_id>.part`, then atomic-renaming into the final
key on completion (cheap same-filesystem rename, no copy). Disk bounded by
`session.expires_at` reaping + `max_size`. This is the cheapest correct backing
and makes local-dev tus work without S3.

### 3d. Completion convergence (LOCKED)

`verify_completion/2` is **unchanged**. The tus Plug's final-PATCH handler does
exactly what `complete_multipart_upload/3` does in the broker today
(`broker.ex:302-329`): completes the multipart upload at the adapter, then
calls `verify_completion(session.id, opts)`. Same head-based trust, same
`PromoteAsset` enqueue in the same transaction. This preserves security
invariants 1 (re-sniff content_type from `head`), 2 (no promote before verify),
and 4 (storage I/O outside the DB transaction).

### 3e. Capability atom (LOCKED): `:tus_upload`, no silent downgrade

Add `:tus_upload` to `Rindle.Storage.Capabilities` `@known`. Adapters advertise
it only if they implement `upload_part_stream/5`. The tus Plug calls
`Capabilities.require_upload(adapter, :tus_upload)` at `init/1` and raises
`ArgumentError` if the mounted profile's adapter does not support it — a
deployment-time failure, matching `WebhookPlug.init/1`'s fail-fast posture
(`webhook_plug.ex:91-99`). **No fallback to presigned PUT, multipart, or GCS
session-URI.** Unsupported → tagged error / hard mount failure, never a degraded
surprise (capability-honesty constraint).

---

## 4. tus protocol surface — what's IN v1 vs DEFERRED

Verified against tus.io/protocols/resumable-upload (1.0.0, 2016-03-25) on
2026-05-22.

| Feature | HTTP | v1.8 status | Notes |
|---|---|---|---|
| Core: `HEAD` returns authoritative `Upload-Offset` | HEAD → 200/204 + `Upload-Offset`, `Cache-Control: no-store` | **IN** | Offset read from `last_known_offset`. |
| Core: `PATCH` at offset, `application/offset+octet-stream` | PATCH → 204 + new `Upload-Offset`; **409** on offset mismatch | **IN** | 409 is the contract tus-js-client auto-retries. |
| Core: `OPTIONS` advertises `Tus-Version`, `Tus-Extension`, `Tus-Max-Size` | OPTIONS → 204 | **IN** | Advertises only the extensions we implement. |
| Creation: `POST` with `Upload-Length`, returns `Location` | POST → 201 + `Location` | **IN** | `Location` = the HMAC-signed tus URL bound to the broker session. |
| Creation: `Upload-Metadata` (filename, type) | header | **IN (opaque)** | Treated as untrusted hint only; re-sniffed at `verify_completion` (invariants 1, 10). |
| Expiration: `Upload-Expires` header; **410 Gone** on expired | header + 410 | **IN** | Populated from `expires_at`; reuses the v1.7 reaper. |
| Termination: `DELETE` aborts upload | DELETE → 204 | **IN** | Converges into existing `cancel_resumable_session`/abort lane + S3 multipart abort. |
| Checksum: per-chunk SHA-1, **460** mismatch | header + 460 | **DEFER** | TLS already prevents transit corruption; `verify_completion` validates final size/type. Add on demand. |
| Concatenation: parallel partial uploads merged | `Upload-Concat` | **DEFER** | Adds real complexity; rule "servers SHOULD NOT process partial uploads until concatenated" conflicts with the per-PATCH `UploadPart` flush model. Document `parallelUploads: 1` for clients. |
| `Upload-Defer-Length` (size unknown at creation) | header | **DEFER** | S3 multipart wants a size estimate for part planning; require `Upload-Length` at creation in v1. |
| IETF RUFH (tus 2.0) `104 Upload Resumption Supported` | new media type | **DEFER (architect for it)** | draft-11, not an RFC (§13). |

**v1 = Core + Creation + Expiration + Termination.** Identical to the three
extensions tussle ships and tus-ruby-server treats as table stakes — but Rindle
implements them itself.

---

## 5. Capability vocabulary changes (LOCKED)

Today (`lib/rindle/storage/capabilities.ex`, `lib/rindle/storage.ex`):
`:presigned_put | :multipart_upload | :signed_url | :head | :local |
:resumable_upload | :resumable_upload_session`.

**Add exactly one atom: `:tus_upload`.** Meaning: "this adapter can accept
server-mediated tus PATCH chunks and flush them to storage" (Topology B). Keep
it distinct from `:resumable_upload` (Topology A, provider-direct session URI).

| Adapter | Today | After v1.8 |
|---|---|---|
| `Rindle.Storage.Local` | `[:local, :presigned_put]` (presumed) | `+ :tus_upload` (tmp-append backing) |
| `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` (`s3.ex:152`) | `+ :tus_upload` once MinIO proof passes |
| `Rindle.Storage.GCS` | `[:signed_url, :head, :resumable_upload, :resumable_upload_session]` (`gcs.ex:141`) | **unchanged** — GCS uses native resumable (Topology A), NOT tus. Documented explicitly. |
| Cloudflare R2 (via S3) | as S3 | `+ :tus_upload`, with guide note that R2 honors S3 `UploadPart` and that R2 also has its *own* native tus surface adopters may prefer to point clients at directly. |

Why a new atom and not reuse `:resumable_upload`: per §1, those are different
topologies with different adapter surfaces (`upload_part_stream/5` vs
`initiate_resumable_upload/3`). Overloading one atom would let the broker route
a tus mount onto GCS (which has no PATCH sink) — a capability lie. Distinct
atoms keep the honesty invariant true.

---

## 6. Ecto / migration shape (LOCKED — minimal, additive)

The v1.6 plan added five `tus_*` columns. **Override: add at most one.** v1.7's
schema already carries everything tus needs:

- `upload_strategy` → reuse `"resumable"`. tus is a wire protocol over a
  resumable session, not a new strategy. (Optional: a `resumable_protocol`
  discriminator column `"gcs_native" | "tus"` if the reaper/status code needs to
  branch on topology — see below. This is the ONE candidate new column.)
- `session_uri` → reuse to hold the **HMAC-signed tus URL token** (it is already
  redacted in `Inspect` and forbidden in telemetry — invariant 14 is already
  enforced for this column). The signing primitive is `Plug.Crypto.sign` as in
  `LocalPlug`.
- `last_known_offset` → IS the tus `Upload-Offset`. No new column.
- `multipart_upload_id` → holds the S3 multipart upload ID (reused exactly as
  direct multipart does today, `broker.ex:547`).
- `multipart_parts` → holds the accumulating part/ETag list.
- `expires_at` / `session_uri_expires_at` → drive `Upload-Expires` + the reaper.

**Recommended single migration:**

```elixir
def change do
  alter table(:media_upload_sessions) do
    add :resumable_protocol, :string  # "gcs_native" | "tus"; nil for legacy rows
  end
  create index(:media_upload_sessions, [:upload_strategy, :resumable_protocol, :state])
end
```

This lets `UploadMaintenance` and `resumable_session_status/2` branch on
topology (GCS sessions poll the provider; tus sessions read `last_known_offset`
locally and abort the S3 multipart, not a GCS session URI). Without it, the
reaper would try to call `cancel_resumable_upload` (a GCS-shaped callback) on a
tus session, which has no remote session to cancel — it has an S3 multipart to
abort. The maintenance code already special-cases `multipart` vs `resumable`
(`upload_maintenance.ex:324-368, 551-555`); `resumable_protocol` lets it
special-case tus-resumable correctly.

**No `tus_*` columns. No new table. No FSM changes** — the `"resuming"` lane
(`upload_session_fsm.ex:9`) already covers `signed → resuming → uploading →
uploaded → verifying → completed`, which is exactly the tus lifecycle.

---

## 7. How it composes with v1.7's shipped resumable work (the unification)

This is the question the maintainer flagged explicitly. **Answer: tus reuses the
`media_upload_sessions` table + the `"resuming"` FSM lane + the broker resumable
entrypoints. It is the SAME family, with a `resumable_protocol` discriminator —
NOT a parallel family.** Concretely:

- **Same table, same FSM.** No new schema, no new states.
- **Same broker lane, extended.** `initiate_resumable_session/2`
  (`broker.ex:182`) already takes a profile + opts, checks
  `Capabilities.require_upload(adapter, :resumable_upload)`, and persists a
  `"resumable"` session. v1.8 adds a sibling path that checks
  `:tus_upload` instead, initiates an S3 multipart (not a GCS session URI),
  signs a tus URL into `session_uri`, and sets `resumable_protocol: "tus"`.
  Same persistence helper (`persist_resumable_session/5`), same telemetry
  emit, same compensation-on-failure pattern (`broker.ex:566-640`).
- **Same completion lane.** Both topologies converge into `verify_completion/2`.
- **Same reaper.** `UploadMaintenance.abort_incomplete_uploads/1` already
  handles `"resumable"` + `"resuming"` sessions past TTL (`upload_maintenance.ex:135-155,
  413-467`). v1.8 teaches `attempt_resumable_cancel` to branch on
  `resumable_protocol`: `"gcs_native"` → adapter `cancel_resumable_upload`
  (existing); `"tus"` → adapter `abort_multipart_upload` (existing multipart
  path). The two converge in `do_delete_session_and_object`.
- **Same redaction.** `session_uri` (now the tus URL) is already redacted in
  `Inspect` and forbidden in telemetry.

The ONLY divergence is the **bytes path**: GCS-native = client→GCS (BEAM
untouched); tus = client→Rindle Plug→S3 UploadPart (BEAM mediates). That
divergence lives entirely in (a) the new `TusPlug`, (b) the new
`upload_part_stream/5` adapter callback, and (c) the `resumable_protocol`
branch points. Everything else is shared. **This is the coherent unification:
one resumable-session family, two protocols, discriminated by one column.**

---

## 8. Lessons from peers — concrete DO / AVOID

Verified live 2026-05-22 where cited.

### tusd (Go reference server)
- **DO**: server-side on-disk buffering of sub-5 MiB chunks before flushing as
  an S3 part (confirmed at tus.github.io/tusd/storage-backends/aws-s3 — "parts
  temporarily stored on disk to meet the minimum part size ... removed
  immediately" after upload). Rindle copies this for the S3 backing (§3b).
- **DO**: explicit lifecycle hooks (pre-create, pre-finish, post-finish,
  post-terminate). Rindle's equivalents are broker entrypoints + the
  `verify_completion` convergence.
- **AVOID (the headline footgun)**: tusd docs say "hooks are usually not
  retried ... if your post-processing step fails, tusd will not retry it. You
  should use another task management system" (confirmed at .../advanced-topics/hooks).
  **Rindle's structural answer:** the final-PATCH handler enqueues `PromoteAsset`
  inside the same `Ecto.Multi` that marks the session completed (already the
  pattern in `broker.ex:457-466`). If the txn commits, the job is durable; if
  not, the session is not completed. **No best-effort hook.** This is Rindle's
  single strongest differentiator vs tusd.
- **AVOID (the auth footgun)**: tusd docs admit "there is no mechanism to
  ensure that the upload is resumed by the same user that created it. We plan on
  addressing this in the future" (confirmed). Rindle does better with HMAC-signed
  URLs + optional rebind authorizer (§9).

### tus-ruby-server (Janko)
- **DO**: mountable endpoint + pluggable metadata store + explicit expiry
  cleanup. Rindle: mountable Plug + Repo-as-store + the v1.7 reaper.
- **AVOID**: tus-ruby-server warns Puma/Unicorn tie up a worker for the upload
  duration and recommends a non-blocking server (Falcon). **On the BEAM this
  footgun largely evaporates** — Bandit/Cowboy handle long-lived PATCHes on
  lightweight processes, not OS threads. Rindle's guide should say this
  explicitly (do NOT scare adopters into a special web server) but still lock
  `read_length`/`read_timeout` so a slow-loris PATCH cannot pin memory.

### Shrine + shrine-tus
- **DO**: "Approach C — unified storage" (the same storage backs both tus and
  the lifecycle; promotion is metadata-only). Rindle does this natively: tus
  PATCHes land in the Rindle storage adapter; completion is a `head` + metadata
  promote, no re-upload.
- **AVOID**: "Approach A — download through the tus server then re-upload to
  permanent storage." Doubles bandwidth, two sources of truth. Rindle's tus
  session IS the S3 multipart; completion is metadata-only.
- **DO (product boundary)**: Shrine treats tus as glue around the lifecycle, not
  the lifecycle. Rindle's positioning is identical — "Media, made durable" is
  the lifecycle; tus is one ingest path.

### Mux UpChunk (the contrast case — DECISIVE for Rindle)
- Mux deliberately did **not** adopt tus; UpChunk uses chunked `PUT` with
  `Content-Range` (confirmed at github.com/muxinc/upchunk). **This is exactly
  Topology A, which Rindle already ships in v1.7.** The lesson: a major video
  vendor concluded tus's auth model was insufficient and built session-URI
  resumable instead. Rindle should NOT read this as "skip tus" — it should read
  it as "Rindle already supports the UpChunk/GCS topology; tus adds the
  server-mediated topology for adopters who want server-side mediation. Rindle
  ends up supporting BOTH topologies, which is a stronger position than either
  vendor alone." And Rindle's HMAC-signed URLs are the explicit answer to the
  auth critique Mux had.

### Uppy `@uppy/tus` + tus-js-client (client pairing adopters expect)
- **DO**: document `@uppy/tus` and `tus-js-client` as the canonical clients.
  tus-js-client defaults (verified 2026-05-22): `retryDelays [0,1000,3000,5000]`,
  auto-retries 409/423, `parallelUploads: 1`. These match Rindle's 409-on-offset
  contract.
- **AVOID**: tus-js-client's `removeFingerprintOnSuccess` defaults to `false`,
  so resumable URLs persist in browser localStorage indefinitely → stale-URL
  accumulation. Guide must say "set `removeFingerprintOnSuccess: true` in
  production."
- **AVOID**: `parallelUploads > 1` (needs Concatenation, deferred). Document
  `parallelUploads: 1` only for v1.
- **DO (chunkSize)**: on HTTP/2 leave `chunkSize` alone; on HTTP/1.1 behind a
  body-buffering proxy, set `chunkSize` to ≥ 5 MiB to align with S3 part minimum.

### Vimeo (validation)
- Vimeo migrated their resumable upload API to tus (2018) for large video
  ingest at scale — validates tus as a stable choice for the AV killer case.

---

## 9. Auth + bearer-URL handling (LOCKED — the security-critical section)

Invariant 14 already names "tus upload URLs" as bearer credentials. The
machinery to enforce it exists (`Plug.Crypto` signing in `LocalPlug`;
`session_uri` redaction in `MediaUploadSession`). Locked posture:

1. **Auth at creation (`POST`):** the adopter's pipeline runs before the
   forward (their `:api`/`:browser` pipeline). The Plug captures the
   authenticated identity (via an adopter-supplied `:identity_fn` opt or the
   conn assigns) into the session row, then signs the tus URL:
   `Plug.Crypto.sign(secret_key_base, "rindle:tus:url", %{session_id: id,
   exp: ...})`. The signed token is the `Location` returned to the client and
   is stored (redacted) in `session_uri`.
2. **Auth at resume (`HEAD`/`PATCH`/`DELETE`):** the Plug verifies the HMAC
   token from the URL path with `Plug.Crypto.verify/3` (exactly as
   `local_plug.ex:66`). Missing/tampered/expired token → 404 (tus convention
   for unknown upload; do not leak existence) or 401. **Guessing the URL is
   insufficient — it must carry a valid Rindle signature.** This closes tusd's
   documented same-user-resume gap with a stronger default.
3. **Optional rebind authorizer:** `config :rindle, :tus_resume_authorizer,
   MyApp.TusAuth` — a callback that re-validates the resuming request's identity
   against the captured creator identity. Default is no-op (HMAC alone). Returns
   `:reject` → 401. This is the belt-and-suspenders answer to the Mux/tusd
   auth critique.
4. **Logging/inspect rule:** the signed tus URL never appears in logs,
   telemetry, or `inspect`. Already enforced: `session_uri` redacted in
   `Inspect` (`media_upload_session.ex:104-113`), forbidden in resumable
   telemetry metadata (`resumable_telemetry.ex:9`). v1.8 must extend the same
   redaction to any new tus telemetry events (§10).
5. **Rindle does not own the auth headers.** The adopter's pipeline owns
   authn/authz; Rindle owns session resolution + HMAC. The guide documents
   cookie (`:browser`) and bearer (`:api`) patterns; the security checklist
   requires one.
6. **Unauthenticated-mount footgun:** if the adopter forwards the tus Plug
   under an unauthenticated pipeline, anyone can create uploads → storage-cost
   DoS. The guide's security checklist must say this in red, and `init/1`
   should log a warning if it cannot detect an auth pipeline (best-effort).

---

## 10. DX / least surprise (LOCKED)

- **`Rindle.upload/3` stays boring.** No tus sugar on the facade. tus is opt-in,
  advanced, requires a JS client. The facade gains nothing.
- **One new broker entrypoint** (sibling to `initiate_resumable_session/2`):
  `initiate_tus_upload/2` returning `{:ok, %{session, location, expires_at,
  max_size}}`. `HEAD`/`PATCH`/`DELETE` are HTTP-only (the Plug), never Elixir
  functions — same decision the v1.6 plan made, correctly.
- **Copy-paste onboarding** (the entire surface):
  1. `pass: ["application/offset+octet-stream"]` in `Plug.Parsers`.
  2. `forward "/uploads/tus", Rindle.Upload.TusPlug, profile: ..., secret_key_base: ...`
     under your auth pipeline.
  3. `Rindle.Upload.Broker.initiate_tus_upload(MyApp.MediaProfile, filename: ...)`
     from your controller → returns the `Location`.
  4. Point `tus-js-client` / `@uppy/tus` at the `Location`.
  5. `mix rindle.doctor` confirms `:tus_upload` is honest.
- **Error vocabulary (additive to `Rindle.Error`, §4 of the v1.6 plan but
  pruned):** `:tus_session_not_found` (404), `:tus_session_expired` (410),
  `:tus_offset_conflict` (409), `:tus_size_exceeded` (413),
  `:tus_url_signature_invalid` (401), `{:upload_unsupported, :tus_upload}`.
  Each gets a fix-oriented `Rindle.Error.message/1` clause matching the existing
  AV/streaming pattern (`error.ex:46-324`).
- **`mix rindle.doctor` extension:** if a profile's adapter lacks `:tus_upload`
  but the adopter mounted `TusPlug` for it → report a configuration mismatch
  (mirrors the existing `--streaming` doctor checks).
- **CORS:** browser tus clients need CORS preflight on the tus endpoint. The
  guide documents the required `Access-Control-Expose-Headers`
  (`Upload-Offset`, `Location`, `Upload-Length`, `Tus-Resumable`, `Upload-Expires`)
  — a standard tus-server requirement adopters always trip over.

### Telemetry (LOCKED — extends the existing `[:rindle, :upload, :resumable, *]`)

Reuse the existing namespace. v1.7 ships `:status` and `:cancel`; tus adds the
edge events:

| Event | Measurements | Metadata (redacted) |
|---|---|---|
| `[:rindle, :upload, :resumable, :patch]` | `bytes`, `duration_native`, `offset_after` | `profile`, `adapter`, `session_id` |
| `[:rindle, :upload, :resumable, :start]` | `system_time` | `profile`, `adapter`, `session_id`, `protocol: :tus` |
| `[:rindle, :upload, :resumable, :stop]` | `system_time`, `total_bytes` | `profile`, `adapter`, `session_id`, `asset_id` |

`[:rindle, :upload, :stop]` continues to fire from `verify_completion/2` so
existing dashboards do not break. All tus events route through
`ResumableTelemetry.emit/*` so the `@forbidden_metadata_keys` allowlist
(`resumable_telemetry.ex:9`) keeps `session_uri`/`upload_key`/`body` out by
construction.

> Historical v1.8 note: this file uses pre-v1.9 shorthand. For the current
> support contract, see `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`,
> `.planning/ROADMAP.md`, and `guides/resumable_uploads.md`.

### Anti-DX traps (locked out)
- No silent downgrade. No tus URL in `inspect`. No server-side PATCH re-attempts
  (only client retries per protocol). No facade sugar.

---

## 11. Security invariants check (PROJECT.md numbered list)

| # | Invariant | tus impact | Status |
|---|---|---|---|
| 1 | Never trust client MIME/filename; magic-byte sniff | `Upload-Metadata` is opaque; `verify_completion` re-sniffs from `head` + profile validation | Preserved |
| 2 | No promote before completion verified | `PromoteAsset` enqueued only after `verify_completion` inside the txn | Preserved |
| 4 | Storage side effects outside DB txns | PATCH→S3 `UploadPart` happens outside the Repo txn; only offset bookkeeping is transactional | Preserved |
| 5 | Purge async, idempotent, auditable | Reuses v1.7 `UploadMaintenance` + `AbortIncompleteUploads`; tus adds an `abort_multipart_upload` branch (already idempotent on `:not_found`) | Preserved |
| 6 | Concurrent replacement races resolve safely | tus session 1:1 with asset + S3 multipart; abort + new initiate creates a new session | Preserved |
| 7 | Missing/stale/failed states queryable | `last_known_offset`, `state`, `resumable_protocol` are first-class columns | Preserved |
| 10 | Container metadata untrusted | `Upload-Metadata` opaque, truncated, not auto-rendered | Preserved |
| 11 | HLS/DASH/playlist ingest out of scope | tus accepts single-container files; validated post-completion | Preserved |
| 13 | Temp files under sweepable `Rindle.tmp/` | sub-5 MiB PATCH buffers + Local backing live under `Rindle.tmp/tus/`, reaped by existing sweeper | Preserved |
| 14 | Provider/bearer creds redacted | tus URL stored in (already-redacted) `session_uri`; HMAC-signed via `Plug.Crypto`; forbidden in telemetry | Preserved (already enforced) |

No new invariant needed — invariant 14 already names tus upload URLs explicitly
(added v1.6). v1.8 *exercises* it for the first time.

---

## 12. Scope cut & phase plan (LOCKED)

**IN v1.8:** tus Core + Creation + Expiration + Termination; bare-`Plug`
endpoint (no tussle, no Phoenix dep); S3 multipart-per-PATCH backing + Local
tmp-append backing; `:tus_upload` capability; HMAC-signed URLs + optional rebind
authorizer; convergence into `verify_completion`; reaper branch for tus;
DX/docs/doctor/telemetry; MinIO + tus-js-client CI proof of the
smartphone-AV-resume case.

**DEFERRED (documented as deferred, not "TBD"):** Checksum extension;
Concatenation / parallel uploads; `Upload-Defer-Length`; IETF RUFH / tus 2.0
(architect the Plug so a second protocol version is additive, §13);
GCS-as-tus-backend (GCS keeps its native Topology-A resumable); R2-native tus
proxying (point clients at R2 directly if they want it); a Rindle-owned
standalone tus JS client package (use tus-js-client / Uppy); richer reusable
uploader component abstractions beyond the supported helper path; and broader
future Phoenix upload abstractions (natural v1.9).

### Phases (continue numbering from v1.7's last phase = 41)

**Phase 42 — tus Protocol Edge (bare Plug, Core + Creation + Expiration + Termination)**
`TUS-01..05`. `Rindle.Upload.TusPlug` (`@behaviour Plug`, mounted via `forward`);
HEAD/PATCH/OPTIONS/POST/DELETE mechanics; HMAC URL signing/verify via
`Plug.Crypto`; `:tus_upload` capability added; broker `initiate_tus_upload/2`;
`resumable_protocol` migration; **Local tmp-append backing** as the first proven
sink; integration test: tus-js-client → Plug → Local → `verify_completion` →
ready asset across simulated PATCH retries. ~4 plans, ~3 days, **Medium** risk
(the "does a hand-rolled Plug get the offset/409/expiry mechanics exactly right"
risk lives here; mitigated by a contract test against the real tus-js-client).

**Phase 43 — S3 Multipart Backing + MinIO Proof**
`TUS-06..09`. New `upload_part_stream/5` adapter callback on `Rindle.Storage`
(optional); S3 impl (per-PATCH `UploadPart` ≥ 5 MiB; sub-5 MiB tmp buffer flush);
`S3` advertises `:tus_upload` after proof; completion →
`complete_multipart_upload` → `verify_completion`; reaper branch aborts the S3
multipart for abandoned tus sessions; MinIO integration: 1 GiB tus upload,
mid-flight drop + resume, abandonment + reaper asserts `list_multipart_uploads`
empty. ~4 plans, ~3–4 days, **Medium-High** risk (the real new code; part
buffering + idempotent cleanup are the trickiest pieces).

**Phase 44 — Auth Hardening, DX, Docs, Telemetry, CI Proof**
`TUS-10..14`. Optional rebind authorizer; tampered-URL contract tests
(401/404 never 200); `Rindle.Error` tus vocabulary + `message/1` clauses; tus
edge telemetry through `ResumableTelemetry`; `mix rindle.doctor` `:tus_upload`
check; `guides/resumable_uploads.md` (endpoint config, `Plug.Parsers :pass`,
CORS, tus-js-client/`@uppy/tus` config, security checklist); generated-app
package-consumer proof lane: `mix phx.new` adopter mounts `TusPlug`, Node
tus-js-client uploads a ~200 MB MP4 against MinIO with one simulated drop,
asserts a `ready` `MediaAsset` with expected `byte_size`/`content_type`.
~3 plans, ~2 days, **Low-Medium** risk.

**Total: 3 phases, ~9–11 plans, ~7–9 focused engineering days.** Roughly half
the v1.6 plan's 5 phases / ~18 plans / ~13–15 days — the delta is exactly the
v1.7 substrate already shipped (§0).

---

## 13. The one strategic caveat: IETF RUFH (tus 2.0)

Verified 2026-05-22: `draft-ietf-httpbis-resumable-upload-11` published
2026-04-20, still an Internet-Draft (NOT an RFC), actively progressing —
discussed at IETF 125 (March 2026) and FOSDEM 2026 ("Resumable uploads on the
web: past, present and future"). It introduces `104 Upload Resumption Supported`
and the `application/partial-upload` media type, and tus itself maintains it as
"tus-v2."

**Implication:** tus 1.0 (2016) is a transitional standard. Betting Rindle's
resumable HTTP edge entirely on tus 1.0 risks a rewrite when RUFH lands as an
RFC and clients migrate. **Mitigation (cheap, lock it now):** because we are
rolling our own Plug (not vendoring tussle, which only speaks 1.0 anyway),
structure `TusPlug` so protocol-version handling is a dispatch seam — the offset
bookkeeping, S3 backing, HMAC auth, and `verify_completion` convergence are
**protocol-agnostic** and live in the broker/storage layer; only the
header-parsing/response-shaping is tus-1.0-specific. When RUFH stabilizes,
adding `protocol: :rufh` is a second handler over the same session machinery —
exactly the additive shape the `resumable_protocol` column already anticipates.
This is, notably, a point IN FAVOR of rolling our own over adopting tussle:
tussle is locked to tus 1.0 with no RUFH path.

This caveat does NOT change the recommendation (tus 1.0 is what real clients —
Uppy, tus-js-client, Vimeo's stack — speak today), but it is why the edge must
be a thin, swappable protocol layer over Rindle's own session substrate.

---

## 14. Locked recommendation

**v1.8 = tus resumable upload protocol. YES. Confidence HIGH on shape.**

But the shape is materially revised from the v1.6 candidate plan, because v1.7
already shipped the substrate that plan assumed it would build:

1. **Roll a bare-`Plug` tus endpoint. Do NOT add `tussle`** (2 stars, 104
   downloads, forces a Phoenix dependency Rindle does not have, locked to tus
   1.0 with no RUFH path). Reuse the in-repo `WebhookPlug`/`LocalPlug` idiom and
   `Plug.Crypto` signing.
2. **Reuse `upload_strategy: "resumable"` + the `"resuming"` FSM lane + the
   broker resumable entrypoints + the v1.7 reaper.** Add ONE column
   (`resumable_protocol`) and ONE adapter callback (`upload_part_stream/5`).
   No `tus_*` columns, no new table, no new FSM, no new completion vocabulary.
3. **The real work is S3 multipart-per-PATCH backing** (Phase 43). Everything
   else is edge + glue.
4. **One new capability atom `:tus_upload`** (Topology B), kept distinct from
   v1.7's `:resumable_upload` (Topology A). No silent downgrade.
5. **Scope: Core + Creation + Expiration + Termination.** Defer Checksum,
   Concatenation, `Upload-Defer-Length`, RUFH, GCS-as-tus, R2-native proxy.
6. **3 phases (42–44), ~9–11 plans, ~7–9 days** — half the v1.6 estimate.
7. **Architect the Plug as a thin, protocol-versioned edge** so IETF RUFH is an
   additive second handler, not a rewrite (§13).

Why not override the candidate entirely (the bar is high, per PROJECT.md): the
architecture cost is now low (substrate paid by v1.7), the killer case (mobile
AV resume) is genuinely unsolved by presigned PUT / client-multipart, the
mountable-Plug idiom and HMAC primitives already exist, and tus completes a
resumable story that currently stops arbitrarily at "GCS only." The only soft
spot is *demand evidence* (no in-repo adopter ticket); given the lowered cost,
that does not clear the bar to override a locked, leading candidate — but it is
the thing to confirm with adopter feedback before committing the milestone, and
the thing to drop the milestone for if a louder pain (e.g. browser→Mux
direct creator upload, `MUX-20..23`, also carried) surfaces first.

---

## Sources

### Live-verified 2026-05-22

- tus protocol 1.0.0: https://tus.io/protocols/resumable-upload (HEAD/PATCH/OPTIONS/POST, `Upload-Offset`, 409 on mismatch, `application/offset+octet-stream`, Creation/Expiration[410]/Termination[DELETE]/Checksum[460]/Concatenation; "Server SHOULD NOT process these partial uploads until they are concatenated")
- IETF RUFH draft-11 (2026-04-20, NOT an RFC; IETF 125 Mar 2026): https://datatracker.ietf.org/doc/draft-ietf-httpbis-resumable-upload/ ; https://httpwg.org/http-extensions/draft-ietf-httpbis-resumable-upload.html ; FOSDEM 2026 talk: https://fosdem.org/2026/schedule/event/7QNJXM-resumable_uploads_on_the_web_past_present_and_future/
- tussle v0.3.1 (2026-03-24; **104 total downloads, 38 this version, 4 last 7 days**, BSD-3): https://hex.pm/packages/tussle
- tussle source (**2 stars, 0 forks, 0 issues, 70 commits**; mix.exs deps = `plug ~> 1.3`, `uuid`, NO phoenix; routes via Phoenix.Router DSL): https://github.com/jvantuyl/tussle ; https://github.com/jvantuyl/tussle/blob/main/mix.exs
- tussle routes (`add_tus_routes/1` requires a Phoenix router; cannot be used in plain Plug.Router): https://hexdocs.pm/tussle/Tussle.Routes.html
- extus (dormant, v0.1.0 2017): https://hex.pm/packages/extus
- tusd S3 backend (on-disk buffering for sub-min-part-size chunks): https://tus.github.io/tusd/storage-backends/aws-s3/
- tusd hooks (hooks "usually not retried"; "use another task management system"; "no mechanism to ensure that the upload is resumed by the same user that created it"): https://tus.github.io/tusd/advanced-topics/hooks/
- tus-js-client (defaults `retryDelays [0,1000,3000,5000]`, auto-retry 409/423, `parallelUploads 1`, `removeFingerprintOnSuccess` default false): https://www.npmjs.com/package/tus-js-client ; https://github.com/tus/tus-js-client/blob/main/docs/api.md
- Uppy `@uppy/tus`: https://uppy.io/docs/tus/
- Mux UpChunk (does NOT use tus; chunked PUT + Content-Range; Topology A): https://github.com/muxinc/upchunk ; https://www.mux.com/docs/guides/upload-files-directly
- tus-ruby-server (mountable, worker-tie-up warning): https://github.com/janko/tus-ruby-server
- shrine-tus (unified-storage "Approach C"): https://github.com/shrinerb/shrine-tus

### Local project context (read in full this pass)

- /Users/jon/projects/rindle/.planning/PROJECT.md (vision, Core Value, 14 security invariants, constraints, Key Decisions; names v1.8 tus as the leading locked candidate)
- /Users/jon/projects/rindle/.planning/research/v1.6-CANDIDATE-TUS.md (prior LOCKED plan, 6/10 — now stale per §0)
- /Users/jon/projects/rindle/.planning/research/TUS-CANDIDATE-MEMO.md (prior memo, 4/10 — stale)
- /Users/jon/projects/rindle/prompts/phoenix-media-uploads-lib-deep-research.md ("support simple direct upload first, then S3 multipart and tus as adapters"; concatenation partial-upload rule; capability modeling)
- /Users/jon/projects/rindle/prompts/gsd-rindle-elixir-oss-dna.md (behavior seams + capability boundaries; "do not fake parity where providers differ materially"; NimbleOptions; telemetry metadata allowlists)
- /Users/jon/projects/rindle/lib/rindle/storage.ex (behaviour + resumable optional callbacks added v1.7; lines 219-285)
- /Users/jon/projects/rindle/lib/rindle/storage/capabilities.ex (`:resumable_upload`/`:resumable_upload_session` already real, lines 11-28)
- /Users/jon/projects/rindle/lib/rindle/storage/s3.ex (multipart callbacks reused by tus backing; lines 72-127, 152)
- /Users/jon/projects/rindle/lib/rindle/storage/gcs.ex (Topology-A native resumable; advertises resumable atoms, line 141)
- /Users/jon/projects/rindle/lib/rindle/upload/broker.ex (`initiate_resumable_session/2`, `resumable_session_status/2`, `cancel_resumable_session/2`, `verify_completion/2`, compensation patterns; lines 182-485, 566-640)
- /Users/jon/projects/rindle/lib/rindle/upload/resumable_telemetry.ex (existing resumable telemetry + redaction allowlist)
- /Users/jon/projects/rindle/lib/rindle/domain/media_upload_session.ex (schema: `session_uri`, `last_known_offset`, `multipart_*`; custom redacting `Inspect`; lines 48-113)
- /Users/jon/projects/rindle/lib/rindle/domain/upload_session_fsm.ex (`"resuming"` lane shipped v1.7; line 9)
- /Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex (resumable + multipart abort/cleanup; lines 135-155, 273-368, 413-555)
- /Users/jon/projects/rindle/lib/rindle/workers/abort_incomplete_uploads.ex (the two-step reaper to extend)
- /Users/jon/projects/rindle/lib/rindle/delivery/webhook_plug.ex (the mountable bare-Plug idiom to mirror; `init/1` fail-fast, `forward` mount, raw-body reader)
- /Users/jon/projects/rindle/lib/rindle/delivery/local_plug.ex (`Plug.Crypto.sign`/`verify` bearer-token signing pattern reused for tus URLs; line 66)
- /Users/jon/projects/rindle/lib/rindle/error.ex (tagged-error vocabulary + `message/1` pattern to extend; lines 46-336)
- /Users/jon/projects/rindle/mix.exs (deps: `plug ~> 1.16`, `phoenix_live_view` optional, NO `phoenix`; `ex_aws*`, `oban`, `goth`/`finch` optional)
