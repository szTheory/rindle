# Requirements: Rindle v1.8 — Resumable Browser Ingest

**Defined:** 2026-05-22
**Core Value:** Media, made durable.
**Source:** Research-driven locked recommendation in `.planning/research/v1.8/`
(`TUS-RESEARCH.md`, `MUX-DIRECT-UPLOAD-RESEARCH.md`, `STRATEGY-SEQUENCING.md`).
These supersede the now-stale `v1.6-CANDIDATE-TUS.md` and `TUS-CANDIDATE-MEMO.md`,
both of which predate v1.7 — which already shipped ~60% of the "tus foundations"
substrate (broker resumable lane, `"resuming"` FSM, `session_uri` redaction,
resumable telemetry, the reaper, capability machinery).

**Goal:** Make unreliable-network, large-file, browser-origin uploads durable.
Ship the tus 1.0 protocol on a mountable **bare `Plug`** (no `tussle`, no Phoenix
dependency) backed by S3 multipart-per-PATCH and Local tmp-append; pull forward
browser→Mux direct creator upload; so every browser ingest path Rindle exposes is
resume-safe and converges into the one trusted `verify_completion/2` promote lane.

**Locked architecture decisions (override the v1.6 candidate plan):**

- Roll a bare `Rindle.Upload.TusPlug` (mirror `WebhookPlug`/`LocalPlug`). Do NOT
  add `tussle` (verified dead: 2 stars / 104 downloads; its routes macro forces
  Phoenix, which Rindle does not depend on).

- Reuse `upload_strategy: "resumable"` + the `"resuming"` FSM lane + broker
  resumable entrypoints + the v1.7 reaper. Add exactly ONE column
  (`resumable_protocol`) and ONE adapter callback (`upload_part_stream/5`).

- New `:tus_upload` capability atom (Topology B: server-mediated, bytes on the
  BEAM hot path), distinct from v1.7's `:resumable_upload` (Topology A:
  provider-direct session URI). No silent downgrade.

- Scope = tus Core + Creation + Expiration + Termination only.

## v1.8 Requirements

### tus Protocol Edge (bare Plug)

- [x] **TUS-01**: Adopter mounts `Rindle.Upload.TusPlug` (a bare `@behaviour Plug`
  with `init/1`+`call/2`) via `forward "/uploads/tus", Rindle.Upload.TusPlug, ...`
  in their router (Phoenix Router OR `Plug.Router`), under their own auth
  pipeline, adding NO Phoenix dependency to Rindle. Mirrors the in-repo
  `WebhookPlug`/`LocalPlug` mount idiom.

- [x] **TUS-02**: tus client creates a resumable upload — `POST` with
  `Upload-Length` + opaque `Upload-Metadata` returns `201` + `Location` (an
  HMAC-signed tus URL bound to a broker session created via
  `Rindle.Upload.Broker.initiate_tus_upload/2`, which initiates the S3 multipart
  upload and persists a `"resumable"` session with `resumable_protocol: "tus"`).

- [x] **TUS-03**: tus client reads the authoritative offset (`HEAD` → `204` +
  `Upload-Offset` from `last_known_offset`, `Cache-Control: no-store`) and
  resumes by `PATCH` (`application/offset+octet-stream`) at that offset, getting
  `204` + new `Upload-Offset` on success and **`409`** on offset mismatch (the
  contract tus-js-client auto-retries).

- [x] **TUS-04**: `OPTIONS` advertises `Tus-Version`, `Tus-Resumable`,
  `Tus-Extension` (creation, expiration, termination — only what is implemented),
  and `Tus-Max-Size`.

- [x] **TUS-05**: tus upload URLs are HMAC-signed via `Plug.Crypto.sign/verify`
  against `secret_key_base`, verified on every `HEAD`/`PATCH`/`DELETE`;
  missing/tampered/expired signature → `404`/`401`, never `200`. URLs are stored
  (already-redacted) in `session_uri` and never appear in logs, telemetry, or
  `inspect`. Additive migration adds ONE column `resumable_protocol`
  (`"gcs_native" | "tus"`; nil for legacy) + a covering index; the **Local**
  adapter is the first proven tus sink (tmp-append under `Rindle.tmp/tus/`,
  atomic-rename on completion).

### Storage Backing (S3 multipart-per-PATCH)

- [x] **TUS-06**: New OPTIONAL adapter callback `upload_part_stream/5` on
  `Rindle.Storage`; the S3 adapter implements it as one S3 `UploadPart` per
  `PATCH` ≥ 5 MiB, buffering a sub-5 MiB final chunk under `Rindle.tmp/tus/` and
  flushing it as the final part on completion (the tusd S3-backend pattern).

- [ ] **TUS-07**: Adapters advertise the new `:tus_upload` capability honestly —
  only if they implement `upload_part_stream/5` (S3 + Local in v1; GCS does NOT,
  it keeps native Topology-A resumable). Mounting `TusPlug` against an adapter
  without `:tus_upload` raises at `init/1` (deploy-time failure; **no silent
  downgrade** to presigned/multipart/GCS).

