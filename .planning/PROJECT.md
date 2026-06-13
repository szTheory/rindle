# Rindle

## Current Milestone: v1.18 Admin Console & Adoption Lab (charter 2026-06-10)

**Maintainer-pull feature milestone** — explicit, recorded override of the PAUSE-03
v1.18+ reservation (LIFE-06/STREAM-10 stay demand-gated, now v1.19+). Phases 86–93,
19 requirements, ships as hex **0.3.0** (brand work releases first as 0.2.0).

Scope: mountable Rindle-branded admin console in the `rindle` package
(Oban-Web/LiveDashboard-style, self-contained assets, light/dark/system theming from
brand tokens); Cohort demo evolution (own brand, audio + document media, full
lifecycle-state seeds, mounts the console); deterministic console E2E + screenshot-driven
polish loop; Docker DX (port-conflict-free compose, layer caching, launch URL map);
durable UI-principles doc linked from AGENTS.md. This deliberately reverses the prior
"admin UI out of scope" decision (JTBD T4) — TRUTH-07 closes docs/facade parity.

**Last shipped:** b1.0 Brand Foundations (2026-06-10) — non-feature brand track,
phases 81–85, BRAND-01..08 validated 8/8. Committed brand system in `brandbook/`:
user-selected Confluence logo, WCAG-verified design tokens, self-contained HTML brand
book, README/HexDocs/social integration. Zero public API, zero `lib/` changes.
Archive: `.planning/milestones/b1.0-*`.

## Feature Posture: Demand-gated pause (superseded for v1.18 duration)

**Formalized:** 2026-05-27 (via `/gsd-new-milestone` — no feature charter)

**Goal:** Maintain Rindle in production-ready maintenance mode until a concrete demand
signal arrives. No feature phases, no new public API, no speculative platform work.

**Posture:**
- Patch/minor Hex releases and issue-driven fixes only
- No feature milestone unless **LIFE-06** (compliance ticket) or **STREAM-10** (named adopter)
- Re-run `/gsd-new-milestone` with option 2 or 3 when a signal is recorded
- Brand/docs/marketing work (b1.0) is not feature work and runs without violating the pause

**Override (2026-06-10):** v1.18 Admin Console & Adoption Lab opened as a self-directed
maintainer-pull feature milestone — recorded in the PAUSE-03 amendment
(`.planning/REQUIREMENTS.md`). The demand gates above shift to v1.19+ and the pause
posture resumes after v1.18 ships unless a new charter exists.

**Last shipped:** v1.17 Adopter-Confidence Hygiene (2026-05-27) — planning-truth hygiene and
CI-04 static-analysis policy record; no new public API.

**Canonical context:**
[post-v117 assessment](threads/2026-05-27-post-v117-milestone-assessment.md) (reaffirmed 2026-05-28),
[path-to-done roadmap](threads/2026-05-27-path-to-done-roadmap.md),
[release train](RELEASE-TRAIN.md).

## Current State

Milestone `v1.17 Adopter-Confidence Hygiene` archived on `2026-05-27`
(Phases 78–80, 3/3 requirements validated). Demand-gated pause formalized the same day.
Rindle is roughly **94–96%** done for its stated mission. Feature work resumes only on
LIFE-06 or STREAM-10 signal (or explicit maintainer override documented in milestone charter).

**v1.16 shipped:** Merge-blocking `proof` CI job (CI-03) runs `docs_parity_test.exs` and
`batch_owner_erasure_task_test.exs`; TusPlug moduledoc parity lock (TRUTH-05); planning
artifact cleanup (PLAN-01). Closes v1.15 audit CI-01/PROOF-06 integration depth and
automated CI proof path flow gap.

**v1.15 shipped:** CI lane severity matrix and merge-blocking package-consumer/adopter
jobs; PROOF-06 mix `batch_owner_failed` integration test; VAL-01 Nyquist closure for
phases 68–70; TRUTH-04 nine-task operations index and TusPlug moduledoc truth;
AUDIT-01 milestone audit ([v1.15-MILESTONE-AUDIT.md](milestones/v1.15-MILESTONE-AUDIT.md)).

**v1.14 shipped:** Batch owner erasure API, operator CLI, PROOF-05 matrix, TRUTH-03
guide parity (Phases 67–70, 8/8 requirements).

**Post-v1.17 (2026-05-28):** Adopter doc hygiene closed (user_flows tus row, roadmap parity lock).
Release train operational at Hex `0.1.6`; next publish validates automated baseline ledger.
Default posture: demand-gated pause until LIFE-06 or STREAM-10 signal.

**v1.18 Phase 86 complete (2026-06-11):** Research & Architecture Lock validated PRIN-01
and produced locked guides for admin console architecture, task-first IA, CSS, motion,
Docker demo DX, and UI principles linked from `AGENTS.md`. No console implementation
shipped yet.

**v1.18 Phase 87 complete (2026-06-11):** Docker & Demo DX validated DX-01..03:
the Cohort Docker preview now uses env-driven loopback host ports with
`COMPOSE_PROJECT_NAME` namespacing, cache-friendly Dockerfile dependency ordering,
deterministic launch URL output, and matching quick-try/proof-matrix docs. Full Docker
startup remains an optional manual smoke; static gates are the validated proof path.

**v1.18 Phase 88 complete (2026-06-11):** Admin Design System & UI Kit validated
DS-01..03 and ADMIN-02 groundwork: token-generated `rindle-admin` CSS,
console-specific contrast gates, deterministic static gallery, screenshot/hash
navigation checks, and the durable admin design-system operating guide are in place.

**v1.18 Phase 89 complete (2026-06-12):** Console Read Surfaces validated
ADMIN-01..03, ADMIN-05, and ADMIN-06: `Rindle.Admin.Router.rindle_admin/2`
mounts host-authenticated read surfaces, `priv/static/rindle_admin` assets ship
self-contained, `Rindle.Admin.Queries` isolates read models, six query-backed
LiveViews render through the shared shell, upload-session lifecycle events
invalidate through configured PubSub, and the optional LiveView compile-away
proof is present locally and in CI.

**v1.18 Phase 91 complete (2026-06-12):** Cohort Demo Evolution validated
DEMO-01..03: Cohort's own lightweight brand, audio + document profiles, seeds
expressing every lifecycle state, mounts the console, and click-around walkthrough.

