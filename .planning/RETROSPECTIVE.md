# Retrospective: Rindle

---

## Milestone: v1.16 — CI Enforcement & Planning Hygiene

**Shipped:** 2026-05-27
**Phases:** 3 (75–77) | **Plans:** 10

### What Was Built

- Merge-blocking `proof` CI job (`docs_parity_test.exs`, `batch_owner_erasure_task_test.exs`).
- Adopter lane narrowed to lifecycle-only; redundant partial doc grep removed.
- TusPlug `@moduledoc` interpolates `@tus_extensions`; `Code.fetch_docs/1` contract lock.
- Nyquist closure for phases 71–72 VALIDATION artifacts and between-milestones STATE truth.

### What Worked

- **Gap-closure sequencing (77 → 76 → 75):** Docs-only planning cleanup landed first,
  avoiding `ci.yml` conflicts; proof job included the new TusPlug parity test.
- **Audit-driven scope:** v1.16 requirements mapped 1:1 to v1.15 audit integration-depth gaps.
- **No public API surface:** Maintenance wedge stayed honest — CI, docs parity, planning truth only.

### What Was Inefficient

- **No v1.16 milestone audit file:** Close relied on phase VERIFICATION artifacts and v1.15
  audit ledger updates rather than a dedicated `v1.16-MILESTONE-AUDIT.md`.
- **ROADMAP phase bloat:** v1.15 phases (71–74) remained expanded in ROADMAP until v1.16 close;
  both milestones collapsed together at archive time.

### Patterns Established

- **Proof lane as merge-blocking:** Highest-signal install-smoke and mix-task proofs run in a
  dedicated `proof` job separate from advisory `quality` (dialyzer/credo/coveralls).
- **Moduledoc contract tests:** `Code.fetch_docs/1` token asserts + stale-phrase refutes for
  TusPlug scope, complementing runtime OPTIONS tests in `tus_plug_test.exs`.

### Key Lessons

- Gap-closure milestones should execute planning truth before CI wiring to reduce merge conflicts.
- Post-milestone assessment thread required at every boundary; see
  `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` (canonical post-v1.16).
- Between-milestones STATE posture needs explicit reset at archive — not only at phase close.

### Cost Observations

- Timeline: 1 day (2026-05-27)
- Git range: ~10 commits, 19 files, ~1,056 LOC delta in milestone commits

---

## Milestone: v1.14 — Bulk Owner-Erasure Orchestration

**Shipped:** 2026-05-27
**Phases:** 4 (67–70) | **Plans:** 8

### What Was Built

- Batch owner-erasure public contract on `Rindle` (types, boundary validation, error vocabulary).
- `preview_batch_owner_erasure/2` and `erase_batch_owner_erasure/2` with sequential per-owner
  `OwnerErasure` delegation, bucket aggregation, and partial-failure reports.
- `mix rindle.batch_owner_erasure` operator CLI (JSON owners file, dry-run default, `--execute`).
- PROOF-05 gap-fill: shared batch fixtures, `CountingFailingTxnRepo`, partial-failure DB proofs.
- TRUTH-03: batch erasure documented in `guides/user_flows.md` with install-smoke docs parity.

### What Worked

- **Contract-before-implementation (Phase 67):** Types and boundary stubs landed before
  planner wiring, matching the v1.10/v1.13 pattern.
- **Reuse v1.10 planner:** Batch orchestration stayed thin — no force-delete or admin UI creep.
- **Four-phase sequencing:** Contract → implementation → operator → proof/docs closed the wedge
  in one day with audit passed before close.
- **Shared test fixtures:** `OwnerErasureBatchFixtures` unified batch, proof, and task tests.

### What Was Inefficient

- **Nyquist partial on phases 68–70:** VALIDATION artifacts exist but are not fully green;
  discovery-only at close.
- **Operator partial-failure E2E gap:** `batch_owner_failed` path implemented but not driven
  by mix-task integration test (non-blocking per audit).

