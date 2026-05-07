# Roadmap: Rindle

## Milestones

- 🚧 **v1.7 GCS Resumable Adapter** — Phases 37–41 (in progress; see Active Milestone)
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07, see archive)
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06, see archive)
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, see archive)
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, see archive)
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, see archive)
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, see archive)
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, see archive)

## Active Milestone

### v1.7 GCS Resumable Adapter (Phases 37–41)

**Goal:** Productize `Rindle.Storage.GCS` as a real second storage adapter
implementing the existing `Rindle.Storage` behaviour, and promote
`:resumable_upload` + `:resumable_upload_session` capabilities from reserved
to shipped — extending v1.4/v1.5's "named-preset, capability-honest,
adopter-owned runtime" posture to cover GCS-style resumable uploads without
making Rindle a file-server.

**Source of truth for scope and shape:**
[`.planning/research/v1.6-CANDIDATE-GCS.md`](research/v1.6-CANDIDATE-GCS.md)
(carried forward unchanged from v1.6 candidate evaluation, score 7.5/10;
locked on technical shape).

**Effort estimate:** ~13 working days locked (Phases 37–41), 18 plans, MEDIUM
overall risk. Comparable in shape to v1.4 Phase 23+24 combined — wide enough
to be meaty, narrow enough to ship in one milestone.

**Note on phase numbering:** v1.6 reserved Phase 37 for browser→Mux direct
creator upload (MUX-20..23) but did not pull it forward — Phases 33–36 closed
under budget without it. The Phase 37 slot is reused here for v1.7's GCS
Adapter Foundation; the deferred Mux direct-creator-upload work moves to
v1.8+ candidate scope.

**New security invariant (locked v1.7):** session URIs returned by resumable
initiation are bearer credentials. They must never be logged,
telemetry-tagged, inspected, or persisted unencrypted in shared logs. The
adapter and broker enforce this via a custom `Inspect` impl on
`MediaUploadSession` that redacts `session_uri` to `"[REDACTED]"`; adopters
are responsible for not exposing session URIs in their own logs/UI.

#### Phase Summary

| Phase | Name | Requirements | Plans | Effort | Risk |
|-------|------|--------------|-------|--------|------|
| 37 | GCS Adapter Foundation | GCS-01..04 (4) | 4 | ~3 days | LOW |
| 38 | Resumable Persistence + FSM | RESUMABLE-01..03 (3) | 3 | ~2 days | LOW |
| 39 | Resumable Adapter Behaviour + Broker Wiring | RESUMABLE-04..08 (5) | 5 | ~4 days | MEDIUM |
| 40 | Maintenance + Cancel Contract | RESUMABLE-09..11 (3) | 3 | ~2 days | LOW |
| 41 | Onboarding + Docs + Doctor + Package-Consumer Proof | RESUMABLE-12..14 (3) | 3 | ~2 days | LOW |

**Totals:** 5 phases, 18 plans, 18 requirements covered.

**Deferred candidates (not v1.7 scope; carried forward):**

| Candidate | REQ-IDs | Locked plan | Status |
|-----------|---------|-------------|--------|
| Browser → Mux Direct Creator Upload | MUX-20..23 (4) | v1.6 Phase 37 (reserved-but-never-executed in v1.6) | Deferred to v1.8+ |
| tus Resumable Upload Protocol | TUS-01..19 (19) | [`v1.6-CANDIDATE-TUS.md`](research/v1.6-CANDIDATE-TUS.md) | Deferred to v1.8 |

#### Phase Details

##### Phase 37 — GCS Adapter Foundation

**Goal:** Land `Rindle.Storage.GCS` as a real `Rindle.Storage` adapter against
the live GCS bucket using `goth ~> 1.4` for auth and `finch ~> 0.21` for HTTP.
No resumable behaviour yet — that ships in Phases 38–39 once the foundation
is proven against a real bucket. Promote signed delivery and `head/2`
checks; defer `:resumable_upload*` capability advertisement until Phase 39.

**Depends on:** v1.6 archive (Phase 36 shipped); no new external Elixir
dependencies beyond `goth ~> 1.4` + `finch ~> 0.21` (already transitive
via Goth) + `gcs_signed_url ~> 0.4.6`.

