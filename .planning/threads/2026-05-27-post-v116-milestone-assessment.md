# Post-v1.16 Milestone Assessment (v1.17+ boundary)

Date: 2026-05-27
Status: active (canonical assessment for between-milestones)

## Framing

Rindle is a Phoenix/Ecto-native **media lifecycle library** — durable work *after*
upload (sessions, verification, assets, variants, Oban processing, signed delivery,
cleanup, owner erasure). It is not a file-upload helper, streaming platform, or CDN
product.

**Done** for this assessment means a serious Phoenix SaaS team can adopt from Hex +
14 guides + generated-app proof without spelunking internals.

**Confidence:** High on shipped capabilities (`lib/`, `test/`, `guides/`). Medium on
exact done-% (94 vs 96). Planning drift on *next-wedge* ranking was resolved in this
thread (supersedes post-v114 assessment for default-next recommendations).

## Done estimate

**~94–96%** — band **90–95% near-done / diminishing returns soon**.

| Rubric axis | Assessment |
|-------------|------------|
| Core JTBD | T0–T2 complete; bulk of T3 (tus, Mux direct+cancel, owner/batch erasure) shipped v1.8–v1.16 |
| Breadth vs category | Matches Active Storage / Shrine / Spatie *lifecycle* expectations for Phoenix; lacks niche enterprise items only |
| Docs / onboarding | 14 guides; README → getting_started; merge-blocking `docs_parity_test` |
| Ops / support-truth | Nine `mix rindle.*` tasks; owner-erasure facade contract in `lib/rindle.ex` moduledoc |
| Proof / CI | Merge-blocking: `proof` job, `package-consumer`, `adopter`, `integration`, `contract` AV hygiene, and `quality` — Run tests with coverage (`mix coveralls`; both matrix cells). Advisory in `quality`: Credo, Doctor, AV doctor, Dialyzer (`continue-on-error: true` in `.github/workflows/ci.yml`). See `RUNNING.md` `## CI lane severity`. |

## v1.15–v1.16 result (shipped)

**v1.15 Maintenance & Proof Honesty:** CI lane severity matrix; PROOF-06
`batch_owner_failed` mix E2E; Nyquist closure phases 68–70; TRUTH-04 ops index;
v1.15 milestone audit.

**v1.16 CI Enforcement & Planning Hygiene:** Merge-blocking `proof` CI job;
TusPlug `@moduledoc` + `Code.fetch_docs/1` lock; planning truth cleanup (phases
75–77). No new public API.

The **maintenance / proof honesty** wedge from post-v114 assessment is **closed**.

## Adopter coverage map

| Flow | Status |
|------|--------|
| Presigned / multipart direct upload | Well-served |
| Tus resumable browser ingest | Well-served |
| Server-side upload + promote | Well-served |
| Image variants + signed delivery | Well-served |
| AV (FFmpeg) video/audio | Well-served |
| Mux streaming + direct upload + cancel | Well-served |
| Owner + batch GDPR-style erasure | Well-served |
| GCS storage (non-tus) | Partially-served (adapter real; tus/multipart deferred; live proof secret-gated) |
| Force-delete shared blobs | Not built (`OwnerErasure.execute/2` has no force path) |
| Second streaming provider | Not built (only `Provider.Mux`) |
| Malware scan | Extension point only (`Rindle.Scanner` behaviour) |
| Signed dynamic transforms (job 33) | Not built |
| EXIF/GPS strip on originals (job 34) | Partial (variants drop metadata; originals as-is) |

**Rough edges:** Streaming/tus need optional deps + webhook mount. TUS multi-node needs
sticky sessions. Green PR CI blocks on the default unit suite (`mix coveralls` in `quality`) but
Credo, Doctor, and Dialyzer remain advisory (`continue-on-error: true` in `.github/workflows/ci.yml`;
`RUNNING.md` `## CI lane severity`). Contract ExUnit (`--only contract`) is also advisory.

