# Phase 46: generated-app-tus-runtime-proof-recovery - Research

**Researched:** 2026-05-24 [VERIFIED: worklog 2026-05-24]
**Domain:** Generated-app tus package-consumer runtime proof recovery for `TUS-14` [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md 2026-05-24]
**Confidence:** MEDIUM [VERIFIED: evidence conflict between `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md`, and `tmp/install_smoke_tus_last_run.json` 2026-05-24]

<user_constraints>
## User Constraints (from CONTEXT.md)

Verbatim copy from `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`. [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md 2026-05-24]

### Locked Decisions
- **D-01:** Treat Phase 46 as a narrow proof-recovery phase, not a tus-contract
  redesign. The only valid fixes are in generated-app wiring, install-smoke
  harness behavior, runtime/environment setup, or reproducibility breadcrumbs.
- **D-02:** Re-run the real package-consumer command first:
  `bash scripts/install_smoke.sh tus`. Planning should assume "verify current
  truth before patching" because the current tree already contains a passing tus
  smoke artifact.
- **D-03:** The authoritative success path remains the real generated-app
  package-consumer lane: packaged Rindle artifact, generated Phoenix app, real
  Node `tus-js-client`, real MinIO backing, one interrupted upload, then resume.
  Do **not** replace this with fake-only or repo-local-only coverage.
- **D-04:** The proof must continue asserting the user-visible contract that
  matters for `TUS-14`: upload creation succeeds, resume discovers at least one
  previous upload, the resulting asset reaches the expected `byte_size` and
  `content_type`, and downstream variants converge.
- **D-05:** Assume the earlier `ECONNRESET` / `socket hang up` failure recorded
  in Phase 44 verification is now potentially stale. The current planning
  baseline is: re-run the proof, compare the live result against the persisted
  artifact in `tmp/install_smoke_tus_last_run.json`, and then update verification
  artifacts to reflect the actual state.
- **D-06:** If the rerun is green, Phase 46 should capture that durable evidence
  explicitly in its own plan/summary/verification artifacts and point back to
  the generated-app smoke breadcrumbs, rather than reopening settled Phase 44
  implementation decisions.
- **D-07:** If the rerun is red, keep the diagnosis anchored to the saved proof
  breadcrumbs: generated workspace root, `install_smoke_tus_report.json`,
  `install_smoke_tus_debug_report.json`, and the failure phase fields already
  emitted by the Node proof harness.
- **D-08:** Any fix must preserve the locked no-silent-downgrade tus contract and
  the existing real-socket drop-and-resume semantics. Reliability is improved by
  making the live proof reproducible, not by weakening the contract.

### Claude's Discretion
- Exact wording and placement of the refreshed verification evidence.
- Whether Phase 46 closes entirely through rerun + artifact reconciliation, or
  needs a small harness/runtime patch first, depending on the live proof result.

### Deferred Ideas (OUT OF SCOPE)
- Reopening tus protocol, auth, telemetry, or guide design choices from Phases
  42 and 44 — out of scope for this recovery phase.
- Expanding the proof into a broader soak or matrix lane — future CI hardening,
  not required to close `TUS-14`.
- Any fake-only substitute for the generated-app package-consumer proof —
  explicitly rejected.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TUS-14 | Generated-app package-consumer proof mounts `TusPlug`, uploads a `>= 200 MB` MP4 with one simulated drop against MinIO through a Node tus client, and asserts a `ready` `MediaAsset` with expected `byte_size` and `content_type`. [VERIFIED: .planning/REQUIREMENTS.md 2026-05-24] | Rerun `bash scripts/install_smoke.sh tus` first; if red, keep fixes inside the shell entrypoint, MinIO bootstrap, generated-app patcher, and Node proof harness that already emit durable JSON breadcrumbs. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `scripts/install_smoke.sh`, `scripts/ensure_minio.sh`, `test/install_smoke/generated_app_smoke_test.exs`, `test/install_smoke/support/generated_app_helper.ex` 2026-05-24] |
</phase_requirements>

## Summary

