# Roadmap: Rindle

## Milestones

- 🚧 **v1.8 Resumable Browser Ingest** — Phases 42–45 (in progress, started 2026-05-22)
- ✅ **v1.7 GCS Resumable Adapter** — Phases 37–41 (shipped 2026-05-08, see archive)
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07, see archive)
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06, see archive)
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, see archive)
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, see archive)
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, see archive)
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, see archive)
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, see archive)

## Overview

v1.8 makes unreliable-network, large-file, browser-origin uploads durable.
Rindle already ships Topology A resumable (v1.7 GCS: bytes go client→provider via
a session URI, the BEAM never touches them). v1.8 adds the other half:

1. **Topology B — the tus 1.0 protocol** served by a bare `Rindle.Upload.TusPlug`
   (no `tussle`, no Phoenix dependency) where upload bytes flow client→Rindle→S3
   `UploadPart` (or a Local tmp file). Built across three phases: the HTTP
   protocol edge proven on Local backing (Phase 42), the S3 multipart-per-PATCH
   backing proven against MinIO (Phase 43), and the auth/DX/docs/CI proof that
   makes it adopter-ready (Phase 44).

2. **Browser → Mux direct creator upload** (Phase 45) — a sibling slice where
   bytes go client→Mux directly and Rindle brokers a one-time URL, completing the
   reserved v1.6 `create_direct_upload/2` callback. Explicitly **droppable** under
   budget pressure; it is the clean cut if the milestone runs long.

Every phase converges into the one trusted `verify_completion/2` promote lane —
one resumable-session family (`media_upload_sessions` + the `"resuming"` FSM lane),
one new discriminator column (`resumable_protocol`), one new adapter callback
(`upload_part_stream/5`), one new capability atom (`:tus_upload`). No new
completion vocabulary, no parallel table, no silent downgrade. Phase 34/35
advisory code-review hygiene rides along (POLISH-01 in Phase 42, POLISH-02 in
Phase 44) at natural file locality. Cut Hex `0.2.0` (additive, pre-1.0) at close.

The locked architecture lives in `.planning/research/v1.8/` and is authoritative:
the bare-Plug / one-column / `:tus_upload`-atom decisions are not relitigated here.

## Phases

**Phase Numbering:**

- Continues from v1.7 (last phase = 41). v1.8 starts at Phase 42 — numbering is
  NOT reset across milestones.

- Integer phases (42, 43, …): planned milestone work.
- Decimal phases (42.1, …): urgent insertions (none yet).

- [x] **Phase 42: tus Protocol Edge (bare Plug)** - Mountable `Rindle.Upload.TusPlug` serving Core + Creation + Expiration + Termination over HMAC-signed URLs, proven end-to-end on Local tmp-append backing (completed 2026-05-22)
- [ ] **Phase 43: S3 Multipart Backing + MinIO Proof** - `upload_part_stream/5` adapter callback flushing PATCH chunks to S3 `UploadPart`, with a MinIO ≥ 1 GiB drop-and-resume and reaper cleanup proof
- [ ] **Phase 44: Auth Hardening, DX, Docs, Telemetry, CI Proof** - Optional resume authorizer, tus error vocabulary, edge telemetry, doctor checks, the resumable-uploads guide, and a generated-app tus-js-client CI proof
- [ ] **Phase 45: Browser → Mux Direct Creator Upload (sibling, droppable)** - Reserved `create_direct_upload/2` implemented, the `video.upload.asset_created` linker, a thin streaming entrypoint, and LiveView `:external`/UpChunk DX

## Phase Details

### Phase 42: tus Protocol Edge (bare Plug)