**v1.18 Phase 92 complete (2026-06-13):** E2E & Screenshot-Driven Polish Loop
validated E2E-01..02: deterministic `/admin/rindle` Playwright helper and
admin console/theme/actions specs, live 22-PNG light/dark/mobile screenshot
matrix, screenshot polish fixes, proof-matrix drift gate, adoption demo README
truth, and merge-blocking `adoption-demo-e2e` wiring. Phase 93 remains active.

Do not reopen tus protocol, single-owner/batch erasure semantics, or Mux surfaces
beyond v1.13. Keep shared-asset safety and maintenance-vs-owner-erasure boundaries
intact.

## Recently Shipped Milestone

<details>
<summary>v1.10 Owner Account Erasure archive notes</summary>

- `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` now define the
  supported account-deletion surface instead of hand-rolled `detach/3` loops.
- The public report vocabulary is frozen around `attachments_to_detach`,
  `assets_to_purge`, and `retained_shared_assets`, with explicit no-op and
  purge-enqueue semantics.
- `PurgeStorage` now re-checks live attachment truth at the destructive
  boundary so shared assets survive stale purge work.
- Hermetic proof, canonical adopter proof, docs parity, and planning truth now
  agree on one owner-erasure story.
- Full artifacts live in `.planning/milestones/v1.10-*`.

</details>

<details>
<summary>v1.9 Phoenix Tus DX Completion archive notes</summary>

- Active planning/docs now describe the shipped Phoenix tus seam honestly
  instead of treating the full LiveView path as deferred.
- `Rindle.LiveView.allow_tus_upload/4` is now the documented supported
  server-side entry point, and `uploader: "RindleTus"` is the canonical client
  path.
- The generated-app smoke lane now proves the documented Phoenix / LiveView
  path end to end, and fast parity checks freeze guide/helper/proof drift.
- Phases 48-50 now have explicit verification artifacts, and Phase 52
  reconciled requirements, validation, roadmap, state, and audit truth for
  clean archive.
- Full artifacts live in `.planning/milestones/v1.9-*`.

</details>

<details>
<summary>v1.8 Resumable Browser Ingest archive notes</summary>

- `Rindle.Upload.TusPlug` now ships as a bare mountable Plug with HMAC-signed
  tus create/read/write/delete semantics and no Phoenix dependency.
- Local and S3 adapters now support honest `:tus_upload` capability-backed
  resumable browser ingest, converging into the unchanged
  `verify_completion/2` lane.
- Reaper, abort, and cross-node safety hardening shipped with live MinIO proof
  and generated-app install-smoke coverage.
- Browser→Mux direct creator upload is now a shipped streaming surface, not a
  carried-forward candidate.
- Full artifacts live in `.planning/milestones/v1.8-*`.

</details>

## What This Is

Rindle is an open-source Phoenix/Ecto-native media lifecycle library for
Phoenix applications. It manages the full media lifecycle after upload: staged
objects, validation, analysis, media assets, attachments,
variants/derivatives, background processing, signed delivery, cleanup,
regeneration, and operational visibility. Rindle is not a file upload helper;
it is the durable lifecycle layer that helps Phoenix teams ship media features
with production confidence.

## Core Value

Media, made durable.

## Decision-Making Contract

Rindle uses a research-driven, decide-by-default posture. Do not escalate
routine design or implementation choices.

After research, agents should produce one coherent recommendation set and
proceed without asking the maintainer to choose among routine local options.
The default deliverable is: chosen path, rationale, notable risks, and
rejected alternatives.

Bias that research left: prefer ecosystem-aware, prior-art-informed, coherent
one-shot recommendation sets by default so the maintainer does not need to
reconstruct the trade study manually each phase.

Do not escalate because multiple viable local options exist. Do not escalate
because a choice is merely ergonomic, additive, local, or reversible.

Escalate only when the choice has high blast radius:

- semver-significant public API reshapes
- destructive or irreversible operations
- security or compliance boundary changes
- material recurring cost surprises
- milestone or scope reshapes
- architectural commitments that are expensive to reverse

When the choice is local, additive, reversible, or mainly ergonomic, pick the
least-surprising option, record the rationale in project artifacts, and
proceed.

If escalation is required, still present a recommended path, why blast radius
is high, and the rollback or containment implications.

### Discuss-Phase Default

Discuss-phase is not brainstorming by default.

When clarifying a phase, agents should:

- read active code, planning truth, prior context, relevant prompts, and recent
  threads before asking anything
- narrow options aggressively using ecosystem research, prior art, and repo
  truth
- return one cohesive recommendation set that is idiomatic for Elixir / Plug /
  Ecto / Phoenix and coherent with Rindle's architecture and support posture
- ask follow-up questions only when a high-blast-radius decision remains
  genuinely unresolved after research

The default discuss deliverable is not "possible options." It is:

- the recommended boundary
- the deferred boundary
- the rationale and tradeoffs
- the specific footguns being avoided
- the rare escalation trigger, if one remains

### Support-Truth Boundary

Supported owner/account deletion goes through the owner-erasure facade shipped in
`v1.10` (`Rindle.preview_owner_erasure/2`, `Rindle.erase_owner/2`).

- `detach/3` remains a slot-scoped attachment API
- `cleanup_orphans` remains upload-session and staged-object maintenance
- shared assets are retained unless removing the target owner's attachments
  makes them newly orphaned

Do not teach `detach/3` loops plus `cleanup_orphans` as the recommended
account-deletion surface. Use the owner-erasure facade for supported flows.

### Operational Enforcement

To keep this posture durable across GSD workflows:

- research, discuss, and planning outputs should return one recommended
  direction by default, not a menu of equal options
- alternatives are for rationale, rejected paths, or contingency planning only
- local, additive, reversible, ergonomic, or wording-level choices should be
  resolved by the agent and recorded in artifacts without user arbitration
- phase artifacts should explicitly name the recommended boundary, deferred
  boundary, and the high-blast-radius triggers that would justify escalation
- discuss-phase should prefer assumptions/research mode, use prior-art-informed
  comparisons where useful, and ask only the minimum number of maintainer
  questions needed after narrowing

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- Phase 1 — Foundation: schemas, FSMs, profile DSL, validation primitives, and
  local/S3 storage adapters shipped in v1.0.
- Phase 2 — Upload & Processing: proxied/direct upload flows, image
  processing, Oban workers, and atomic attach/purge behavior shipped in v1.0.