Phase 46 should be planned as a two-branch recovery loop, not as fresh implementation work. The locked context requires a rerun-first workflow with `bash scripts/install_smoke.sh tus`, and the current tree already contains a later green artifact in `tmp/install_smoke_tus_last_run.json` even though Phase 44 verification still records an earlier red `ECONNRESET` attempt. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md`, `tmp/install_smoke_tus_last_run.json` 2026-05-24]

The live proof path is already concrete and narrow. `scripts/install_smoke.sh` unpacks the package artifact, normalizes the profile, starts or reuses MinIO through `scripts/ensure_minio.sh`, and runs `test/install_smoke/generated_app_smoke_test.exs`. The generated-app helper then patches router/config, installs `tus-js-client@4.3.1`, uses `tus.FileUrlStorage`, splits the proof into interrupt and resume passes, and persists both summary and debug JSON reports. [VERIFIED: `scripts/install_smoke.sh`, `scripts/ensure_minio.sh`, `test/install_smoke/generated_app_smoke_test.exs`, `test/install_smoke/support/generated_app_helper.ex`, npm registry 2026-05-24]

The plan therefore only needs two executable branches. If the rerun is green, the work is evidence reconciliation and durable verification updates. If the rerun is red, the most likely fix surface is limited to generated-app router/config patching, MinIO/bootstrap assumptions, the Node proof harness, or the shell entrypoint; reopening Phases 42 or 44 protocol/auth decisions would violate the locked contract. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `.planning/ROADMAP.md`, `test/install_smoke/support/generated_app_helper.ex` 2026-05-24]

**Primary recommendation:** Plan Phase 46 around `rerun -> compare live output with tmp/install_smoke_tus_last_run.json -> either reconcile docs or patch only the harness/runtime files already in the proof loop`. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `tmp/install_smoke_tus_last_run.json`, `scripts/install_smoke.sh` 2026-05-24]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `POST /uploads/tus` creation and signed upload URL issuance | API / Backend [VERIFIED: `Rindle.Upload.TusPlug` mount in helper-generated router 2026-05-24] | Database / Storage [VERIFIED: upload session assertions in generated-app smoke test 2026-05-24] | The generated app forwards `/uploads/tus` to `Rindle.Upload.TusPlug`, while session state and upload backing live behind the broker/storage path. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24] |
| Interrupted upload and resume discovery | Browser / Client [VERIFIED: Node `tus-js-client` proof script 2026-05-24] | API / Backend [VERIFIED: proof script targets the live generated-app endpoint 2026-05-24] | The simulated drop and `findPreviousUploads()` behavior belong to the real client, but only succeed if the backend exposes a correct tus contract. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`; `tus-js-client` API docs `findPreviousUploads` and URL storage [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md]] |
| Multipart/local persistence and MinIO convergence | Database / Storage [VERIFIED: Phase 43/46 context and MinIO-backed proof contract 2026-05-24] | API / Backend [VERIFIED: generated-app proof promotes through backend jobs 2026-05-24] | The asset only reaches the expected `byte_size`, `content_type`, and ready variants if storage and promote lanes converge after the backend receives completed tus state. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24] |
| Proof artifact persistence and stale-vs-current reconciliation | API / Backend [VERIFIED: helper writes JSON artifacts and shell script prints hints 2026-05-24] | CDN / Static [ASSUMED] | The executable truth is emitted by the test helper into JSON artifacts and then consumed by planning and verification docs. The CDN/static tier is not materially involved in this phase. [VERIFIED: `scripts/install_smoke.sh`, `test/install_smoke/support/generated_app_helper.ex` 2026-05-24] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `tus-js-client` | `4.3.1` published `2025-01-16` [VERIFIED: npm registry 2026-05-24] | Real client for the generated-app drop-and-resume proof. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex` 2026-05-24] | The harness already installs this exact version and uses its supported `FileUrlStorage`, `findPreviousUploads`, and `resumeFromPreviousUpload` APIs. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex` 2026-05-24; CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md] |
| `Plug` | locked `1.19.1`, recent `1.19.2` released `2026-05-14` [VERIFIED: `mix hex.info plug` 2026-05-24] | Runtime for the mounted `Rindle.Upload.TusPlug` endpoint under the generated Phoenix router. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex` 2026-05-24] | The proof must keep exercising the real Plug-mounted endpoint instead of a fake adapter-only seam. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24] |
| `ExUnit` on Elixir `1.19.5` [VERIFIED: local `elixir --version` 2026-05-24] | Host test framework for package-consumer orchestration and assertions. [VERIFIED: `test/install_smoke/generated_app_smoke_test.exs`, `test/test_helper.exs` 2026-05-24] | The proof lane is already encoded as an ExUnit generated-app smoke test, so Phase 46 should reuse it rather than add another runner. [VERIFIED: `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@uppy/tus` | `5.1.1` published `2026-02-03` [VERIFIED: npm registry 2026-05-24] | Adopter-facing browser client documented in `guides/resumable_uploads.md`; not used by the proof harness itself. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24] | Use only for docs-parity verification and adopter guidance; the live proof keeps using raw `tus-js-client`. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/support/generated_app_helper.ex` 2026-05-24; CITED: https://uppy.io/docs/tus/] |
| `Oban` | locked `2.21.1`, recent `2.22.1` released `2026-04-30` [VERIFIED: `mix hex.info oban` 2026-05-24] | Promotion and variant jobs after the tus session completes. [VERIFIED: `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24] | Required whenever the rerun reaches completion and must prove `poster` plus `web_720p` convergence. [VERIFIED: `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24] |
| `ffmpeg` | `8.0.1` installed locally [VERIFIED: local `ffmpeg -version` 2026-05-24] | Builds the `>= 200 MB` MP4 fixture and supports video variant generation in the generated app. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, local runtime audit 2026-05-24] | Required for the live tus proof lane; no same-fidelity fallback exists in the current harness. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex` 2026-05-24] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Real Node `tus-js-client` proof [VERIFIED: locked by context 2026-05-24] | Fake or repo-local-only tus tests [VERIFIED: existing test suite already has lower-level coverage 2026-05-24] | Rejected because Phase 46 is specifically about restoring the package-consumer runtime proof authority for `TUS-14`, not increasing unit coverage. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `.planning/REQUIREMENTS.md` 2026-05-24] |
| Raw `tus-js-client` harness [VERIFIED: helper installs it 2026-05-24] | `@uppy/tus` in the proof harness [VERIFIED: not used in current helper 2026-05-24] | Rejected because the proof runs under Node without browser UI concerns, while the guide can still document `@uppy/tus` separately. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, `.planning/REQUIREMENTS.md`; CITED: https://uppy.io/docs/tus/] |
| `Application.compile_env!` router secret lookup [VERIFIED: helper patch uses it 2026-05-24] | `Endpoint.config/1` inside the generated router [VERIFIED: Phase 44 verification says this drift was fixed 2026-05-24] | Rejected because the router mount is compile-time code and Phase 44 already recorded `Application.compile_env!/2` as the required fix. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`; CITED: https://hexdocs.pm/elixir/main/Application.html] |