- [ ] **TUS-08**: tus completion (final `PATCH`, `offset == length`) calls
  `complete_multipart_upload/4` then converges into the existing
  `verify_completion/2` lane — head-based content re-sniff, size/type validation
  against the profile, `PromoteAsset` enqueued in the same `Ecto.Multi`. **Zero
  new completion vocabulary.**

- [x] **TUS-09**: tus sessions expire via `expires_at` → `Upload-Expires` header
  + `410 Gone`; `DELETE` terminates. The existing
  `UploadMaintenance`/`AbortIncompleteUploads` reaper branches on
  `resumable_protocol`: `"tus"` → abort the S3 multipart (or remove the local
  tmp); `"gcs_native"` → existing session-URI cancel. MinIO proof: a ≥ 1 GiB
  tus upload with a mid-flight drop + resume completes, and abandonment + reaper
  asserts `list_multipart_uploads` is empty.

### Auth, DX, Docs, Proof

- [ ] **TUS-10**: Optional resume authorizer
  (`config :rindle, :tus_resume_authorizer, MyApp.TusAuth`) re-validates the
  resuming request's identity against the captured creator identity; default is
  no-op (HMAC alone). Returns `:reject` → `401`. (The belt-and-suspenders answer
  to the tusd/Mux "same-user-resume" gap.)

- [ ] **TUS-11**: tus errors surface through `Rindle.Error` with tagged reasons
  — `:tus_session_not_found`, `:tus_session_expired`, `:tus_offset_conflict`,
  `:tus_size_exceeded`, `:tus_url_signature_invalid`,
  `{:upload_unsupported, :tus_upload}` — each with a fix-oriented `message/1`
  clause matching the existing AV/streaming pattern.

- [ ] **TUS-12**: tus edge telemetry emits through the existing
  `[:rindle, :upload, :resumable, *]` namespace (`:start`, `:patch`, `:stop`)
  via `ResumableTelemetry`, preserving the forbidden-metadata-key allowlist (no
  `session_uri`/`upload_key`/`body` in metadata).

- [ ] **TUS-13**: `mix rindle.doctor` reports tus capability/config mismatches
  (a profile mounts `TusPlug` but its adapter lacks `:tus_upload`), mirroring the
  existing `--streaming` doctor checks.

- [ ] **TUS-14**: A `guides/resumable_uploads.md` documents tus endpoint config
  (`Plug.Parsers :pass` for `application/offset+octet-stream`; CORS expose-headers
  `Upload-Offset`/`Location`/`Upload-Length`/`Tus-Resumable`/`Upload-Expires`;
  tus-js-client / `@uppy/tus` config incl. `removeFingerprintOnSuccess: true` +
  `parallelUploads: 1`), the security checklist, and the no-silent-downgrade
  contract. A generated-app package-consumer CI proof lane mounts `TusPlug`,
  uploads a ≥ 200 MB MP4 with one simulated drop against MinIO via a Node
  tus-js-client, and asserts a `ready` `MediaAsset` with the expected
  `byte_size`/`content_type`.

### Browser → Mux Direct Creator Upload (sibling — droppable under budget)

- [ ] **MUX-20**: The Mux adapter implements the reserved `create_direct_upload/2`
  callback — returns `%{upload_url, upload_id, provider_asset_id: nil}` (the
  asset id is unknown at create time) via `Mux.Video.Uploads.create/2` with a
  required `cors_origin`, `new_asset_settings.playback_policies`, and `passthrough`
  ≤ 255 chars — and advertises the `:direct_creator_upload` capability.

- [ ] **MUX-21**: The `video.upload.asset_created` webhook branch is upgraded
  from a no-op stub into the upload→asset linker: it correlates the upload to its
  Rindle provider-asset row via Mux `passthrough` (stamped at create time),
  stamps `provider_asset_id`, transitions the FSM, and broadcasts the
  already-reserved `:provider_asset_created` PubSub event. One additive nullable
  correlation column is added (redacted in `Inspect`/telemetry).

- [ ] **MUX-22**: Adopter requests a direct upload via a thin streaming-side
  entrypoint (`Rindle.Streaming.create_direct_upload/2`, capability-gated via the
  existing `Capabilities.supports?/2`) that creates a `"pending"`
  `media_provider_assets` row with `ingest_mode: "direct_creator_upload"`,
  stamps `passthrough`, and returns ONLY `%{upload_url, asset_id}` (the Rindle
  asset id) — never the raw Mux upload/asset id.

- [ ] **MUX-23**: LiveView adopters wire a browser direct upload via an
  `:external`/UpChunk helper (`Rindle.LiveView.allow_direct_upload/4`) +
  `subscribe(:provider_asset, id)`; a `guides/streaming_providers.md` section + an
  end-to-end test (create upload → simulate `video.upload.asset_created` +
  `video.asset.ready` → assert both PubSub events) cover the flow. A
  controller/JSON variant is the documented baseline.

### Code-Review Polish (hygiene sub-stream)