- Phase 3 — Delivery & Observability: signed delivery, telemetry contract, and
  responsive image helpers shipped in v1.0.
- Phase 4 — Day-2 Operations: cleanup, regeneration, storage verification,
  metadata backfill, and maintenance workers shipped in v1.0.
- Phase 5 — CI & 1.0 Readiness: CI lanes, adopter integration, release lane,
  and narrative guides shipped in v1.0.
- Phase 6 — Adopter Runtime Ownership: public runtime Repo resolution,
  adopter-only lifecycle proofs, and adopter-first Repo/Oban guidance verified
  in v1.1.
- Phase 7 — Multipart Uploads: multipart session persistence, cleanup, and real
  MinIO-backed completion/abort proofs verified in v1.1.
- Phase 8 — Storage Capability Confidence: shared capability vocabulary,
  MinIO-backed proof, and honest Cloudflare R2 compatibility guidance verified
  in v1.1.
- Phase 9 — Install & Release Confidence: generated-app package-consumer smoke,
  CI and release reuse, and executable install-doc parity proof verified in
  v1.1.
- ✓ First public `Hex.pm` publish path exercised from the real repository
  workflow — v1.2 (Phase 11)
- ✓ Release automation performs a protected real publish and fails safely before
  publication if package/docs/install gates drift — v1.2 (Phase 11)
- ✓ Maintainer can verify the published package from Hex.pm and follow a
  documented rollback path — v1.2 (Phase 12)
- ✓ Release requirement traceability metadata and runbook aligned with live
  workflow contract — v1.2 (Phase 13)
- ✓ Phases 10 and 11 VALIDATION artifacts completed to Nyquist-compliant state
  — v1.2 (Phase 14)
- ✓ First live Hex.pm publish executed from the real repo workflow with
  `HEX_API_KEY` and post-publish public verification confirmed — v1.3
  (Phases 15/16, formally verified Phase 20) (PUBLISH-01)
- ✓ CI failures in the release pipeline diagnosed and fixed before live
  publish attempt — v1.3 (Phase 15, formally verified Phase 20) (PUBLISH-02)
- ✓ Routine release path documented and executable after first publish — v1.3
  (Phase 16, formally verified Phase 20) (PUBLISH-03)
- ✓ Public API surface reviewed for naming inconsistencies — v1.3 (Phase 17)
  (API-01)
- ✓ Missing convenience functions identified and added to public surface
  (`attachment_for/2`, `ready_variants_for/1`, `!`-bang variants) — v1.3
  (Phase 19) (API-02)
- ✓ `@doc`, `@spec`, `@moduledoc` coverage gaps resolved on public functions
  (100/100/100, enforced via `mix doctor --raise`) — v1.3 (Phase 18) (API-03)
- ✓ Breaking-change audit completed to lock the right surface area before 1.0
  — v1.3 (Phase 17) (API-04)
- ✓ HexDocs reachability probe verifies post-publish public docs availability
  — v1.3 (Phase 21) (VERIFY-02)
- ✓ AV capability negotiation, guarded FFmpeg/FFprobe subprocess execution,
  boot probing, and `mix rindle.doctor` shipped — v1.4 (Phase 23) (AV-01)
- ✓ Typed AV domain fields, per-kind DSL validation, probe dispatch, and
  image-only backward compatibility shipped — v1.4 (Phase 24) (AV-02)
- ✓ `Rindle.Processor.AV` shipped preset-led video/audio outputs, waveform
  generation, runtime guards, and durable worker contracts — v1.4 (Phase 25)
  (AV-03)
- ✓ Delivery gained `streaming_url/3`, local range-aware playback, RFC 5987
  filenames, and frozen delivery telemetry — v1.4 (Phase 26) (AV-04)
- ✓ Phoenix-facing AV helpers, LiveView progress/cancellation, and the locked
  AV error vocabulary shipped — v1.4 (Phase 27) (AV-05)
- ✓ Public AV onboarding, profile-aware doctor CI gates, smartphone-source
  lifecycle proof, and docs/telemetry parity shipped — v1.4 (Phase 28)
  (AV-06)
- ✓ Provider boundary contract — capability vocabulary, promoted
  `Rindle.Streaming.Provider` runtime behaviour, additive
  `media_provider_assets` Ecto table + FSM, profile DSL `:streaming` key,
  `streaming_url/3` dispatch tree, 5 streaming reason atoms with parity
  freeze, `Rindle.Capability.report/0` extension — v1.6 (Phase 33)
  (STREAM-01..09)
- ✓ Mux REST adapter + server-push sync — `mux ~> 3.2` + `jose ~> 1.11`
  optional deps, signed-playback URL minting via `Mux.Token` with explicit
  TTL (defeats 7-day default), `MuxIngestVariant` Oban worker with two-layer
  idempotency + atomic-promote race protection + 429 Retry-After snooze,
  `MuxSyncCoordinator` + `MuxSyncProviderAsset` defensive polling, telemetry
  redaction parity — v1.6 (Phase 34) (MUX-01..08)
- ✓ Signed-webhook plug + idempotent ingest — mountable
  `Rindle.Delivery.WebhookPlug`, raw-body cache pattern via
  `WebhookBodyReader`, `Mux.Webhooks.verify_header/4` HMAC-SHA256 verify,
  multi-secret rotation with `secret_index` telemetry, 60–900s configurable
  replay window, `IngestProviderWebhook` Oban worker idempotent on Mux event
  UUID, race-snooze on row-missing, two-topic PubSub broadcast,
  `mix rindle.runtime_status --provider-stuck` extension — v1.6 (Phase 35)
  (MUX-09..14)
- ✓ Public DX, onboarding, CI proof — `Rindle.Profile.Presets.MuxWeb` preset,
  `mix rindle.doctor --streaming` 4 PASS/FAIL checks + 5s smoke ping,
  `guides/streaming_providers.md` (341 lines), README + getting-started
  `Streaming with Mux (optional)` subsections, generated-app `mux-enabled`
  cassette lane (every PR) + label-gated `mux-soak` real-Mux sibling
  (`streaming`-labelled PRs only) with three-layer asset-leak mitigation
  — v1.6 (Phase 36) (MUX-15..19)