**Installation:** [VERIFIED: `test/install_smoke/support/generated_app_helper.ex` 2026-05-24]
```bash
npm install --no-save tus-js-client@4.3.1
```

**Version verification:** `tus-js-client` latest is `4.3.1` and `@uppy/tus` latest is `5.1.1` as of 2026-05-24. [VERIFIED: npm registry 2026-05-24]

## Architecture Patterns

### System Architecture Diagram

```text
package artifact
  -> bash scripts/install_smoke.sh tus
  -> scripts/ensure_minio.sh
  -> generated Phoenix app boot
  -> forward "/uploads/tus" -> Rindle.Upload.TusPlug
  -> Node tus-js-client interrupt pass
  -> persisted upload URL via FileUrlStorage
  -> Node tus-js-client resume pass
  -> MediaUploadSession completed
  -> PromoteAsset + ProcessVariant jobs
  -> tmp/install_smoke_tus_report.json + tmp/install_smoke_tus_debug_report.json
  -> tmp/install_smoke_tus_last_run.json
  -> verification docs reconcile stale vs current evidence
```
[VERIFIED: `scripts/install_smoke.sh`, `scripts/ensure_minio.sh`, `test/install_smoke/generated_app_smoke_test.exs`, `test/install_smoke/support/generated_app_helper.ex`, `tmp/install_smoke_tus_last_run.json` 2026-05-24]

### Recommended Project Structure

```text
scripts/
├── install_smoke.sh          # Canonical package-consumer entrypoint [VERIFIED: codebase 2026-05-24]
└── ensure_minio.sh           # Local MinIO bootstrap + bucket reset [VERIFIED: codebase 2026-05-24]

test/install_smoke/
├── generated_app_smoke_test.exs   # Executable TUS-14 assertions [VERIFIED: codebase 2026-05-24]
└── support/generated_app_helper.ex # Generated-app patching, Node proof, artifact persistence [VERIFIED: codebase 2026-05-24]

tmp/
└── install_smoke_tus_last_run.json # Latest persisted proof artifact for stale/current reconciliation [VERIFIED: codebase 2026-05-24]
```

### Pattern 1: Rerun-First Evidence Reconciliation

**What:** Run the exact package-consumer command before proposing any patch, then compare the live result to the persisted JSON artifact and stale docs. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `tmp/install_smoke_tus_last_run.json`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md` 2026-05-24]

**When to use:** Always for Phase 46 execution and again before closing verification artifacts. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24]

**Example:**
```bash
# Source: scripts/install_smoke.sh
bash scripts/install_smoke.sh tus
```

### Pattern 2: Compile-Time Router Mount Patching

**What:** The generated app should mount `Rindle.Upload.TusPlug` with `secret_key_base` read through `Application.compile_env!`, not through runtime endpoint config inside the router macro. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`; CITED: https://hexdocs.pm/elixir/main/Application.html]