### Patterns Established

- **Batch wraps single-owner facade:** Public batch API delegates to `OwnerErasure` per owner
  with transactional isolation and aggregate reporting.
- **Operator thin wrapper:** Mix task calls batch facade only; CLI schema in `@moduledoc`.
- **Counting failing txn repo for DB proofs:** Closes partial-failure integration gaps without
  production code changes.

### Key Lessons

- A pre-ranked lifecycle wedge (bulk orchestration) ships cleanly as a four-phase milestone
  when contract, implementation, operator, and proof are sequenced explicitly.
- Defer force-delete and admin UI to keep blast radius bounded; batch orchestration is
  orthogonal to destructive shared-asset policy.

### Cost Observations

- Timeline: 1 day (2026-05-27)
- Git: ~42 commits, ~1,045 LOC in `.ex`/`.exs` for the batch erasure lane
- Notable: v1.14 closed same day as v1.13; second lifecycle wedge in one session

---

## Milestone: v1.13 — Cancel Direct Upload

**Shipped:** 2026-05-27
**Phases:** 3 (64–66) | **Plans:** 8

### What Was Built

- Additive `provider_upload_id` column on `media_provider_assets` with partial
  unique index and Inspect redaction (security invariant 14).
- FSM terminal cancel edges from `pending`/`uploading` to `deleted`.
- `create_direct_upload/2` persists provider upload handle without changing the
  public return map.
- Frozen `cancel_direct_upload/1` types, error vocabulary, and optional Provider
  callback before implementation landed.
- Mux Client/HTTP `Uploads.cancel/2` with 403/404 idempotency at the HTTP layer.
- `Rindle.Streaming.cancel_direct_upload/1` with FSM-first conditional
  `update_all` before provider HTTP.
- PROOF-01 hermetic matrix (Bypass HTTP + ClientMock edge cases).
- TRUTH-01 cancel section in `guides/streaming_providers.md` with install-smoke
  docs parity test.

### What Worked

- **Contract-before-implementation (Phase 64):** Freezing types, FSM, persistence,
  and errors before Mux HTTP reduced integration churn in Phase 65.
- **FSM-first orchestration:** Conditional DB transition before provider cancel
  HTTP gives a clear race story and testable intermediate states.
- **Narrow milestone scope:** Three phases, six requirements, one provider —
  shipped in a single day without scope creep into tus or second-provider work.
- **Audit passed before close:** v1.13 milestone audit (`passed`, 6/6) gave
  confidence to archive without gap-closure phases.

### What Was Inefficient

- **Nyquist partial on phases 64 and 66:** VALIDATION artifacts exist but are not
  fully green; acceptable at close but would benefit from `/gsd-validate-phase`
  if validation hygiene matters for future audits.
- **Assessment thread lag:** Post-v1.12 assessment recommended *not* opening v1.13
  proactively; demand materialized quickly — thread status should be updated when
  scope changes.

### Patterns Established

- **Contract slice then adapter slice:** Public boundary + persistence + FSM in
  one phase; provider HTTP + orchestration in the next; proof + docs in the third.
- **HTTP-layer idempotency for Mux 403/404:** Treat already-cancelled uploads as
  `:ok` at `Mux.HTTP` before adapter normalization.
- **Install-smoke docs parity for streaming cancel:** Substring parity test locks
  guide language to shipped API surface.

### Key Lessons

- A pre-ranked demand wedge (`cancel_direct_upload/1`) can ship as a tight
  three-phase milestone when contract, implementation, and proof are sequenced
  explicitly.
- Mux-only scope in v1.13 keeps the Provider callback honest; defer
  second-provider cancel until an adapter exists.
- Cosmetic tech debt (`@typedoc` "ships Phase 65") is cheap to fix post-ship;
  document in audit rather than blocking close.

### Cost Observations