- ✓ `Rindle.Storage.GCS` adapter foundation — public `@behaviour Rindle.Storage`
  surface (store/download/delete/head/url) wired over hand-rolled Finch JSON-API
  client + `gcs_signed_url` PEM Client mode; `capabilities/0 == [:signed_url, :head]`
  (resumable atoms reserved for Phase 39); secret-gated `gcs-soak` CI lane and
  GCS-aware `mix rindle.doctor` checks shipped with adopter zero-noise guarantee
  for image-only profiles — v1.7 (Phase 37) (GCS-01..04). Live-bucket proof is
  accepted CI automation via `gcs-soak` (`ci_verified`), not manual follow-up.

- ✓ `Rindle.Streaming.cancel_direct_upload/1` public API by `asset_id` with
  idempotent re-cancel and frozen error vocabulary — v1.13 (Phases 64–65)
  (CANCEL-01, CANCEL-02)
- ✓ `create_direct_upload/2` persists provider `upload_id` with invariant-14
  redaction — v1.13 (Phase 64) (CANCEL-03)
- ✓ Mux adapter `cancel_direct_upload/1` via `Mux.Video.Uploads.cancel/2` and
  terminal FSM transition — v1.13 (Phase 65) (CANCEL-04)
- ✓ Hermetic cancel proof matrix and streaming integration coverage — v1.13
  (Phase 66) (PROOF-01)
- ✓ `guides/streaming_providers.md` cancel semantics and Mux-only scope — v1.13
  (Phase 66) (TRUTH-01)
- ✓ Batch owner-erasure policy contract with aggregate report vocabulary and
  configurable owner-count limit — v1.14 (Phase 67) (BULK-01, BULK-02)
- ✓ Batch preview/execute API reusing `OwnerErasure` with per-owner isolation and
  idempotent rerun — v1.14 (Phase 68) (BULK-03..05)
- ✓ `mix rindle.batch_owner_erasure` operator surface with dry-run default and
  documented CLI contract — v1.14 (Phase 69) (OPS-02)
- ✓ PROOF-05 hermetic batch erasure matrix and TRUTH-03 guide/docs parity — v1.14
  (Phase 70) (PROOF-05, TRUTH-03)
- ✓ CI lane severity matrix and merge-blocking package-consumer/adopter jobs — v1.15
  (Phase 71) (CI-01, CI-02)
- ✓ Mix `batch_owner_failed` partial-failure integration proof — v1.15 (Phase 72)
  (PROOF-06)
- ✓ Nyquist-compliant validation artifacts for v1.14 erasure phases 68–70 — v1.15
  (Phase 73) (VAL-01)
- ✓ Nine-task operations index and TusPlug moduledoc truth — v1.15 (Phase 74)
  (TRUTH-04)
- ✓ v1.15 milestone audit and planning truth alignment — v1.15 (Phase 74) (AUDIT-01)
- ✓ Merge-blocking `proof` CI job for docs parity and batch-owner-erasure mix proof — v1.16
  (Phase 75) (CI-03)
- ✓ TusPlug moduledoc scope locked via `Code.fetch_docs/1` contract test — v1.16 (Phase 76)
  (TRUTH-05)
- ✓ v1.15 Nyquist metadata closure and between-milestones STATE truth — v1.16 (Phase 77)
  (PLAN-01)
- ✓ Post-v116 assessment and path-to-done threads match CI severity — v1.17 (Phase 78)
  (TRUTH-06)
- ✓ JTBD-MAP anchor and planning charter alignment — v1.17 (Phase 78) (PLAN-02)
- ✓ Recorded Credo/Dialyzer advisory policy (CI-04) — v1.17 (Phase 79)
- ✓ Durable UI-principles guidance linked from `AGENTS.md`, with admin console
  architecture, IA, CSS, motion, and Docker DX locks — v1.18 (Phase 86) (PRIN-01)

### Active

- **v1.18 Admin Console & Adoption Lab (charter 2026-06-10):** ADMIN-01..06 (mountable
  console: router macro + host auth, self-contained assets, read surfaces, ops actions,
  pubsub live updates, optional-dep safety), DS-01..03 (token-generated design system,
  light/dark/system theme picker, contrast gate), DEMO-01..03 (Cohort own brand, full
  media-type + state coverage, mounts console), E2E-01..02 (deterministic console specs,
  screenshot polish loop), DX-01..03 (port-conflict-free compose, layer caching, launch
  URL map), TRUTH-07 (scope-reversal docs parity). PRIN-01 is validated in Phase 86;
  DX-01..03 are validated in Phase 87; DEMO-01..03 are validated in Phase 91.
  Full text: `.planning/REQUIREMENTS.md`.

**Demand-gated for v1.19+ feature milestone:**

- **LIFE-06** — force-delete for still-shared assets (compliance/legal ticket required)
- **STREAM-10** — second streaming provider (named adopter + provider choice required)

Deferred long-tail (explicit product pull only): TRANS-01 (signed dynamic transforms),
PRIV-01 (EXIF strip on originals).

Out of scope or deferred: force-delete without charter, second provider speculatively,
IETF RUFH (tus 2.0), GCS-as-tus-backend, standalone tus JS client, uploader UI kits,
signed dynamic transforms, EXIF privacy stripping.

### Out of Scope

- Full HLS/DASH streaming platform, DRM, global adaptive video management —
  Rindle is a lifecycle library, not a media platform; these belong to provider
  adapters (Mux, Transloadit)
- Arbitrary unsigned dynamic transformation API — unsigned dynamic resizes are
  a DoS/cost vector; named presets and signed transforms only
- Built-in GPU/AI runtime requirements — AI processors are extension points
  backed by external providers, not core dependencies
- Office/PDF/SVG broad processing by default — requires hardened
  sandbox/container guidance that is not universally available
- "Cloud replacement" or managed CDN product positioning — Rindle is a
  library; CDN behavior is an adopter responsibility
- Full GCS adapter in v1.1 — capability design should remain ready for GCS, but
  the adapter and resumable flow stay deferred until after multipart/S3 support
- tus/resumable upload protocol in v1.1 — multipart is the nearer production
  need; tus remains a later adapter path
- FFmpeg/Membrane adapters in v1.1 — image-first remains the wedge; video/audio
  adapters follow once host-app/runtime boundaries are solid
- PDF preview adapter in v1.1 — still out-of-scope until sandboxing posture is
  documented
- ~~Admin LiveView UI in v1.1 — operator workflows remain code/telemetry/task
  driven for now~~ — **reversed 2026-06-10**: v1.18 ships a mountable admin console
  (D-v1.18-01); console actions reuse existing facade capabilities only