**When to use:** Any time the rerun fails on `POST /uploads/tus` before reaching the interrupt/resume branch. [VERIFIED: generated-app helper mount plus Phase 44 failure notes 2026-05-24]

**Example:**
```elixir
// Source: test/install_smoke/support/generated_app_helper.ex
forward "/uploads/tus", Rindle.Upload.TusPlug,
  profile: MyApp.VideoProfile,
  secret_key_base:
    Application.compile_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base]
```

### Pattern 3: Split Interrupt/Resume Proof with Durable URL Storage

**What:** The proof deliberately runs one Node process for `interrupt` and a second for `resume`, persisting the upload URL through `tus.FileUrlStorage` so `findPreviousUploads()` can rediscover the server upload. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`; CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md]

**When to use:** Any live proof that claims recovery from one drop, because one-process happy-path uploads do not prove resume semantics. [VERIFIED: `test/install_smoke/generated_app_smoke_test.exs`, `test/install_smoke/support/generated_app_helper.ex` 2026-05-24]

**Example:**
```javascript
// Source: tus-js-client API docs + generated-app helper
const upload = new tus.Upload(file, { urlStorage: new tus.FileUrlStorage(path) })
const previous = await upload.findPreviousUploads()
if (previous.length) upload.resumeFromPreviousUpload(previous[0])
upload.start()
```

### Anti-Patterns to Avoid

- **Patching before rerunning:** This would ignore the locked Phase 46 workflow and risks fixing a stale failure that the current tree already no longer has. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `tmp/install_smoke_tus_last_run.json` 2026-05-24]
- **Switching to fake-only coverage:** This would violate the requirement that `TUS-14` be satisfied by the generated-app package-consumer lane, not by lower-level tests alone. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24]
- **Enabling `parallelUploads > 1`:** `tus-js-client` uses the concatenation extension when `parallelUploads` is greater than `1`, while Rindle v1.8 explicitly scopes tus to Core + Creation + Expiration + Termination only. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/support/generated_app_helper.ex`; CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md]
- **Relying on Node default URL storage:** The tus client docs say Node defaults to dummy URL storage; the proof must keep `tus.FileUrlStorage` or resume discovery can fail by construction. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`; CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| tus resume client behavior | Custom `http.request` POST/HEAD/PATCH script [ASSUMED] | `tus-js-client@4.3.1` with `findPreviousUploads()` and `resumeFromPreviousUpload()` [VERIFIED: helper + npm registry 2026-05-24; CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md] | The official client already handles upload URL discovery, retries, response hooks, and protocol framing. [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md] |
| Cross-process URL persistence | Ad hoc JSON mapping format [ASSUMED] | `tus.FileUrlStorage` [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md] | Node’s default URL storage is a dummy implementation, so the file-backed implementation is the standard durable path. [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md] |
| Local MinIO orchestration | Manual operator setup for each rerun [ASSUMED] | `scripts/ensure_minio.sh` through `scripts/install_smoke.sh` [VERIFIED: codebase 2026-05-24] | The script already health-checks MinIO, downloads `minio` and `mc` when needed, and resets the bucket for non-GCS runs. [VERIFIED: `scripts/install_smoke.sh`, `scripts/ensure_minio.sh` 2026-05-24] |
| Failure breadcrumbs | Grepping terminal logs after failure [ASSUMED] | `install_smoke_tus_report.json`, `install_smoke_tus_debug_report.json`, and `tmp/install_smoke_tus_last_run.json` [VERIFIED: codebase 2026-05-24] | The helper and entrypoint already persist machine-readable evidence including `failure_phase`, endpoint, resume count, and workspace path. [VERIFIED: `scripts/install_smoke.sh`, `test/install_smoke/support/generated_app_helper.ex`, `tmp/install_smoke_tus_last_run.json` 2026-05-24] |

**Key insight:** Phase 46 does not need a new proof system; it needs disciplined reuse of the existing one until the live rerun and the narrative artifacts agree. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`, `tmp/install_smoke_tus_last_run.json` 2026-05-24]

## Common Pitfalls

### Pitfall 1: Treating the stale Phase 44 verification report as the current source of truth

**What goes wrong:** Planning assumes the `ECONNRESET` report is still live and jumps into speculative code changes. [VERIFIED: `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md` 2026-05-24]

**Why it happens:** The tree contains both an older failed narrative and a newer passing persisted artifact. [VERIFIED: `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md`, `tmp/install_smoke_tus_last_run.json` 2026-05-24]

**How to avoid:** Make the first task a live rerun, then reconcile docs against the rerun plus the persisted artifact. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24]

**Warning signs:** The plan proposes changes before running `bash scripts/install_smoke.sh tus`. [VERIFIED: locked decision D-02 in context 2026-05-24]

