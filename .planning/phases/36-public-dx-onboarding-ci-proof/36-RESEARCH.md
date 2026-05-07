# Phase 36: Public DX, Onboarding, CI Proof — Research

**Researched:** 2026-05-07
**Domain:** Adopter DX (preset macro + mix task flag + guide + package-consumer CI)
**Confidence:** HIGH (all decisions locked upstream by 35-decision CONTEXT.md; this research is pure analog-code excavation, validation architecture, and pitfall surfacing — no new technology choices).

## Summary

Phase 36 is a pure DX/CI/docs phase. The runtime work is shipped (Phases 33-35); Phase 36 packages it for adopters: a `MuxWeb` preset that wraps the existing `Web` preset and merges a locked `:streaming` block, four new doctor checks appended to the existing `RuntimeChecks` pipeline, a new `streaming_providers.md` guide, and a third profile mode (`:mux`) in the existing generated-app package-consumer harness — cassette-driven by default, with a label-gated `mux-soak` job that exercises real Mux. The CONTEXT.md upstream of this research locks 35 decisions across all three slices; the candidate memo and external research subagent already resolved the GitHub Actions fork-secret, Mux free-tier, and 2026 webhook-tunnel surfaces. **Nothing in this research re-derives those.**

What this research uniquely adds: (1) the verbatim analog code excerpts the planner needs to wire executor tasks (MuxWeb mirrors `Web`'s 30-line `__using__/1`; the four doctor checks copy `check_local_playback`'s vacuous-summary pattern; the `:mux` lifecycle-test source extends the existing `:video` head-clause); (2) a Validation Architecture section mapping every MUX-15..19 requirement to a specific automated test command runnable in <30s; (3) the four-pitfall list — JOSE PEM parse on assumption-only tests, Mox `set_mox_from_context` ordering, `mix phx.new --install` cassette-mode race, doc-parity guard regex landmines.

**Primary recommendation:** Slice into 3 plans matching the natural file boundaries: (Plan 01) `MuxWeb` preset + four doctor checks + `--streaming` flag (compiles + tests in pure unit lane, no MinIO needed); (Plan 02) `streaming_providers.md` + `mix.exs` extras entry + README/getting_started subsection + doc-parity guard extension (pure docs lane, verifiable via doc-parity grep + ExDoc compile); (Plan 03) `:mux` profile mode in `generated_app_helper.ex` + `install_smoke.sh` extension + cassette CI step + soak job + cleanup script (the heaviest slice — exercises the existing v1.5 package-consumer scaffolding plus all the Phase 34/35 fixtures). All three plans are independent (parallelizable across executors); the doc-parity guard extension in Plan 02 fails until Plan 01's `MuxWeb` module exists, but that's a CI ordering constraint, not a planning dependency.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `MuxWeb` preset compile-time DSL | Library / Profile DSL | — | Same tier as `Web` preset; pure compile-time macro wrapping `use Rindle.Profile`. No runtime concerns. |
| Four `mix rindle.doctor` streaming checks | Library / Ops (RuntimeChecks pipeline) | Library / Capability (profile-discovery gating) | Existing single-file pipeline owns this. `Capability.report/0` provides discovery surface. |
| `--streaming` task flag | Mix Task / OptionParser | Library / Ops | Thin task shell stays unchanged; OptionParser strict opt is added at task boundary; flag value plumbs through to RuntimeChecks via `opts`. |
| `streaming_providers.md` guide | Documentation / HexDocs extras | Library moduledocs (canonical-snippet source) | New guide lives in `guides/`; copies wiring snippets verbatim from `WebhookPlug` and `MuxSyncCoordinator` `@moduledoc` (single source of truth — D-13). |
| README + getting_started subsection | Documentation / Top-level README | Doc-parity guard (CI verification) | Append-only; canonical AV path stays byte-identical (D-28); doc-parity guard adds one new required string (`Rindle.Profile.Presets.MuxWeb`). |
| Generated-app `:mux` profile mode | Test infra / package-consumer harness | Test fixtures (Phase 34/35 cassettes) | Extends `:image \| :video` discriminator to `:image \| :video \| :mux`; reuses fixtures committed in Phase 34/35; Mox-on-`:http_client`-config seam (Phase 34 D-34) handles cassette mode. |
| `mux-soak` CI job | CI workflow / GitHub Actions | Mux Cloud (real API) | Sibling top-level job (NOT a step inside `package-consumer`); label-gated; secrets resolved via `pull_request` event (NOT `_target` — fork-PR-secret-safe by D-19/D-20). |
| Soak-lane cleanup | CI workflow + Elixir try/after + cleanup script | Mux REST DELETE | Three-layer belt-and-suspenders: Elixir `try/after` in lifecycle test, GitHub Actions `if: always()` step calling `scripts/mux_soak_cleanup.sh`, sweep-by-list within the script. |

## User Constraints (from CONTEXT.md)

> All 35 decisions D-01..D-35 are LOCKED upstream. Reproduced verbatim from `36-CONTEXT.md` for the planner's convenience. Deferrals are out of scope.

### Locked Decisions (D-01..D-35)

**MuxWeb Preset (MUX-15)**
- **D-01:** Ship `Rindle.Profile.Presets.MuxWeb` at `lib/rindle/profile/presets/mux_web.ex` as a thin `__using__/1` wrapper that calls `Rindle.Profile.Presets.Web.variants/1` directly to inherit the variant set verbatim, then merges the locked streaming block last so adopter overrides win.
- **D-02:** Streaming block shape is `delivery: [streaming: %{provider: Rindle.Streaming.Provider.Mux, playback_policy: :signed, ingest_mode: :server_push, source_variant: :web_720p}]`. Validated by Phase 33's `@streaming_schema` at `lib/rindle/profile/validator.ex:61`.
- **D-03:** No `__using__/1` opt-out for streaming. Preset compiles unchanged when `:mux` dep is absent (DSL stores only the provider module atom; runtime resolution via `Code.ensure_loaded?`).
- **D-04:** No new variant atoms. Reusing `web_720p` + `poster` keeps `:mux` lane's ready-variant assertion byte-identical to `:video` lane's.

**Doctor Streaming Checks (MUX-16)**
- **D-05:** Four checks appended to `RuntimeChecks.run/2`'s `checks` list at `runtime_checks.ex:44-54`. IDs: `doctor.streaming_credentials`, `doctor.streaming_signing_key`, `doctor.streaming_webhook_secrets`, `doctor.streaming_smoke_ping`. `:component` is `:streaming` for all four.
- **D-06:** Profile-discovery gating via `Rindle.Capability.report/0`. When `streaming.configured_profiles` is empty, all four return `ok_result` with vacuous summary. When at least one profile opts in but `:mux` dep is absent, return `error_result` with fix `"Add {:mux, \"~> 3.2\", optional: true} and {:jose, \"~> 1.11\", optional: true} to your deps."`
- **D-07:** `--streaming` boolean OptionParser strict opt on `Mix.Tasks.Rindle.Doctor`; plumbs through `RuntimeChecks.run/2` opts. Smoke ping is gated; other three always run when streaming-enabled profiles are discovered.
- **D-08:** Smoke-ping failure-mode taxonomy: 200 → ok; 401/403 → token-fix; 429 → rate-limit; timeout → network; other 4xx/5xx → status-referenced. Hard 5s timeout via `Task.await/Task.shutdown` pattern.

**Guide (MUX-17)**
- **D-09:** Single new guide `guides/streaming_providers.md`, Mux-only, no second-provider scaffolding. Add to `mix.exs` `extras` adjacent to `secure_delivery.md`.
- **D-10:** 11 sections in locked order — see CONTEXT.md for exact ordering.
- **D-11:** Local-tunnel section: cloudflared primary (TryCloudflare quick tunnel; signup-free), ngrok alternative-with-caveat (signup required as of 2026).
- **D-12:** Style mirrors `guides/secure_delivery.md`.
- **D-13:** Source-of-truth: copy webhook-plug + cron snippets verbatim from existing `@moduledoc` blocks; if inlining for narrative, include `<!-- source: ... -->` HTML comment.

**Generated-app `:mux` lane (MUX-18 part 1)**
- **D-14:** Add `:mux` to `profile_mode` discriminator in `generated_app_helper.ex` (currently `:image | :video` at lines 14, 19); extend `selected_profiles/0` env-var dispatch (lines 857-864 — add `"mux" -> [:mux]` and `"all" -> [:image, :video, :mux]`); add `lifecycle_test_source(_app_module, :mux)` head-clause after the existing `:video` head at line 905.
- **D-15:** `:mux` lane reuses `:video` profile's variant assertions verbatim; layered on top: emit `MuxWeb` instead of `Web`, and add a single new assertion: cassette-driven `Rindle.Delivery.streaming_url/3` returns a Mux-signed HLS URL whose JWT decodes against the test signing public key.
- **D-16:** Cassette/fixture replay uses Phase 34's Mox-on-`:http_client`-config seam (NOT Bypass, NOT ExVCR, NOT Tesla.Mock). `patch_test_config!/2` at lines 342-382 gets a new appended block when `profile_mode == :mux`.
- **D-17:** Five fixture-value `RINDLE_MUX_*` env vars in `shared_env/1` (~line 789). PEM read from `test/fixtures/mux/test_signing_private_key.pem` (Phase 34 D-37 — already committed).

**CI Lane Wiring (MUX-18 part 2)**
- **D-18:** `mux-enabled` cassette step added to `package-consumer` job after line 376-377. Reuses MinIO + Postgres services. Single line: `bash scripts/install_smoke.sh mux`. `scripts/install_smoke.sh` `case` (line 19) extends to `all|image|video|mux`.
- **D-19:** `pull_request.types` extends to `[opened, synchronize, reopened, labeled]` — `labeled` MUST be added explicitly.
- **D-20:** `mux-soak` separate top-level job (NOT a step). `if: contains(github.event.pull_request.labels.*.name, 'streaming')`. Uses `pull_request` (NOT `pull_request_target`) — fork PRs labeled `streaming` get empty secrets and fail closed; no leak.
- **D-21:** `RINDLE_MUX_USE_REAL_API=1` flips generated-app's `:http_client` from `ClientMock` back to `HTTP`.
- **D-22:** Soak-lane cleanup is MANDATORY (10-stored-asset free-tier cap). Three layers: Elixir `try/after`, GitHub Actions `if: always()` step, `scripts/mux_soak_cleanup.sh` safety-net sweep.
- **D-23:** Rate-limit budget: 1 RPS POST / 5 RPS GET-DELETE; one create + 2-3s polling + one delete per PR; ≤90s end-to-end; $0 at 50 PRs/month.
- **D-24:** Five new GitHub Secrets required (matches Phase 34 D-29 env-var names).