- Timeline: 1 day (2026-05-27)
- Git: ~23 commits, ~761 LOC in `.ex`/`.exs` for the cancel lane
- Notable: Full milestone (3 phases, 8 plans) closed same day as v1.12 archive

---

## Milestone: v1.2 — First Hex Publish

**Shipped:** 2026-04-29
**Phases:** 5 (10–14) | **Plans:** 11

### What Was Built

- Maintainer-facing Hex publish guidance with explicit versioning, auth, and owner model plus executable parity gate
- Shared release preflight script proving artifact contents, release-doc parity, install smoke, and docs warnings
- Protected live Hex.pm publish via scoped credential in GitHub release environment with concurrency guard
- Version drift gate (`assert_version_match.sh`) blocking publication on tag/mix.exs mismatch
- Automated CI dry-run publish job exercising the release flow on every commit
- Fresh-runner post-publish verification job proving Hex.pm network resolution on every release
- Maintainer release runbook covering first-publish, routine releases, and rollback/revert locked to live workflow by parity tests
- Canonical `requirements-completed` frontmatter normalized across all release phase summaries
- Phase 10 and Phase 11 VALIDATION artifacts completed to Nyquist-compliant state

### What Worked

- **Tight phase scoping:** Keeping v1.2 narrowly focused on the publish/release path (no new API surface) meant every phase compounded directly on the previous one.
- **Executable parity gates:** Using ExUnit to assert guide language matches live workflow step names and commands (positive + refutation assertions) caught drift that would have been missed in a prose-only review.
- **Preflight script as single source of truth:** Centralizing the package, docs, and install-smoke gates behind `scripts/release_preflight.sh` prevented workflow drift between local and CI release checks.
- **Separate `public_verify` job:** Isolating post-publish verification in a fresh-runner job with cleared credentials cleanly separated publish concerns from verification concerns.
- **Phase 13 as cleanup phase:** Explicitly planning a traceability normalization phase rather than trying to fix metadata drift as a side effect of other work kept the closure clean and auditable.

### What Was Inefficient

- **Audit `tech_debt` status required two cleanup phases:** The v1.2 milestone audit landed at `tech_debt` rather than `passed` because requirement trace metadata was inconsistent across summaries. Phases 13 and 14 were planned specifically to close that debt. Better metadata discipline during earlier phases would have avoided these cleanup phases entirely.
- **Summary frontmatter inconsistency:** Three different frontmatter keys (`requirement:`, `requirements:`, `requirements-completed`) were used across phases. A shared frontmatter convention established before execution would have prevented the Phase 13-01 repair work.
- **Validation artifacts left draft:** Phases 10 and 11 VALIDATION files were left in partial/draft state after their respective phases completed. Building validation closure into the phase execution checklist rather than deferring to Phase 14 would be cleaner.

### Patterns Established

- **Release preflight pattern:** `mix hex.build --unpack → metadata gate → release-doc parity gate → install smoke → mix docs --warnings-as-errors` as the canonical pre-publish sequence, invoked both locally and from CI.
- **Parity test with refutation:** Assert both required presence (step names, commands) and prohibited absence (stale/deferred wording) to catch both omission and regression drift.
- **`requirements-completed: [REQ-ID]` frontmatter:** Canonical key for all phase summaries that close a milestone requirement, enabling strict three-source audit cross-checks.
- **Validation closure pattern:** After a phase is verified, flip VALIDATION.md markers from ready/draft to complete by confirming evidence in VERIFICATION.md, then updating frontmatter, Per-Task Map, Wave 0 checklist, and Approval line atomically.

### Key Lessons

- Establish a shared summary frontmatter schema (`requirements-completed:`) and validate it during phase planning, not after audit.
- Build VALIDATION artifact closure into the phase execution checklist — don't leave `wave_0_complete: false` after a phase passes VERIFICATION.
- Audit `tech_debt` status is acceptable at milestone close if the debt is non-blocking, but it reliably generates cleanup work. Tighter metadata hygiene during execution is cheaper than dedicated closure phases.
- Scoped publish automation (protected environment, version gate, CI dry-run) is the right pattern before any broader distribution or protocol work.

