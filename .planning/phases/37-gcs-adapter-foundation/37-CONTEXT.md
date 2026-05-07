# Phase 37: GCS Adapter Foundation - Context

**Gathered:** 2026-05-07 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Land `Rindle.Storage.GCS` as a real `Rindle.Storage` adapter against the live
GCS bucket using `goth ~> 1.4` for auth and `finch ~> 0.21` for HTTP.
Implements the 5 standard `Rindle.Storage` callbacks (`store/3`, `download/3`,
`delete/2`, `head/2`, `url/2`) plus V4 signed URL generation via
`gcs_signed_url ~> 0.4.6` (private-key auth mode). `capabilities/0` returns
`[:signed_url, :head]` ONLY at end-of-phase; `:resumable_upload` and
`:resumable_upload_session` atoms are explicitly NOT advertised yet (they
ship in Phase 39).

**Requirements:** GCS-01, GCS-02, GCS-03, GCS-04 (4 total).

**Out of scope (deferred to later phases):**
- Resumable upload behaviour callbacks → Phase 39 (RESUMABLE-04..08)
- `media_upload_sessions` resumable columns + FSM `"resuming"` state → Phase 38
- Resumable-specific `mix rindle.doctor` CORS-suspected check → Phase 41 (RESUMABLE-13). (Basic Goth/bucket/signing-key health checks DO ship in Phase 37 per D-13.)
- Package-consumer GCS proof lane (fresh `mix phx.new` install) → Phase 41 (RESUMABLE-14)
- IAM SignBlob auth mode → v1.7+ behind config flag
- Customer-supplied session URIs, CMEK, Object Versioning → out
</domain>

<decisions>
## Implementation Decisions

### Module File Layout

