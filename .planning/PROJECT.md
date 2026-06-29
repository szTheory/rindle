# Rindle

## Current State

**Last shipped:** v1.21 CI/DX Reliability Tail — shipped 2026-06-29 and archived at
[.planning/milestones/v1.21-ROADMAP.md](milestones/v1.21-ROADMAP.md) with 24/24 requirements
validated across 5/5 verified phases (108–112). A non-feature/DX companion to v1.20 that made the
merge gate deterministic and trustworthy — a green PR now reliably means a green `main`. Delivered:
single-run coverage (one `mix coveralls.multiple --type local --type json` per lane, killing the
double-suite run; COV-01..04); subprocess `:epipe` hardening (`run_isolated/5` absorbs the MuonTrap
#98 broken-pipe `{:EXIT, port, :epipe}` exit at the single AV chokepoint; EPIPE-01..05 + TRUTH-01
invariant-13 correction); async-isolation hardening (`Rindle.Config.repo/0` now consults a
`$callers`-aware process-dictionary override before app-env, retiring the global `put_env(:rindle,
:repo, …)` swap; the v1.20 async-safety guard's `:global_repo_swap` rule makes the footgun
un-reintroducible; ISO-01..05); five merge-blocking shipped-artifact regression-lock meta-tests for
the 2026-06-26 cluster (LOCK-01..05); and the lean `adoption-demo-e2e-smoke` PR lane wired into
`CI Summary` LAST — only after the de-flake phases landed and 3 green push:main runs were observed
(GATE-01..04). The two adopter-invisible `lib/` patches (`av/subprocess.ex`, `config.ex`) ship as Hex
**0.3.2** via release-please `fix:` commits. All three hard release-coupling invariants held throughout.