**README + getting_started Subsection (MUX-19)**
- **D-25:** Both files gain one subsection `## Streaming with Mux (optional)` (README) / `### Streaming with Mux (optional)` (getting_started). ≤15 lines max. Placement: AFTER canonical AV path; must NOT displace the first-run story.
- **D-26:** Three elements only: one-sentence intro, one code snippet (`use Rindle.Profile.Presets.MuxWeb, ...`), one link to `streaming_providers.md`.
- **D-27:** Doc-parity guard at `.github/workflows/ci.yml:518-545` extends required-strings list with one new entry: `"Rindle.Profile.Presets.MuxWeb"`. Negative regex check unchanged.
- **D-28:** Image and AV onboarding paths remain canonical. The doc-parity guard's existing required strings (`Rindle.Profile.Presets.Web`, `Rindle.initiate_upload`, `Rindle.verify_completion`, `Rindle.attach`, `Rindle.url`, `mix rindle.doctor`) all remain enforced.

**Configuration / Files / Documentation Touch (D-29..D-34)**
- D-29..D-32: Module/file layout — see CONTEXT.md `## Module / File Layout` section for the verbatim added/modified files list.
- D-33: CHANGELOG entry for v0.2.0 hex release at v1.6 milestone close.
- D-34: No release-note rewrites for v1.4-v1.5 surfaces; Phase 36 is additive.

**Decision-Making Preference**
- D-35: Decide-by-default downstream; escalate only for high-blast-radius tradeoffs. The single security-critical decision (`mux-soak` fork-secret boundary) is already locked by D-19/D-20.

### Claude's Discretion (Planner / Executor)

The candidate memo + CONTEXT.md lock the contract surface; these are autonomous implementation choices the planner / executor may make:

- Exact preset macro internals (call `Web.variants/1` directly vs. inline keyword list — D-01 prefers the helper call).
- Exact phrasing of doctor PASS/FAIL summaries and fix recipes (D-08 lists the failure-mode taxonomy; planner picks wording).
- Whether new guide's Step 5 inlines the moduledoc snippet or links via `<!-- source: ... -->` HTML comment (D-13 expresses preference).
- Whether `scripts/mux_soak_cleanup.sh` is Bash-shells-out-to-mix or a standalone Elixir script.
- Test file organization for `mux_web_test.exs` and `runtime_checks_streaming_test.exs` (one file per concern — mirrors existing layout).
- Exact wording of `RINDLE_MUX_USE_REAL_API` conditional in `patch_test_config!/2` (D-21).
- Whether doc-parity guard extension goes in existing `for REQUIRED in \\` list or a new sibling list (D-27 prefers extending existing).
- Internal helper organization for the four `defp check_streaming_*` clauses (D-05) — single file fine; extract `Rindle.Ops.RuntimeChecks.Streaming` private module if cohesion improves (still `@moduledoc false`).
- Soak-lane cleanup script: list-by-name-pattern (`test-asset-*`) vs. metadata tag (`{"meta": {"rindle_soak": "true"}}`) — latter more robust if cassette and soak share create payload.

### Deferred Ideas (OUT OF SCOPE)

- `Rindle.Streaming.Provider.Mux.create_direct_upload/2` adopter onboarding — Phase 37 / v0.3+.
- Second streaming provider scaffolding (Cloudflare Stream / Bunny Stream / Cloudinary Video) — v1.7+.
- `JOSE.JWK.from_pem/1` `:persistent_term` cache implementation — v1.7+ (Phase 36 documents the optimization in guide Section 11; impl deferred).
- Multi-provider doctor checks — v1.7+. Phase 36's checks are Mux-specific in fix-recipes; v1.7's second provider triggers refactor to per-provider namespacing.
- Automated Mux-dashboard signing-key creation via API — v1.7+ if real adopter demand.
- `mix rindle.webhook.replay` event-replay tooling — v1.7+.
- Configurable telemetry redaction posture — v1.7+ (v1.6 hardcodes last-4-char `provider_asset_id`).
- Cancellation surface (`Rindle.cancel_provider_ingest/1`) — v1.7+ (use `Oban.cancel_jobs/1` as v1.6 workaround).
- DASH playback kind in MuxWeb / guide — v1.7+ (v1.6 ships `:hls` only).
- Per-adopter cost estimator in `mix rindle.doctor --streaming` — v1.7+.
- `mix rindle.streaming.test_webhook` synthetic-event task — v1.7+.
- Multi-tunnel guidance in local-dev section (tailscale funnel, smee.io, etc.) — out of scope; D-11 limits section to cloudflared primary + ngrok alternative.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MUX-15 | `Rindle.Profile.Presets.MuxWeb` ships alongside `Web`; demonstrates `:streaming` opt-in with `:signed` named playback policy. | `lib/rindle/profile/presets/web.ex` (the analog template) + `lib/rindle/profile/validator.ex:61-82` (`@streaming_schema` validates the four-key DSL block). Test pattern in `test/rindle/profile/presets_web_test.exs`. |
| MUX-16 | `mix rindle.doctor` validates streaming config (token id/secret, signing key id + RSA private key, webhook secrets, 5s smoke ping); reports per-profile streaming status PASS/FAIL. | `lib/rindle/ops/runtime_checks.ex:33-78` (`run/2` pipeline) + `:220-251` (`check_local_playback` is the profile-discovery-gated precedent) + `lib/mix/tasks/rindle.doctor.ex` (thin task shell — OptionParser plumb-through). `Rindle.Capability.report/0` at `lib/rindle/capability.ex:29-41` returns `streaming.configured_profiles`. |
| MUX-17 | `guides/streaming_providers.md` ships Mux-only section: env vars, signing-key creation, secret rotation, raw-body cache wiring, ngrok-style local tunnel guidance, doctor smoke. | `mix.exs:116-128` `extras` list (insertion point between `secure_delivery.md` and `troubleshooting.md`). Canonical wiring snippets live in `lib/rindle/delivery/webhook_plug.ex:1-65` `@moduledoc` (Steps 1-3 + secrets resolver + telemetry) and `lib/rindle/workers/mux_sync_coordinator.ex:5-67` `@moduledoc` (cron config + backpressure + observability). |
| MUX-18 | Generated-app harness gains `mux-enabled` lane; PR builds use cassette by default; gated `mux-soak` lane runs against real Mux on PRs labelled `streaming`. | `test/install_smoke/support/generated_app_helper.ex` (the literal extension surface — see Code Examples §1 and §2). `scripts/install_smoke.sh:19` (one-line `case` extension). `.github/workflows/ci.yml:284-391` (`package-consumer` job — cassette step), `:393-545` (adopter job — structural template for `mux-soak`), `:518-545` (doc-parity guard). |
| MUX-19 | README + `getting_started.md` gain "Streaming with Mux" subsection; image/AV onboarding paths remain canonical first-run story. | Existing canonical AV section in `README.md` ~lines 101-120; existing canonical narrative in `guides/getting_started.md` Sections 1-10 (must stay byte-identical). Doc-parity guard at `.github/workflows/ci.yml:524-541` is the byte-level enforcement. |

## Standard Stack

### Core (already shipped — Phase 36 only consumes)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `mux` | `~> 3.2` (optional) | Real Mux SDK; smoke-ping check calls `Mux.Video.Assets.list/1` | Phase 34 locked. `optional: true` posture preserved (D-03). [VERIFIED: mix.exs:68] |
| `jose` | `~> 1.11` (optional) | JWT primitives for signed playback URL parsing in cassette assertion | Phase 34 locked. [VERIFIED: mix.exs:69] |
| `nimble_options` | `~> 1.1` | Profile DSL validation; `@streaming_schema` validates MuxWeb's locked block | Phase 33 locked. [VERIFIED: mix.exs:72] |
| `mox` | `~> 1.2` (test only) | `Rindle.Streaming.Provider.Mux.ClientMock` cassette seam in `:mux` lane | Phase 34 locked. [VERIFIED: mix.exs:91, test/support/mocks.ex:7-8] |
| `oban` | `~> 2.21` | Required by `MuxSyncCoordinator` cron snippet in guide Step 6 | Phase 34 locked. [VERIFIED: mix.exs:59] |
| `plug` | `~> 1.16` | Required by `WebhookPlug` adopter wiring in guide Step 5 | Phase 35 locked. [VERIFIED: mix.exs:88] |

**No new deps in Phase 36.** Adopters who don't enable streaming pay zero transitive cost (Phase 34 D-01).

### Supporting (Phase 36 internal — already in mix.exs)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ex_doc` | `~> 0.40` (dev only) | Builds HexDocs from `mix.exs` `extras` list — verifies `streaming_providers.md` builds. | Verify `mix docs` succeeds with new entry. [VERIFIED: mix.exs:99] |
| `:telemetry` | `~> 1.2` | `[:rindle, :runtime, :check, :stop]` per-check telemetry from `run_check/1` (line 65-72) | Existing — new checks emit automatically. [VERIFIED: mix.exs:85, runtime_checks.ex:65-72] |

### Alternatives Considered (rejected upstream)

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Mox-on-`:http_client` cassette | Bypass against `api.mux.com` | Rejected by Phase 34 D-35 — Mux SDK base URL is hardcoded; Bypass redirect path is fragile. |
| Mox-on-`:http_client` cassette | ExVCR record/replay | Rejected by Phase 34 D-35 — record/replay drift; transitive test dep leak. |
| Mox-on-`:http_client` cassette | Tesla.Mock | Rejected by Phase 34 D-35 — process-locality fragile; cross-process Oban worker calls would fail. |
| Sibling `mux-soak` job | Step inside `package-consumer` | Rejected by D-19/D-20 — needs separate `if: contains(...)` label gate that doesn't apply to the rest of `package-consumer`. |
| `pull_request_target` (label-gate runs in base context) | `pull_request` (label-gate runs in PR-head context) | Rejected by D-19/D-20 — `pull_request_target` would expose secrets to fork PRs. `pull_request` fails closed on forks (empty secrets resolved). |

**Installation:** None — no new deps.

**Version verification:** Versions inherited from Phases 33-35; verified live via `Mix.Dep.Lock.read()` in CI. No registry probe needed for Phase 36.

## Architecture Patterns

### System Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────────┐
│ Adopter app (Phase 36 onboarding target)                                  │
│   defmodule MyApp.Streaming, do: use Rindle.Profile.Presets.MuxWeb, ...   │
└───────────────────────────────────────────────────────────────────────────┘
        │  compile-time
        ▼
┌─────────────────────────────────────┐
│ MuxWeb.__using__/1  (NEW Plan 01)   │
│   ─ calls Web.variants/1            │
│   ─ merges streaming block last     │
│   ─ passthrough opts (storage, etc.)│
└─────────────────────────────────────┘
        │  delegates to
        ▼
┌─────────────────────────────────────┐
│ Rindle.Profile.__using__/1          │ ── validates ──▶ Profile.Validator
│   (existing)                        │                  @streaming_schema
└─────────────────────────────────────┘                  (Phase 33)