**Requirements:** GCS-01, GCS-02, GCS-03, GCS-04 (4 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `Rindle.Storage.GCS` implements every required `Rindle.Storage` callback —
   `store/3`, `download/3`, `delete/2`, `head/2`, `url/2` — against a real
   GCS bucket using a configurable Goth instance name (`MyApp.Goth`) and a
   configurable Finch instance name (`MyApp.Finch`); the adapter does not
   start Goth or Finch itself, matching the existing "adopter owns the
   runtime" posture.
2. `Rindle.Storage.GCS.capabilities/0` returns `[:signed_url, :head]` only
   at end-of-phase; `:resumable_upload` and `:resumable_upload_session` atoms
   are explicitly NOT advertised yet (they ship in Phase 39); image-only
   profile can `Rindle.upload/3` to GCS using the local-file ingest path with
   no resumable behaviour.
3. V4 signed URL generation works via `gcs_signed_url ~> 0.4.6` in
   private-key auth mode; signed-URL TTL respects
   `Rindle.Config.signed_url_ttl_seconds/0`; `Content-Disposition` and
   `Content-Type` are written into object metadata at `store/3` (not URL
   params), per the Active Storage lesson that GCS V4 signed URLs do not
   safely enforce `response-content-disposition` / `response-content-type`.
4. The standalone GCS proof lane in CI is gated behind
   `GOOGLE_APPLICATION_CREDENTIALS_JSON`; the lane runs on PR only when the
   secret is present, and runs on release always (mirrors the existing
   MinIO lane discipline). Fork PRs without the secret skip the lane.
5. `mix test --only gcs` passes against the real bucket; `mix rindle.doctor`
   reports GCS adapter health when configured (Goth running, bucket
   reachable, signing key present); image-only S3 adopters see no new
   noise in `doctor` output.

**Plans:** 4 plans

Plans:
- [x] 37-01-PLAN.md — Hand-rolled Finch JSON-API client (Rindle.Storage.GCS.Client) + optional dep declarations + dialyzer PLT entries (Wave 1, GCS-01)
- [ ] 37-02-PLAN.md — V4 signed URL wrapper (Rindle.Storage.GCS.Signer) over gcs_signed_url Client mode + signing-key dispatch + TTL fallback (Wave 2, GCS-03)
- [ ] 37-03-PLAN.md — Public Rindle.Storage.GCS @behaviour adapter + capabilities/0 lock + cross-adapter parity test extension + hexdoc grouping (Wave 3, GCS-01, GCS-02)
- [ ] 37-04-PLAN.md — gcs-soak CI lane (secret-gated) + mix rindle.doctor GCS health checks (profile-aware) (Wave 4, GCS-04)

**UI hint**: no

##### Phase 38 — Resumable Persistence + FSM

**Goal:** Land the additive `media_upload_sessions` migration (template form,
shipped under `priv/repo/migrations` as a generator template — adopters run
their own migrations against their adopter-owned Repo), the FSM transition
into `"resuming"`, the bearer-credential redaction discipline on
`MediaUploadSession`, and the resumable telemetry vocabulary. No adapter
behaviour callbacks yet — those ship in Phase 39 once the persistence layer
is in place.

**Depends on:** Phase 37 (GCS adapter ships `store/3`, `download/3`, `head/2`,
`url/2` against a real bucket; CI lane proven).

**Requirements:** RESUMABLE-01, RESUMABLE-02, RESUMABLE-03 (3 total).

**Success criteria** (what must be TRUE when this phase ships):

1. A reversible Ecto migration template ships in Rindle's source tree under
   `priv/repo/migrations` adding `session_uri` (text), `session_uri_expires_at`
   (utc_datetime_usec), `last_known_offset` (bigint, default 0, not null),
   and `region_hint` (string, size 64, nullable) to `media_upload_sessions`;
   `upload_strategy` allowed values widen to
   `["presigned_put", "multipart", "resumable"]`. The migration ships as a
   generator-template `priv/repo/migrations` file (NOT as an
   `Ecto.Migration` Rindle runs directly against an adopter Repo) — adopters
   own their runtime Repo and run the migration themselves, consistent with
   the v1.1 invariant. A partial index on `session_uri_expires_at` filtered
   to `upload_strategy = 'resumable'` exists for the maintenance worker's
   expiry sweep.
2. `Rindle.Domain.MediaUploadSession.changeset/2` casts the four new fields;
   `Rindle.Domain.UploadSessionFSM` gains state `"resuming"` between
   `"signed"` and `"uploading"` with the locked allowed transition set
   `"signed" → "resuming" → "uploading"`. The existing
   `"uploading" → "uploaded" → "verifying" → "completed"` lane and the
   cancel path (any non-terminal state → `"aborted"`) are unchanged.
3. A custom `Inspect` impl on `MediaUploadSession` redacts `session_uri` to
   `"[REDACTED]"` whenever the field is populated; `inspect/2` output
   never reveals the raw URI in any operator surface (logs, error reports,
   `IEx.dbg`, ExUnit failure output).
4. Two new telemetry events emit:
   `[:rindle, :upload, :resumable, :status]` and
   `[:rindle, :upload, :resumable, :cancel]`, modelled on the existing
   `[:rindle, :upload, :start | :stop]` shape; `session_uri` is provably
   absent from telemetry metadata, logger metadata, and `inspect/2` output
   (a parity test asserts the redaction at every emit site, mirroring
   Phase 34's security-invariant-14 redaction parity test for Mux).
5. Existing presigned-PUT and multipart proofs ship unchanged; FSM tests
   cover the new `"resuming"` state and the cancel-from-`"resuming"`
   transition; `mix rindle.doctor` confirms the new columns exist on the
   adopter-owned `media_upload_sessions` table.
6. `guides/storage_gcs.md` (drafted in Phase 41) documents the
   `Logger.add_translator` / logger-metadata-filter recipe for adopters who
   want defence-in-depth against accidental `session_uri` leakage in their
   own application logs.

**Plans:** 3 plans (TBD by `/gsd-plan-phase 38`). Plan-count guidance:
RESUMABLE-01..03 ≈ 3 plans, one per requirement; LOW risk, additive
migration template + FSM transition + telemetry naming, no external
dependencies.

**UI hint**: no

##### Phase 39 — Resumable Adapter Behaviour + Broker Wiring

**Goal:** Highest-surface phase. Promote `:resumable_upload` and
`:resumable_upload_session` from reserved to shipped capability atoms; wire
the four new `@optional_callbacks` on `Rindle.Storage`; ship the GCS
implementation of all four; ship the three new broker entrypoints; lock the
public error vocabulary; prove an end-to-end resumable upload against a real
GCS bucket.

**Depends on:** Phase 37 (`Rindle.Storage.GCS` adapter foundation, real-bucket
CI lane) + Phase 38 (`media_upload_sessions` columns, FSM `"resuming"` state,
`session_uri` redaction discipline, resumable telemetry vocabulary).

**Requirements:** RESUMABLE-04, RESUMABLE-05, RESUMABLE-06, RESUMABLE-07,
RESUMABLE-08 (5 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `Rindle.Storage` behaviour adds four `@optional_callbacks` with the locked
   arities documented in `v1.6-CANDIDATE-GCS.md` §4:
   `initiate_resumable_upload/3`, `resumable_upload_status/3`,
   `cancel_resumable_upload/3`, `verify_resumable_completion/3`. Return
   shapes match the locked typespecs (`resumable_init_result`,
   `resumable_status_result`, `head_result`, plus locked error tuples).
2. `Rindle.Storage.GCS` implements all four callbacks via a hand-rolled JSON
   API client over Finch against
   `https://storage.googleapis.com/upload/storage/v1/b/$BUCKET/o?uploadType=resumable`
   (NOT `google_api_storage`); `capabilities/0` becomes
   `[:signed_url, :head, :resumable_upload, :resumable_upload_session]`.
3. `Rindle.Upload.Broker` ships three new public entrypoints —
   `initiate_resumable_session/2` → `resumable_session_status/2` →
   `cancel_resumable_session/2` — with the locked typespecs and return
   shapes; `verify_completion/2` is unchanged (it remains the single trust
   gate, calling the adapter's `head/2`); storage I/O happens before the DB
   transaction; persist failure triggers a compensating `cancel_resumable_upload/3`
   (mirrors the existing `compensate_failed_multipart_persist/4` shape).
4. End-to-end resumable upload against a real GCS bucket: a test fixture
   streams chunked PATCHes via Finch from a streamed body to a session URI
   minted by `initiate_resumable_session/2`; `verify_completion/2` finds the
   final object via `head/2` and promotes it; the `media_provider_assets`
   row reaches the locked terminal state. `Rindle.Storage.S3.capabilities/0`
   and `Rindle.Storage.Local.capabilities/0` are confirmed NOT to advertise
   `:resumable_upload` or `:resumable_upload_session`; calling resumable
   broker entrypoints against either returns
   `{:error, {:upload_unsupported, :resumable_upload_session}}` with no
   silent fallback.
5. Every locked public error atom from `v1.6-CANDIDATE-GCS.md` §4 is
   returnable from a real adapter path and exercised by tests:
   `{:upload_unsupported, _}`, `:session_uri_expired`,
   `:session_uri_unknown`, `{:offset_mismatch, %{server: _, client: _}}`,
   `:region_pinned_initiation`, `{:gcs_http_error, %{status: _, body: _}}`,
   `:goth_unconfigured`, `:missing_bucket`, `:storage_object_missing`. All
   atoms ship in `Rindle.Error.t()`'s reason union and in `guides/storage_gcs.md`.
6. The presigned-PUT and S3 multipart contracts ship unchanged; no S3-side
   capability flips, no auto-fallback resumable→PUT or PUT→resumable, no
   silent reuse of S3 multipart as "resumable."

**Plans:** 5 plans (TBD by `/gsd-plan-phase 39`). Plan-count guidance:
RESUMABLE-04..08 ≈ 5 plans (one per requirement); MEDIUM risk — most
surface-area churn in v1.7 lives here (new behaviour callbacks, broker
entrypoints, end-to-end real-bucket proof, public error vocabulary lock).
Roughly 40% of v1.7 effort.

**UI hint**: no

##### Phase 40 — Maintenance + Cancel Contract

**Goal:** Idempotent cleanup of resumable sessions through the existing two-step
maintenance lane (`AbortIncompleteUploads` then `CleanupOrphans`), with
`runtime_status` operator visibility into stuck/expired resumable sessions.
Reuses the existing maintenance lane; cancel idempotency is the only real
engineering work.

**Depends on:** Phase 39 (resumable adapter callbacks, broker entrypoints,
`{:error, :session_uri_unknown}` / `{:error, :session_uri_expired}` atoms
returnable from a real GCS adapter path).

**Requirements:** RESUMABLE-09, RESUMABLE-10, RESUMABLE-11 (3 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `Rindle.Ops.UploadMaintenance.abort_incomplete_uploads/1` queries sessions
   where `state IN ("signed", "uploading", "resuming")` AND
   `expires_at < now()`; for `upload_strategy = "resumable"` rows it
   dispatches `cancel_resumable_upload/3` on the adapter; both
   `{:error, :session_uri_unknown}` and `{:error, :session_uri_expired}`
   count as idempotent success (the remote is gone or never existed). The
   maintenance report distinguishes `:resumable_aborts` from
   `:multipart_aborts` and `:presigned_put_aborts` counters.
2. Local row deletion happens ONLY after the remote cancel returns success
   or an idempotent error; remote-failure paths leave the row in the
   terminal `"aborted"` FSM state with `failure_reason` populated, available
   to a retry via existing Oban backoff. `CleanupOrphans` deletes rows in
   `state = "expired"` only when the resumable cancel has already confirmed
   the remote is gone.
3. `mix rindle.runtime_status` surfaces three new resumable counters:
   `resumable_sessions_pending` (rows in `"signed"`, `"resuming"`, or
   `"uploading"` with `upload_strategy = "resumable"`),
   `resumable_sessions_expired` (`session_uri_expires_at < now()`), and a
   COUNT (NOT URI) of stale session URIs past `session_uri_expires_at`. The
   raw `session_uri` is provably never in `runtime_status` output.
4. The real GCS proof lane (added in Phase 37; extended in Phase 39) covers
   two end-to-end maintenance scenarios: (a) initiate → cancel → cleanup
   (idempotent; the row reaches `"aborted"` then is removed by
   `CleanupOrphans`); (b) initiate → expire → cleanup (the GCS server has
   already 410'd the URI; the cancel returns `:session_uri_expired`; the
   row is removed). Orphaned sessions are visible in `runtime_status`
   between the steps.
5. Telemetry: the existing `[:rindle, :cleanup, :run]` measurement gains a
   `:resumable_aborts` integer field; the existing
   `mix rindle.abort_incomplete_uploads` and `mix rindle.cleanup_orphans`
   tasks learn the new resumable path automatically (they delegate to the
   `Ops.UploadMaintenance` module).

**Plans:** 3 plans (TBD by `/gsd-plan-phase 40`). Plan-count guidance:
RESUMABLE-09..11 ≈ 3 plans (one per requirement); LOW risk, reuses the
existing two-step maintenance lane.

**UI hint**: no

##### Phase 41 — Onboarding + Docs + Doctor + Package-Consumer Proof

**Goal:** Lock the adopter onboarding path for GCS resumable uploads; prove
the package-consumer story matches v1.5's image-only / AV-enabled bar and
v1.6's mux-enabled bar. Mirrors the v1.4/v1.5/v1.6 onboarding-phase shape.

**Depends on:** Phase 40 (resumable maintenance lane working end-to-end;
`runtime_status` counters in place; CI proof lane functional through the
full lifecycle).

**Requirements:** RESUMABLE-12, RESUMABLE-13, RESUMABLE-14 (3 total).

**Success criteria** (what must be TRUE when this phase ships):

1. `guides/storage_gcs.md` ships maintainer-to-maintainer: bucket setup
   walk-through, service-account JSON wiring with `MyApp.Goth` supervision,
   a copy-pasteable `gsutil cors set` recipe explicitly enabling `PATCH`
   and `PUT` methods + `Content-Range` and `x-goog-resumable` allowed
   headers, a "session URI is a bearer credential" callout, the
   one-week session expiry callout, the region-pin cost callout, the
   `cloak_ecto` recipe for at-rest encryption of `session_uri`, and the
   logger metadata filter recipe for defence-in-depth.
2. `mix rindle.doctor` adds GCS-aware checks gated on the profile actually
   declaring a GCS storage backend: Goth instance running and reachable,
   bucket reachable via a 5s `head` probe, signing key configured (private
   key present + valid format), CORS-suspected warning when the profile
   uses `:resumable_upload_session` (since CORS is the dominant
   first-deploy footgun). The check is profile-aware so image-only S3
   adopters see no new noise.
3. The capability matrix in `guides/storage_capabilities.md` is updated to
   reflect that `:resumable_upload` and `:resumable_upload_session` are
   now shipped (no longer reserved); `Rindle.Storage.GCS` advertises both;
   `Rindle.Storage.S3` and `Rindle.Storage.Local` advertise neither;
   adopter-supplied custom adapters can advertise either, both, or
   neither honestly.
4. The generated-app package-consumer proof harness gains a `gcs-enabled`
   lane alongside the existing `image-only`, `av-enabled`, and
   `mux-enabled` lanes; a fresh `mix phx.new` adopter installs Rindle,
   declares a GCS profile, runs `mix rindle.doctor`, and exercises the
   canonical adopter lifecycle test (initiate resumable session →
   chunked PATCH → verify completion → asset promoted) against a real
   GCS bucket. The lane is gated by `GOOGLE_APPLICATION_CREDENTIALS_JSON`
   and runs on every PR when the secret is present (mirroring v1.5's MinIO
   discipline and v1.6's mux-cassette discipline).
5. README and getting-started gain a "Storage with GCS (optional)"
   subsection (≤15 lines) that points at the new `guides/storage_gcs.md`
   while the image and AV onboarding paths remain the canonical
   first-run story; HexDocs render confirms the new guide and capability
   matrix update appear correctly post-publish.

**Plans:** 3 plans (TBD by `/gsd-plan-phase 41`). Plan-count guidance:
RESUMABLE-12..14 ≈ 3 plans (one per requirement); LOW risk, mirrors v1.4
Phase 28 / v1.5 Phase 32 / v1.6 Phase 36 onboarding-phase shape — mostly
DX/docs/CI-infra integration rather than novel runtime work.

**UI hint**: no

#### Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 37 — GCS Adapter Foundation | 0/4 | Not started | — |
| 38 — Resumable Persistence + FSM | 0/3 | Not started | — |
| 39 — Resumable Adapter Behaviour + Broker Wiring | 0/5 | Not started | — |
| 40 — Maintenance + Cancel Contract | 0/3 | Not started | — |
| 41 — Onboarding + Docs + Doctor + Package-Consumer Proof | 0/3 | Not started | — |

#### Coverage

- Total v1.7 requirements: **18** (GCS-01..04 = 4, RESUMABLE-01..14 = 14)
- Mapped: **18 / 18** ✓
- Orphaned: 0
- Duplicated across phases: 0

## Archive

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