## Ranked wedges (v1.17+ only when demanded)

| Rank | Wedge | Type | Done enough |
|------|-------|------|-------------|
| 1 | Planning hygiene | IMPORTANT-BUT-NARROW | **Done 2026-05-27:** post-v116 thread TRUTH-06 closure, JTBD anchor v1.16 refresh; no feature surface |
| 2 | CI confidence tightening | IMPORTANT-BUT-NARROW | **Done 2026-05-27:** `mix coveralls` merge-blocking; Credo/Dialyzer still advisory |
| 3 | Force-delete (LIFE-06) | IMPORTANT-BUT-NARROW | Opt-in `force:`; preview collateral damage; never default |
| 4 | Second provider (STREAM-10) | IMPORTANT-BUT-NARROW | One adapter + doctor; explicit adopter demand only |
| 5 | Jobs 33–34 polish | LONG-TAIL | Signed dynamic transforms / EXIF strip on explicit pull |

## Recommended next milestone

**Default: No feature milestone.** Do not open `/gsd-new-milestone` with a feature
charter unless there is a concrete compliance ticket (LIFE-06) or a named adopter
requesting a second provider (STREAM-10).

**Active micro milestone (Branch C, 2026-05-27):** v1.17 Adopter-Confidence Hygiene —
planning-truth closure (Phase 78) and explicit Credo/Dialyzer policy record (Phase 79 / CI-04).
Default unit suite merge-blocking shipped in commit `0036760`. **No new public API.**

**Conditional upgrade:** v1.17 Force-Delete Shared Assets (LIFE-06) — only if
legal/compliance requires destroying blobs that still have surviving attachments from
other owners.

**Suggested ordering after that:**

1. Demand-gated pause / patch releases only
2. LIFE-06 (if legal pull)
3. STREAM-10 (if named adopter)
4. Jobs 33–34 (if explicit product pull)

## Do not build (default)

- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Generic uploader component library
- Platform scope (DRM, HLS platform, admin UI, CDN replacement)
- Second streaming provider speculatively "to finish the abstraction"
- Force-delete bundled into maintenance without explicit charter

## Open concerns (non-blocking)

### CI proof honesty (residual)

Merge-blocking lanes now include `proof`, `package-consumer`, `adopter`, `integration`,
`contract` (AV hygiene), and **`quality` — Run tests with coverage** (`mix coveralls`,
2026-05-27). **Advisory:** Credo, Doctor, Dialyzer in `quality` job. Release workflow can
bypass CI on timeout/failure (`gate-ci-green` BYPASSED). See `RUNNING.md` and
`.github/workflows/ci.yml`.

**Decision deferred:** Credo / Dialyzer merge-blocking (static-analysis policy unchanged).

### Planning hygiene

- JTBD-MAP was stale at v1.15 anchor until patched 2026-05-27 (this assessment pass).
- No dedicated `v1.16-MILESTONE-AUDIT.md` (gap-closure validated via phase artifacts).

## Verdict

**Finish the last important wedges on demand — mostly stop proactive feature work.**

Core JTBD for the stated mission is shipped. Maintenance/proof wedge is complete through
v1.16. Force-delete is the single feature milestone worth opening on compliance pull.

## Evidence pointers

- v1.16 archive: `.planning/milestones/v1.16-ROADMAP.md`, `v1.16-REQUIREMENTS.md`
- v1.15 audit: `.planning/milestones/v1.15-MILESTONE-AUDIT.md`
- Owner erasure contract: `lib/rindle.ex` moduledoc, `lib/rindle/internal/owner_erasure.ex`
- CI lanes: `.github/workflows/ci.yml`, `RUNNING.md`
- JTBD: `.planning/JTBD-MAP.md`

## Supersedes

- `.planning/threads/2026-05-27-post-v114-milestone-assessment.md` — default-next and gap
  #1 (maintenance) recommendations are obsolete; maintenance shipped v1.15–v1.16.