## Context

**v1.6 result:** Rindle ships a real streaming provider contract with Mux as
the single reference adapter — the v1.4-reserved `streaming_url/3` seam now
backs a runtime behaviour, durable provider state, signed-webhook ingest with
multi-secret rotation, idempotent Oban-driven sync, and a generated-app
package-consumer `mux-enabled` proof lane alongside v1.5's image-only and
AV-enabled lanes. Optional `mux` + `jose` deps preserve zero transitive cost
for non-streaming adopters. The single-provider rule keeps the abstraction
honest; v1.7+ adapters (GCS, second streaming provider) become contract tests.

**Between milestones:** Demand-gated pause formalized 2026-05-27 after v1.17 archive.
Post-v117 assessment (repo-verified) reaffirms pause as default — no feature milestone
until LIFE-06 or STREAM-10 signal. Mission coverage ~94–96%. Feature milestones require
LIFE-06 or STREAM-10 signal per `config.json`
`workflow.milestone_boundary.block_feature_milestone_without_signal`.
See `.planning/threads/2026-05-27-post-v117-milestone-assessment.md`.

**Support-truth note:** Adopter-facing roadmap prose in `guides/user_flows.md` must not
claim tus or browser→Mux direct upload as future work — both shipped v1.8–v1.11. Refresh
that section on next docs maintenance pass.

**Reference implementations:**
- Rails Active Storage: attachment/blob ownership patterns, redirect-style
  delivery, and background purge lessons
- Shrine: host-app ownership, atomic promotion, and derivatives as first-class
  records
- Spatie Media Library: strong "day-two" ergonomics and opinionated DX
- imgproxy: capability- and signature-driven delivery constraints

**Security invariants (must hold in all implementations):**
1. Never trust client MIME/filename; enforce magic-byte sniffing and allowlists
2. Do not attach/process direct uploads until completion is verified
3. Do not allow unbounded variant explosion; named presets only by default
4. Storage side effects are not hidden inside DB transactions
5. Purge paths are async, idempotent, and auditable
6. Concurrent replacement races resolve safely
7. Missing/stale/failed variant states are visible, queryable, and actionable
8. FFmpeg / FFprobe subprocess invocation uses argv list only — never shell.
   All user-controllable parameters (codec, container, dimensions, duration,
   bitrate) are validated against named-preset allowlists before reaching argv.
9. Every FFmpeg / FFprobe invocation passes `-protocol_whitelist file,crypto,data`
   and runs under hard caps for duration (`-t`), output size (`-fs`), CPU
   time (`-timelimit`), wall-clock time (external), and threads (`-threads`).
   Wall-clock kill is enforced externally; FFmpeg's `-timelimit` alone is
   insufficient.
10. Container metadata (title, artist, comment, embedded subtitles,
    attachments) is treated as untrusted user-controlled content end-to-end.
    Rindle stores it opaquely (truncated, control-chars stripped); adopters
    MUST sanitize on render.
11. HLS / DASH / playlist-style ingest is out of scope. Inputs accepted by
    ingest are single-container files only (mp4, mov, webm, m4a, mp3, wav,
    flac, ogg).
12. Rindle declares an FFmpeg minimum version (≥ 6.0), capability-probes at
    supervisor boot, and refuses to start with stale or missing FFmpeg when
    video / audio profiles are configured. Adopters never silently inherit
    FFmpeg CVE exposure.
13. Temp files for transcoding live under a single sweepable root
    (`Rindle.tmp/`); orphans are reaped by a scheduled `Rindle.Ops` worker.
    No transcode is allowed without an enforceable parent-death subprocess
    kill (MuonTrap on Linux; Rambo on macOS / Windows dev).
14. Raw provider identifiers (`provider_asset_id`, provider upload IDs,
    provider session URIs) are never exposed in adopter-facing paths,
    URLs, logs, telemetry metadata, or `inspect/2` output. Only the
    public-side `playback_id` (or equivalent) crosses into URLs. Telemetry
    metadata redacts provider-internal IDs to last-4-char tags. Provider
    bearer credentials (Mux signing keys, GCS resumable session URIs, tus
    upload URLs) are treated as secrets at rest and in transit; custom
    `Inspect` impls on persistence rows redact them. (Added v1.6.)

## Constraints

- **Tech stack**: Elixir/Phoenix/Ecto only in core; no non-Elixir runtime in
  the library
- **Repo ownership**: adopter apps own the runtime Repo and DB credentials; the
  library may keep `Rindle.Repo` only as a local test/dev harness
- **Background jobs**: Oban remains the required job backend; multipart flows
  and cleanup must integrate with Oban rather than invent a parallel runner
- **Security defaults**: private delivery remains the default; multipart support
  must preserve the same verification and allowlist guarantees as presigned PUT
- **Capability honesty**: adapters must advertise only what they truly support;
  unsupported flows must fail as tagged errors, not degraded surprises
- **Backward compatibility**: existing presigned PUT flows stay supported;
  multipart is additive and must not break current adopters
