# Post-v1.25 Milestone Assessment

Date: 2026-08-27
Status: canonical (supersedes post-v1.17 assessment for current-state and next-work recommendations)
Supersedes: `2026-05-27-post-v117-milestone-assessment.md` (ranking only; historical facts remain valid)
Companion: `2026-05-27-path-to-done-roadmap.md` (demand gates remain valid)

## Framing

Rindle is a Phoenix/Ecto-native media lifecycle library: it owns durable work after upload rather than
trying to become a hosted media platform. “Done enough” means a serious Phoenix SaaS team can install the
published package, complete upload→verify→attach→deliver flows, operate and repair them, and trust the
documented failure behavior without spelunking internals.

Evidence priority for this assessment was shipped code/tests/install-smoke/demo first, active planning
second, archives third, and prompts last. Confidence is high on shipped capabilities and the purge bug;
medium on external adoption because no independent adopter evidence is recorded.

Two planning surfaces drifted from shipped truth during assessment:

- `JTBD-MAP.md` is anchored at v1.18 / Hex 0.3.0.
- Current and archived roadmaps contained a Phase 132 block saying `21/22 plans executed`, while the
  v1.25 audit proved 22/22 and passed closure. Both roadmap counts were corrected during shipment prep.

These lower planning-surface confidence but do not erase the code, package, audit, or proof evidence.

## Current State

**Primary job:** make media durable inside a Phoenix application after bytes arrive: verified uploads,
asset/attachment state, variants and AV, private delivery, cleanup, repair, and operator visibility.

**Done estimate:** approximately **94%**, band **90–95% near-done / diminishing returns soon**.

| Rubric axis | Assessment |
|---|---|
| Core JTBD coverage | T0–T2 flows are shipped; one core purge failure invariant is false |
| Breadth vs category | Direct/server/multipart/tus/GCS upload, image/AV, Mux, LiveView, erasure, and admin are broad |
| Docs/onboarding/install/examples | Strong guides, packed generated apps, canonical adopter, Cohort demo; two planning maps are stale |
| Operator/admin/diagnostics | Doctor, runtime status, maintenance tasks, telemetry, and console are strong; purge errors are silent |
| Proof/CI honesty | Unusually strong layered proof, but current purge tests cover success/no-op only and v1.25 is not remote yet |
| Remaining delta | One foundational correctness patch; otherwise important-but-narrow or long-tail demand gates |

Rindle is code-mature enough to discuss 1.0, but not independently adopter-validated enough to make the
stability promise. Hex 0.4.4 is live; the package has 1,584 all-time downloads and 148 in the current
week as of this assessment, but download counts do not replace a named pilot or blocked workflow.

## Adopter Coverage Map

### Well-Served

- Direct presigned, server-side, multipart, tus, and GCS resumable upload foundations.
- Attachment replacement/detach, image variants, AV poster/waveform/transcode, signed delivery, and
  responsive rendering.
- Mux signed streaming, browser-direct creator upload, webhook ingest/reconciliation, and cancel.
- Local/S3/GCS capability boundaries, adopter-owned Repo/Oban, dedicated-by-default Postgres schema,
  versioned migrations, and bounded upgrade/reversal guidance.
- Owner and batch erasure with conservative shared-asset semantics.
- Doctor/runtime status, maintenance tasks, telemetry, mountable admin console, troubleshooting, and
  operations guidance.
- Layered proof: packed generated Phoenix apps, canonical adopter, Cohort browser E2E, docs parity,
  release/public smoke, live-provider lanes, and supported-toolchain gates.

### Partially Served

- External adoption: Cohort is intentionally a maintainer-owned lab, not proof that an unrelated
  Phoenix team finds the API and brownfield migration path unsurprising.
- GCS browser demo: package/live-provider proof exists, while the demo Playwright spec remains a
  secret-gated placeholder.
- Malware detection: `Rindle.Scanner` is a real extension point, not a bundled scanning engine.
- Original privacy stripping: derived variants lose metadata, but originals have no explicit EXIF/GPS
  stripping control.
- Stable-version confidence: 0.4.4 permits minor-version breaking changes; two compatibility shims and
  the post-v1.3 public surface need explicit disposition before 1.0.

### Still Rough

- **Purge failure truth:** `PurgeStorage` discards every `Rindle.delete/3` result, deletes the asset row,
  and returns success. Tagged errors and normalized adapter exceptions therefore do not trigger Oban's
  three attempts, while remote keys lose their durable DB handle. This affects replacement, detach,
  single-owner erasure, and batch erasure.
- **Support-truth mismatch:** `guides/background_processing.md` says transient purge failures retry and
  cannot leave DB state inconsistent; current failure behavior contradicts that claim.