### Pitfall 2: Breaking resume discovery by removing file-backed URL storage

**What goes wrong:** The interrupt pass may succeed, but the resume pass finds zero previous uploads or cannot prove recovery semantics. [VERIFIED: generated helper resume assertions 2026-05-24]

**Why it happens:** In Node.js, tus-js-client’s default URL storage is a dummy implementation unless `tus.FileUrlStorage` is provided. [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md]

**How to avoid:** Keep `storeFingerprintForResuming: true`, a stable fingerprint, and `urlStorage: new tus.FileUrlStorage(...)`. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`; CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md]

**Warning signs:** `failure_phase: "resume_lookup"` or `previous_uploads: 0` appears in the debug report. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex` 2026-05-24]

### Pitfall 3: Regressing the generated router back to runtime config lookup

**What goes wrong:** The generated app can fail before the proof ever reaches a clean `POST /uploads/tus`, because the router mount depends on compile-time configuration. [VERIFIED: Phase 44 verification and helper patch 2026-05-24]

**Why it happens:** Router macros compile before endpoint runtime config is available in the same way. `Application.compile_env!` is the documented compile-time API. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`; CITED: https://hexdocs.pm/elixir/main/Application.html]

**How to avoid:** Keep the current router patching pattern exactly unless the rerun proves a different failure source. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md` 2026-05-24]

**Warning signs:** The plan starts editing lower-level tus code even though failures occur before the first successful `POST`. [ASSUMED]

### Pitfall 4: Mixing raw `tus-js-client` guidance with modern `@uppy/tus` guidance

**What goes wrong:** Docs or follow-up fixes may apply `removeFingerprintOnSuccess` to Uppy even though modern `@uppy/tus` removed that option. [CITED: https://uppy.io/docs/guides/migration-guides/]

**Why it happens:** Phase requirements intentionally mention both raw `tus-js-client` and `@uppy/tus`, but their option surfaces are no longer identical. [VERIFIED: `.planning/REQUIREMENTS.md`; CITED: https://uppy.io/docs/tus/ and https://uppy.io/docs/guides/migration-guides/]

**How to avoid:** Keep the harness pinned to raw `tus-js-client` and keep the guide split explicit between raw client and Uppy client examples. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/generated_app_smoke_test.exs`; CITED: https://uppy.io/docs/tus/]

**Warning signs:** A patch proposes using Uppy-specific options in the Node proof harness. [VERIFIED: current harness has no Uppy dependency 2026-05-24]

## Code Examples

Verified patterns from official sources and the current codebase:

### Real Resume Flow
```javascript
// Source: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md
const upload = new tus.Upload(file, { endpoint, urlStorage: new tus.FileUrlStorage(path) })
const previous = await upload.findPreviousUploads()
if (previous.length) upload.resumeFromPreviousUpload(previous[0])
upload.start()
```

### Generated-App Mount Pattern
```elixir
// Source: test/install_smoke/support/generated_app_helper.ex
forward "/uploads/tus", Rindle.Upload.TusPlug,
  profile: MyApp.VideoProfile,
  secret_key_base:
    Application.compile_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base]
```

### Canonical Rerun Command
```bash
# Source: scripts/install_smoke.sh
bash scripts/install_smoke.sh tus
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Trust the earlier `44-VERIFICATION.md` `ECONNRESET` narrative as the blocker. [VERIFIED: codebase 2026-05-24] | Treat the live rerun plus `tmp/install_smoke_tus_last_run.json` as the planning baseline. [VERIFIED: Phase 46 context and persisted artifact 2026-05-24] | Locked in Phase 46 context on `2026-05-24`. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24] | Prevents speculative fixes against stale evidence. [VERIFIED: context D-05/D-06 2026-05-24] |
| Read router `secret_key_base` with `Endpoint.config/1` inside generated router logic. [VERIFIED: `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md` 2026-05-24] | Read it with `Application.compile_env!` in the patched router mount. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`; CITED: https://hexdocs.pm/elixir/main/Application.html] | Changed before the later Phase 44 validation snapshot. [VERIFIED: `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md` 2026-05-24] | Keeps the generated app compiling and mounting the tus endpoint correctly. [VERIFIED: codebase + verification docs 2026-05-24] |
| Treat `removeFingerprintOnSuccess` as shared guidance for both raw tus and Uppy. [ASSUMED] | Keep it only in raw `tus-js-client` guidance; modern `@uppy/tus` removed the option and auto-cleans its stored data on success. [CITED: https://uppy.io/docs/guides/migration-guides/] | Documented in the Uppy 2.0 migration guide. [CITED: https://uppy.io/docs/guides/migration-guides/] | Prevents docs drift and false guidance during follow-up fixes. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/generated_app_smoke_test.exs`; CITED: https://uppy.io/docs/tus/] |