- **Docs posture**: practical, copy-pasteable, production-aware, and
  maintainer-to-maintainer in tone

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Media-agnostic core, image-first implementation | Images are the highest-leverage wedge; core domain model must not assume image so video/audio can slot in later | ✓ Good |
| Variants are first-class DB records, not hidden filenames | Queryable state enables admin, retries, stale detection, cleanup, and reporting | ✓ Good |
| Oban as required job backend | Oban is SQL-backed, persistent, observable, and supports transactional enqueueing | ✓ Good |
| Telemetry naming and metadata are public contracts | Operators will build dashboards and alerts against these; silent breakage is unacceptable | ✓ Good |
| Named presets only by default; dynamic transforms opt-in and signed | Unsigned dynamic transforms are a DoS/cost vector | ✓ Good |
| Async purge after DB commit | Storage I/O inside DB transactions is a consistency and latency trap | ✓ Good |
| Repo ownership is adopter-first (`repo: MyApp.Repo`), not library-owned | Matches idiomatic Ecto library architecture and avoids split ownership | ✓ Good |
| `Rindle.Repo` is test/dev harness only, not a consumer runtime dependency | Keeps library development practical while preserving adopter-owned runtime boundaries | ✓ Validated in Phase 6 |
| Capability-driven storage negotiation is the contract boundary | Backend support differs materially across S3-compatible providers and future GCS/resumable flows | ✓ Validated in Phase 8 |
| Multipart uploads belong in v1.1, not v1.0 | Presigned PUT was enough for the first release, but larger production workloads need a better direct-upload path | ✓ Validated in Phase 7 |
| Install proof should be package-consumer-first | A passing repo CI lane is not the same as a fresh Phoenix adopter succeeding from the published artifact | ✓ Validated in Phase 9 |
| First public Hex publish should be scoped narrowly and exercised before broader API cleanup | The release path is the remaining trust gap and should become routine before new surface-area bets | ✓ Validated in Phases 10–14 |
| Public API surface and convenience helpers locked before 1.0 | Adoption pressure grows after first publish; renames carry semver cost | ✓ Validated in Phases 17–19 |
| Video / audio ships via system FFmpeg subprocess (FFmpex + MuonTrap), not Membrane / NIFs / bundled provider | Out-of-process subprocess crashes retry cleanly via Oban; NIFs that wrap libavcodec turn FFmpeg CVEs into BEAM crashes; Membrane is the right tool for streaming pipelines, wrong tool for one-shot file derivatives; every peer lib (Active Storage, Shrine, Spatie, CarrierWave, Django) shells out to FFmpeg | Locked v1.4 |
| Single `media_assets` + `:kind` discriminator (vs polymorphic / split tables) | Active Storage validates the single-table approach at scale; Elixir pattern matching shines on atom enums; operator queryability requires typed columns, not JSONB-only | Locked v1.4 |
| Variants stay first-class DB rows with `:output_kind`; cross-kind derivatives (video → poster image, audio → waveform) are plain rows, no special cases | Day-2 ops queries (`WHERE state='failed' AND output_kind=:video`) stay SQL-native; Shrine's flat-derivatives JSON blob loses this | Locked v1.4 |
| HLS / DASH / DRM / live streaming / dynamic per-request video transforms remain out of core scope | Streaming framework territory (Mux, Cloudflare Stream, Membrane); manifest ingest is an SSRF + RCE surface (CVE-2016-1897, CVE-2020-13904, multiple HackerOne reports) | Locked v1.4 |
| Provider-delegated processors (Mux / Cloudflare Stream / Transloadit) ship as a documented custom-`Rindle.Processor` recipe, not as bundled adapters in core | Adopter contract stays narrow; adapter pluggability can land in v1.5+ if real adopter feedback requests it; v1.2 / v1.3 retro confirmed tight scope ships cleanly | Locked v1.4 |
| `Rindle.Delivery.streaming_url/3` ships as a no-op delegate now to reserve the surface for HLS / Mux / CF Stream provider adapters | Active Storage's mistake was conflating progressive-blob URLs with manifest URLs; reserving the namespace now means adopter video templates won't churn when streaming providers land | ✓ Validated in v1.6 (Phase 33: 8-branch dispatch tree on the reserved surface; zero adopter churn) |
| `Rindle.Streaming.Provider` is the contract boundary, not adapter modules; Mux is the reference adapter, not the contract | Single-provider rule keeps abstraction honest; second adapter (Cloudflare/Bunny) is the contract test in v1.7+, not v1.6 scope | Locked v1.6 |
| `mux ~> 3.2` + `jose ~> 1.11` ship as optional deps, not required deps | Adopters who don't enable streaming pay zero transitive cost; Mux SDK's Tesla + JOSE surface stays adapter-local | ✓ Validated v1.6 (Phase 34) |
| Webhook signature verification delegates to `Mux.Webhooks.verify_header/4`, not reimplemented in Rindle | Mux SDK's HMAC + JOSE implementations are the highest-risk pieces; reimplementing risks divergence from the provider's own constant-time semantics | ✓ Validated v1.6 (Phase 35) |
| Raw-body cache for webhooks is the `Plug.Parsers :body_reader` MFA pattern, not a separate route or `pull_request_target`-style escape hatch | Same pattern Stripe.WebhookPlug uses; mountable via documented `forward` declaration; bypasses JSON decoding only in the webhook scope | ✓ Validated v1.6 (Phase 35) |
| Provider-internal IDs (Mux `asset_id`, upload IDs, session URIs) redact to last-4-char tag in telemetry, logs, and `Inspect` output (security invariant 14) | Raw provider IDs leak across adopter boundaries in dashboards and traces; cross-cutting parity test enforces last-4 redaction at every emit site | Locked v1.6 |
| Generated-app `mux-soak` lane is label-gated (`streaming` PR label), not on every PR; cassette lane runs every PR with zero secrets | Real-Mux quota + cost; fork-PR safety: secrets resolve to empty strings on forks via `pull_request` (NOT `pull_request_target`) trigger | ✓ Validated v1.6 (Phase 36) |
| Phase 37 (browser→Mux direct creator upload) ships only if Phases 33-36 ship under budget | Single-provider rule keeps milestone scope honest; direct-creator-upload is small additive surface on already-built primitives — clean v1.7 deferral | ✓ Deferred to v1.7 (Phases 33-36 closed at budget without pulling forward) |
| v1.9 is a Phoenix tus DX completion / truth-alignment milestone, not a new tus capability milestone | The repo already ships the headless tus edge, `Rindle.initiate_tus_upload/2`, and the thin `Rindle.LiveView.allow_tus_upload/4` seam; the remaining gap is coherent support truth, productized adopter guidance, and proof | Locked v1.9 |
| The supported Phoenix tus path remains helper + documented client uploader over the existing `verify_completion/2` lane; richer Rindle-owned uploader abstractions stay optional future scope unless the current seam proves insufficient | This preserves the shipped headless contract, avoids overclaiming a component that does not exist yet, and keeps the milestone on the highest-leverage wedge | Locked v1.9 |
| Browser→Mux direct creator upload is shipped in v1.8 and should not be treated as a carried-forward candidate | Public streaming entrypoints, LiveView wrapper, provider support, tests, and adopter docs are already in the tree; remaining streaming follow-on work is narrower (`cancel_direct_upload/1`, second-provider demand) | ✓ Validated in v1.8 / v1.9 boundary assessment |
| Owner/account erasure in v1.10 uses conservative shared-asset semantics: detach the erased owner's rows, purge only newly orphaned assets, and report retained shared assets explicitly | `attach` / `detach` are slot-scoped while purge is asset-scoped; deleting an asset that still has another live attachment would violate current repo truth and surprise adopters during account deletion | Locked v1.10 |
| v1.12 is maintenance-only; v1.13+ is demand-driven | At ~93% mission coverage, highest leverage is planning/support-truth hygiene and avoiding speculative tus/platform breadth | Locked v1.12 |
| Contract-before-implementation for cancel | Freeze types, FSM, persistence, and error vocabulary in Phase 64 before Mux HTTP in Phase 65 | ✓ Good v1.13 |
| FSM-first cancel orchestration | Conditional `update_all` to terminal state before provider HTTP reduces race windows | ✓ Good v1.13 |
| Mux-only cancel in v1.13 | Second-provider cancel is a contract extension when explicit demand ships an adapter | Locked v1.13 |
| v1.14 bulk erasure extends v1.10 facade | Batch orchestration reuses `OwnerErasure`; no force-delete or admin UI in scope | ✓ Good v1.14 |
| Mission-complete default = demand-gated pause post-v1.16 | ~94–96% mission coverage; T0–T2 complete; T3 gaps (LIFE-06, STREAM-10) demand-gated only; path-to-done roadmap defines terminal state | Locked 2026-05-27 (overridden for v1.18 by maintainer pull, 2026-06-10) |
| D-v1.18-01: Admin console ships in the `rindle` package, mountable Oban-Web/LiveDashboard-style (router macro, optional `phoenix_live_view`, self-contained precompiled assets, no host Tailwind dependency) | Adopter DX lives in the library, not the demo; `Code.ensure_loaded?(Phoenix.LiveView)` gating and host-repo `Rindle.Config.repo()` patterns already exist; separate package adds a second release train for a 0.x project | Locked v1.18 charter |
| D-v1.18-02: Brand work releases as 0.2.0 now; v1.18 ships as hex 0.3.0 | Clean separation — no weeks-stale release PR held open for the console | Locked v1.18 charter |
| D-v1.18-03: Cohort stays the demo domain, extended with audio + document media and full lifecycle-state seeds | Familiar domain that naturally needs every media type; 12 E2E specs + seeds already built on it; no churn for its own sake | Locked v1.18 charter |
| Console CSS = BEM + custom properties generated from `brandbook/tokens/tokens.json`; Cohort keeps Tailwind/daisyUI | Shipped library UI must be host-independent (no Tailwind build assumption); brandbook vanilla-CSS momentum carries; demo momentum is Tailwind | Locked v1.18 charter |


