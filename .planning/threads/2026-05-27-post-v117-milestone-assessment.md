# Post-v1.17 Milestone Assessment (v1.18 boundary)

Date: 2026-05-27
Status: canonical (supersedes post-v116 assessment for default-next recommendations)
Supersedes: `.planning/threads/2026-05-27-post-v116-milestone-assessment.md` (wedge ranking only; v1.17 ship facts unchanged)
Companion: `.planning/threads/2026-05-27-path-to-done-roadmap.md` (still valid; no reorder needed)

## Framing

Rindle is a Phoenix/Ecto-native **media lifecycle library** — durable work *after*
upload. **Done** for this assessment = a serious Phoenix SaaS team can adopt from
Hex + 14 guides + generated-app proof without spelunking internals.

**Confidence:** High on shipped capabilities (`lib/`, `test/`, `guides/`, CI).
Medium on exact done-% (94 vs 96). Roadmap prose drift from the 2026-05-27 pass is
**resolved** (2026-05-28 maintenance); confidence on support-truth docs is high again.

## Done estimate

**~94–96%** — band **90–95% near-done / diminishing returns soon**.

| Rubric axis | Assessment |
|-------------|------------|
| Core JTBD | T0–T2 complete; 32/36 jobs shipped per JTBD-MAP; T3 gaps demand-gated only |
| Breadth vs category | Matches Active Storage / Shrine / Spatie *lifecycle* for Phoenix |
| Docs / onboarding | Strong: facade-first, 14 guides, operations index, docs parity tests |
| Ops / support-truth | Nine `mix rindle.*` tasks; owner-erasure facade locked in moduledoc |
| Proof / CI | Merge-blocking: `proof`, `package-consumer`, `adopter`, `integration`, `quality` (coveralls); Credo/Dialyzer advisory (CI-04) |

## Repo verification (2026-05-27)

Parallel source inspection (not docs alone):

| Gap | Verified state | Evidence |
|-----|----------------|----------|
| LIFE-06 force-delete | **Not built** | `OwnerErasure.execute/2` ignores opts (`lib/rindle/internal/owner_erasure.ex:25-26`); purge only when `surviving_attachment_count == 0`; `PurgeStorage` no-ops if attachments exist; moduledoc denies force-delete (`lib/rindle.ex:47-48`) |
| Batch opts propagation | **Latent gap** | `run_batch_owner_erasure/3` hardcodes `[]` per owner (`lib/rindle.ex:1007`); must fix before LIFE-06 |
| STREAM-10 second provider | **Not built** | Single adapter `Rindle.Streaming.Provider.Mux`; workers/webhooks/doctor/CI Mux-coupled |
| TRANS-01 dynamic transforms | **Not built** | Named presets only (by design) |
| PRIV-01 EXIF strip on originals | **Partial** | Variants drop metadata; originals served as-is |
| Tus + Mux direct upload | **Shipped** | TusPlug, `initiate_tus_upload/2`, `create_direct_upload/2`, cancel — CI smoke on every PR |

## New findings (2026-05-27 pass)

### 1. user_flows roadmap drift — **RESOLVED 2026-05-28**

| Item | Resolution |
|------|------------|
| § "Where Rindle is headed" listed tus/Mux as near-term | Already fixed on `main` before reassessment — section states shipped v1.8–v1.11 |
| Find-your-job omitted tus | Fixed: tus row + GCS row clarified (`guides/user_flows.md`) |
| Regression risk | Locked: `docs_parity_test.exs` refutes near-term tus/Mux language |

### 2. Image-only install-smoke not PR merge-blocking — **RESOLVED 2026-05-28**

PR `package-consumer` job already runs `install_smoke.sh image` (`.github/workflows/ci.yml`).
README claim is accurate for merge-blocking generated-app proof. No further action.

## Adopter coverage map

| Flow | Status |
|------|--------|
| Presigned / multipart direct upload | Well-served |
| Tus resumable (S3/Local) | Well-served |
| Server-side upload + promote | Well-served |
| Image variants + signed delivery | Well-served |
| AV video/audio + poster/waveform | Well-served |
| Mux streaming + direct upload + cancel | Well-served |
| Owner + batch GDPR erasure | Well-served |
| GCS storage (non-tus) | Partially-served (live proof secret-gated) |
| Malware scan | Extension point only (`Rindle.Scanner`) |
| Force-delete shared blobs | Not built |
| Second streaming provider | Not built |
| Signed dynamic transforms | Not built (by design) |
| EXIF/GPS strip on originals | Partial |

**Rough edges:** AV-centric README default; libvips not in install path.

## Ranked wedges (v1.18+ only when demanded)

| Rank | Wedge | Type | Done enough | Size |
|------|-------|------|-------------|------|
| 1 | **Demand-gated pause (default)** | Posture | Assessment + path-to-done current | — |
| 2 | Force-delete (LIFE-06) | IMPORTANT-BUT-NARROW | Opt-in `force:` preview + execute; batch/CLI inherit; PurgeStorage force path; proof + docs lock | ~3 phases |
| 3 | Second provider (STREAM-10) | IMPORTANT-BUT-NARROW | Contract audit → one adapter + doctor → proof/truth; generalize Mux-coupled workers | ~3–4 phases (large) |
| 4 | Adopter doc/proof hygiene | IMPORTANT-BUT-NARROW | libvips callout only (user_flows + image smoke closed 2026-05-28) | Issue-driven |
| 5 | TRANS-01 / PRIV-01 polish | LONG-TAIL | Signed bounded transforms; EXIF strip on originals | Explicit product pull |

## Recommended next milestone

**Default: No feature milestone.** Continue demand-gated pause. Patch/minor Hex
releases and issue-driven fixes only.

**Conditional upgrade A:** v1.18 Force-Delete Shared Assets (LIFE-06) — only on
concrete compliance/legal ticket recorded in milestone charter.

**Conditional upgrade B:** v1.18 Second Streaming Provider (STREAM-10) — only on
named adopter + provider choice (Cloudflare Stream or Bunny).

**Suggested ordering:**

1. Pause / patch releases (now)
2. LIFE-06 (if legal pull)
3. STREAM-10 (if named adopter)
4. Issue-driven doc/proof fixes (libvips callout, if needed)
5. TRANS-01 / PRIV-01 (if explicit product pull)

## Do not build (default)

- IETF RUFH / tus 2.0, GCS-as-tus-backend, standalone tus JS client
- Second provider speculatively "to finish the abstraction"
- Force-delete without compliance charter
- Signed dynamic transforms without adopter pull
- Platform scope (DRM, HLS platform, admin UI, CDN replacement)

## Graduation candidates (for next phase LEARNINGS)

- Batch erasure opts propagation must be fixed before LIFE-06 ships
- Second provider requires worker/webhook generalization, not adapter-only
- Adopter docs should be CI-locked for "shipped vs near-term" roadmap sections

## Reassessment (2026-05-28)

Repo-verified refresh after maintenance + release-train work:

- **Default unchanged:** demand-gated pause; no v1.18 feature milestone.
- **Wedge #4 (doc/proof hygiene):** closed for user_flows roadmap + PR image smoke.
- **Release train:** Hex `0.1.6` live; automerge + branch-protection cron green; baseline
  job failed on first publish run then fixed (`43cfe62`); next publish must prove
  automated baseline PR merge (see `.planning/RELEASE-TRAIN.md` verification log).
- **LIFE-06 / STREAM-10:** still not built; still demand-gated only.

## Verdict

**Mostly stop.** Mission-complete frontier reached for stated scope (~94–96%).
Finish last wedges only on explicit demand. Risk is overbuilding, not under-shipping.