- **D-01:** `Rindle.Storage.GCS` ships as a 3-file split:
  - `lib/rindle/storage/gcs.ex` — `@behaviour Rindle.Storage` impl + capability
    + config helpers (the public, hexdoc'd module).
  - `lib/rindle/storage/gcs/client.ex` — `@moduledoc false` hand-rolled Finch
    JSON-API wrapper for `head/store/download/delete` over
    `https://storage.googleapis.com/storage/v1/b/$BUCKET/o`.
  - `lib/rindle/storage/gcs/signer.ex` — `@moduledoc false` V4-signing wrapper
    around `gcs_signed_url ~> 0.4.6`.
  - **Why split (vs S3's single file):** S3 delegates to `ExAws.S3.*` and owns
    no protocol code. GCS hand-rolls ~250 LOC over Finch (locked candidate
    §11), and Phases 38–41 add 4 more callbacks (`initiate_resumable_upload/3`,
    `resumable_upload_status/3`, `cancel_resumable_upload/3`,
    `verify_resumable_completion/3`) sharing the same auth/HTTP plumbing.
    Splitting now avoids a churny rename later.

### Public Contract (Mirrors `Rindle.Storage.S3`)

- **D-02:** `head/2` returns `{:ok, %{size: integer, content_type: binary | nil}}`
  with `{:error, :not_found}` for HTTP 404 — exact shape mirror of
  `lib/rindle/storage/s3.ex:130-149` and the parity assertion at
  `test/rindle/storage/s3_test.exs:117`. Cross-adapter parity test at
  `test/rindle/storage/storage_adapter_test.exs:41-51` MUST stay green.

- **D-03:** `store/3` writes `Content-Type` and `Content-Disposition` as
  **GCS object metadata** (the bucket-side fields, not URL query params) at
  upload time. Active Storage lesson (locked candidate §8.7 + §10): GCS V4
  signed URLs do NOT safely enforce `response-content-disposition` /
  `response-content-type`, so disposition/type lives in object metadata.

- **D-04:** `url/2` accepts `expires_in` opt and falls back to
  `Rindle.Config.signed_url_ttl_seconds/0` — exact mirror of
  `lib/rindle/storage/s3.ex:55-61`. V4 signing only (V2 is legacy per Google
  docs); private-key auth mode in Phase 37 (IAM SignBlob deferred to v1.7+).

- **D-05:** Phase 37 does NOT touch `lib/rindle/error.ex`. Error atoms
  (`:goth_unconfigured`, `:missing_bucket`, `:storage_object_missing`,
  `{:gcs_http_error, %{status, body}}`) route through the generic
  `def message(%{action: action, reason: reason})` fallthrough at
  `lib/rindle/error.ex:334-336`. `lib/rindle/error.ex` only adds bespoke
  `message/1` branches for user-facing fix-oriented atoms (FFmpeg, capability
  drift, streaming, Mux); Phase 37 atoms are bare-atom transport errors that
  fit the fallthrough pattern (cf. S3's `:missing_bucket` at
  `lib/rindle/storage/s3.ex:173-178`).

### Optional Deps + Config Keying

- **D-06:** Add to `mix.exs deps/0` matching the v1.6 streaming-deps pattern
  at `mix.exs:67-69`:
  - `{:goth, "~> 1.4", optional: true}`
  - `{:finch, "~> 0.21", optional: true}` (already transitive via Goth, but
    declared explicitly with `optional: true` for hex-tooling honesty)
  - `{:gcs_signed_url, "~> 0.4.6", optional: true}`
  - **Adopters who don't enable GCS pay zero transitive cost** — same posture
    as v1.6's `mux ~> 3.2` + `jose ~> 1.11`.

- **D-07:** Extend `mix.exs:22` `dialyzer.plt_add_apps` from
  `[:mix, :ex_unit, :mux, :jose]` to add `:goth` and `:gcs_signed_url`. (Not
  `:finch` — already in tree as a non-optional dep elsewhere; verify in plan.)

- **D-08:** Config keyspace mirrors S3's `Application.get_env(:rindle, __MODULE__, [])`
  pattern (`lib/rindle/storage/s3.ex:173-177`):
  ```
  config :rindle, Rindle.Storage.GCS,
    bucket: "my-bucket",
    goth: MyApp.Goth,
    finch: MyApp.Finch,
    signing_key: %{...},  # service-account JSON or PEM
    signed_url_ttl: 3600,
    region_hint: "us-central1"
  ```
  Rindle does NOT start Goth or Finch — adopter owns the runtime, exactly
  like the existing Repo/Oban/Goth posture from v1.4/v1.6.

- **D-09:** Optional-dep guard at runtime entry: `Code.ensure_loaded?(Goth)`
  returning `{:error, :goth_unconfigured}` when missing — mirrors
  `lib/rindle/ops/runtime_checks.ex:536`'s `Code.ensure_loaded?(Mux.Video.Assets)`
  pattern. Non-GCS adopters get a clean error tuple instead of `Code.LoadError`.

### CI Proof Lane + Test Harness

- **D-10:** Add a `gcs-soak` job to `.github/workflows/ci.yml` mirroring the
  shape of `mux-soak` at `.github/workflows/ci.yml:566-653`, but **gated on
  secret presence** rather than label:
  ```yaml
  if: ${{ secrets.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' }}
  ```
  REQUIREMENTS GCS-04 specifies "runs on PR only when secret is present, runs
  on release always" — that's the secret-presence pattern. Fork-PR safe:
  forks resolve the secret to `''` and the lane skips cleanly (mirrors
  existing MinIO lane discipline from v1.5).

- **D-11:** Tests at `test/rindle/storage/gcs_test.exs` tagged `@tag :gcs`
  with a `@gcs_skip_reason` module attribute that nil-checks
  `GOOGLE_APPLICATION_CREDENTIALS_JSON` and `RINDLE_GCS_BUCKET` env vars —
  exact pattern from `test/rindle/storage/s3_test.exs:13-18, 29-30`. Local
  runs without credentials skip cleanly; the `@tag :gcs` filter means
  `mix test --only gcs` is the integration-test entry point.

- **D-12:** Use **Bypass alone** (already in `mix.exs:92` as
  `{:bypass, "~> 2.1", only: :test}`) for unit-level fixtures of the JSON API
  surface. Live-bucket integration runs the full GCS proof lane behind the
  secret. **Do NOT** add fakegcs as a dep — Bypass + live bucket is the
  established Rindle pattern (S3 uses Bypass + MinIO; mirror it).

- **D-13:** **Phase 37 ships basic `mix rindle.doctor` GCS health checks**:
  Goth instance running (named lookup succeeds), bucket reachable
  (`GET /storage/v1/b/$BUCKET` returns 200/403 — present), signing key
  parses cleanly. Per ROADMAP success criterion #5 (`.planning/ROADMAP.md:105-108`),
  user-confirmed in `37-DISCUSSION-LOG.md` "Corrections Made" 2026-05-07.
  The doctor checks are **profile-aware** so image-only S3 adopters see no
  new noise — fires only when an adopter profile declares
  `storage: Rindle.Storage.GCS`. Mirrors the v1.6 `mix rindle.doctor --streaming`
  profile-aware discipline at `lib/rindle/ops/runtime_checks.ex:526-607`.
  The resumable-specific "CORS suspected when profile uses GCS+resumable"
  check STAYS deferred to Phase 41 (RESUMABLE-13) — no resumable concerns
  leak into Phase 37 doctor output.

- **D-14:** **Phase 37 does NOT touch the package-consumer lane**
  (`.github/workflows/ci.yml:289`). That's RESUMABLE-14 / Phase 41 (fresh
  `mix phx.new` adopter installs Rindle, configures a GCS profile). Phase 37
  ships the standalone `gcs-soak` lane only.

### Claude's Discretion

- Plan-level ordering of the 4 plans (one per requirement, per ROADMAP
  guidance) — researcher/planner pick the most testable execution order.
- Whether a cross-cutting `gcs_capabilities_test.exs` parity test ships in
  Phase 37 or rolls into Phase 39 alongside the resumable atoms — open for
  planner judgment, but Phase 37 MUST assert
  `Rindle.Storage.GCS.capabilities/0 == [:signed_url, :head]` somewhere
  (locked invariant from GCS-02).
- Specific Bypass fixture topology (one `setup` block per callback vs a
  shared fixture module) — open to planner taste.

### Folded Todos

None — `gsd-sdk query list-todos` returned `count: 0`. The pending todos
in STATE.md (Phase 34/35 code-review polish, tus candidate preservation,
v1.8+ Phase-37-style pull-forward) are out of Phase 37 scope.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/research/v1.6-CANDIDATE-GCS.md` — locked candidate plan, source
  of truth for hex versions, auth mode, library choices, peer-library
  lessons, public API shape (§4), security invariants (§9), DX rules (§8).
- `.planning/REQUIREMENTS.md` (lines 17-35) — GCS-01..GCS-04 acceptance
  criteria.
- `.planning/ROADMAP.md` (lines 68-99) — Phase 37 goal, depends-on,
  success criteria, plan-count guidance.
- `.planning/PROJECT.md` (lines 24-67, 296-342) — current milestone scope,
  security invariant 14 (provider-internal IDs redaction), constraints,
  key decisions including the locked v1.6 streaming patterns.
- `lib/rindle/storage.ex` — `Rindle.Storage` behaviour contract.
- `lib/rindle/storage/s3.ex` — primary mirror target for return shapes,
  error atoms, opts threading, config keying.
- `lib/rindle/storage/local.ex` — `{:error, {:upload_unsupported, X}}`
  pattern for unsupported callbacks.
- `lib/rindle/storage/capabilities.ex` — `:resumable_upload` /
  `:resumable_upload_session` atoms already reserved in `@known`; Phase 37
  must NOT advertise them from GCS.
- `lib/rindle/error.ex` — public error vocabulary; Phase 37 atoms route
  through generic fallthrough at line 334.
- `lib/rindle/config.ex` — `signed_url_ttl_seconds/0` source for `url/2`
  TTL fallback.
- `mix.exs` (lines 22, 67-69, 92, 158-163) — dialyzer `plt_add_apps`,
  optional-dep declaration shape, Bypass already declared, hexdoc adapter
  groupings.
- `.github/workflows/ci.yml` (lines 566-653) — `mux-soak` job is the
  structural template for `gcs-soak` (with secret-gating substitution).
- `test/rindle/storage/s3_test.exs` (lines 13-18, 29-30, 117) —
  credential-gated integration-test pattern + head-shape assertion.
- `test/rindle/storage/storage_adapter_test.exs` (lines 41-51, 77-83) —
  cross-adapter parity tests Phase 37's GCS adapter must satisfy.
- `lib/rindle/ops/runtime_checks.ex` (lines 526-607) — streaming-credentials
  doctor check is the **template Phase 37 follows for the basic Goth /
  bucket-reachable / signing-key health checks (D-13)**. The
  resumable-specific CORS-suspected branch defers to Phase 41 (RESUMABLE-13)
  and layers on top of the same module without restructuring it.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Rindle.Storage` behaviour (`lib/rindle/storage.ex`) — already defines the
  5 callbacks Phase 37 implements. No behaviour changes in this phase
  (resumable callbacks ship in Phase 39 as `@optional_callbacks`).
- `Rindle.Storage.Capabilities` (`lib/rindle/storage/capabilities.ex`) —
  `:signed_url` and `:head` atoms already in `@known`; Phase 37 just
  advertises them. `:resumable_upload` and `:resumable_upload_session` are
  reserved-but-unused; Phase 37 must NOT advertise these from GCS.
- `Rindle.Config.signed_url_ttl_seconds/0` (`lib/rindle/config.ex:14-17`) —
  TTL fallback used by S3's `url/2`; GCS adapter inherits same fallback.
- `Rindle.Security.StorageKey.generate/3` — produces unique storage keys per
  asset; GCS adapter inherits unchanged (no changes to key derivation).
- `Bypass` already in `mix.exs:92` as `{:bypass, "~> 2.1", only: :test}` —
  no new test deps required for unit-level JSON API fixtures.
- `mux-soak` job at `.github/workflows/ci.yml:566-653` — structural template
  for the new `gcs-soak` job (substitute label-gating for secret-gating).

### Established Patterns

- **Adopter owns runtime supervision** (locked v1.4 / v1.6). Repo, Oban,
  Goth, Finch all adopter-supervised; Rindle looks them up by configurable
  name from `config :rindle, Rindle.Storage.GCS`. Same posture as the v1.6
  Mux adapter looking up `goth`/`finch` instances by name.
- **Optional deps for adapter-specific transitive cost** (locked v1.6).
  `{:mux, "~> 3.2", optional: true}` + `{:jose, "~> 1.11", optional: true}`
  is the template; Phase 37 mirrors with `goth`, `finch`, `gcs_signed_url`.
- **Code.ensure_loaded? guard at adapter entry** (locked v1.6 Phase 36
  via `runtime_checks.ex:536`). Returns clean `{:error, atom}` tuple
  instead of `Code.LoadError` when adopter hasn't installed the optional
  dep.
- **Credential-gated integration test pattern** (locked v1.1 MinIO, v1.6
  Mux). Module attribute `@<adapter>_skip_reason` nil-checks env vars,
  `@tag skip:` skips cleanly when credentials absent.
- **Secret-gated CI proof lane discipline** (locked v1.5 MinIO). PRs
  without the secret skip the lane (fork-PR safe via secret resolving to
  empty string). Release lane always runs.
- **Hand-rolled HTTP client over Finch when SDK is too coupled** (locked v1.6
  Phase 35 webhook handling — raw-body cache pattern). GCS adapter inherits:
  `google_api_storage` is rejected (Tesla-coupled, doesn't surface session
  URI cleanly per candidate §3); hand-rolled Finch JSON API is the locked
  choice.

### Integration Points

- **`Rindle.Upload.Broker.verify_completion/2`** — calls adapter's `head/2`
  to confirm object exists in storage. GCS `head/2` MUST return the same
  shape as S3's so the broker doesn't need to branch on adapter.
- **`Rindle.Profile` DSL** — adopters select storage adapter via
  `storage: Rindle.Storage.GCS`. No DSL changes needed; capability resolution
  already works through `Rindle.Storage.Capabilities`.
- **`mix.exs` hexdoc adapter grouping** (`mix.exs:158-163`) — adds
  `Rindle.Storage.GCS` as a public hexdoc'd module under "Storage and
  Processor Adapters". `gcs/client.ex` and `gcs/signer.ex` stay
  `@moduledoc false` (private internals).
- **Cross-adapter parity test** (`test/rindle/storage/storage_adapter_test.exs:41-51, 77-83`)
  — asserts every adapter exports the 5 required callbacks with matching
  arities and the capability-list contract. GCS must pass without parity-test
  changes.
- **`Rindle.Error.t()` mapping** — Phase 37 error atoms route through the
  generic fallthrough at `lib/rindle/error.ex:334`. No Error module changes.
</code_context>

<specifics>
## Specific Ideas

- **`google_api_storage` is explicitly REJECTED** as the SDK choice. Per
  candidate §3: auto-generated, Tesla-coupled, exposes
  `storage_objects_insert_resumable/5` returning `{:ok, nil}` (doesn't
  surface session URI cleanly). Hand-rolled Finch JSON API is locked.
- **V4 signing only.** V2 is legacy per Google docs.
- **Private-key auth mode only in Phase 37.** IAM SignBlob mode (GKE / Cloud
  Run service-account-impersonation pattern) is deferred to v1.7+ behind a
  config flag.
- **Disposition/type goes in object metadata at `store/3`,** never as URL
  query params. Active Storage's lesson (CVE-history-adjacent): GCS V4
  signed URLs don't safely enforce `response-content-disposition` /
  `response-content-type`.
- **Rindle does NOT start Goth or Finch.** Adapter looks up adopter-supplied
  instance names. Same posture as Repo/Oban from v1.0/v1.1, Goth from v1.6.
- **Tesla is explicitly NOT used in adapter hot path.** Req is fine for
  test harness only (it's already in tree). Finch is the lowest common
  runtime denominator and Goth pulls it in transitively.
</specifics>

<deferred>
## Deferred Ideas

- **Resumable-specific `mix rindle.doctor` CORS-suspected check** → Phase 41
  (RESUMABLE-13). The "CORS suspected when profile uses GCS+resumable" branch
  needs the resumable capability advertised (Phase 39 promotes
  `:resumable_upload_session` from reserved to shipped) before the check has
  meaning. Phase 37 ships ONLY the basic Goth/bucket/signing-key health checks
  (D-13); the resumable-specific layering happens cleanly on top in Phase 41.
  *Earlier assumption-analysis run (same date) initially deferred ALL doctor
  work to Phase 41; user corrected on 2026-05-07 to honor ROADMAP success
  criterion #5 — basic doctor checks DO ship in Phase 37, resumable-specific
  layering defers to Phase 41.*
- **Package-consumer GCS proof lane** (fresh `mix phx.new` install) →
  Phase 41 (RESUMABLE-14).
- **Resumable upload behaviour callbacks** (`initiate_resumable_upload/3`,
  `resumable_upload_status/3`, `cancel_resumable_upload/3`,
  `verify_resumable_completion/3`) → Phase 39 (RESUMABLE-04..08).
- **`media_upload_sessions` resumable columns** + FSM `"resuming"` state →
  Phase 38 (RESUMABLE-01..03).
- **IAM SignBlob auth mode** (service-account-impersonation, GKE/Cloud Run
  pattern) → v1.7+ behind config flag.
- **Customer-supplied session URIs** — adopter-pre-signed flow → defer
  until requested.
- **CMEK, Object Versioning, Object Lifecycle, Encryption-at-rest of
  `session_uri`** — bucket-level concerns; documented (`cloak_ecto` recipe
  in `guides/storage_gcs.md`) but not enforced.
- **`Rindle.Storage.GCSResumable` as a separate adapter** — locked
  one-adapter-multiple-capabilities; rejected.
- **Auto-fallback resumable→PUT or PUT→resumable** — explicit family choice
  via profile DSL; rejected.
- **Generic "unified resumable" abstraction across S3 multipart and GCS
  resumable** — different protocols, different failure modes; rejected per
  peer-library lessons (Shrine, Active Storage, django-storages).

### Reviewed Todos (not folded)

None — no pending todos matched Phase 37 scope (`gsd-sdk query list-todos`
returned `count: 0`). The STATE.md "Pending Todos" entries (Phase 34/35
code-review polish, tus candidate preservation, MUX-20..23 pull-forward)
are out of Phase 37 scope.
</deferred>