## Historical Snapshot

<details>
<summary>v1.16 CI Enforcement & Planning Hygiene (Phases 75–77) — SHIPPED 2026-05-27</summary>

Gap-closure milestone from the v1.15 audit. Delivered: merge-blocking `proof` CI job,
TusPlug `@moduledoc` / `docs_parity_test` contract lock, and Nyquist/STATE planning truth
cleanup. No new public feature surface.

Full artifacts live in:

- [.planning/milestones/v1.16-ROADMAP.md](.planning/milestones/v1.16-ROADMAP.md)
- [.planning/milestones/v1.16-REQUIREMENTS.md](.planning/milestones/v1.16-REQUIREMENTS.md)

</details>

<details>
<summary>v1.14 Bulk Owner-Erasure Orchestration (Phases 67–70) — SHIPPED 2026-05-27</summary>

Milestone v1.14 extended v1.10 single-owner erasure with batch orchestration.
Delivered: batch contract types and boundary validation,
`preview_batch_owner_erasure/2` / `erase_batch_owner_erasure/2`,
`mix rindle.batch_owner_erasure`, PROOF-05 hermetic proof matrix, and TRUTH-03
guide/docs parity.

Full artifacts live in:

- [.planning/milestones/v1.14-ROADMAP.md](.planning/milestones/v1.14-ROADMAP.md)
- [.planning/milestones/v1.14-REQUIREMENTS.md](.planning/milestones/v1.14-REQUIREMENTS.md)
- [.planning/milestones/v1.14-MILESTONE-AUDIT.md](.planning/milestones/v1.14-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.13 Cancel Direct Upload (Phases 64–66) — SHIPPED 2026-05-27</summary>

Milestone v1.13 closed the remaining Mux direct-upload control gap. Delivered:
additive `provider_upload_id` persistence, FSM terminal cancel edges,
`Rindle.Streaming.cancel_direct_upload/1`, Mux adapter via
`Mux.Video.Uploads.cancel/2`, hermetic PROOF-01 matrix, and TRUTH-01 guide/docs
parity with install-smoke enforcement.

Full artifacts live in:

- [.planning/milestones/v1.13-ROADMAP.md](.planning/milestones/v1.13-ROADMAP.md)
- [.planning/milestones/v1.13-REQUIREMENTS.md](.planning/milestones/v1.13-REQUIREMENTS.md)
- [.planning/milestones/v1.13-MILESTONE-AUDIT.md](.planning/milestones/v1.13-MILESTONE-AUDIT.md)

</details>


<details>
<summary>v1.8 Resumable Browser Ingest (Phases 42–47) — SHIPPED 2026-05-25</summary>

Milestone v1.8 turned browser-origin resumable ingest into a shipped Rindle
contract. Delivered: a bare `Rindle.Upload.TusPlug`, honest `:tus_upload`
capability negotiation, one-column `resumable_protocol` discrimination over the
existing v1.7 resumable substrate, Local tmp-append and S3 multipart-per-PATCH
backing, hard failure handling for abort/reaper/cross-node edge cases, a
generated-app tus package-consumer proof, and browser→Mux direct creator upload
with webhook correlation, streaming entrypoints, LiveView support, and docs.

Full artifacts live in:

- [.planning/milestones/v1.8-ROADMAP.md](.planning/milestones/v1.8-ROADMAP.md)
- [.planning/milestones/v1.8-REQUIREMENTS.md](.planning/milestones/v1.8-REQUIREMENTS.md)
- [.planning/milestones/v1.8-MILESTONE-AUDIT.md](.planning/milestones/v1.8-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.6 Provider Boundary + Mux (Phases 33–36) — SHIPPED 2026-05-07</summary>

Milestone v1.6 turned v1.4's reserved `streaming_url/3` seam into a real
provider contract with Mux as the single reference adapter, without making
Rindle a video platform. Delivered: `Rindle.Streaming.Provider` runtime
behaviour with locked callbacks, additive `media_provider_assets` durable
state schema, profile DSL `:streaming` key, 8-branch dispatch tree,
`Rindle.Streaming.Provider.Mux` reference adapter (server-push ingest,
signed HLS playback, defensive sync workers, security-invariant-14
telemetry redaction), mountable `Rindle.Delivery.WebhookPlug` with
multi-secret rotation + replay protection + raw-body cache, idempotent
`IngestProviderWebhook` Oban worker, public `Rindle.Profile.Presets.MuxWeb`,
`mix rindle.doctor --streaming` validation, `guides/streaming_providers.md`
adopter reference, and a generated-app `mux-enabled` package-consumer
proof lane (cassette every PR + label-gated real-Mux soak). Optional
`mux` + `jose` deps mean non-streaming adopters pay zero transitive cost.

Full artifacts live in:

- [.planning/milestones/v1.6-ROADMAP.md](.planning/milestones/v1.6-ROADMAP.md)
- [.planning/milestones/v1.6-REQUIREMENTS.md](.planning/milestones/v1.6-REQUIREMENTS.md)

</details>

<details>
<summary>v1.5 Adopter Hardening & Lifecycle Repair (Phases 29–32) — SHIPPED 2026-05-06</summary>

Milestone v1.5 turned the fresh AV wedge into a much more truthful adoption and
operations story. Delivered: package-consumer proof for image-only and
AV-enabled installs from shipped artifacts, explicit `reprobe` and
`requeue_variants` repair surfaces, dry-run-first sweep and truthful
regeneration guidance, deterministic `mix rindle.doctor` and
`mix rindle.runtime_status` diagnostics, additive repair/runtime telemetry, and
a generated-app proof lane for upgrading pre-v1.4 adopters into the current
AV-aware shape and recovering cancelled work.

Full artifacts live in:

- [.planning/milestones/v1.5-ROADMAP.md](.planning/milestones/v1.5-ROADMAP.md)
- [.planning/milestones/v1.5-REQUIREMENTS.md](.planning/milestones/v1.5-REQUIREMENTS.md)
- [.planning/milestones/v1.5-MILESTONE-AUDIT.md](.planning/milestones/v1.5-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.4 Video & Audio Wedge (Phases 23–28) — SHIPPED 2026-05-05</summary>

Milestone v1.4 expanded Rindle from image-first into image+video+audio without
changing the core lifecycle philosophy. Delivered: AV capability negotiation,
guarded FFmpeg/FFprobe subprocesses, typed `kind`/`output_kind` domain fields,
`Rindle.Processor.AV`, range-aware local playback, `video_tag/3` and
`audio_tag/3`, LiveView progress/cancellation contracts, and a smartphone-source
adopter proof lane that locks the public onboarding story into docs and CI.

Full artifacts live in:

- [.planning/milestones/v1.4-ROADMAP.md](.planning/milestones/v1.4-ROADMAP.md)
- [.planning/milestones/v1.4-REQUIREMENTS.md](.planning/milestones/v1.4-REQUIREMENTS.md)
- [.planning/milestones/v1.4-MILESTONE-AUDIT.md](.planning/milestones/v1.4-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.3 Live Publish & API Ergonomics (Phases 15–22) — SHIPPED 2026-05-02</summary>

Milestone v1.3 executed Rindle's first real Hex.pm publish from the
repository workflow and locked the public API surface before adoption
pressure grew. Delivered: live `0.1.0` publish via the protected release
workflow with `HEX_API_KEY`, post-publish HTTP probe for `hexdocs.pm/rindle`
reachability, explicit `Rindle.Error` struct with typed reasons across
constraints / variants / attachments, 100/100/100 `@doc` / `@spec` /
`@moduledoc` coverage enforced via `mix doctor --raise`, ergonomic
`attachment_for/2` / `ready_variants_for/1` plus `!`-bang variants on the
public facade, tightened Dialyzer struct resolution, residual LiveView
correctness fixes, and goal-backward retrospective metadata closure for
Phases 15 and 16.

Full artifacts live in:

- [.planning/milestones/v1.3-ROADMAP.md](.planning/milestones/v1.3-ROADMAP.md)
- [.planning/milestones/v1.3-REQUIREMENTS.md](.planning/milestones/v1.3-REQUIREMENTS.md)
- [.planning/milestones/v1.3-MILESTONE-AUDIT.md](.planning/milestones/v1.3-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.2 First Hex Publish (Phases 10–14) — SHIPPED 2026-04-29</summary>

Milestone v1.2 proved Rindle's first real `Hex.pm` publication path end to end.
Delivered: shared release preflight, protected live publish with scoped
credentials, version drift gate, automated CI dry-run publish, post-publish
public verification job, maintainer release runbook with rollback/revert, and
Nyquist-compliant validation artifacts for all milestone phases.

Full artifacts live in:

- [.planning/milestones/v1.2-ROADMAP.md](.planning/milestones/v1.2-ROADMAP.md)
- [.planning/milestones/v1.2-REQUIREMENTS.md](.planning/milestones/v1.2-REQUIREMENTS.md)
- [.planning/milestones/v1.2-MILESTONE-AUDIT.md](.planning/milestones/v1.2-MILESTONE-AUDIT.md)

</details>

<details>
<summary>v1.1 Adopter Hardening (Phases 6–9) — SHIPPED 2026-04-28</summary>

The `v1.1` milestone focused on adopter runtime ownership, multipart
upload support, capability honesty across MinIO and Cloudflare R2, and
package-consumer install proof from the built artifact.

Full artifacts live in:

- [.planning/milestones/v1.1-ROADMAP.md](.planning/milestones/v1.1-ROADMAP.md)
- [.planning/milestones/v1.1-REQUIREMENTS.md](.planning/milestones/v1.1-REQUIREMENTS.md)
- [.planning/milestones/v1.1-MILESTONE-AUDIT.md](.planning/milestones/v1.1-MILESTONE-AUDIT.md)

</details>

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? Move to Out of Scope with reason
2. Requirements validated? Move to Validated with phase reference
3. New requirements emerged? Add to Active
4. Decisions to log? Add to Key Decisions
5. "What This Is" still accurate? Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check; still the right priority?
3. Audit Out of Scope; reasons still valid?
4. Update Context with current state
5. Write post-ship assessment thread; feature milestones require issue/compliance signal
   (`workflow.milestone_boundary.block_feature_milestone_without_signal`)

---
*Last updated: 2026-06-12 after Phase 91 Cohort Demo Evolution completion*