**Goal**: An adopter can mount a bare tus 1.0 endpoint in their router (adding no Phoenix dependency) and a real tus client can create, resume across drops, complete, and delete a resumable upload that promotes through the existing verify lane — proven against Local tmp-append backing.
**Depends on**: Phase 41 (v1.7 resumable substrate: `media_upload_sessions`, the `"resuming"` FSM lane, broker resumable entrypoints, `session_uri` redaction, the reaper)
**Requirements**: TUS-01, TUS-02, TUS-03, TUS-04, TUS-05, POLISH-01
**Success Criteria** (what must be TRUE):

  1. An adopter mounts `Rindle.Upload.TusPlug` (a bare `@behaviour Plug` with `init/1`+`call/2`) via `forward "/uploads/tus", ...` in a Phoenix Router OR a `Plug.Router`, under their own auth pipeline, and Rindle adds no Phoenix dependency.
  2. A tus client creates an upload (`POST` with `Upload-Length` + opaque `Upload-Metadata` → `201` + `Location`), reads the authoritative offset (`HEAD` → `204` + `Upload-Offset`, `Cache-Control: no-store`), resumes via `PATCH` (`application/offset+octet-stream`) getting `204` + new offset, receives `409` on offset mismatch, and `OPTIONS` advertises `Tus-Version`/`Tus-Resumable`/`Tus-Extension`/`Tus-Max-Size` for only the implemented extensions.
  3. Every tus URL is HMAC-signed via `Plug.Crypto.sign/verify` against `secret_key_base` and verified on each `HEAD`/`PATCH`/`DELETE`; a missing/tampered/expired signature returns `404`/`401`, never `200`, and the URL is stored redacted in `session_uri` and never appears in logs/telemetry/`inspect`.
  4. A `tus-js-client` contract test uploads through the Plug to the Local tmp-append sink (`Rindle.tmp/tus/`, atomic-rename on completion) across simulated PATCH retries and produces a `ready` `MediaAsset` via the existing `verify_completion/2` lane; the additive migration adds exactly one `resumable_protocol` column (`"gcs_native" | "tus"`, nil for legacy) plus a covering index, and the `:tus_upload` capability atom is registered.
  5. Phase 34 advisory code-review findings (9 Warning + 3 Info in `34-REVIEW.md`) are resolved via `/gsd-code-review 34 --fix` or explicitly waived with rationale (POLISH-01).

**Plans**: 4 plans

- [x] 42-01-PLAN.md — Foundation: :tus_upload capability + resumable_protocol migration/schema + Broker.initiate_tus_upload/2 + Local tmp-append backing [Wave 1]
- [x] 42-02-PLAN.md — TusPlug edge: init/1 capability raise, OPTIONS, POST (HMAC sign + Location), path_info token verify, HEAD [Wave 2]
- [x] 42-03-PLAN.md — TusPlug PATCH hot path (409/415/413 + streaming), completion into unchanged verify_completion/2, DELETE, full resume contract flow [Wave 3]
- [x] 42-04-PLAN.md — POLISH-01: D-13 selective Mux code-review fixes (8 fix / 3 waive / 1 document), tus-isolated [Wave 1, parallel]

**UI hint**: no

### Phase 43: S3 Multipart Backing + MinIO Proof

**Goal**: An S3-compatible adapter can serve tus by streaming each PATCH into an S3 multipart upload, completing through the existing verify lane, and abandoned tus sessions are reliably reaped — proven against MinIO with a ≥ 1 GiB drop-and-resume and a zero-leak abort assertion.
**Depends on**: Phase 42 (the tus protocol edge, `:tus_upload` capability, `resumable_protocol` discriminator, broker `initiate_tus_upload/2`)
**Requirements**: TUS-06, TUS-07, TUS-08, TUS-09
**Success Criteria** (what must be TRUE):

  1. A new OPTIONAL `upload_part_stream/5` callback on `Rindle.Storage` is implemented by S3 as one `UploadPart` per `PATCH` ≥ 5 MiB, buffering a sub-5 MiB final chunk under `Rindle.tmp/tus/` and flushing it as the final part on completion (the tusd S3-backend pattern).
  2. Adapters advertise `:tus_upload` honestly — only if they implement `upload_part_stream/5` (S3 + Local in v1; GCS does NOT, keeping native Topology-A resumable); mounting `TusPlug` against an adapter without `:tus_upload` raises at `init/1` (deploy-time failure, no silent downgrade to presigned/multipart/GCS).
  3. tus completion (final `PATCH`, `offset == length`) calls `complete_multipart_upload/4` then converges into the existing `verify_completion/2` lane — head-based content re-sniff, size/type validation against the profile, `PromoteAsset` enqueued in the same `Ecto.Multi` — with zero new completion vocabulary.
  4. tus sessions expire (`expires_at` → `Upload-Expires` + `410 Gone`) and `DELETE` terminates; the `UploadMaintenance`/`AbortIncompleteUploads` reaper branches on `resumable_protocol` (`"tus"` → abort the S3 multipart or remove the local tmp; `"gcs_native"` → existing session-URI cancel).
  5. A MinIO integration proof completes a ≥ 1 GiB tus upload with a mid-flight drop + resume, and asserts that after abandonment + reaper, `list_multipart_uploads` returns empty.

**Plans**: 10 plans (5 shipped + 5 gap-closure for the 3/5 verification gaps)