**Deprecated/outdated:**
- Treating the Node proof as a single uninterrupted upload is outdated for this phase, because `TUS-14` explicitly requires one simulated drop and resume discovery. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24]
- Planning around `parallelUploads > 1` is outdated for this milestone, because that activates the concatenation extension in `tus-js-client` while Rindle v1.8 excludes concatenation from scope. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/support/generated_app_helper.ex`; CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The CDN / Static tier is not materially involved in this phase. [ASSUMED] | Architectural Responsibility Map | Low; planner may omit a non-issue tier review. |
| A2 | A custom raw `http.request` proof client would be materially worse than `tus-js-client` for this exact proof lane. [ASSUMED] | Don't Hand-Roll | Low; the repo already uses `tus-js-client`, so this mainly affects how strongly alternatives are rejected. |
| A3 | Some future red reruns could still fail before the first successful `POST` without touching lower-level tus logic. [ASSUMED] | Common Pitfalls | Low; this only changes debugging order, not the locked contract. |
| A4 | Historical guidance may previously have mixed raw tus and Uppy options. [ASSUMED] | State of the Art | Low; the current planner only needs the current split. |

## Open Questions (RESOLVED)

1. **RESOLVED: Does the live rerun on this machine stay green right now?**
   What we know: The latest persisted artifact records `failure_phase: "none"`, `previous_uploads: 1`, `byte_size: 210777744`, and `content_type: "video/mp4"`. [VERIFIED: `tmp/install_smoke_tus_last_run.json` 2026-05-24]
   What's unclear: This research pass did not execute `bash scripts/install_smoke.sh tus`, so the current runtime state is still inferred from persisted evidence rather than freshly observed. [VERIFIED: worklog 2026-05-24]
   Resolution: Plan `46-01` makes the rerun the first executable task and treats its result as the authoritative branch selector for the rest of the phase. [VERIFIED: Phase 46 locked decision D-02 2026-05-24]

2. **RESOLVED: Should Phase 46 also normalize optional-dependency compile warnings in the generated package-consumer lane?**
   What we know: The latest saved smoke output still includes warnings about optional modules such as `JOSE.JWK`, `Mux.Base`, `Goth`, `Finch`, and `GcsSignedUrl`. [VERIFIED: `tmp/install_smoke_tus_last_run.json` 2026-05-24]
   What's unclear: The warnings do not block the saved green run, but they can still distract audits and hide signal if a future rerun is red. [VERIFIED: `tmp/install_smoke_tus_last_run.json` 2026-05-24]
   Resolution: Keep this out of the core Phase 46 success path. It is permitted only as secondary cleanup after a green rerun and must not displace `TUS-14` recovery or widen the phase scope. [VERIFIED: narrow scope in `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `bash` | Canonical proof entrypoint `scripts/install_smoke.sh` [VERIFIED: codebase 2026-05-24] | ✓ [VERIFIED: local runtime audit 2026-05-24] | `5.2.37` [VERIFIED: local runtime audit 2026-05-24] | — |
| `curl` | `scripts/ensure_minio.sh` health checks and binary downloads [VERIFIED: codebase 2026-05-24] | ✓ [VERIFIED: local runtime audit 2026-05-24] | `8.7.1` [VERIFIED: local runtime audit 2026-05-24] | None in current scripts. [VERIFIED: codebase 2026-05-24] |
| `node` | Node proof runner [VERIFIED: helper uses `System.cmd("node", ...)` 2026-05-24] | ✓ [VERIFIED: local runtime audit 2026-05-24] | `v22.14.0` [VERIFIED: local runtime audit 2026-05-24] | None for the authoritative proof lane. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24] |
| `npm` | Installs `tus-js-client@4.3.1` inside the generated app [VERIFIED: helper code 2026-05-24] | ✓ [VERIFIED: local runtime audit 2026-05-24] | `11.1.0` [VERIFIED: local runtime audit 2026-05-24] | None for the authoritative proof lane. [VERIFIED: helper code 2026-05-24] |
| `mix` / Elixir | Builds package, compiles generated app, runs ExUnit proof [VERIFIED: codebase 2026-05-24] | ✓ [VERIFIED: local runtime audit 2026-05-24] | Elixir `1.19.5`, OTP `28` [VERIFIED: local runtime audit 2026-05-24] | None. [VERIFIED: codebase 2026-05-24] |
| `ffmpeg` | Builds the large MP4 fixture and proves variant convergence [VERIFIED: helper code 2026-05-24] | ✓ [VERIFIED: local runtime audit 2026-05-24] | `8.0.1` [VERIFIED: local runtime audit 2026-05-24] | None in the current proof harness. [VERIFIED: helper code 2026-05-24] |
| PostgreSQL (`psql`) | Generated app DB + Ecto migrations [VERIFIED: helper workflow 2026-05-24] | ✓ [VERIFIED: local runtime audit 2026-05-24] | `14.17` [VERIFIED: local runtime audit 2026-05-24] | None in the current proof harness. [VERIFIED: helper workflow 2026-05-24] |
| MinIO server binary | Real S3-compatible backing for non-GCS proofs [VERIFIED: `scripts/install_smoke.sh` 2026-05-24] | Auto-bootstrapped [VERIFIED: `scripts/ensure_minio.sh` 2026-05-24] | Downloaded on demand [VERIFIED: `scripts/ensure_minio.sh` 2026-05-24] | Reuse an already-running local MinIO at `RINDLE_MINIO_URL`. [VERIFIED: `scripts/ensure_minio.sh` 2026-05-24] |
| `mc` client | Bucket reset and bootstrap [VERIFIED: `scripts/ensure_minio.sh` 2026-05-24] | Auto-bootstrapped [VERIFIED: `scripts/ensure_minio.sh` 2026-05-24] | Downloaded on demand [VERIFIED: `scripts/ensure_minio.sh` 2026-05-24] | None besides auto-download. [VERIFIED: `scripts/ensure_minio.sh` 2026-05-24] |