═══════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────┐
│ mix rindle.doctor [--streaming]  │  ── Plan 01: --streaming OptionParser opt
└──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────┐    ┌────────────────────────────────┐
│ RuntimeChecks.run/2              │───▶│ Rindle.Capability.report/0     │
│   checks list (existing 8)       │    │   .streaming.configured_profiles│
│   + 4 new (Plan 01):             │    └────────────────────────────────┘
│     doctor.streaming_credentials │             │ profile-discovery
│     doctor.streaming_signing_key │             │ gating (D-06)
│     doctor.streaming_webhook_*   │◀────────────┘
│     doctor.streaming_smoke_ping  │  Plan 01: gated on --streaming flag (D-07)
└──────────────────────────────────┘
        │
        ▼ when smoke ping enabled
┌──────────────────────────────────┐
│ Mux.Video.Assets.list(client, %{ │  Plan 01: 5s timeout via Task.await/shutdown
│   limit: 1                       │  D-08 failure-mode taxonomy
│ })                                │
└──────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════

┌────────────────────────────────────────────────────────────────────────────┐
│ scripts/install_smoke.sh mux  (Plan 03)                                    │
│   RINDLE_INSTALL_SMOKE_PROFILE=mux                                         │
└────────────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────┐
│ generated_app_helper.ex                    │
│   ─ profile_enabled?(:mux)                 │  Plan 03: extend guard
│   ─ selected_profiles() returns [:mux]     │  Plan 03: extend env dispatch
│   ─ patch_test_config!(:mux) emits         │  Plan 03: append config block
│      config :rindle, ..Mux,                │  Plan 03: D-21 conditional
│        http_client: ClientMock             │
│      (UNLESS RINDLE_MUX_USE_REAL_API=1)    │
│   ─ shared_env/1 +5 RINDLE_MUX_*           │  Plan 03: fixture env vars
│   ─ lifecycle_test_source(_, :mux)         │  Plan 03: new head-clause
└────────────────────────────────────────────┘
        │ generates Phoenix app
        ▼
┌────────────────────────────────────────────┐
│ Generated app's RindleInstallSmokeTest     │
│   1. Initiate AV upload                    │
│   2. PUT to MinIO presigned URL            │
│   3. Verify completion                     │
│   4. PromoteAsset / ProcessVariant         │
│   5. Assert ["poster", "web_720p"] ready   │
│   6. NEW: Rindle.Delivery.streaming_url    │
│      returns Mux-signed HLS URL            │
│   7. NEW: JWT verifies against pubkey      │
└────────────────────────────────────────────┘
        │
        ▼ in cassette mode (default)
┌────────────────────────────────────────────┐
│ Mux.ClientMock (Mox)                       │
│   create_asset → asset_create_201.json     │
│   get_asset    → asset_get_ready.json      │
└────────────────────────────────────────────┘

  in soak mode (label-gated, RINDLE_MUX_USE_REAL_API=1):
        │
        ▼
┌────────────────────────────────────────────┐    ┌──────────────────────┐
│ Rindle.Streaming.Provider.Mux.HTTP         │───▶│  api.mux.com         │
│   (real adapter)                           │◀───│  (real Mux Cloud)    │
└────────────────────────────────────────────┘    └──────────────────────┘
        │
        ▼  Plan 03: try/after Elixir cleanup + GitHub Actions if: always() step
┌────────────────────────────────────────────┐
│ Mux.Video.Assets.delete/2                  │
│ + scripts/mux_soak_cleanup.sh sweep        │
└────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────────┐
│ guides/streaming_providers.md  (Plan 02)                             │
│   ─ Steps 1-11 in locked order (D-10)                                │
│   ─ Step 5 verbatim from WebhookPlug @moduledoc (lines 1-65)         │
│   ─ Step 6 verbatim from MuxSyncCoordinator @moduledoc (lines 5-67)  │
│   ─ Step 7 cloudflared primary + ngrok alternative-with-caveat (D-11)│
└──────────────────────────────────────────────────────────────────────┘
        │ added to mix.exs extras
        ▼
┌──────────────────────────────────────────────────────────────────────┐
│ mix docs (HexDocs build)                                             │
│   verified by Phase 21 reachability probe at v0.2.0 publish          │
└──────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure (Phase 36 additions)

```
lib/rindle/profile/presets/
├── web.ex                         # existing — analog template for MuxWeb
└── mux_web.ex                     # NEW (Plan 01) — D-31

lib/rindle/ops/
└── runtime_checks.ex              # MODIFIED (Plan 01) — append 4 streaming checks

lib/mix/tasks/
└── rindle.doctor.ex               # MODIFIED (Plan 01) — add --streaming OptionParser opt

guides/
└── streaming_providers.md         # NEW (Plan 02) — D-31

scripts/
├── install_smoke.sh               # MODIFIED (Plan 03) — extend case "$PROFILE" to mux
└── mux_soak_cleanup.sh            # NEW (Plan 03) — D-31

test/fixtures/mux/
├── test_signing_private_key.pem   # existing (Phase 34 D-37)
└── test_signing_public_key.pem    # NEW (Plan 03) — D-31; openssl rsa -pubout

test/rindle/profile/presets/
└── mux_web_test.exs               # NEW (Plan 01) — D-31

test/rindle/ops/
└── runtime_checks_streaming_test.exs   # NEW (Plan 01) — D-31

test/install_smoke/support/
└── generated_app_helper.ex        # MODIFIED (Plan 03) — extend :mux profile mode

test/install_smoke/
└── generated_app_smoke_test.exs   # MODIFIED (Plan 03) — add GeneratedAppSmokeMuxTest

.github/workflows/
└── ci.yml                         # MODIFIED (Plan 02 doc-parity, Plan 03 jobs)

mix.exs                            # MODIFIED (Plan 02 extras list)
README.md                          # MODIFIED (Plan 02 streaming subsection)
guides/getting_started.md          # MODIFIED (Plan 02 streaming subsection)
CHANGELOG.md                       # MODIFIED (Plan 02 v0.2.0 entry)
```

### Pattern 1: Preset Macro Wrapping Another Preset

**What:** `MuxWeb` does NOT redeclare variants; it calls `Web.variants/1` and merges a streaming block.

**When to use:** Whenever a preset is "X PLUS opt-in feature" rather than "different X".

**Example (the literal `Web` template MuxWeb mirrors):**
```elixir
# Source: lib/rindle/profile/presets/web.ex (verbatim, 47 lines total)
defmodule Rindle.Profile.Presets.Web do
  @moduledoc """
  Stock AV preset helpers for the canonical web onboarding story.
  """

  defmacro __using__(opts) do
    opts = Macro.expand_literals(opts, __CALLER__)
    scrub_strip? = Keyword.get(opts, :scrub_strip, false)

    profile_opts =
      opts
      |> Keyword.delete(:scrub_strip)
      |> Keyword.put(:variants, variants(scrub_strip: scrub_strip?))

    quote do
      use Rindle.Profile, unquote(Macro.escape(profile_opts))
    end
  end

  @spec variants([option()]) :: keyword(keyword())
  def variants(opts \\ []) do
    scrub_strip? = Keyword.get(opts, :scrub_strip, false)
    [
      web_720p: [kind: :video, preset: :web_720p],
      poster: [kind: :image, preset: :video_poster_scene]
    ] ++ maybe_scrub_strip(scrub_strip?)
  end

  defp maybe_scrub_strip(true), do: [scrub_strip: [kind: :image, preset: :video_thumbnail_strip]]
  defp maybe_scrub_strip(false), do: []
end
```

**MuxWeb shape (recommended — D-01 prefers calling `Web.variants/1`):**
```elixir
defmodule Rindle.Profile.Presets.MuxWeb do
  @moduledoc """
  Mux streaming preset — the canonical AV web preset PLUS streaming opt-in.

  Inherits the `web_720p` + `poster` variant set verbatim from `Rindle.Profile.Presets.Web`
  and adds a locked `:streaming` delivery block (provider Mux, signed playback,
  server-push ingest, web_720p source).

  See `guides/streaming_providers.md` for full setup (Mux dashboard, webhook plug,
  doctor smoke, secret rotation).
  """

  defmacro __using__(opts) do
    opts = Macro.expand_literals(opts, __CALLER__)
    scrub_strip? = Keyword.get(opts, :scrub_strip, false)

    # Adopter-supplied :delivery block (if any) wins over the preset's defaults
    # for keys other than :streaming. The streaming block is locked.
    adopter_delivery = Keyword.get(opts, :delivery, [])

    locked_streaming = [
      streaming: %{
        provider: Rindle.Streaming.Provider.Mux,
        playback_policy: :signed,
        ingest_mode: :server_push,
        source_variant: :web_720p
      }
    ]

    delivery = Keyword.merge(adopter_delivery, locked_streaming)

    profile_opts =
      opts
      |> Keyword.delete(:scrub_strip)
      |> Keyword.put(:variants, Rindle.Profile.Presets.Web.variants(scrub_strip: scrub_strip?))
      |> Keyword.put(:delivery, delivery)

    quote do
      use Rindle.Profile, unquote(Macro.escape(profile_opts))
    end
  end
end
```

