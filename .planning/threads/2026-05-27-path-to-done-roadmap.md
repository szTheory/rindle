# Path-to-Done Roadmap (v1.17+ boundary)

Date: 2026-05-27
Status: active (canonical multi-milestone ordering)
Supersedes: none (extends post-v116 assessment with milestone sequence)

## Framing

Rindle is a Phoenix/Ecto-native **media lifecycle library** — durable work *after* upload.
**Done** for this roadmap = mission-complete frontier reached (~95%+) with no
IMPORTANT-BUT-NARROW wedges left unless explicitly deferred with documented demand gate.

**Done estimate:** ~94–96% (90–95% near-done band). T0–T2 complete; T3 demand-driven only.
See [JTBD-MAP.md](../JTBD-MAP.md) and
[post-v116 assessment](2026-05-27-post-v116-milestone-assessment.md).

**Confidence:** High on shipped capabilities (`lib/`, `test/`, `guides/`). Residual
uncertainty is exact done-% (94 vs 96), not whether core flows exist.

## Repo verification (2026-05-27)

Parallel inspection confirmed (code, not docs alone):

| Gap | Verified state | Evidence |
|-----|----------------|----------|
| LIFE-06 force-delete | **Not built** | `OwnerErasure.execute/2` ignores opts; purges only when `surviving_attachment_count == 0` (`lib/rindle/internal/owner_erasure.ex:106-118`); moduledoc denies force-delete (`lib/rindle.ex:47-48`) |
| STREAM-10 second provider | **Not built** | Single adapter `Rindle.Streaming.Provider.Mux` (`lib/rindle/streaming/provider/mux.ex`); Mux-only guide (`guides/streaming_providers.md:3`) |
| CI proof honesty | **Maintenance wedge closed** | `mix coveralls` merge-blocking; Credo/Dialyzer advisory (`ci.yml`); `proof` job merge-blocking |
| Batch erasure force opt-in | **Not propagated** | `run_batch_owner_erasure/3` hardcodes `[]` per-owner opts (`lib/rindle.ex:1007`) |

**Doc drift note:** post-v116 assessment has 3 stale phrases around unit-test blocking
status (§ Done estimate L30, § Rough edges L63, § Optional micro L81). `ci.yml` is
source of truth — coveralls is merge-blocking.

## Mission-complete definition

Rindle reaches **mission complete** when:

1. T0–T2 JTBD tiers remain shipped (no regression)
2. All IMPORTANT-BUT-NARROW T3 gaps are either:
   - shipped on explicit demand (LIFE-06, STREAM-10), or
   - explicitly deferred with documented demand gate in PROJECT.md Out of Scope
3. No open CI/proof honesty gaps block adoption
4. Maintainer declares maintenance mode in PROJECT.md Current Milestone

Long-tail polish (TRANS-01, PRIV-01) is **not required** for mission complete.

## Multi-milestone sequence

### Milestone 0 (current): Demand-gated pause — DEFAULT

- **Status:** Active (post-v1.16)
- **Work:** Patch/minor Hex releases; issue-driven fixes only
- **Prereq:** None
- **Done enough:** Assessment + path-to-done threads current; no blocking CI gaps
- **Do NOT:** Open speculative feature milestone

### Milestone v1.17 (conditional — pick ONE branch at `/gsd-new-milestone`)

#### Branch A: `v1.17 Force-Delete Shared Assets` (LIFE-06)

**Trigger:** Concrete compliance/legal ticket (record in milestone charter)

| Phase | Theme | Prereq | REQ-IDs | Done enough |
|-------|-------|--------|---------|-------------|
| 78 | Contract freeze | v1.10 owner-erasure facade | LIFE-06-01 | Opt-in `force:` types; preview collateral-damage report; frozen error vocab |
| 79 | Execute path | Phase 78 | LIFE-06-02 | Force-purge shared assets; never default; batch inherits opt-in |
| 80 | Proof + truth | Phase 79 | LIFE-06-03 | Hermetic matrix + guide/docs parity + `docs_parity_test` lock |

**Blast radius:** High — conflicts with conservative shared-asset contract (PROJECT.md Key Decisions v1.10)
**Size:** ~3 phases

**Implementation checklist (from repo inspection):**

- Wire `force: true` through `OwnerErasure.preview/2` and `execute/2` (opts currently ignored)
- Planner branch: move `surviving_attachment_count > 0` assets to purge-eligible bucket when forced
- Preview: surface collateral damage (other owners affected)
- Propagate through `run_batch_owner_erasure/3` and `mix rindle.batch_owner_erasure --force`
- Update moduledoc contract in `lib/rindle.ex` (currently denies force-delete)
- Hermetic tests + `docs_parity_test.exs` vocabulary lock

#### Branch B: `v1.17 Second Streaming Provider` (STREAM-10)

**Trigger:** Named adopter + provider choice documented (Cloudflare Stream or Bunny)