- [x] 43-01-PLAN.md — Wave 0: declare upload_part_stream/5 + complete_part_stream/4 OPTIONAL callbacks + test scaffolding (2 NEW test files, 3 extended)
- [x] 43-02-PLAN.md — S3 adapter: tail-buffer upload_part_stream/5 (ETag-from-headers), complete_part_stream/3, advertise :tus_upload
- [x] 43-03-PLAN.md — Reaper: branch expire_session on resumable_protocol; tus -> abort S3 multipart (closes the orphaned-multipart leak)
- [x] 43-04-PLAN.md — Local impl + TusPlug polymorphic dispatch; converge into UNCHANGED verify_completion/2 (D-08)
- [x] 43-05-PLAN.md — MinIO >= 1 GiB drop+resume + list_multipart_uploads-empty zero-leak proof (+ CI checkpoint)
- [x] 43-06-PLAN.md — Gap closure: S3 adapter tus_tail_path/2 helper (CR-02 source) + cross-node loud-fail guard + single-node moduledoc (CR-04) [Wave 1]
- [x] 43-07-PLAN.md — Gap closure: Rindle.tmp/ sweeper recurses into tus/ to age out tus/*.tail & *.part regular files (CR-03) [Wave 1]
- [x] 43-08-PLAN.md — Gap closure: reaper routes remove_tus_tail through S3.tus_tail_path (CR-02 wiring) + Local-root abort (IN-03) + FSM-gated tus expiry (WR-01) + reusable abort helper [Wave 2]
- [ ] 43-09-PLAN.md — Gap closure: tus DELETE aborts the backing multipart (CR-01) + honours update result (WR-02) + Plug single-node moduledoc (CR-04) [Wave 3]
- [ ] 43-10-PLAN.md — Gap closure: MinIO proof — DELETE-then-list_multipart_uploads-empty + post-reap tail-gone (SC5/IN-04) [Wave 4]

**UI hint**: no

### Phase 44: Auth Hardening, DX, Docs, Telemetry, CI Proof

**Goal**: tus is adopter-ready and trustworthy — optional same-user resume authorization, fix-oriented errors, edge telemetry, doctor diagnostics, a copy-pasteable guide, and a generated-app package-consumer proof that a browser tus client survives a network drop against real storage.
**Depends on**: Phase 43 (S3 backing + reaper proven; the tus path is functionally complete)
**Requirements**: TUS-10, TUS-11, TUS-12, TUS-13, TUS-14, POLISH-02
**Success Criteria** (what must be TRUE):

  1. An optional resume authorizer (`config :rindle, :tus_resume_authorizer, MyApp.TusAuth`) re-validates the resuming request's identity against the captured creator identity (default no-op, HMAC alone; `:reject` → `401`), and tampered-URL contract tests confirm signature failures return `401`/`404` and never `200`.
  2. tus errors surface through `Rindle.Error` with tagged reasons (`:tus_session_not_found`, `:tus_session_expired`, `:tus_offset_conflict`, `:tus_size_exceeded`, `:tus_url_signature_invalid`, `{:upload_unsupported, :tus_upload}`), each with a fix-oriented `message/1` clause matching the existing AV/streaming pattern.
  3. tus edge telemetry emits through the existing `[:rindle, :upload, :resumable, *]` namespace (`:start`, `:patch`, `:stop`) via `ResumableTelemetry`, preserving the forbidden-metadata-key allowlist (no `session_uri`/`upload_key`/`body`), and `mix rindle.doctor` reports a tus capability/config mismatch when a profile mounts `TusPlug` against an adapter lacking `:tus_upload`.
  4. `guides/resumable_uploads.md` documents endpoint config (`Plug.Parsers :pass` for `application/offset+octet-stream`; CORS expose-headers `Upload-Offset`/`Location`/`Upload-Length`/`Tus-Resumable`/`Upload-Expires`; tus-js-client / `@uppy/tus` config incl. `removeFingerprintOnSuccess: true` + `parallelUploads: 1`), the security checklist, and the no-silent-downgrade contract.
  5. A generated-app package-consumer CI proof lane mounts `TusPlug`, uploads a ≥ 200 MB MP4 with one simulated drop against MinIO via a Node tus-js-client, and asserts a `ready` `MediaAsset` with the expected `byte_size`/`content_type`; Phase 35 advisory code-review findings (6 Warning + 7 Info) are resolved via `/gsd-code-review 35 --fix` or explicitly waived with rationale (POLISH-02).

**Plans**: TBD
**UI hint**: no

### Phase 45: Browser → Mux Direct Creator Upload (sibling, droppable)

**Goal**: A browser can upload a large video directly to Mux through a Rindle-brokered one-time URL, and Rindle reconciles the resulting asset and notifies LiveView clients — completing the reserved v1.6 direct-creator-upload seam. **Droppable under budget pressure: this is the clean cut if the milestone runs long.**
**Depends on**: Phase 41 (v1.6/v1.7 Mux substrate: reserved `create_direct_upload/2` callback, the `video.upload.asset_created` webhook branch, `media_provider_assets` FSM, `:provider_asset_created` PubSub event, redaction machinery). Independent of the tus phases (42–44).
**Requirements**: MUX-20, MUX-21, MUX-22, MUX-23
**Success Criteria** (what must be TRUE):

  1. The Mux adapter implements the reserved `create_direct_upload/2` — returning `%{upload_url, upload_id, provider_asset_id: nil}` via `Mux.Video.Uploads.create/2` with a required `cors_origin`, `new_asset_settings.playback_policies`, and `passthrough` ≤ 255 chars — and advertises the `:direct_creator_upload` capability.
  2. The `video.upload.asset_created` webhook branch is upgraded from a no-op stub into the upload→asset linker: it correlates the upload to its Rindle provider-asset row via Mux `passthrough` (stamped at create time), stamps `provider_asset_id`, transitions the FSM, and broadcasts the already-reserved `:provider_asset_created` PubSub event; one additive nullable correlation column is added and redacted in `Inspect`/telemetry.
  3. An adopter requests a direct upload via a thin streaming-side entrypoint (`Rindle.Streaming.create_direct_upload/2`, capability-gated via `Capabilities.supports?/2`) that creates a `"pending"` `media_provider_assets` row with `ingest_mode: "direct_creator_upload"`, stamps `passthrough`, and returns ONLY `%{upload_url, asset_id}` (the Rindle asset id) — never the raw Mux upload/asset id.
  4. A LiveView adopter wires a browser direct upload via an `:external`/UpChunk helper (`Rindle.LiveView.allow_direct_upload/4`) + `subscribe(:provider_asset, id)`, with a controller/JSON variant documented as the baseline.
  5. A `guides/streaming_providers.md` section plus an end-to-end test (create upload → simulate `video.upload.asset_created` + `video.asset.ready` → assert both PubSub events) cover the flow.

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 42 → 43 → 44 → 45. Phase 45 (Mux direct upload)
is independent of 42–44 and may be reordered or dropped under budget pressure
without affecting the tus spine.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 42. tus Protocol Edge (bare Plug) | v1.8 | 4/4 | Complete    | 2026-05-22 |
| 43. S3 Multipart Backing + MinIO Proof | v1.8 | 8/10 | In Progress|  |
| 44. Auth Hardening, DX, Docs, Telemetry, CI Proof | v1.8 | 0/TBD | Not started | - |
| 45. Browser → Mux Direct Creator Upload (droppable) | v1.8 | 0/TBD | Not started | - |

## Carried Forward Candidates

None outstanding for v1.8 — the v1.7 carried-forward candidates (tus protocol,
browser→Mux direct upload) are now in-milestone scope above.

## Deferred to v1.9+

tus Checksum/Concatenation; `Upload-Defer-Length`; IETF RUFH (tus 2.0,
draft-11); GCS-as-tus-backend; R2-native tus proxying; a Rindle-owned tus JS
client; a LiveView tus uploader component; a second streaming provider
(Cloudflare/Bunny); `cancel_direct_upload/1` (Mux).

## Archive

- `.planning/milestones/v1.7-ROADMAP.md`
- `.planning/milestones/v1.7-REQUIREMENTS.md`
- `.planning/milestones/v1.7-MILESTONE-AUDIT.md`
- `.planning/milestones/v1.7-phases/`

<details>
<summary>✅ v1.6 Provider Boundary + Mux (Phases 33–36) — SHIPPED 2026-05-07</summary>

Full archive: [.planning/milestones/v1.6-ROADMAP.md](milestones/v1.6-ROADMAP.md)

</details>

<details>
<summary>✅ v1.5 Adopter Hardening & Lifecycle Repair (Phases 29–32) — SHIPPED 2026-05-06</summary>

Full archive: [.planning/milestones/v1.5-ROADMAP.md](milestones/v1.5-ROADMAP.md)

</details>

<details>
<summary>✅ v1.4 Video & Audio Wedge (Phases 23–28) — SHIPPED 2026-05-05</summary>

Full archive: [.planning/milestones/v1.4-ROADMAP.md](milestones/v1.4-ROADMAP.md)

</details>

<details>
<summary>✅ v1.3 Live Publish & API Ergonomics (Phases 15–22) — SHIPPED 2026-05-02</summary>

Full archive: [.planning/milestones/v1.3-ROADMAP.md](milestones/v1.3-ROADMAP.md)

</details>

<details>
<summary>✅ v1.2 First Hex Publish (Phases 10–14) — SHIPPED 2026-04-29</summary>

Full archive: [.planning/milestones/v1.2-ROADMAP.md](milestones/v1.2-ROADMAP.md)

</details>

<details>
<summary>✅ v1.1 Adopter Hardening (Phases 6–9) — SHIPPED 2026-04-28</summary>

Full archive: [.planning/milestones/v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 MVP (Phases 1–5) — SHIPPED</summary>

Full archive: [.planning/milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>