**Proof posture:** v1.21 audit `passed` (`milestones/v1.21-MILESTONE-AUDIT.md`): 24/24 requirements
satisfied via 3-source cross-reference, integration **14/14 WIRED** (0 blockers, 0 warnings), the
CI-gate E2E flow complete, and the load-bearing de-flake→lock→shift-left order proven in the shipped
artifacts (the smoke lane's needs-wiring commit is the last `ci.yml` touch). Tech debt is minimal and
advisory (WR-01 cyclic-`$callers` defense-in-depth hardening; 7 pre-existing `actionlint` findings in
unrelated `ci.yml` jobs, byte-identical before/after). One stale v1.18-era docker-demo-warnings
tooling todo was acknowledged and deferred at close — outside v1.21 scope (see STATE.md Deferred Items).

**Prior milestone:** v1.20 CI/CD Performance — shipped 2026-06-22, 18/18 requirements validated across
5/5 phases (103–107) with **zero `lib/` change** (CI observability + baseline, `setup-elixir`/
`setup-minio` composites + PLT restore/save split, single `CI Summary` aggregate required check + live
branch-protection flip, fast PR lane + `nightly.yml` split, reliability/security/DX hardening).
Archived to `milestones/v1.20-*.md`. v1.19 Design-System Stress-Test shipped 2026-06-19 (20/20); v1.18
Admin Console & Adoption Lab closed `shipped` 2026-06-20 after HUMAN-UAT sign-off. All archived.

**Open planning debt:** None. v1.18, v1.19, v1.20, and v1.21 are all shipped and archived.

**Active milestone:** **v1.22 OSS Quality & Trust Hardening** — chartered 2026-06-29 from **SEED-005**,
the non-feature signal for a two-milestone software-quality consolidation arc (v1.22 trust hardening →
v1.23 Postgres schema isolation). Phases resume at **113**. Feature milestones remain demand-gated on
**LIFE-06** / **STREAM-10**; this arc is non-feature/DX, so the feature-pause block does not apply.

> **Release-state correction (2026-06-29):** Hex **0.3.2 was never published.** Hex live = 0.3.1;
> `mix.exs` / `.release-please-manifest.json` / CHANGELOG all = 0.3.1. The v1.21 `lib/` fixes
> (`fix(109-01)` `:epipe` absorb, `fix(110-01..04)` config override) plus 3 `feat` / 6 `fix` commits are
> merged to `main` but **unreleased** — no `release rindle 0.3.2` commit and no open release-please PR.
> The v1.21 prose below claiming "ships as Hex 0.3.2" is therefore aspirational, not shipped. v1.22
> HYGIENE cuts the stuck 0.3.2 release and reconciles the claim.

## Current Milestone: v1.22 OSS Quality & Trust Hardening

**Goal:** Close the cheap, high-ROI OSS trust/positioning/governance gaps surfaced by the 2026-06-29
software-quality recon, and ship the versioned `Rindle.Migration` substrate v1.23 needs — low risk, no
breaking change, ships as a 0.3.x minor (0.4.0 is reserved for v1.23's breaking schema isolation).

**Target features (requirement areas):**
- **EVAL** — concise, evidence-cited scored-weakness summary as the milestone's opening artifact
  (sharpened recon; not the full 36-dimension report).
- **TRUST** — `SECURITY.md` (untrusted uploads / MIME sniffing / signed delivery / webhook HMAC),
  `CODE_OF_CONDUCT.md`, `.github/ISSUE_TEMPLATE/` + `PULL_REQUEST_TEMPLATE.md`.
- **META** — Hex `package:` metadata: `links` "Changelog" + "Docs" (HexDocs convention) + `maintainers`.
- **VERSION** — stated SemVer / pre-1.0 stability contract (README + CONTRIBUTING) + generalized
  `guides/upgrading.md` beyond the single pre-0.1.4 case.
- **README** — image-first "first attachment in ~2 minutes" path (today's first-run is FFmpeg/AV-heavy)
  + a "what this is NOT / when not to use" block.
- **MIGRATE** — versioned `Rindle.Migration.up/1`+`down/1` module (Oban-style, idempotent) replacing the
  raw 15-file `Ecto.Migrator` copy-paste install path; **stop creating `oban_jobs`** (adopter owns Oban).
  Non-breaking: defaults keep tables in `public`; existing adopters' applied migrations stay valid. This
  is the foundation v1.23 builds the schema prefix onto.
- **HYGIENE** — cut the stuck Hex 0.3.2 release (adopter-facing `:epipe`/config fixes are merged-but-
  unreleased) and reconcile PROJECT.md; fix stale `status: open` frontmatter on SEED-003/004 (consumed).

**Key context:** Non-feature/DX charter from **SEED-005**. Two false premises were corrected in recon:
szTheory peer deps → empty (Rindle depends on none), and CI/CD performance → already done by v1.20+v1.21.
The `Rindle.Migration` module is intentionally pulled into v1.22 (not v1.23) because it is a "good-guest"
fix in its own right and de-risks the v1.23 breaking flip. Full arc: SEED-005 + the approved roadmap at
`/Users/jon/.claude/plans/software-quality-evaluation-prompt-txt-gleaming-sifakis.md`.


## Last Milestone: v1.21 CI/DX Reliability Tail (shipped 2026-06-29)

<details>
<summary>v1.21 CI/DX Reliability Tail — shipped scope (collapsed)</summary>

**Goal:** Close the reliability tail v1.20 (SEED-003) left open — make the merge gate deterministic
and trustworthy by killing the structural double-suite-run, fixing the underlying subprocess
`:epipe` race, closing the PR↔main gate-coverage gap, and hardening the last latent async-isolation
smell — so a green PR reliably means a green `main`.

**Target features (requirement areas):**
- **Single-run coverage** — one `mix coveralls.multiple --type local --type json` per lane instead
  of running the whole ExUnit suite twice (gate run + JSON-artifact re-run). Halves test wall-clock
  AND halves `:epipe` exposure; the `local` analyzer keeps identical merge-gate semantics.
- **Subprocess `:epipe` hardening (`lib/`)** — absorb the upstream MuonTrap #98 broken-pipe exit in
  `Rindle.AV.Subprocess.run/3` (~25 lines; adopter-invisible; security invariants 8–13 byte-equal).
- **PR↔main gate-coverage gap** — add ONE lean deterministic `adoption-demo-e2e-smoke` PR job into
  `CI Summary.needs` so the class that reached `main` on 2026-06-26 is caught pre-merge, keeping PR
  p95 ≈7 min. Strict ordering: de-flake (coverage/epipe/async) BEFORE this lane gates PRs.
- **Async-isolation hardening (`lib/`)** — make `Rindle.Config.repo/0` consult a `$callers`-aware
  process-dictionary override before app-env, eliminating the global `Application.put_env(:rindle,
  :repo, …)` in the counting-repo double; close the matching gap in the v1.20 async-safety guard.
- **Regression locks + proof** — durable shipped-artifact meta-tests for the already-fixed
  2026-06-26 cluster (phx.new self-install, `:focus-visible` Tab-modality, `.planning/`-path
  hygiene) plus a deterministic `:epipe` repro; assert SHIPPED artifacts only, never `.planning/`.
- **Truth fix** — security-invariant 13's "Rambo on macOS/Windows" clause is stale (the path is
  MuonTrap-only; no Rambo in `mix.lock`); correct it.

**Key context:** Non-feature/DX charter from **SEED-004**; two adopter-invisible `lib/` patches
authorized (D-v1.21-01) → ships Hex **0.3.2**. Hard invariants carry over from v1.20: never rename
`ci.yml` / `name: CI` (release-train coupling); `CI Summary` keeps `skipped`==pass (fork-PR safety);
never weaken the release full-verification gate. Research locked in `.planning/research/v1.21-*.md`.
Phases resume at **108**.

</details>

<details>
<summary>v1.20 CI/CD Performance — shipped scope (collapsed)</summary>

**Goal:** Cut PR CI feedback time and harden gate determinism/reliability — without dropping real
quality signal — via a measure → classify → restructure pass shipped as stepwise PRs.

**Delivered:** Baseline + CI observability; pipeline topology split (fast PR gate vs push:main vs
nightly vs release); A–E test-value classification; ExUnit async-safety guard + conversions; caching
correctness (deps/_build/PLT keys + restore/save split); matrix/trigger refinement scoping the heavy
package-consumer lane; faithful local Linux-Chromium repro; supply-chain posture (SHA-pinned actions,
Dependabot, `mix_audit`, least-privilege permissions); and a single local `mix ci` equivalent +
readable job summaries + contributor docs.

**Key context:** Chartered from **SEED-003** (planted 2026-06-20) — the maintainer's locked 10-lens
CI/CD performance-audit prompt as the authoritative, research-driven spec. Measured baseline: PR
wall-clock ≈ 15–17 min, long pole = `Package Consumer Proof Matrix + Release Preflight` (~15m).
Non-feature / DX-infrastructure milestone (no `lib/` public-API change), so
`block_feature_milestone_without_signal` did not apply; SEED-003 was the documented signal.

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

Supported Phoenix/LiveView resumable upload goes through the shipped tus seam:
`Rindle.LiveView.allow_tus_upload/4` is the documented server-side entry point,
`uploader: "RindleTus"` is the canonical client uploader, and completion
converges on the unchanged `verify_completion/2` lane. Richer Rindle-owned
uploader abstractions stay optional future scope (locked v1.9).

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
- ✓ **v1.18 Admin Console & Adoption Lab** — shipped 2026-06-20 (HUMAN-UAT signed off):
  mountable token-generated admin console (ADMIN-01..06, DS-01..03), Cohort adoption-lab
  demo with full media-type + lifecycle-state coverage (DEMO-01..03), deterministic console
  E2E + screenshot polish loop (E2E-01..02), port-conflict-free Docker DX (DX-01..03), and
  scope-reversal docs parity (TRUTH-07). Archived: `milestones/v1.18-REQUIREMENTS.md`.
- ✓ **v1.19 Design-System Stress-Test** — shipped 2026-06-19: token-pipeline CI gate +
  new token categories (PIPE-01..02), fractal admin/operator DS uplift (UPLIFT-01..08),
  Cohort `.ck-*` component layer + dark/reduced-motion + page migrations + daisyUI retirement
  (COHORT-01..06), and a single merge-blocking computed-style visual matrix (VIS-01..04).
  20/20 validated. Archived: `milestones/v1.19-REQUIREMENTS.md`.
- ✓ **v1.20 CI/CD Performance** — shipped 2026-06-22 (non-feature / DX-infra, **zero `lib/`
  change**): CI observability + committed baseline (OBS-01..03), cache & tooling hygiene via
  `setup-elixir`/`setup-minio` composites + PLT restore/save split + lockfile-drift gates
  (CACHE-01..05), single `CI Summary` aggregate required check + live branch-protection flip
  (GATE-01..02), fast PR lane + nightly split + A–E lane classification (LANE-01..04), and
  reliability/security/DX hardening — async-safety AST guard, SHA-pinned actions + Dependabot +
  `mix_audit`, `mix ci` alias, faithful Linux-Chromium repro (HARD-01..04). 18/18 validated.
  Archived: `milestones/v1.20-REQUIREMENTS.md`.
- ✓ **v1.21 CI/DX Reliability Tail** — shipped 2026-06-29 (non-feature/DX, two adopter-invisible
  `lib/` `fix:` patches → Hex 0.3.2): single-run coverage killing the double-suite run
  (COV-01..04), subprocess `:epipe` hardening via `run_isolated/5` at the AV chokepoint + invariant-13
  truth correction (EPIPE-01..05, TRUTH-01), `$callers`-aware process-scoped repo override retiring the
  global swap + `:global_repo_swap` guard rule (ISO-01..05), five shipped-artifact regression-lock
  meta-tests for the 2026-06-26 cluster (LOCK-01..05), and the lean `adoption-demo-e2e-smoke` PR lane
  wired into `CI Summary` LAST after de-flake + 3 green main runs (GATE-01..04). 24/24 validated.
  Archived: `milestones/v1.21-REQUIREMENTS.md`.

### Active

**v1.22 OSS Quality & Trust Hardening** (chartered 2026-06-29 from SEED-005) — see the Current Milestone
section above. Requirement areas: EVAL, TRUST, META, VERSION, README, MIGRATE, HYGIENE. Scoped in
`.planning/REQUIREMENTS.md`; phases begin at 113. Followed by **v1.23 Postgres Schema Isolation**
(breaking → 0.4.0), chartered after v1.22 ships.

**Demand-gated for next feature milestone:**

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
    kill. MuonTrap is the sole subprocess runner on every platform
    (`Rindle.AV.Subprocess.run/3` → `MuonTrap.cmd/3`); its POSIX port wrapper
    kills the child when the BEAM dies on both Linux and macOS dev. cgroup
    resource caps (memory / CPU) are Linux-only and gated on
    `:os.type() == {:unix, :linux}`; on macOS the kill guarantee holds without
    cgroup caps. There is no Rambo dependency.
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
| Video / audio ships via system FFmpeg subprocess (MuonTrap runner; argv built in-house, not FFmpex), not Membrane / NIFs / bundled provider | Out-of-process subprocess crashes retry cleanly via Oban; NIFs that wrap libavcodec turn FFmpeg CVEs into BEAM crashes; Membrane is the right tool for streaming pipelines, wrong tool for one-shot file derivatives; every peer lib (Active Storage, Shrine, Spatie, CarrierWave, Django) shells out to FFmpeg | Locked v1.4 |
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
| v1.20 is a non-feature / DX-infrastructure milestone with **zero `lib/` public-API change** | CI wall-clock + gate reliability were the velocity bottleneck (~15–17 min PR lane); SEED-003's 10-lens audit is the documented signal, so the feature-pause block does not apply | ✓ Good v1.20 (invariant held: 0 `lib/` diff across the range) |
| Load-bearing CI restructure order: observability → cache → aggregate required check → lane split → hardening | Research-unanimous; reversing the aggregate-check and lane-split steps would force a second branch-protection migration | ✓ Validated v1.20 (single branch-protection flip; no rework) |
| One stable `CI Summary` aggregate as the sole required check (`needs:` all, `if: always()`, `skipped`==pass) before any lane rename | Decouples branch protection from lane names so future matrix/trigger changes never touch branch protection; closes the fork-PR "pending forever" trap | ✓ Good v1.20 (Phase 105; live flip executed) |
| Never rename `ci.yml`/`name: CI`; never weaken the release full-verification gate | Release-train coupling (`release-please-automerge.yml` + `gate-ci-green`) reads the workflow name + full-matrix push:main run; renaming or weakening it would silently break publishing | ✓ Held v1.20 (byte-unchanged across all 5 phases) |
| Scope the `package-consumer` long pole by trigger (lean `image` smoke on PR; full 5-profile matrix + preflight + dry-run on push:main/nightly/release) | The headline wall-clock cut; release readiness proven by the push:main run conclusion via `gate-ci-green`, not by a PR-gating check name | ✓ Good v1.20 (Phase 106; PR p95 under ≤7 min) |
| ExUnit async conversion is gated behind an AST static-safety meta-test; `--partitions` deferred until measured core-starvation | Fail-closed guard prevents silent shared-state races; partitioning payoff is evidence-gated, not assumed (DEFER-02) | ✓ Good v1.20 (Phase 107; 15 modules converted, 2 latent races fixed) |
| D-v1.21-01: v1.21 relaxes v1.20's zero-`lib/`-change invariant for two adopter-invisible hardening patches (`av/subprocess.ex` MuonTrap-#98 `:epipe` absorb; `config.ex` `$callers`-aware process-scoped repo override) | The correctness-true fixes for the recurring `:epipe` flake and the async-isolation root cause both live in production code; both are adopter-invisible (no public API / return-shape / error-vocab / security-invariant change), so they ship as a `fix:` patch (0.3.2) without escalation beyond this authorization | ✓ Good v1.21 (both patches landed adopter-invisible; audit confirmed `lib/` seam unchanged at all 11 Ffmpeg/Ffprobe call sites + default no-override repo path) |
| D-v1.21-02: keep `mix coveralls` (`local` analyzer) as the merge-gate; never derive the gate from `coveralls.json`'s exit code | ExCoveralls 0.18.5 source: `coveralls.json` does NOT call `ensure_minimum_coverage`, so gating on it would silently drop threshold enforcement; `coveralls.multiple --type local --type json` gives both from one run | ✓ Good v1.21 (Phase 108; one suite run per lane emits both the `local` gate and `excoveralls.json`) |


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
*Last updated: 2026-06-29 after chartering v1.22 OSS Quality & Trust Hardening (from SEED-005) — a
two-milestone software-quality consolidation arc (v1.22 trust hardening → v1.23 Postgres schema
isolation). Recon corrected two premises (szTheory deps → empty; CI/CD perf → already done by v1.20+v1.21)
and confirmed Hex 0.3.2 was never published (v1.21 `lib/` fixes are merged-but-unreleased). v1.21 phase
dirs archived to `milestones/v1.21-phases/`. Phases resume at 113.*