| Phase | Theme | Prereq | REQ-IDs | Done enough |
|-------|-------|--------|---------|-------------|
| 78 | Contract audit | v1.6 provider behaviour | STREAM-10-01 | Mux proves all `@callback`s; gap list for second adapter |
| 79 | Adapter + doctor | Phase 78 | STREAM-10-02 | One adapter; `mix rindle.doctor --streaming` extended |
| 80 | Proof + truth | Phase 79 | STREAM-10-03 | Hermetic + label-gated soak; guide parity |

**Prereq:** Named adopter
**Size:** ~3–4 phases (large — new optional dep, webhook/sync, Mux-coupled workers to generalize)

**Mux coupling to address:**

- Workers: `MuxIngestVariant`, `MuxSyncCoordinator`, `MuxSyncProviderAsset`
- Doctor: Mux-specific env vars and checks (`runtime_checks.ex`)
- CI: `:mux` install-smoke only; need second profile mode + optional soak lane
- Cancel: Mux-only in v1.13; provider-agnostic cancel deferred to STREAM-10

#### Branch C: `v1.17 Adopter-Confidence Hygiene` (optional micro)

**Trigger:** Maintainer choice; no public API

- JTBD anchor refresh (already at v1.16)
- Fix stale phrases in post-v116 assessment thread
- Residual CI policy decision: Credo/Dialyzer merge-blocking (currently deferred)
- **Done enough:** Updated threads + RUNNING.md truth; no new `lib/` surface
- **Size:** 1–2 phases max

**If both LIFE-06 and STREAM-10 signals exist:** sequence **LIFE-06 first** (compliance blast
radius; extends existing facade; second provider is greenfield adapter work).

### Milestone v1.18+ (only if prior conditional shipped OR new demand)

| Priority | Milestone | Trigger | REQ-IDs | Notes |
|----------|-----------|---------|---------|-------|
| 1 | Whichever of LIFE-06 / STREAM-10 was not v1.17 | Second demand signal | Same as above | Same phase structure |
| 2 | `v1.19 Privacy & Delivery Polish` | Explicit product pull | TRANS-01, PRIV-01 | Jobs 33–34; long-tail |
| 3 | `v1.20+ GCS tus/resumable depth` | Adopter request only | — | Partial today; not on critical path |

### Terminal state: Mission complete — maintenance mode

After v1.17 conditional (or if no demand ever arrives):

1. Update PROJECT.md Current Milestone → **"Mission complete — maintenance mode"**
2. Archive this thread alongside final assessment
3. Stop proactive feature milestones; reopen only on new adopter/compliance signal
4. Continue: Hex releases, security patches, Elixir/Phoenix compat

## Suggested ordering

```
Pause (now) → LIFE-06 (if legal) → STREAM-10 (if adopter) → TRANS/PRIV (if pull) → STOP
```

## Do not build (default)

- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Generic uploader component library
- Platform scope (DRM, HLS platform, admin UI, CDN replacement)
- Second streaming provider speculatively "to finish the abstraction"
- Force-delete bundled into maintenance without explicit charter

## REQ-ID traceability (deferred from v1.16)

| REQ-ID | Milestone branch | Job # | Status |
|--------|------------------|-------|--------|
| LIFE-06 | v1.17 Branch A | 32 extension | deferred (demand-gated) |
| STREAM-10 | v1.17 Branch B | — | deferred (demand-gated) |
| TRANS-01 | v1.19+ | 33 | deferred (long-tail) |
| PRIV-01 | v1.19+ | 34 | deferred (long-tail) |

Source: `.planning/milestones/v1.16-REQUIREMENTS.md` Future Requirements

## Graduation candidates (cross-phase patterns)

Reuse in LIFE-06 and STREAM-10 milestones:

1. **Contract-before-implementation** — freeze types, error vocab, preview report shape before execute path (v1.13 cancel pattern)
2. **Gap-closure sequencing** — planning truth before CI wiring (v1.16 retro)
3. **Moduledoc `Code.fetch_docs/1` contract tests** — support-truth lock (v1.16 TRUTH-05)
4. **Demand-gated milestone boundary** — `block_feature_milestone_without_signal` is correct default
5. **Proof lane separation** — highest-signal proofs merge-blocking; static analysis advisory

## Verdict

**Finish the last important wedges on demand — mostly stop proactive feature work.**

Default maintainer action: **stay in pause**. Open v1.17 only with compliance ticket (LIFE-06)
or named adopter (STREAM-10).

## Evidence pointers

- Owner erasure: `lib/rindle/internal/owner_erasure.ex`, `lib/rindle.ex` moduledoc
- Streaming: `lib/rindle/streaming/provider.ex`, `lib/rindle/streaming/provider/mux.ex`
- CI: `.github/workflows/ci.yml`, `RUNNING.md`
- JTBD: `.planning/JTBD-MAP.md`
- Assessment: `.planning/threads/2026-05-27-post-v116-milestone-assessment.md`