- **Remote shipment:** [PR #96](https://github.com/szTheory/rindle/pull/96) remains draft at `869ca9c`;
  local archive/tag `f5741dc` is 26 commits ahead.
- **Planning drift:** the v1.18 JTBD anchor still obscures otherwise strong current truth; the stale
  Phase 132 plan count was corrected during shipment prep.

Live issue signals do not authorize feature work. The only open issues are the previously narrowed
[async-isolation issue #42](https://github.com/szTheory/rindle/issues/42) and a stale
[nightly-failure issue #88](https://github.com/szTheory/rindle/issues/88); the four most recent nightly
runs are green. There is no LIFE-06 compliance ticket, STREAM-10 provider request, or named 1.0 pilot.

## Next-Work Recommendation

### 1. Purge failure truth and durability — FOUNDATIONAL correctness patch

**Why it matters:** this is a deterministic violation of the library's core durable-lifecycle promise,
not speculative breadth. Any adopter experiencing a storage/auth/network failure during replacement,
detach, or erasure can receive false success and lose the only durable repair handle.

**Who it serves:** every adopter using attachment cleanup or owner erasure.

**Done enough:** only delete the DB asset after all non-nil source/variant keys succeed or are
authoritatively already absent; preserve rows and return `{:error, reason}` for every real failure so
Oban retries; normalize S3 absence, GCS `:not_found`, and Local `:enoent`; prove variant/source failure,
adapter exception, partial retry, absence idempotence, and surviving-attachment no-op; correct operator
guidance. Do not bundle LIFE-06, public API, new telemetry, historical reconciliation, or soft-delete
redesign.

**Shape:** patch-eligible bugfix under the green-main release train, not a milestone.

### 2. External adopter evidence and 1.0 graduation — IMPORTANT-BUT-NARROW, conditional

**Why it matters:** stability and learnability now matter more than another feature. The code/proof
surface looks ready, but internal examples cannot validate an unrelated team's experience.

**Who it serves:** serious teams that will not accept a broad 0.x contract.

**Done enough:** a named non-maintainer Phoenix SaaS pilot installs the published 0.4.x artifact and
produces executable/sanitized evidence for primary lifecycle, migrations, and one day-two repair flow;
inventory and lock the current public API/types/errors/telemetry/migrations; explicitly retain or remove
legacy shims; graduate only if no pilot blocker requires another breaking 0.x release.

**Gate:** no named pilot exists. Do not start or declare 1.0 from maintainer confidence alone.

### 3. LIFE-06 force-delete shared assets — IMPORTANT-BUT-NARROW, conditional

**Why it matters:** strict legal deletion may require destroying a shared blob and accepting collateral
loss. Existing conservative owner erasure deliberately retains shared assets.

**Who it serves:** adopters with a concrete legal/compliance policy requiring physical deletion.

**Done enough:** explicit never-default force intent; preview identifies every surviving attachment and
owner affected; single/batch/CLI paths preserve conservative defaults; durable storage/provider
completion and race policy are truthful; hermetic and docs-parity proof cover the blast radius.

**Gate:** `.planning/threads/LIFE-06-prep.md` still has a pending ticket. Defer.

### 4. STREAM-10 second provider — IMPORTANT-BUT-NARROW, conditional

**Why it matters:** one adopter-chosen provider would validate the generic seam and unlock non-Mux
teams, but current workers/webhooks/doctor/CI remain materially Mux-coupled.

**Who it serves:** a named team already committed to Cloudflare Stream, Bunny, or another provider.

**Done enough:** exactly one selected adapter and required capabilities; durable provider state,
verified webhook readiness, signed playback, lost-webhook reconciliation, truthful redaction/errors,
provider-specific doctor/docs, hermetic adopter proof, and one bounded live proof. No catalog, routing
platform, DRM, or lowest-common-denominator abstraction.

**Gate:** no named adopter or provider choice exists. Defer.

### 5. TRANS-01 / PRIV-01 delivery and privacy polish — LONG-TAIL

Signed bounded transforms and original EXIF/GPS stripping are real but narrow. Build only from explicit
product/security pull after the core purge defect is fixed and a concrete adopter requests the policy.

## Milestone Decision and Ordering

**Single next-milestone recommendation: do not open one.** The highest-value work is a patch-eligible
correctness repair, and the repository has no qualifying feature or graduation signal.

Ordering:

1. Publish the local v1.25 closeout to PR #96 and require fresh exact-head proof before merge; the stale
   roadmap block was corrected during shipment prep.
2. Fix and release the bounded `PurgeStorage` correctness patch.
3. Return to the demand-gated pause.
4. If a named external pilot appears, evaluate the 1.0 graduation milestone.
5. If a compliance ticket or named provider request appears first, charter LIFE-06 or STREAM-10 from
   that concrete signal.

## Diminishing-Returns Judgment

The purge patch and genuine external adoption evidence are high leverage. Feature breadth is not.
Speculative second-provider work, force deletion without policy, dynamic transforms, tus 2.0,
GCS-as-tus-backend, uploader component kits, more internal demo proof, generic load testing, DRM/HLS
platform scope, or a ceremonial 1.0 bump would add maintenance faster than adopter value.

**Verdict:** fix one core failure invariant, then mostly stop proactive product work.

## Blunt Maintainer Takeaway

Do not build v1.26 yet. First get v1.25 onto main, then make the existing purge promise true and clean
the remaining stale JTBD map. After that, silence on the wire is the correct posture until a real team or
legal requirement pulls a bounded milestone into existence.

## Bookkeeping Written

- `STATE.md`: current focus, assessment summary, patch-first next step, and three live concerns.
- `PROJECT.md`: durable priority corrected to name the patch-eligible purge invariant and the external
  evidence gate for 1.0.
- `ROADMAP.md` and the v1.25 roadmap archive: Phase 132 corrected to 22/22 completed plans.
- This thread: canonical cross-session assessment and candidate ordering.
- No phase `LEARNINGS.md` was created or updated because there is no active phase or existing relevant
  learnings destination. The purge failure/retry pattern belongs in the repair's phase learnings only if
  a phase is later created.

## Shift-Left Applied

No configuration or global-default changes were needed. Existing repo-local settings already enforce
the demand gate, post-ship assessment, automation-first acceptance, Nyquist validation, and PR-first
serious work.