**Missing dependencies with no fallback:**
- None detected in the current environment. [VERIFIED: local runtime audit + codebase 2026-05-24]

**Missing dependencies with fallback:**
- `minio` and `mc` are not assumed preinstalled; `scripts/ensure_minio.sh` downloads them automatically when the target endpoint is local and unreachable. [VERIFIED: `scripts/ensure_minio.sh` 2026-05-24]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir `1.19.5` [VERIFIED: `test/test_helper.exs`, local runtime audit 2026-05-24] |
| Config file | `test/test_helper.exs` [VERIFIED: codebase 2026-05-24] |
| Quick run command | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` [VERIFIED: `scripts/install_smoke.sh`, Phase 44 validation 2026-05-24] |
| Full suite command | `bash scripts/install_smoke.sh tus` [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `scripts/install_smoke.sh` 2026-05-24] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TUS-14 | Generated-app package-consumer lane mounts `TusPlug`, survives one drop, resumes at least one previous upload, and converges to the expected `MediaAsset` plus ready variants. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24] | integration + live proof [VERIFIED: codebase 2026-05-24] | `bash scripts/install_smoke.sh tus` [VERIFIED: context + script 2026-05-24] | ✅ [VERIFIED: `test/install_smoke/generated_app_smoke_test.exs` 2026-05-24] |

### Sampling Rate

- **Per task commit:** `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` [VERIFIED: existing infrastructure + phase surface 2026-05-24]
- **Per wave merge:** `bash scripts/install_smoke.sh tus` [VERIFIED: locked proof authority 2026-05-24]
- **Phase gate:** Full generated-app proof green with fresh JSON artifacts before any new verification doc claims `TUS-14` complete. [VERIFIED: `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`, `tmp/install_smoke_tus_last_run.json` 2026-05-24]

### Wave 0 Gaps

- None — existing test infrastructure already covers the only requirement, and the missing work is live rerun plus evidence reconciliation rather than new test scaffolding. [VERIFIED: `test/install_smoke/generated_app_smoke_test.exs`, `.planning/REQUIREMENTS.md` 2026-05-24]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: `TUS-10` remains part of the locked surface 2026-05-24] | Optional `:tus_resume_authorizer` remains part of the same proof family and must not be bypassed during recovery. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md` 2026-05-24] |
| V3 Session Management | yes [VERIFIED: signed resumable URLs and previous upload lookup are core to proof 2026-05-24] | HMAC-signed upload URLs plus persisted resume state; do not leak `session_uri` or stored upload URLs in logs. [VERIFIED: `.planning/REQUIREMENTS.md`, `tmp/install_smoke_tus_last_run.json` redacted reporting posture 2026-05-24] |
| V4 Access Control | yes [VERIFIED: no-silent-downgrade and signed URL checks remain locked 2026-05-24] | Keep `TusPlug` capability and signature checks intact while debugging runtime failures. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24] |
| V5 Input Validation | yes [VERIFIED: tus edge validates length/metadata/offset headers 2026-05-24] | Preserve existing tus request validation; Phase 46 fixes should not bypass request parsing or offset checks to force green proof. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/rindle/upload/tus_plug_test.exs` grep 2026-05-24] |
| V6 Cryptography | yes [VERIFIED: signed URL contract remains required 2026-05-24] | `Plug.Crypto`-backed `secret_key_base` signing path must remain the generated-app mount contract. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/support/generated_app_helper.ex`; CITED: https://hexdocs.pm/elixir/main/Application.html] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Signed upload URL leakage through logs or artifacts | Information Disclosure [VERIFIED: bearer-credential language in requirements/docs parity 2026-05-24] | Keep using redacted reports and do not add raw session URIs or auth data to debug output. [VERIFIED: `.planning/REQUIREMENTS.md`, `test/install_smoke/generated_app_smoke_test.exs`, `test/install_smoke/support/generated_app_helper.ex` 2026-05-24] |
| Silent downgrade from tus to another upload path | Tampering [VERIFIED: no-silent-downgrade is explicit 2026-05-24] | Only fix the harness/runtime; do not replace the proof with presigned or fake-only flows. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` 2026-05-24] |
| Resume hijack or mismatched user resumption | Spoofing / Elevation of Privilege [VERIFIED: `TUS-10` exists 2026-05-24] | Preserve the existing signed URL semantics and optional resume authorizer during all debugging. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md` 2026-05-24] |
| Over-parallelized client causing unsupported concatenation behavior | Denial of Service / Tampering [VERIFIED: tus-js-client docs + Rindle scope 2026-05-24] | Keep `parallelUploads: 1` in the proof harness and guide split. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`; CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md` - locked scope, rerun-first workflow, authoritative proof contract. [VERIFIED: codebase 2026-05-24]
- `.planning/REQUIREMENTS.md` - exact `TUS-14` requirement and v1.8 scope boundaries. [VERIFIED: codebase 2026-05-24]
- `.planning/ROADMAP.md` - Phase 46 goal, success criteria, and dependency chain. [VERIFIED: codebase 2026-05-24]
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md` - stale red evidence that must be reconciled. [VERIFIED: codebase 2026-05-24]
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md` - later green validation narrative referencing the persisted artifact. [VERIFIED: codebase 2026-05-24]
- `tmp/install_smoke_tus_last_run.json` - latest persisted proof artifact and smoke output. [VERIFIED: codebase 2026-05-24]
- `scripts/install_smoke.sh` and `scripts/ensure_minio.sh` - canonical entrypoint and MinIO bootstrap behavior. [VERIFIED: codebase 2026-05-24]
- `test/install_smoke/generated_app_smoke_test.exs` and `test/install_smoke/support/generated_app_helper.ex` - real proof assertions, router patching, Node harness, artifact persistence. [VERIFIED: codebase 2026-05-24]
- `https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md` - official API behavior for URL storage, resume discovery, `parallelUploads`, and `removeFingerprintOnSuccess`. [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/docs/api.md]
- `https://raw.githubusercontent.com/tus/tus-js-client/main/README.md` - official statement that v4 targets tus protocol `1.0.0` and supports Node.js. [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/README.md]
- `https://hexdocs.pm/elixir/main/Application.html` - official compile-time config API for `Application.compile_env!`. [CITED: https://hexdocs.pm/elixir/main/Application.html]
- `https://uppy.io/docs/tus/` and `https://uppy.io/docs/guides/migration-guides/` - current Uppy tus surface and removal of `removeFingerprintOnSuccess` from modern Uppy. [CITED: https://uppy.io/docs/tus/ and https://uppy.io/docs/guides/migration-guides/]
- npm registry (`npm view tus-js-client ...`, `npm view @uppy/tus ...`) - current package versions and publish dates. [VERIFIED: npm registry 2026-05-24]

### Secondary (MEDIUM confidence)

- `mix hex.info plug` and `mix hex.info oban` - current Hex release visibility for supporting Elixir dependencies. [VERIFIED: Hex registry 2026-05-24]

### Tertiary (LOW confidence)

- None. [VERIFIED: research inventory 2026-05-24]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions, install patterns, and client APIs are all verified from the codebase, npm, Hex, or official docs. [VERIFIED: codebase + registries + docs 2026-05-24]
- Architecture: HIGH - the authoritative runtime path is directly encoded in the shell entrypoint, generated-app smoke test, and helper. [VERIFIED: codebase 2026-05-24]
- Pitfalls: MEDIUM - the failure modes are strongly evidenced by prior artifacts and docs, but the current live rerun was not executed during this research pass. [VERIFIED: verification drift + persisted artifact 2026-05-24]

**Research date:** 2026-05-24 [VERIFIED: worklog 2026-05-24]
**Valid until:** 2026-05-31 for runtime-state assumptions; dependency/doc references are stable longer but should still be rechecked if Phase 46 executes after that date. [VERIFIED: narrow runtime-proof phase + current-date context 2026-05-24]