### Cost Observations

- Sessions: multiple parallel executor worktrees used in Phases 13 and 14
- Notable: Phase 13 and 14 combined took ~10 minutes of execution time despite representing 4 plans — metadata and documentation closure work is fast when evidence already exists

---

## Milestone: v1.6 — Provider Boundary + Mux

**Shipped:** 2026-05-07
**Phases:** 4 (33–36) | **Plans:** 15

### What Was Built

- `Rindle.Streaming.Provider` promoted from a v1.4-reserved 2-callback seam to a runtime contract with locked callbacks (capability query, asset CRUD, signed playback URL, webhook verify, optional direct-creator-upload)
- Closed `Rindle.Streaming.Capabilities` vocabulary; profile DSL `:streaming` key validated through NimbleOptions; 8-branch `Rindle.Delivery.streaming_url/3` dispatch tree; 5 additive locked error atoms with byte-frozen parity test
- Additive `media_provider_assets` Ecto table + `MediaProviderAsset` schema with FSM and `Inspect` redaction (security invariant 14)
- `Rindle.Streaming.Provider.Mux` reference adapter with `mux ~> 3.2` + `jose ~> 1.11` as **optional deps** (zero transitive cost for non-streaming adopters)
- `MuxIngestVariant` server-push ingest worker with atomic-promote race protection, two-layer Oban-unique idempotency, 429 Retry-After snooze, compensating Mux delete on drift
- Explicit JOSE-signed JWT TTL respecting profile policy (defeats Mux SDK's 7-day default footgun)
- `MuxSyncCoordinator` + `MuxSyncProviderAsset` defensive-poll workers with stuck-threshold transition; cross-cutting telemetry redaction parity test
- Mountable `Rindle.Delivery.WebhookPlug` with raw-body cache (`WebhookBodyReader`, 1 MiB cap, list-of-binaries assigns shape, `Plug.Parsers` JSON bypass)
- HMAC-SHA256 verify via `Mux.Webhooks.verify_header/4`, configurable 60–900s replay window, multi-secret rotation with `secret_index` telemetry
- `IngestProviderWebhook` Oban worker idempotent on Mux event UUID, race-snooze on row-missing, two-topic PubSub broadcast with provider-id redaction
- Typed `video.upload.asset_created` branch (D-29 silent-corruption fix as forward-compat for Phase 37)
- `mix rindle.runtime_status --provider-stuck` operator-visibility extension on the v1.5 surface
- `Rindle.Profile.Presets.MuxWeb` ships alongside `Rindle.Profile.Presets.Web` with `:streaming` opt-in + `:signed` named playback policy
- `mix rindle.doctor --streaming` adds 4 PASS/FAIL streaming checks + 5s smoke ping to `Mux.Video.Assets.list/1` (env-var names only, never values)
- `guides/streaming_providers.md` (341 lines, 11 sections) — env vars, signing-key creation, secret rotation, raw-body wiring, ngrok-tunnel guidance
- README + getting-started gain `Streaming with Mux (optional)` subsections (≤15 lines each) without displacing image/AV first-run path
- Generated-app `mux-enabled` proof harness — cassette lane every PR (Mox-on-`:http_client`, zero secrets); label-gated `mux-soak` real-Mux sibling job on `streaming`-labelled PRs only with three-layer asset-leak mitigation

### What Worked

- **Locked candidate research up front:** Three locked candidate plans (`v1.6-CANDIDATE-PROVIDER-MUX.md`, `v1.6-CANDIDATE-GCS.md`, `v1.6-CANDIDATE-TUS.md`) before milestone planning meant the scope conversation became a scoring exercise (8/10 vs 7.5/10 vs 6/10) rather than open-ended ideation. v1.7 and v1.8 candidates emerged free as research byproducts.
- **Single-provider rule kept the abstraction honest:** Resisting "ship Cloudflare Stream alongside Mux" preserved the contract boundary; the second adapter becomes the contract test in v1.7+ rather than a parallel codepath that drifts.
- **Optional deps pattern (`mux` + `jose`):** Adopters who don't enable streaming pay zero transitive cost — `Mox.set_mox_from_context` with `Code.ensure_loaded?` guards mean even the test suite respects the optional boundary.
- **Phase 33 lock-without-Mux-code:** Landing the contract, schema, DSL, dispatch tree, and error vocabulary in Phase 33 with **zero Mux code** meant Phases 34-36 had a stable contract to consume; a single behaviour signature change in Phase 34 would have rippled across 11 plans.
- **D-29 forward-compat fix:** Phase 35 landed the typed `video.upload.asset_created` branch as forward-compat (D-29) even though Phase 37 was always optional. When Phase 37 didn't pull forward, the branch still exists in Phase 35 with no rework needed when v1.7 adds direct creator upload.
- **Three-layer soak cleanup design:** try/after + `if: always()` + idempotent cleanup with last-4 redaction was the right defense-in-depth pattern for Mux quota burn (CR-01/02 found gaps in two of three layers; layer 2 still works).
- **Decision-making preference paid off:** "Front-load research, decide by default, escalate only impactful decisions" cut interview cost on Phases 33-36 dramatically. 46 decisions locked in Phase 35 alone via three parallel research subagents.

### What Was Inefficient

- **Verification status model needed a CI-specific state:** Phase 36 proved that CI-time provider observables were being misclassified as `human_needed` even when no human interaction was required. The repo now uses `ci_verified` for accepted secret-backed/provider-backed automation, reserving `human_needed` for true manual review.
- **Code-review BLOCKERs without verifier blocking:** CR-01/02/03 in Phase 36 were operational defects in the soak lane that didn't block the milestone goal but were classified BLOCKER by the reviewer. Better classification (e.g., `goal-blocking BLOCKER` vs `operational BLOCKER`) would let the verifier resolve "5/5 must-haves verified, 3 advisory blockers tracked" without ambiguity at close.
- **Auto-extracted milestone accomplishments:** `gsd-sdk milestone.complete` produced 14 noisy auto-extracted lines mixing real accomplishments with code-review fix entries and test-pass strings. Required manual rewrite to match v1.5's milestone-summary cadence.
- **`requirements-completed` not flipped at phase summary time:** REQUIREMENTS.md still showed `MUX-01..08`, `MUX-15..19` as `[ ] (Planned)` even after Phases 34-36 closed because the per-plan SUMMARY frontmatter wasn't propagated into REQUIREMENTS.md. Required manual ticking before milestone archive.

### Patterns Established

- **Reserved-then-promoted contract pattern:** v1.4 reserved `streaming_url/3` and `Rindle.Streaming.Provider` as no-op delegates / 2-callback stubs; v1.6 Phase 33 promoted them to runtime behaviour with zero adopter churn. This is a v2.0-safe namespace pattern for future provider work.
- **Optional-dep + Mox-on-client pattern:** Provider SDKs (`mux`, future `cloudflare_stream_*`) ship as optional deps; Rindle defines a `Client` behaviour; production wires the SDK; tests wire `Mox`-stubbed `ClientMock`. Cassette lanes pass with zero secrets.
- **Raw-body cache via `Plug.Parsers :body_reader` MFA:** Adopters mount via documented `forward` declaration; Stripe.WebhookPlug parity. The MFA pattern bypasses JSON decoding only in the webhook scope without inventing a separate route.
- **Three-layer cleanup pattern for external resource leaks (CI):** try/after (in-test) + `if: always()` (CI step) + idempotent cleanup script (belt-and-suspenders). Even when one layer fails (CR-01/02), the other two contain the leak.
- **Label-gated real-API CI lane:** Cassette lane runs every PR (zero secrets); real-API soak lane is `streaming`-PR-label-gated and uses `pull_request` (NOT `pull_request_target`) to fail closed on fork PRs.
- **Provider-internal ID redaction (security invariant 14):** Last-4-char tag redaction in telemetry, logs, `Inspect`, and PubSub payloads. Cross-cutting parity test enforces redaction at every emit site.
- **D-style typed-branch forward-compat:** When a downstream phase is optional but a future-adjacent surface is risky, land the typed handler as a no-op or pass-through in the current phase rather than wait for the optional phase. Avoids retrofit cost if the optional phase later pulls forward.

### Key Lessons

- Single-provider rule is non-negotiable: the contract is the deliverable, not the catalog of providers. Second-adapter pull-in is the contract test, not the contract.
- Optional deps need test-suite-aware design: `Code.ensure_loaded?` guards aren't enough — Mox stubs need `:http_client` config wiring at the adapter level, not module-level conditional compilation.
- Provider-internal IDs leak everywhere by default: telemetry, logs, `Inspect`, PubSub, error messages. A cross-cutting redaction parity test is the only way to prevent regression as new emit sites are added.
- "Defer to next milestone" is a first-class scope move, not a scope failure: Phase 37 deferral kept v1.6 budget honest. Pulling it forward would have added ~1 day on top of an already-tight 7.5-day milestone.
- CI-time observables ≠ artifact gaps: A verifier scoring 5/5 with 5 items routed to human queue is a closed phase, not an open one. The audit semantics need to distinguish "verification didn't happen yet" from "verification can only happen in this environment."

### Cost Observations

- Sessions: spanned 2 days (2026-05-06 → 2026-05-07), 152 commits in milestone range
- Notable: Phase 35 took ≈40% of milestone effort (4 plans, highest-risk webhook + Plug + worker work) but landed without rework via parallel research subagents (mountable Plug pattern + IngestProviderWebhook contract + Mux event catalog)
- Notable: Phase 33 (4 plans, zero Mux code) was the highest-leverage phase — locking the contract before any adapter code meant Phases 34-36 consumed it without negotiation
- Notable: 144 files changed / 42,665 insertions; ratio of test:lib commits ≈ 1:1 (true TDD cadence on adapter callbacks + Plug + worker contracts)

---

## Cross-Milestone Trends

| Trend | v1.1 | v1.2 | v1.5 | v1.6 | v1.16 |
|-------|------|------|------|------|-------|
| Cleanup phases needed | 0 | 2 (Phases 13, 14) | 0 | 0 | 1 (Phase 77) |
| Audit status at close | passed | tech_debt (closed) | passed | acknowledged-and-defer | no dedicated audit (gap-closure) |
| Plans per phase (avg) | 3.0 | 2.2 | 3.5 | 3.75 | 3.3 |
| Phase count | 4 | 5 | 4 | 4 | 3 |
| Files changed | — | 60 | — | 144 | 19 |
| Timeline (days) | — | 5 | 2 | ~1 (~22h) | 1 |
| Optional phase deferred | — | — | — | Phase 37 (deferred to v1.7) | — |

**Recurring observation:** Each milestone has ended with some planning artifact debt (stale STATE.md references, incomplete VALIDATION files, metadata inconsistencies, REQUIREMENTS.md checkboxes not flipped). The debt accumulates faster than it is addressed during execution. A milestone-close checklist that explicitly audits these before declaring done would reduce closure phase count.

**v1.6 trend:** First milestone to formalize "acknowledged-and-defer" close mode — recognizing that some artifact-and-wiring-complete phases route observable proof to CI/maintainer environments by design. The audit semantics need to evolve to distinguish these from real gaps. Optional-phase deferral (Phase 37 → v1.7) emerged as a clean scope-management primitive separate from cleanup-phase work.