**Why "merge last":** Adopter's `delivery: [public: false, signed_url_ttl_seconds: 3600]` should compose with the preset's `delivery: [streaming: %{...}]`. Putting `locked_streaming` second in `Keyword.merge/2` means streaming always wins (correct — adopter cannot override the streaming block; that would defeat the preset's purpose).

### Pattern 2: Profile-Discovery-Gated Doctor Check

**What:** When no profile of the relevant kind is discovered, return `ok_result` with a vacuous summary — NOT `error_result`. Avoids "you have no streaming profiles → ERROR" noise.

**When to use:** Any check whose preconditions aren't satisfied for adopters who haven't opted into the feature.

**Example (the literal precedent):**
```elixir
# Source: lib/rindle/ops/runtime_checks.ex:220-251 (verbatim)
defp check_local_playback(profiles, local_playback_route) do
  local_av_profiles =
    profiles
    |> Enum.filter(&(local_av_profile?(&1)))
    |> Enum.map(&inspect/1)

  cond do
    local_av_profiles == [] ->
      ok_result(
        "doctor.local_playback",
        :delivery,
        "No local AV playback profiles were discovered.",
        @local_playback_fix
      )

    complete_local_playback_route?(local_playback_route) ->
      ok_result(
        "doctor.local_playback",
        :delivery,
        "Local AV playback route config is present for #{Enum.join(local_av_profiles, ", ")}.",
        @local_playback_fix
      )

    true ->
      error_result(
        "doctor.local_playback",
        :delivery,
        "Local AV playback route config is missing or incomplete for #{Enum.join(local_av_profiles, ", ")}.",
        @local_playback_fix
      )
  end
end
```

**Streaming-check shape (recommended):**
```elixir
defp check_streaming_credentials(profiles, env) do
  case streaming_profiles(profiles) do
    [] ->
      ok_result(
        "doctor.streaming_credentials",
        :streaming,
        "No streaming-enabled profiles discovered.",
        @streaming_credentials_fix
      )

    _ when not Code.ensure_loaded?(Rindle.Streaming.Provider.Mux) ->
      error_result(
        "doctor.streaming_credentials",
        :streaming,
        "Streaming-enabled profile detected but :mux dep is not loaded.",
        ~s(Add {:mux, "~> 3.2", optional: true} and {:jose, "~> 1.11", optional: true} to your deps.)
      )

    _streaming_profiles ->
      missing = missing_streaming_credentials(env)
      if missing == [] do
        ok_result("doctor.streaming_credentials", :streaming,
          "All five RINDLE_MUX_* credentials are set.", @streaming_credentials_fix)
      else
        error_result("doctor.streaming_credentials", :streaming,
          "Missing RINDLE_MUX_* credentials: #{Enum.join(missing, ", ")}.",
          @streaming_credentials_fix)
      end
  end
end
```

Helper:
```elixir
defp streaming_profiles(profiles) do
  Enum.filter(profiles, fn profile ->
    case profile.delivery_policy() do
      %{streaming: streaming} when not is_nil(streaming) -> true
      _ -> false
    end
  end)
end
```

**Note on `Capability.report/0`:** D-06 says consult `report/0`. The function returns `streaming.configured_profiles` (a `[module()]` list). Two equivalent paths exist: (a) call `Rindle.Capability.report/0` once and read `report.streaming.configured_profiles`, or (b) helper above that filters `profiles` directly using `delivery_policy()`. Option (b) is faster (no double-pass) but more coupled; option (a) is the documented contract surface. Either is acceptable; planner picks. See `lib/rindle/capability.ex:90-95` for the `configured_streaming_profiles/1` helper that already exists.

### Pattern 3: Mox-on-`:http_client`-Config Seam (Cassette Mode)

**What:** The Mux adapter reads `config :rindle, Rindle.Streaming.Provider.Mux, http_client: ...` per call. Setting `http_client: Rindle.Streaming.Provider.Mux.ClientMock` in the generated app's config swaps the live HTTP impl for Mox. The behaviour `Rindle.Streaming.Provider.Mux.Client` (3 callbacks: `create_asset/1`, `get_asset/1`, `delete_asset/1`) is the seam.

**When to use:** Generated-app cassette CI lane. NOT the soak lane (which uses real `Rindle.Streaming.Provider.Mux.HTTP`).

**Example (the canonical setup from the existing Mux test):**
```elixir
# Source: test/rindle/streaming/provider/mux/mux_test.exs:26-45 (verbatim)
setup do
  prev = Application.get_env(:rindle, Adapter, [])

  Application.put_env(
    :rindle,
    Adapter,
    Keyword.merge(prev,
      http_client: ClientMock,
      token_id: "test_token_id",
      token_secret: "test_token_secret",
      signing_key_id: "test_kid",
      signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem"),
      webhook_tolerance_seconds: 300
    )
  )

  on_exit(fn -> Application.put_env(:rindle, Adapter, prev) end)
  :ok
end

# Mox stub:
expect(ClientMock, :create_asset, fn params ->
  assert params["inputs"] == [%{"url" => "https://signed.example/v.mp4"}]
  assert params["playback_policies"] == ["signed"]
  {:ok, fixture("asset_create_201.json")}  # File.read!("test/fixtures/mux/asset_create_201.json") |> Jason.decode!
end)
```

**For the `:mux` lifecycle test source (D-15) the planner must inline this same setup pattern**, but the Mox stubs run inside the GENERATED Phoenix app, not the host project. Two options:

1. **Stub-via-fixture-files (recommended).** Generated app's `RindleInstallSmokeTest` reads the same fixture JSON files (`asset_create_201.json`, `asset_get_ready.json`) and stubs the Mox client to return them. The fixtures are committed in `test/fixtures/mux/` (Phase 34/35) — but the generated app lives in a temp dir, so `patch_test_config!/2` must `File.cp_r!/2` the fixtures into the generated app's `test/fixtures/mux/`. Mirrors the existing MinIO env-var staging at lines 384-421.

2. **Stub-via-deftesting.** Define a `Rindle.Test.MuxCassette` module in `test/support/` that returns canned responses; the generated app does `config :rindle, ..Mux, http_client: Rindle.Test.MuxCassette`. Cleaner for the test source but requires `test/support` to be in the generated app's `elixirc_paths` (the existing helper compiles `test/support/generated_app_helper.ex` separately — see `test/install_smoke/generated_app_smoke_test.exs:1`).

**Recommendation:** Option 1 — copy fixtures + use Mox stubs. Mirrors the canonical Mux test pattern (`mux_test.exs`). Avoids introducing a new test-support module that has to be installed into the generated app's compile path.

### Pattern 4: GitHub Actions PR-Label Job Gating (Fork-Secret-Safe)

**What:** Soak lane runs only when a PR is labelled `streaming`. Uses `pull_request` event (NOT `pull_request_target`); fork PRs labelled `streaming` get empty secrets and fail closed.

**When to use:** Any CI lane that needs real-API secrets but should run on-demand only.

**Example (recommended):**
```yaml
# .github/workflows/ci.yml — extension to the existing on: trigger
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened, labeled]   # NEW — D-19

# .github/workflows/ci.yml — new top-level job, sibling to package-consumer
mux-soak:
  name: Mux Soak (real API)
  runs-on: ubuntu-latest
  needs: quality
  if: contains(github.event.pull_request.labels.*.name, 'streaming')
  env:
    MIX_ENV: test
    RINDLE_MUX_USE_REAL_API: "1"
    RINDLE_MUX_TOKEN_ID: ${{ secrets.RINDLE_MUX_TOKEN_ID }}
    RINDLE_MUX_TOKEN_SECRET: ${{ secrets.RINDLE_MUX_TOKEN_SECRET }}
    RINDLE_MUX_SIGNING_KEY_ID: ${{ secrets.RINDLE_MUX_SIGNING_KEY_ID }}
    RINDLE_MUX_SIGNING_PRIVATE_KEY: ${{ secrets.RINDLE_MUX_SIGNING_PRIVATE_KEY }}
    RINDLE_MUX_WEBHOOK_SECRETS: ${{ secrets.RINDLE_MUX_WEBHOOK_SECRETS }}
  services:
    postgres:
      image: postgres:16-alpine
      ports: ["5432:5432"]
      env:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
        POSTGRES_DB: rindle_test
      options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
  steps:
    - uses: actions/checkout@v4
    - uses: erlef/setup-beam@v1
      with: { elixir-version: "1.17", otp-version: "27" }
    - run: sudo apt-get install -y libvips-dev
    - run: mix deps.get
    - name: Run real-Mux soak proof
      run: bash scripts/install_smoke.sh mux
    - name: Cleanup soak assets (ALWAYS — belt-and-suspenders)
      if: always()
      run: bash scripts/mux_soak_cleanup.sh
```

**Why `pull_request` not `pull_request_target`:** `pull_request_target` runs in the BASE branch context with full secrets — fork PRs labelled `streaming` would leak. `pull_request` runs in the PR HEAD context; for forks, GitHub injects empty strings for `secrets.*`, so the lane fails closed (Mux 401s, no leak). External research Topic 1 (CONTEXT.md D-19/D-20) confirmed this is the safe pattern.

### Anti-Patterns to Avoid

- **`pull_request_target` for label-gated jobs that need secrets.** Triggers fork-PR secret leaks. Always `pull_request` + accept that fork-PR runs fail closed.
- **Caching `JOSE.JWK.from_pem/1` results in adopter code.** Phase 36's guide Section 11 documents the ~1k playback URLs/sec footgun but does NOT ship the cache (deferred to v1.7+). Mentioning the cache as "optional adopter-side patch" is fine; auto-installing one is out of scope.
- **Re-deriving the streaming DSL block in `MuxWeb`.** The four-key block (`provider`, `playback_policy`, `ingest_mode`, `source_variant`) is locked by `@streaming_schema` (Phase 33). Hardcoding it in MuxWeb is the right thing — the schema is the validator, and the preset's job is to write the validated shape.
- **Per-provider doctor namespacing in v1.6.** All four checks have Mux-specific fix recipes. v1.7's second provider triggers the refactor; premature now.
- **`File.cp!` for fixture staging without idempotency.** The cassette test runs after `mix ecto.create`; if the fixture was already copied, recopying is fine, but `File.mkdir_p!` is required first.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OptionParser strict opts on a Mix task | Custom argv parsing for `--streaming` | `OptionParser.parse(args, strict: [streaming: :boolean])` | Standard library; matches the existing pattern in other Rindle mix tasks. |
| 5s timeout on Mux smoke ping | `Process.send_after` + `receive` dance | `Task.async/1` + `Task.yield/2` + `Task.shutdown/2` | Standard OTP timeout pattern. Don't reinvent. |
| Test cassettes for Mux | ExVCR record/replay | Mox-on-`:http_client`-config seam (Phase 34 D-34) | Already shipped in Phase 34; the `Rindle.Streaming.Provider.Mux.Client` behaviour is the seam. Reuse. |
| Soak-lane GitHub Actions gating | Custom shell-script gate inside a single job | Top-level `if: contains(github.event.pull_request.labels.*.name, 'streaming')` | Job-level `if:` is the standard label-gate pattern. |
| Mux asset cleanup at soak-lane end | Custom polling for "is asset deleted yet" | Three layers: Elixir `try/after` + GitHub Actions `if: always()` + sweep script | Belt-and-suspenders required because of the 10-asset free-tier cap (D-22). |
| JWT verification in the `:mux` lane assertion | Hand-rolled RS256 base64 decoding | `JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)` | `jose` already in deps (optional). Mirrors `signed_playback_url_test.exs:60-72`. |
| Public PEM fixture | `openssl rsa -pubout` separate fixture file | `JOSE.JWK.from_pem(private_pem) \|> JOSE.JWK.to_public()` | The existing test at `signed_playback_url_test.exs:66-70` does this in-test — no need to commit a separate public-key file. **D-31 says commit the public PEM, but research finds it's redundant** — see Open Questions §2. |

**Key insight:** Phase 36 has near-zero hand-rolling risk because Phases 33-35 already shipped the load-bearing seams. The four anti-patterns above are all "don't reinvent the seam Phase 34 gave you."

## Runtime State Inventory

> Phase 36 is additive — no rename/refactor/migration. **Skipping this section per researcher protocol.**

## Common Pitfalls

### Pitfall 1: JOSE PEM parse silent failure on fixture rotation

**What goes wrong:** `JOSE.JWK.from_pem/1` returns `[]` (empty JWK list) on malformed PEM rather than raising. If the test signing private key fixture (Phase 34 D-37) gets corrupted (line ending normalization, encoding shift), `doctor.streaming_signing_key` would silently treat it as valid in some code paths.

**Why it happens:** JOSE's `from_pem/1` is intentionally non-raising for compositional reasons — it returns `[]` so callers can pattern-match.

**How to avoid:** The check MUST verify the result is a `%JOSE.JWK{}` struct, not just truthy. Pattern:
```elixir
case JOSE.JWK.from_pem(pem) do
  %JOSE.JWK{} -> :ok
  _ -> {:error, :pem_parse_failed}
end
```

Or, the test in `runtime_checks_streaming_test.exs` MUST assert against a known-good fixture AND a known-malformed string (e.g., `"-----BEGIN RSA PRIVATE KEY-----\nGARBAGE\n-----END RSA PRIVATE KEY-----"`).

**Warning signs:** Doctor passes in CI but Mux signing fails at runtime with cryptic JOSE error. The check ID `doctor.streaming_signing_key` should NEVER false-positive.

### Pitfall 2: Mox `set_mox_from_context` ordering in cassette lifecycle test

**What goes wrong:** The generated-app's lifecycle test runs Oban workers via `Oban.Testing.perform_job/2`, which spawns a new process. By default Mox stubs are process-local; `set_mox_from_context` is required for cross-process stubs to be visible to spawned worker processes.

**Why it happens:** Mox v1.0+ defaults to `:private` mode (per-process stubs) for safety. The Phase 34 worker tests (which call `perform_job`) use `set_mox_from_context` and `verify_on_exit!`. The generated-app's test source MUST emit the same setup.

**How to avoid:** The `lifecycle_test_source(_, :mux)` head-clause MUST emit:
```elixir
import Mox
setup :set_mox_from_context
setup :verify_on_exit!
```

at the top of the generated `RindleInstallSmokeTest` module (it currently emits no Mox setup because `:image` and `:video` lanes don't need it). See the canonical Phase 34 test setup at `test/rindle/streaming/provider/mux/mux_test.exs:1-10`.

**Warning signs:** Cassette lane fails with `(Mox.UnexpectedCallError)` from inside a worker process even though the test sets up the stub correctly at the top level.

### Pitfall 3: `mix phx.new --install` racing with cassette-mode env vars

**What goes wrong:** `generate_phoenix_app!/2` (line 277-293) uses `mix phx.new --install`, which runs `mix deps.get` and `mix deps.compile` inline. The generated mix.exs at this point does NOT yet have the rindle dep wired (it's added later in `patch_mix_exs!/3`). The `RINDLE_MUX_*` env vars in `shared_env/1` are set BEFORE `mix phx.new` runs but are inert until `patch_runtime_config!/3` adds the rindle Mux config block.

**Why it happens:** The current helper does `generate_phoenix_app!` → `patch_generated_app!` → `fetch_deps!` in that order; the patch step is what wires rindle into the app. There is no race per se, but the helper's order is load-bearing.

**How to avoid:** Phase 36's modifications to `patch_test_config!/2` (D-16) and `shared_env/1` (D-17) MUST preserve the existing call order. The new `:mux`-specific config block in `patch_test_config!/2` must be appended AFTER the existing Oban + repo blocks (lines 361-379), not interleaved. Specifically: the `RINDLE_MUX_USE_REAL_API` conditional (D-21) reads `System.get_env/1` at HOST-side patch time, NOT at generated-app runtime — this means the generated app's `config/test.exs` either contains the `http_client: ClientMock` line (cassette mode) or doesn't (soak mode). **Do not push the conditional into the generated app's `config/test.exs`** — that would require runtime-config Mox lookups inside the generated app, which is fragile.

**Warning signs:** Cassette lane works locally but fails in CI with `Mux.Base.new/2` 401 because the generated app didn't pick up the `http_client: ClientMock` config. Diagnosis: dump the generated app's `config/test.exs` from a failing run.

### Pitfall 4: Doc-parity guard regex landmines on the new subsection

**What goes wrong:** The doc-parity guard at `.github/workflows/ci.yml:518-545` has TWO checks: a positive `for REQUIRED in ...` loop (must contain) and a negative `search_regex "Broker\\.initiate_session|..."` check (must NOT contain). The new "Streaming with Mux (optional)" subsection in README.md and getting_started.md introduces `Rindle.Profile.Presets.MuxWeb`, which D-27 adds to the positive list. But the new subsection MUST NOT introduce any of the forbidden patterns: `Broker.initiate_session`, `Broker.verify_completion`, `Rindle.Delivery.url`.

**Why it happens:** The streaming guide (Plan 02) documents the public facade (`Rindle.Delivery.streaming_url/3`); if the planner accidentally references `Rindle.Delivery.url/3` (the v1.4 progressive surface), it will trip the guard's negative regex.

**How to avoid:** Plan 02's writer MUST verify both files locally before committing:
```bash
grep -nE "Broker\.initiate_session|Broker\.verify_completion|Rindle\.Delivery\.url" README.md guides/getting_started.md
# expected output: nothing
grep -F "Rindle.Profile.Presets.MuxWeb" README.md guides/getting_started.md
# expected output: at least one match per file
```

Also, `Rindle.Delivery.streaming_url` (the new public surface) is fine — only the BARE `Rindle.Delivery.url` (with the dot, no `streaming_` prefix) trips the regex. Use `streaming_url` exclusively.

**Warning signs:** Plan 02 PR fails CI with "FAIL: README.md still references stale non-facade onboarding calls." Fix: scan for `Rindle.Delivery.url` (no `streaming_url` prefix) and replace with `Rindle.Delivery.streaming_url` or remove.

### Pitfall 5: `mix phx.new` version drift breaks cassette generated app

**What goes wrong:** `generate_phoenix_app!/2` uses `mix phx.new` without a version pin. Phoenix 1.7+ generates a different `endpoint.ex` shape than 1.6; if the generated `config/runtime.exs` block in `patch_runtime_config!/3` (lines 384-421) makes assumptions about Phoenix endpoint shape that drift, the cassette lane silently breaks.

**Why it happens:** `mix phx.new` always uses the newest Phoenix in the host's archive. CI installs `phx.new` via `mix archive.install hex phx_new` typically without a version pin (none in current ci.yml; relies on latest).

**How to avoid:** Phase 36's helper modifications should NOT assume a specific Phoenix version. The current helper is Phoenix-version-agnostic (string substitution on `Plug.Parsers` etc.). Plan 03's `:mux` head-clause should follow the same posture — manipulate test config via `Kernel.<>/2` append, not regex shape-match against Phoenix-generated content.

**Warning signs:** Cassette lane works on Phoenix 1.7.10 but fails on 1.7.11 with `Plug.Conn.NotFoundError`. Diagnosis: read the generated app's `config/test.exs` from a failing run; check if the Mux config block landed.

## Code Examples

### `:mux` Profile Discriminator Extension (Plan 03)

```elixir
# Source: test/install_smoke/support/generated_app_helper.ex:14, 19, 857-864
# Phase 36 extends from :image | :video to :image | :video | :mux

# Line 14 — guard
def profile_enabled?(profile_mode) when profile_mode in [:image, :video, :mux] do
  selected_profiles()
  |> Enum.member?(profile_mode)
end

# Line 19 — guard
def prove_package_install!(profile_mode \\ :image) when profile_mode in [:image, :video, :mux] do
  # ... unchanged ...
end

# Lines 857-864 — env-var dispatch
defp selected_profiles do
  case System.get_env("RINDLE_INSTALL_SMOKE_PROFILE", "all") do
    "all" -> [:image, :video, :mux]   # NEW
    "image" -> [:image]
    "video" -> [:video]
    "mux" -> [:mux]                    # NEW
    other -> raise "unsupported RINDLE_INSTALL_SMOKE_PROFILE: #{inspect(other)}"
  end
end
```

### `lifecycle_test_source/2` `:mux` Head-Clause (Plan 03 — D-15)

The new clause goes AFTER line 905 `:video` head and BEFORE the `:upgrade` head (which is `defp upgrade_test_source/1`). Structure mirrors `:video` head verbatim with two additions:

```elixir
# Source: test/install_smoke/support/generated_app_helper.ex (NEW head-clause after line 905)
defp lifecycle_test_source(_app_module, :mux) do
  """
      test "generated app proves the canonical AV path PLUS Mux streaming URL via cassette" do
        assert_install_smoke_marker!()
        assert :presigned_put in VideoProfile.storage_adapter().capabilities()

        # Mox stubs for cassette mode (set up only when not in soak mode).
        # In soak mode (RINDLE_MUX_USE_REAL_API=1), config :rindle, ..Mux has no :http_client
        # entry, so the real Rindle.Streaming.Provider.Mux.HTTP is used.
        if Application.get_env(:rindle, Rindle.Streaming.Provider.Mux)[:http_client] == Rindle.Streaming.Provider.Mux.ClientMock do
          import Mox

          # Read fixture JSONs (copied into generated app's test/fixtures/mux/ by patch_test_config!/2)
          create_response = "test/fixtures/mux/asset_create_201.json" |> File.read!() |> Jason.decode!()
          ready_response = "test/fixtures/mux/asset_get_ready.json" |> File.read!() |> Jason.decode!()

          Rindle.Streaming.Provider.Mux.ClientMock
          |> stub(:create_asset, fn _params -> {:ok, create_response} end)
          |> stub(:get_asset, fn _id -> {:ok, ready_response} end)
        end

        fixture_path = Path.expand("../tmp/generated-app-video.webm", __DIR__)

        {:ok, session} = Rindle.initiate_upload(VideoProfile, filename: "generated-app-video.webm")
        {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
        :ok = put_to_presigned_url(presigned.url, File.read!(fixture_path))

        {:ok, %{session: completed, asset: asset}} = Rindle.verify_completion(session.id)
        assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})
        # ... [identical :video lane work — variants, ProcessVariant, ready assertions] ...

        # NEW assertion 1: Streaming URL renders.
        {:ok, %{url: streaming_url, kind: :hls}} =
          Rindle.Delivery.streaming_url(VideoProfile, asset)

        assert streaming_url =~ ~r{^https://stream\.mux\.com/[a-zA-Z0-9-]+\.m3u8\?token=}

        # NEW assertion 2: JWT decodes against the test signing public key.
        %URI{query: query} = URI.parse(streaming_url)
        %{"token" => jwt} = URI.decode_query(query)

        public_jwk =
          "test/fixtures/mux/test_signing_private_key.pem"
          |> File.read!()
          |> JOSE.JWK.from_pem()
          |> JOSE.JWK.to_public()

        assert {true, _payload, _jws} = JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)

        File.mkdir_p!("tmp")
        File.write!("tmp/install_smoke_av_report.json", Jason.encode!(%{
          ready_variants: ["poster", "web_720p"],
          playback_storage_key: "<see :video>",
          delivery_path: URI.parse(streaming_url).path,
          streaming_url_kind: "hls"
        }))
      end
  """
end
```

### `patch_test_config!/2` Mux Block Conditional (Plan 03 — D-16, D-21)

```elixir
# Source: test/install_smoke/support/generated_app_helper.ex:342-382
# Phase 36 extends with a :mux-mode-only appended block.
# The current function takes (root, app_name); D-16 says we need to thread profile_mode.

defp patch_test_config!(root, app_name, profile_mode) do
  path = Path.join(root, "config/test.exs")

  # ... existing string substitutions unchanged ...
  base_updated =
    path
    |> File.read!()
    |> String.replace(~r/username: "postgres"/, ...)
    # ... [existing lines 348-359 unchanged] ...
    |> Kernel.<>(<<existing Oban + repo block, lines 361-379>>)

  mux_block = if profile_mode == :mux do
    real_api? = System.get_env("RINDLE_MUX_USE_REAL_API") == "1"
    if real_api? do
      # Soak mode — no :http_client override; defaults to Rindle.Streaming.Provider.Mux.HTTP
      """

      config :rindle, Rindle.Streaming.Provider.Mux,
        token_id: System.get_env("RINDLE_MUX_TOKEN_ID"),
        token_secret: System.get_env("RINDLE_MUX_TOKEN_SECRET"),
        signing_key_id: System.get_env("RINDLE_MUX_SIGNING_KEY_ID"),
        signing_private_key: System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY"),
        webhook_secrets:
          System.get_env("RINDLE_MUX_WEBHOOK_SECRETS", "") |> String.split(",", trim: true)
      """
    else
      # Cassette mode — Mox client; fixture credentials still set so config-resolution path works
      """

      config :rindle, Rindle.Streaming.Provider.Mux,
        http_client: Rindle.Streaming.Provider.Mux.ClientMock,
        token_id: System.get_env("RINDLE_MUX_TOKEN_ID"),
        token_secret: System.get_env("RINDLE_MUX_TOKEN_SECRET"),
        signing_key_id: System.get_env("RINDLE_MUX_SIGNING_KEY_ID"),
        signing_private_key: System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY"),
        webhook_secrets:
          System.get_env("RINDLE_MUX_WEBHOOK_SECRETS", "") |> String.split(",", trim: true)
      """
    end
  else
    ""
  end

  # Also stage fixture files into the generated app's test/fixtures/mux/.
  # Mirrors MinIO setup at lines 384-421 (env-var staging).
  if profile_mode == :mux do
    fixture_dir = Path.join(root, "test/fixtures/mux")
    File.mkdir_p!(fixture_dir)
    for fixture <- ~w(asset_create_201.json asset_get_ready.json test_signing_private_key.pem) do
      File.cp!(
        Path.join("test/fixtures/mux", fixture),
        Path.join(fixture_dir, fixture)
      )
    end
  end

  File.write!(path, base_updated <> mux_block)
end
```

### `shared_env/1` Mux Fixture Env Vars (Plan 03 — D-17)

```elixir
# Source: test/install_smoke/support/generated_app_helper.ex:789-804
# Phase 36 extends with five RINDLE_MUX_* fixture env vars.

defp shared_env(db_name) do
  base = [
    {"MIX_ENV", "test"},
    {"RINDLE_INSTALL_SMOKE_DB", db_name},
    {"PGUSER", env_or_default("PGUSER", System.get_env("USER") || "postgres")},
    {"PGPASSWORD", System.get_env("PGPASSWORD")},
    {"PGHOST", env_or_default("PGHOST", "localhost")},
    {"PGPORT", env_or_default("PGPORT", "5432")},
    {"RINDLE_MINIO_URL", env_or_default("RINDLE_MINIO_URL", "http://localhost:9000")},
    {"RINDLE_MINIO_BUCKET", env_or_default("RINDLE_MINIO_BUCKET", "rindle-test")},
    {"RINDLE_MINIO_ACCESS_KEY", env_or_default("RINDLE_MINIO_ACCESS_KEY", "minioadmin")},
    {"RINDLE_MINIO_SECRET_KEY", env_or_default("RINDLE_MINIO_SECRET_KEY", "minioadmin")},
    {"RINDLE_MINIO_REGION", env_or_default("RINDLE_MINIO_REGION", "us-east-1")}
  ]

  # NEW: Mux fixture env vars. In soak mode, these are overridden by the GitHub
  # Actions job's `env:` block (real secrets). In cassette mode, the fixture values
  # exercise the RINDLE_MUX_* -> config :rindle, ..Mux resolution path without ever
  # hitting api.mux.com (the Mox client returns canned responses).
  mux_env = [
    {"RINDLE_MUX_TOKEN_ID", env_or_default("RINDLE_MUX_TOKEN_ID", "test-token-id")},
    {"RINDLE_MUX_TOKEN_SECRET", env_or_default("RINDLE_MUX_TOKEN_SECRET", "test-token-secret")},
    {"RINDLE_MUX_SIGNING_KEY_ID", env_or_default("RINDLE_MUX_SIGNING_KEY_ID", "test-signing-key-id")},
    {"RINDLE_MUX_SIGNING_PRIVATE_KEY",
     System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY") ||
       File.read!("test/fixtures/mux/test_signing_private_key.pem")},
    {"RINDLE_MUX_WEBHOOK_SECRETS",
     env_or_default("RINDLE_MUX_WEBHOOK_SECRETS",
       "whsec_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")}
  ]

  (base ++ mux_env)
  |> Enum.reject(fn {_key, value} -> is_nil(value) end)
end
```

Note: env_or_default uses `System.get_env(name) || default` — so in soak mode, the GitHub Actions job's `env:` block (which sets the real secrets) wins. In cassette mode, fixtures win.

### Test Module for `mux_web_test.exs` (Plan 01)

Mirrors `test/rindle/profile/presets_web_test.exs` shape:

```elixir
defmodule Rindle.Profile.Presets.MuxWebTest do
  use ExUnit.Case, async: true

  alias Rindle.Profile.Presets.MuxWeb

  defmodule MuxWebProfile do
    @moduledoc false
    use MuxWeb,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
      max_bytes: 524_288_000
  end

  describe "compile" do
    test "inherits Web's web_720p + poster variants verbatim" do
      assert Enum.sort_by(MuxWebProfile.variants(), &elem(&1, 0)) ==
               [
                 poster: %{preset: :video_poster_scene},
                 web_720p: %{kind: :video, preset: :web_720p, faststart: true}
               ]
    end

    test "writes the locked streaming block to delivery_policy/0" do
      assert MuxWebProfile.delivery_policy().streaming == %{
               provider: Rindle.Streaming.Provider.Mux,
               playback_policy: :signed,
               ingest_mode: :server_push,
               source_variant: :web_720p
             }
    end

    test "preset is the only public delivery_policy.streaming source — Phase 33 schema validates" do
      # The validator at lib/rindle/profile/validator.ex:282 enforces the four-key shape.
      # If MuxWeb emits anything outside the schema, this module wouldn't compile.
      assert function_exported?(MuxWebProfile, :delivery_policy, 0)
    end
  end

  describe "passthrough opts" do
    defmodule MuxWebProfileWithStrip do
      @moduledoc false
      use MuxWeb,
        storage: Rindle.Storage.S3,
        allow_mime: ["video/mp4"],
        max_bytes: 100_000_000,
        scrub_strip: true
    end

    test "scrub_strip flag passes through to Web.variants/1" do
      assert {:scrub_strip, _} = List.keyfind(MuxWebProfileWithStrip.variants(), :scrub_strip, 0)
    end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ngrok as default local-tunnel recommendation | cloudflared TryCloudflare quick tunnel | Pre-2026 → 2026 | ngrok now requires signup + auth-token install before a single tunnel; cloudflared `--url` is signup-free. Inverts the historical default. (D-11 / external research Topic 3.) |
| `pull_request_target` for label-gated jobs needing secrets | `pull_request` (fork-PR-fail-closed) | Pre-2025 → 2025+ | `pull_request_target` exposed fork PRs to base-branch secrets; `pull_request` injects empty strings on forks. (D-19/D-20 / external research Topic 1.) |
| Mux SDK singular `input` / `playback_policy` REST keys | Plural `inputs` / `playback_policies` | 2026-05 | Singular keys deprecated. Phase 34 D-04 already locked PLURAL. Phase 36 doesn't change this; called out for guide Section 4 reviewer awareness. |

**Deprecated/outdated:**
- ngrok-as-default in adopter onboarding docs: deprecated by Mux's own dev-loop docs; cloudflared is recommended.
- ExVCR for HTTP cassette tests in Elixir: deprecated by community in favor of Mox-on-behaviour-seam (Phase 34 D-35 rejected ExVCR explicitly).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Plan slicing into 3 PLAN.md files (preset+doctor / guide+README / generated-app+CI) is the right cleavage. | Summary, Plan-slice recommendation | LOW — CONTEXT.md `## Specifics` already names this slicing pattern (3 plans matching v1.5 phase 32 baseline). Planner is free to merge or split further. |
| A2 | Pattern 3 Recommendation 1 (stub-via-fixture-files in generated app) is preferred over Recommendation 2 (deftesting in test/support). | Pattern 3, Recommendation note | MEDIUM — Untested locally. If `File.cp!` of the PEM into the generated app's compile path causes a permission or path issue, fall back to embedding the PEM as a literal string in `patch_test_config!/2`'s emitted block. |
| A3 | The four streaming doctor checks share enough plumbing that one private module (`Rindle.Ops.RuntimeChecks.Streaming` `@moduledoc false`) is the right cohesion break point. | Pattern 2 / Don't Hand-Roll | LOW — D-05 says single file is fine. Either approach is acceptable. |
| A4 | `JOSE.JWK.from_pem/1` returning `[]` on malformed PEM is the actual behaviour. (Stated in Pitfall 1.) | Pitfall 1 | MEDIUM — verified by JOSE README pattern but not reproduced in this session. The `runtime_checks_streaming_test.exs` test should explicitly probe this with a malformed PEM string before merging. |
| A5 | `test/fixtures/mux/test_signing_public_key.pem` is REDUNDANT — `JOSE.JWK.to_public/1` derives it in-test. (Stated in Don't Hand-Roll table and Open Questions §2.) | Don't Hand-Roll, Open Questions §2 | LOW — D-31 lists the public PEM as a NEW file. If derived-in-test pattern is preferred, omit the file commit and document in Open Questions §2 for planner to confirm. |
| A6 | `Mux.Video.Assets.list/1` is the correct smoke-ping target. | D-08 / Pattern 1 / Architecture diagram | HIGH — Verified via REQUIREMENTS MUX-16 which says explicitly "5s smoke ping to `Mux.Video.Assets.list/1`" and the Mux SDK source at `lib/mux/video/assets.ex`. Function takes a Tesla client + `params \\ %{}`; pass `%{limit: 1}` to minimize bandwidth. |
| A7 | `Phoenix.new` 1.7.x compatibility — current helper works, Phase 36 changes don't introduce new shape-matching. | Pitfall 5 | LOW — Phase 29 (v1.5 package-consumer proof) shipped this helper; v1.5 + v1.6 phases 33-35 all built atop it without Phoenix-version drift issues. |
| A8 | Free-tier Mux account set up at the org level (not per-developer) — secrets injected via repo-level GitHub Secrets. | D-24 maintainer setup | MEDIUM — One-time maintainer setup; documented as such in CONTEXT.md but not actionable until a maintainer creates the Mux account and adds the five secrets. Phase 36 PRs CAN ship and merge without the secrets configured (cassette lane runs without them; soak lane only runs on label, and label-gating gracefully no-ops if secrets are absent). |

## Open Questions

1. **Does CONTEXT.md require committing both PEMs (private+public) or only deriving public-from-private at test time?**
   - What we know: D-31 lists `test/fixtures/mux/test_signing_public_key.pem` as a NEW file with the openssl command. Existing pattern at `signed_playback_url_test.exs:66-70` derives the public key in-test from the private PEM.
   - What's unclear: Is the public PEM file load-bearing for any future test, or is the derivation pattern preferred (no extra file to maintain)?
   - Recommendation: **Defer to planner.** If planner ships the public PEM file per D-31, it works (just one more committed file); if planner uses derivation per the existing test pattern, it also works (no new file). Either is correct. Planner picks based on consistency preference.

2. **Should the `:mux` lifecycle test source pull `import Mox` and `setup :set_mox_from_context` from inside the generated app, or wire those via a generated `RindleInstallSmokeMuxHelper` test-support module copied alongside?**
   - What we know: Pitfall 2 establishes the requirement; the existing `:image` and `:video` heads don't need Mox.
   - What's unclear: Whether stamping `import Mox` and `setup` callbacks directly in the lifecycle test source (option A) vs. extracting them into a shared test-support module copied into the generated app (option B) is cleaner.
   - Recommendation: **Option A (stamp directly).** The `lifecycle_test_source/2` head-clauses are already verbose; one extra `import Mox` line is not a maintenance hazard. Option B requires the existing helper's test-support copying surface to extend, which is invasive.

3. **Should `scripts/mux_soak_cleanup.sh` use `mix` (Elixir + adapter) or pure `curl` (no compile dep on the host)?**
   - What we know: D-22 says "belt-and-suspenders sweep"; CONTEXT.md leaves the implementation to the planner.
   - What's unclear: GitHub Actions `if: always()` step runs even if the previous step failed compile-time; if `mix` itself can't be invoked (because compile failed), a pure-curl fallback survives. But pure-curl requires hand-rolling Mux's basic-auth header.
   - Recommendation: **`mix run` script with a pure-curl fallback.** Primary path `mix run -e 'Rindle.Streaming.Provider.Mux.HTTP.list(...) |> Enum.each(&Mux.Video.Assets.delete/2)'`; if `mix` fails (compile error), fall back to `curl -u $TOKEN_ID:$TOKEN_SECRET ...`. The fallback is ~10 lines of bash and survives any host-side rindle compile failure.

4. **Do all four doctor checks need separate test files, or can `runtime_checks_streaming_test.exs` cover them with describe blocks?**
   - What we know: D-31 lists ONE file. CONTEXT.md `## Claude's Discretion` allows extracting a private helper module if cohesion improves.
   - What's unclear: Test coverage organization preference — one file per check (4 files) vs. one file with 4 describe blocks (1 file).
   - Recommendation: **One file with describe blocks.** Existing `runtime_checks_test.exs` uses describe blocks for the 8 existing checks; mirror that pattern. Keeps test discoverability local.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All Phase 36 work | ✓ | per `setup-beam@v1` matrix (1.15 + 1.17 in CI) | — |
| Erlang/OTP | All Phase 36 work | ✓ | per `setup-beam@v1` matrix (26 + 27) | — |
| `mix phx.new` | Plan 03 generated-app harness | ✓ | latest in Phoenix archive (currently 1.7.x) | — |
| MinIO | Plan 03 cassette + soak lanes | ✓ | per CI service block | — |
| PostgreSQL | Plan 03 cassette + soak lanes | ✓ | postgres:16-alpine per CI services | — |
| ffmpeg | Plan 03 lane processing | ✓ | 6.0 via FedericoCarboni/setup-ffmpeg@v3 | — |
| libvips | Plan 03 (image processing) | ✓ | apt-get install -y libvips-dev | — |
| `cloudflared` (CLI) | Guide section 7 (documentation only) | N/A | not invoked from CI; adopter installs locally | — |
| Real Mux account | Plan 03 `mux-soak` lane | One-time maintainer setup | Mux Cloud free tier | Cassette lane runs without it; soak lane fails closed on missing secrets (D-20 fork-secret-safe pattern) |
| `openssl` | Plan 03 public PEM generation (if A5/Open Q1 chooses commit-the-file) | ✓ | macOS + Linux ship openssl | Use derivation pattern (`JOSE.JWK.to_public/1`) |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** Real Mux account — fallback is cassette mode (zero-cost, no secrets). Soak lane gracefully no-ops without secrets.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.15-1.17 stdlib) + Mox 1.2 + Oban.Testing 2.21 |
| Config file | `test/test_helper.exs` (existing — no changes needed) |
| Quick run command | `mix test test/rindle/profile/presets/mux_web_test.exs test/rindle/ops/runtime_checks_streaming_test.exs` |
| Full suite command | `mix test --include minio` (includes generated-app smoke; takes ~2-3 min on CI) |
| Cassette lane command | `bash scripts/install_smoke.sh mux` (cassette mode by default) |
| Soak lane command | `RINDLE_MUX_USE_REAL_API=1 bash scripts/install_smoke.sh mux` (label-gated in CI) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MUX-15 | `MuxWeb` ships, inherits Web variants, writes locked streaming block to delivery_policy | unit | `mix test test/rindle/profile/presets/mux_web_test.exs -x` | ❌ Wave 0 (NEW file) |
| MUX-15 | `MuxWeb` compiles when `:mux` dep absent (locked streaming block stores only the provider module atom) | unit (compile-only) | `mix compile --warnings-as-errors` (Quality job already covers) | ✅ existing |
| MUX-16 | `doctor.streaming_credentials` PASS when all 5 RINDLE_MUX_* env vars set | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs:test_credentials_pass -x` | ❌ Wave 0 (NEW file) |
| MUX-16 | `doctor.streaming_credentials` FAIL with fix recipe when env var missing | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs:test_credentials_fail -x` | ❌ Wave 0 |
| MUX-16 | `doctor.streaming_signing_key` PASS on valid PEM, FAIL on malformed | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs:test_signing_key -x` | ❌ Wave 0 |
| MUX-16 | `doctor.streaming_webhook_secrets` validates ≥32 chars per secret | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs:test_webhook_secrets -x` | ❌ Wave 0 |
| MUX-16 | `doctor.streaming_smoke_ping` skipped without `--streaming` flag | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs:test_smoke_ping_gated -x` | ❌ Wave 0 |
| MUX-16 | `doctor.streaming_smoke_ping` enforces 5s timeout | unit (via Mox slow stub) | `mix test test/rindle/ops/runtime_checks_streaming_test.exs:test_smoke_ping_timeout -x` | ❌ Wave 0 |
| MUX-16 | `doctor.streaming_smoke_ping` taxonomy: 401/403 → token fix; 429 → rate-limit; etc. | unit (table-driven via Mox) | `mix test test/rindle/ops/runtime_checks_streaming_test.exs:test_smoke_ping_failure_taxonomy -x` | ❌ Wave 0 |
| MUX-16 | All four streaming checks return vacuous-OK when no streaming-enabled profiles discovered | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs:test_no_streaming_profiles -x` | ❌ Wave 0 |
| MUX-16 | `--streaming` OptionParser flag plumbs through to RuntimeChecks.run/2 opts | unit | `mix test test/mix/tasks/rindle.doctor_test.exs:test_streaming_flag -x` | ❌ Wave 0 (extend existing if present, else NEW) |
| MUX-17 | `streaming_providers.md` builds in HexDocs | docs build | `MIX_ENV=dev mix docs && [ -f doc/streaming_providers.html ]` | ✅ existing (mix docs) |
| MUX-17 | Guide is in mix.exs `:extras` list | grep | `grep -F 'guides/streaming_providers.md' mix.exs` | ✅ verifiable post-Plan-02 |
| MUX-17 | Guide Section 5 matches WebhookPlug @moduledoc verbatim (single source of truth) | grep / diff | `diff <(sed -n '/Step 1 — install/,/Step 3 — set/p' lib/rindle/delivery/webhook_plug.ex) <(sed -n '/Step 1 — install/,/Step 3 — set/p' guides/streaming_providers.md)` | manual until Plan 02 ships |
| MUX-18 | Cassette lane: `bash scripts/install_smoke.sh mux` produces a Mux-signed HLS URL whose JWT verifies | end-to-end (smoke) | `bash scripts/install_smoke.sh mux` (CI: package-consumer job's new step) | ❌ Wave 0 (NEW step in CI) |
| MUX-18 | Cassette lane reuses MinIO + Postgres services (no new services) | CI verification | inspect `.github/workflows/ci.yml` package-consumer block; assert no new `services:` keys added | manual |
| MUX-18 | Soak lane gated on `streaming` label | CI verification | inspect `.github/workflows/ci.yml` `mux-soak.if:` clause | manual |
| MUX-18 | Soak lane fails closed on fork PRs (empty secrets → 401) | CI verification | run a fork PR labelled `streaming`; expect Mux 401 + clean failure | manual + maintainer-only |
| MUX-18 | Soak lane cleanup runs even on test failure | CI verification | inspect `mux-soak` job for `if: always()` cleanup step | manual |
| MUX-19 | README + getting_started have `Rindle.Profile.Presets.MuxWeb` reference | grep | `grep -F 'Rindle.Profile.Presets.MuxWeb' README.md guides/getting_started.md` | ❌ Wave 0 (Plan 02 ships it) |
| MUX-19 | README + getting_started preserve all existing required strings (D-28 invariant) | doc-parity guard | the existing CI step at `.github/workflows/ci.yml:518-545` runs on every PR | ✅ existing |
| MUX-19 | README + getting_started do NOT introduce forbidden patterns (`Broker.initiate_session`, `Broker.verify_completion`, `Rindle.Delivery.url`) | grep / regex | the existing negative regex in the doc-parity guard | ✅ existing |
| MUX-19 | Subsection placement: AFTER canonical AV, ≤15 lines | manual review | inspect README.md and getting_started.md placement in PR review | manual |

### Sampling Rate

- **Per task commit (Plan 01):** `mix test test/rindle/profile/presets/mux_web_test.exs test/rindle/ops/runtime_checks_streaming_test.exs --warnings-as-errors` (~2s; pure unit)
- **Per task commit (Plan 02):** `MIX_ENV=dev mix docs --formatter html >/dev/null && grep -F 'Rindle.Profile.Presets.MuxWeb' README.md guides/getting_started.md` (~5s; docs build + grep)
- **Per task commit (Plan 03):** `bash scripts/install_smoke.sh mux` (cassette mode; ~90s; full generated-app round-trip)
- **Per wave merge:** `mix test --include minio` (full suite; ~3 min)
- **Phase gate:** Full suite green + `bash scripts/install_smoke.sh mux` cassette green + soak lane label-tested at least once via maintainer-labelled PR before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/rindle/profile/presets/mux_web_test.exs` — covers MUX-15 unit coverage. **Blocker for Plan 01.**
- [ ] `test/rindle/ops/runtime_checks_streaming_test.exs` — covers MUX-16. New shared fixtures: a malformed-PEM string, a too-short webhook secret, Mox stubs for the four smoke-ping HTTP responses. **Blocker for Plan 01.**
- [ ] (Optional) `test/mix/tasks/rindle.doctor_test.exs` — does it already exist? If yes, extend with `--streaming` flag test; if no, create. Search: `find test -name 'rindle*doctor*test*'`. **Verify before Plan 01 starts.**
- [ ] `test/install_smoke/generated_app_smoke_test.exs` — extend with `GeneratedAppSmokeMuxTest` module mirroring `GeneratedAppSmokeImageTest`/`VideoTest`. **Blocker for Plan 03.**
- [ ] `test/fixtures/mux/test_signing_public_key.pem` — IF planner chooses commit-the-file (Open Q1 option A) rather than derivation (option B). Generate via `openssl rsa -in test/fixtures/mux/test_signing_private_key.pem -pubout -out test/fixtures/mux/test_signing_public_key.pem`.
- [ ] No framework install needed — Mox + Oban.Testing + ExUnit all already in deps.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (Mux API token + signing key) | RINDLE_MUX_TOKEN_ID/SECRET as basic-auth; signing key for JWT — already shipped in Phase 34. Phase 36's doctor checks VALIDATE these are present + well-formed; do not echo them back. |
| V3 Session Management | no | n/a |
| V4 Access Control | no (adopter app is responsible for end-user authz) | n/a — security invariant 14 (`MediaProviderAsset.redact_id/1`) covers telemetry; no Phase 36 surface introduces new authz boundaries. |
| V5 Input Validation | yes | NimbleOptions schema (`@streaming_schema` Phase 33); validates `MuxWeb`'s emitted streaming block at compile time. |
| V6 Cryptography | yes (RSA-2048 PEM, RS256 JWT) | `JOSE.JWK.from_pem/1` + `Mux.Token.sign_playback_id/2` — already shipped in Phase 34. Phase 36's signing-key check uses JOSE; never hand-rolls cryptography. |
| V7 Error Handling & Logging | yes | Doctor failures emit fix-recipe text only; never echo credential values. `mix rindle.doctor --streaming` output for `doctor.streaming_credentials` says "Missing RINDLE_MUX_TOKEN_ID" — does NOT print the value of `RINDLE_MUX_TOKEN_ID` even when present. |
| V8 Data Protection | yes (security invariant 14: provider_asset_id last-4-char redaction) | Soak-lane cleanup script's logs MUST redact provider_asset_id. Reuse `Rindle.Domain.MediaProviderAsset.redact_id/1` (Phase 34 surface). |
| V13 API & Web Service | yes (mux-soak fork-secret boundary) | `pull_request` event (NOT `_target`) + label gate. Fork PRs labelled `streaming` get empty secrets → fail closed. (D-19/D-20.) |

### Known Threat Patterns for Phase 36

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Fork PR exfiltrating maintainer Mux secrets via label-gated workflow | Information Disclosure | `pull_request` event (NOT `pull_request_target`); GitHub injects empty `secrets.*` on forks → lane fails closed (D-19/D-20). |
| Soak-lane test asset leak filling Mux free-tier 10-asset cap | Denial of Service (against the project itself) | Three-layer cleanup: Elixir try/after, GitHub Actions `if: always()` step, sweep script (D-22). |
| Doctor output leaking partial secret values | Information Disclosure | Doctor messages reference env-var NAMES only (`"Missing RINDLE_MUX_TOKEN_ID"`), never values. Capability.report/0 already enforces this contract (lib/rindle/capability.ex:8-15). |
| Cassette fixture key reuse in adopter prod (developer copies fixture into runtime config) | Identification & Authentication failure | Fixture PEM is clearly marked test-only (filename `test_signing_private_key.pem` under `test/fixtures/`); guide Section 3 emphasizes adopters create their OWN signing key via Mux dashboard. |
| Doc-parity guard regression (someone removes `Rindle.Profile.Presets.Web` from required-strings list) | Tampering with onboarding canon | The guard's `for REQUIRED in \\` list is asserted on EVERY PR; D-28 invariant explicitly preserves the existing list. |
| Plug.Conn body-reader misconfigured by adopter (cf Phase 35) | Tampering | Guide Step 5 copies the canonical wiring verbatim from `WebhookPlug.@moduledoc`; no fork in the snippet. |
| `JOSE.JWK.from_pem/1` returning `[]` on malformed PEM passes silently | Tampering / Repudiation | `doctor.streaming_signing_key` MUST pattern-match against `%JOSE.JWK{}` struct, not just truthy result (Pitfall 1). |

## Project Constraints (from CLAUDE.md)

> CLAUDE.md is empty / not present at the working directory root. No project-level directives to enforce beyond the standard `.planning/STATE.md` decision-making preference (decide-by-default, escalate-only-impactful) and the `memory/feedback_research_driven_one_shot.md` posture (research-driven one-shot recommendations).

The closest equivalents (already enforced by CONTEXT.md):
- Security invariant 14 (last-4-char `provider_asset_id` redaction) applies to any new Phase 36 telemetry/log surface.
- Adopter-owned config posture: Rindle ships modules + documented snippets; adopter wires `endpoint.ex`, `router.ex`, `config/runtime.exs`, `Oban.Plugins.Cron` themselves.
- Optional-dep posture: `:mux` and `:jose` are `optional: true`; adopters who don't enable streaming pay zero transitive cost (Phase 34 D-01).
- Single-source-of-truth posture: webhook-plug + cron snippets live in module `@moduledoc`; guide LINKS or COPIES, never forks (D-13).
- Single-file pipeline for runtime checks: `Rindle.Ops.RuntimeChecks` is the one-pipeline-many-checks shape.

## Sources

### Primary (HIGH confidence) — verified in this session

- `lib/rindle/profile/presets/web.ex` — direct template for MuxWeb (read in full).
- `lib/rindle/ops/runtime_checks.ex` — direct template for the four streaming checks (read in full).
- `lib/mix/tasks/rindle.doctor.ex` — OptionParser + RuntimeChecks integration (read in full).
- `lib/rindle/capability.ex` — `report/0` shape + streaming.configured_profiles helper (read in full).
- `lib/rindle/streaming/provider/mux.ex` — adapter behaviour, http_client config seam (read in full).
- `lib/rindle/streaming/provider/mux/client.ex` — Mox behaviour target (read in full).
- `lib/rindle/streaming/provider/mux/http.ex` — real adapter implementation (read in full).
- `lib/rindle/delivery/webhook_plug.ex:1-65` — canonical guide Step 5 source (`@moduledoc`).
- `lib/rindle/workers/mux_sync_coordinator.ex:5-67` — canonical guide Step 6 source (`@moduledoc`).
- `lib/rindle/profile/validator.ex:42-82` — `@delivery_schema` and `@streaming_schema`.
- `mix.exs:50-227` — deps list, extras list, package config (read in full).
- `test/install_smoke/support/generated_app_helper.ex:1-805` — generated-app harness (key sections read).
- `test/install_smoke/generated_app_smoke_test.exs` — image/video/upgrade test module shape (read in full).
- `test/rindle/profile/presets_web_test.exs` — preset test pattern (read in full).
- `test/rindle/ops/runtime_checks_test.exs:1-100` — runtime checks test pattern.
- `test/rindle/streaming/provider/mux/mux_test.exs:1-80` — Mox cassette setup pattern.
- `test/rindle/streaming/provider/mux/signed_playback_url_test.exs` — JWT verification pattern (read in full).
- `test/rindle/streaming/provider/mux/optional_dep_test.exs` — optional-dep + Mox client mock loader smoke.
- `test/support/mocks.ex` — `Rindle.Streaming.Provider.Mux.ClientMock` definition.
- `test/test_helper.exs` — global test setup (read in full).
- `test/fixtures/mux/asset_create_201.json` — cassette fixture shape.
- `test/fixtures/mux/test_signing_private_key.pem` — verified existing.
- `scripts/install_smoke.sh` — profile case dispatch (read in full).
- `.github/workflows/ci.yml:1-545` — full CI workflow (key sections read).
- `.planning/phases/36-public-dx-onboarding-ci-proof/36-CONTEXT.md` — 35 locked decisions (read in full).
- `.planning/REQUIREMENTS.md:114-133` — MUX-15..19 (read in full).
- `.planning/STATE.md` — decision preference, v0.2.0 release plan (read in full).
- `.planning/ROADMAP.md:208-246` — Phase 36 goal + success criteria.
- `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` — source-of-truth memo (§5 dispatch tree confirmed).

### Secondary (MEDIUM confidence) — referenced from CONTEXT.md, not re-verified

- External research Topic 1 (GitHub Actions `pull_request` vs `_target` fork-secret boundary, `labeled` event type) — locked in D-19/D-20.
- External research Topic 2 (Mux free-tier policy: 10-asset stored cap, 1 RPS POST / 5 RPS GET-DELETE rate limits, $0/PR cost) — locked in D-22/D-23.
- External research Topic 3 (cloudflared TryCloudflare quick tunnel signup-free; ngrok now requires signup) — locked in D-11.

### Tertiary (LOW confidence)

- (none — Phase 36's surface is fully verified by reading the codebase + CONTEXT.md.)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all deps already in mix.exs verified; no new deps in Phase 36.
- Architecture: HIGH — all analog code excerpts verified by reading the literal source files.
- Pitfalls: MEDIUM-HIGH — Pitfalls 1, 2, 3 verified by reading existing test files and helper. Pitfalls 4, 5 derived from inspection of the doc-parity guard regex and CI workflow shape; would benefit from a dry-run of the CI workflow after Plan 02 ships.
- Validation Architecture: HIGH — every requirement maps to a specific automated command; commands runnable in <30s for the unit lane and ~90s for the cassette lane.

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (30 days; Phase 36 is stable-domain DX/CI work; the only volatility surface is `mix phx.new` Phoenix version drift which Pitfall 5 mitigates).

---

## RESEARCH COMPLETE

Phase 36 is a pure DX/CI/docs phase atop the locked Phases 33-35 runtime. CONTEXT.md upstream of this research locked all 35 decisions; the candidate memo + external research subagent already resolved the GitHub Actions fork-secret, Mux free-tier, and 2026 webhook-tunnel surfaces. This research adds (a) verbatim analog code excerpts the planner needs to wire executor tasks (`Web` → `MuxWeb` macro; `check_local_playback` → four streaming checks; `:video` → `:mux` lifecycle test source); (b) a Validation Architecture section with 23 requirement→test rows and concrete <30s automated commands per row, broken down by the three natural plan slices (Plan 01 preset+doctor, Plan 02 guide+README+doc-parity, Plan 03 generated-app+CI); (c) five pitfalls with reproducible warning signs (JOSE PEM silent-failure, Mox process-locality, `mix phx.new --install` ordering, doc-parity regex landmines, Phoenix version drift); (d) eight assumptions logged with risk levels and four open questions deferred explicitly to the planner with recommendations. Confidence is HIGH across stack, architecture, and validation; MEDIUM-HIGH on pitfalls. The recommended slicing into 3 plans matches Phase 32's velocity baseline and the natural file boundaries in CONTEXT.md `## Module / File Layout`.