- [x] **POLISH-01**: Phase 34 advisory code-review findings (9 Warning + 3 Info
  in `34-REVIEW.md`) are resolved via `/gsd-code-review 34 --fix`, or explicitly
  waived with rationale. Folded into the foundation phase (natural locality —
  these touch Mux files that MUX-20..23 also touch).

- [ ] **POLISH-02**: Phase 35 advisory code-review findings (6 Warning + 7 Info)
  are resolved via `/gsd-code-review 35 --fix`, or explicitly waived with
  rationale. Folded into the docs/CI phase.

## Out of Scope (v1.8)

Explicitly excluded; deferred to v1.9+ or permanently out of scope. Documented to
prevent scope creep and "why didn't you include X" later.

| Feature | Reason |
|---------|--------|
| tus Checksum extension (per-chunk SHA-1, 460) | TLS prevents transit corruption; `verify_completion` validates final size/type. Add on demand. |
| tus Concatenation / parallel partial uploads | Real complexity; conflicts with the per-PATCH `UploadPart` flush. Document `parallelUploads: 1`. |
| `Upload-Defer-Length` (size unknown at create) | S3 multipart wants a size estimate for part planning; require `Upload-Length` in v1. |
| IETF RUFH / tus 2.0 (`104 Upload Resumption`) | draft-11, not an RFC. Architect the Plug as a protocol-versioned edge so RUFH is additive later. |
| `tussle` dependency | Verified dead (2 stars / 104 downloads); forces Phoenix; locked to tus 1.0. Roll a bare Plug. |
| GCS-as-tus-backend | GCS keeps native Topology-A resumable; tus targets S3/Local. |
| R2-native tus proxying | Point clients at R2's own native tus surface if they want it. |
| Rindle-owned tus JS client | Use tus-js-client / `@uppy/tus`. |
| LiveView tus uploader component | Natural v1.9 follow-on. |
| Second streaming provider (Cloudflare/Bunny) | The contract test for v1.7+; no demand signal yet. |
| `cancel_direct_upload/1` (Mux) | Mux auto-`timed_out` covers most cases; defer unless asked. |

## Traceability

Which phases cover which requirements. Phase numbering continues from v1.7
(last phase = 41); v1.8 spans Phases 42–45.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TUS-01 | Phase 42 — tus Protocol Edge (bare Plug) | Complete |
| TUS-02 | Phase 42 — tus Protocol Edge (bare Plug) | Complete |
| TUS-03 | Phase 42 — tus Protocol Edge (bare Plug) | Complete |
| TUS-04 | Phase 42 — tus Protocol Edge (bare Plug) | Complete |
| TUS-05 | Phase 42 — tus Protocol Edge (bare Plug) | Complete |
| POLISH-01 | Phase 42 — tus Protocol Edge (bare Plug) | Complete |
| TUS-06 | Phase 43 — S3 Multipart Backing + MinIO Proof | Complete |
| TUS-07 | Phase 43 — S3 Multipart Backing + MinIO Proof | Pending |
| TUS-08 | Phase 43 — S3 Multipart Backing + MinIO Proof | Pending |
| TUS-09 | Phase 43 — S3 Multipart Backing + MinIO Proof | Complete |
| TUS-10 | Phase 44 — Auth Hardening, DX, Docs, Telemetry, CI Proof | Pending |
| TUS-11 | Phase 44 — Auth Hardening, DX, Docs, Telemetry, CI Proof | Pending |
| TUS-12 | Phase 44 — Auth Hardening, DX, Docs, Telemetry, CI Proof | Pending |
| TUS-13 | Phase 44 — Auth Hardening, DX, Docs, Telemetry, CI Proof | Pending |
| TUS-14 | Phase 44 — Auth Hardening, DX, Docs, Telemetry, CI Proof | Pending |
| POLISH-02 | Phase 44 — Auth Hardening, DX, Docs, Telemetry, CI Proof | Pending |
| MUX-20 | Phase 45 — Browser → Mux Direct Creator Upload (droppable) | Pending |
| MUX-21 | Phase 45 — Browser → Mux Direct Creator Upload (droppable) | Pending |
| MUX-22 | Phase 45 — Browser → Mux Direct Creator Upload (droppable) | Pending |
| MUX-23 | Phase 45 — Browser → Mux Direct Creator Upload (droppable) | Pending |

**Coverage:**

- v1.8 requirements: 20 total (14 TUS + 4 MUX + 2 POLISH)
- Mapped to phases: 20 ✓ (every requirement → exactly one phase, no orphans, no duplicates)
- Unmapped: 0 ✓

**Phase distribution:**

- Phase 42 (tus Protocol Edge): TUS-01..05 + POLISH-01 (6)
- Phase 43 (S3 Multipart Backing + MinIO Proof): TUS-06..09 (4)
- Phase 44 (Auth, DX, Docs, Telemetry, CI Proof): TUS-10..14 + POLISH-02 (6)
- Phase 45 (Browser → Mux Direct Creator Upload, droppable): MUX-20..23 (4)

---
*Requirements defined: 2026-05-22*
*Last updated: 2026-05-22 — roadmap created; 100% coverage mapped across Phases 42–45.*
