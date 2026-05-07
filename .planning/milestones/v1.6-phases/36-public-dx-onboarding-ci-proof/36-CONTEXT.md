# Phase 36: Public DX, Onboarding, CI Proof — Context

**Gathered:** 2026-05-07
**Status:** Ready for planning
**Mode:** Research-driven one-shot. Per `STATE.md` Decision-Making Preference and the user feedback memo (`memory/feedback_research_driven_one_shot.md`), the assumptions analyzer scouted 16 source files + 4 prior CONTEXT artifacts; an external research subagent resolved three open gaps (GitHub Actions PR-label fork-secret boundary, Mux free-tier soak budget, 2026 webhook-tunnel tooling). Findings folded in below as locked decisions; nothing was asked of the user that didn't qualify as VERY impactful (public-API/semver, destructive, security, cost, scope).

<domain>
## Phase Boundary

Phase 36 is the **adopter-facing close-out** of v1.6. The runtime — provider boundary (Phase 33), Mux REST adapter + workers (Phase 34), signed-webhook plug + idempotent ingest (Phase 35) — is shipped and verified. Phase 36 turns that into a copy-pasteable adopter onboarding lane equivalent in fidelity to v1.5's image-only and AV-enabled bars.

In scope:
- `Rindle.Profile.Presets.MuxWeb` (PUBLIC) — thin wrapper over `Rindle.Profile.Presets.Web`'s variant set (`web_720p` + `poster`) that injects the locked `:streaming` block (provider Mux, `:signed` playback, `:server_push` ingest, `:web_720p` source).
- Four new `mix rindle.doctor` checks added to `Rindle.Ops.RuntimeChecks` (one ID each: `doctor.streaming_credentials`, `doctor.streaming_signing_key`, `doctor.streaming_webhook_secrets`, `doctor.streaming_smoke_ping`); profile-discovery-gated; smoke ping is `--streaming` opt-in only.
- New `guides/streaming_providers.md` (Mux-only; no second-provider scaffold) covering deps, signing-key creation, profile config, plug wiring, cron coordinator, local cloudflared tunnel, secret rotation, doctor smoke, stuck-asset runbook.
- Generated-app package-consumer harness gains a third `:mux` profile mode in `test/install_smoke/support/generated_app_helper.ex`; reuses `:video` lane assertions verbatim and layers a Mux-signed-HLS-URL JWT-decode assertion; cassette-driven by default via the existing Phase 34 Mox-on-`:http_client`-config seam.
- New CI step in the existing `package-consumer` job runs `bash scripts/install_smoke.sh mux` (cassette mode, no secrets); separate new top-level `mux-soak` job, label-gated on `streaming`, runs the same lane against real Mux with delete-on-finally cleanup.
- README.md and `guides/getting_started.md` gain a single short "Streaming with Mux (optional)" subsection (≤15 lines) appended after the canonical AV path; doc-parity guard at `.github/workflows/ci.yml:518-545` extends to require `Rindle.Profile.Presets.MuxWeb`.

Out of scope (explicit deferrals):
- `Rindle.Streaming.Provider.Mux.create_direct_upload/2` and the `:provider_asset_created` PubSub event for direct-creator-uploads — Phase 37 / v1.7.
- Second streaming provider (Cloudflare Stream / Bunny Stream / Cloudinary Video) — v1.7+ per memo §1 #2 and §13. v1.6 ships single-provider scope.
- `Rindle.LiveView.subscribe(:provider_asset, id)` extension — Phase 37 (MUX-23).
- Webhook event replay tooling (`mix rindle.webhook.replay`) — v1.7+.
- Configurable telemetry redaction — v1.7+.
- DASH playback kind — v1.7+.
- `JOSE.JWK.from_pem/1` `:persistent_term` cache for high-throughput signing — Phase 36 documents the optimization in the new guide; implementation is v1.7+ (Phase 34 D-09 deferred).
- Cancellation surface for in-flight provider ingest (`Rindle.cancel_provider_ingest/1`) — v1.7+.
- Multi-provider scaffold guide structure ("Streaming Providers (Mux, Cloudflare Stream coming v1.7+)") — v1.6 ships Mux-only; second-provider docs land with the second adapter.

</domain>

<decisions>
## Implementation Decisions

All decisions below are LOCKED. Source: candidate memo `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` §2 (MUX-15..19 block at line 91), §11 CI proof, §13 deferred + Phase 33 CONTEXT.md (capabilities + DSL) + Phase 34 CONTEXT.md (adapter shape, optional-dep pattern, config layout) + Phase 35 CONTEXT.md (Plug wiring, body reader, runtime_status) + assumptions-analyzer scout + external research findings (Topics 1, 2, 3 below).

### MuxWeb Preset (MUX-15)

- **D-01:** Ship `Rindle.Profile.Presets.MuxWeb` at `lib/rindle/profile/presets/mux_web.ex` as a thin `__using__/1` macro wrapper over the `Rindle.Profile.Presets.Web` variant set. Inherits `web_720p` (`kind: :video, preset: :web_720p`) + `poster` (`kind: :image, preset: :video_poster_scene`) **verbatim** from `Web.variants/1` (do NOT redeclare the variant atoms — call `Rindle.Profile.Presets.Web.variants/1`). Accepts the same passthrough opts as `Web` (`:scrub_strip`, `:storage`, `:allow_mime`, `:max_bytes`, etc.) and merges the locked streaming block last so adopter overrides win.
- **D-02:** Streaming block shape (passed to `use Rindle.Profile, ...`):
  ```elixir
  delivery: [
    streaming: %{
      provider: Rindle.Streaming.Provider.Mux,
      playback_policy: :signed,
      ingest_mode: :server_push,
      source_variant: :web_720p
    }
  ]
  ```
  Validated by Phase 33 NimbleOptions schema at `lib/rindle/profile/validator.ex` (`@streaming_schema`). The four keys are the entire DSL surface (Phase 33 D-15); raw provider knobs are forbidden.
- **D-03:** **No `__using__/1` opt-out option for streaming.** MuxWeb is a streaming-on preset by definition; adopters who want AV-only stay on `Web`. The preset compiles unchanged when `:mux` optional dep is absent — the DSL stores only the provider module atom; runtime resolution happens via `Code.ensure_loaded?` in `Rindle.Delivery.streaming_url/3` (Phase 33). This preserves Phase 34's "adopters who do not configure streaming pay zero transitive cost" invariant (D-01 of Phase 34).
- **D-04:** **No new variant atoms.** Reusing `web_720p` + `poster` keeps the package-consumer `:mux` lane's ready-variant assertion byte-identical to the `:video` lane's (`["poster", "web_720p"]` at `test/install_smoke/generated_app_smoke_test.exs:88`). MuxWeb is "AV-canonical web preset PLUS streaming opt-in," not "different web preset."

### `mix rindle.doctor` Streaming Checks (MUX-16)

- **D-05:** Extend `Rindle.Ops.RuntimeChecks.run/2` (NOT a sibling module) with **four** new check functions appended to the `checks` list at `runtime_checks.ex:44-54`. Each follows the existing `defp check_<id>(...) do ... ok_result/error_result ... end` arity-1 pattern and returns the `%{id, status, component: :streaming, summary, fix}` shape. Check IDs:
  - `doctor.streaming_credentials` — presence of `RINDLE_MUX_TOKEN_ID` + `RINDLE_MUX_TOKEN_SECRET` + `RINDLE_MUX_SIGNING_KEY_ID` + `RINDLE_MUX_SIGNING_PRIVATE_KEY` + `RINDLE_MUX_WEBHOOK_SECRETS` (the five env-mapped config keys from Phase 34 D-29).
  - `doctor.streaming_signing_key` — `JOSE.JWK.from_pem/1` parse smoke on `RINDLE_MUX_SIGNING_PRIVATE_KEY`. Validates the PEM is well-formed before runtime hits it.
  - `doctor.streaming_webhook_secrets` — non-empty list with at least one secret of length ≥ 32 chars (matches Mux's documented minimum).
  - `doctor.streaming_smoke_ping` — 5s `Mux.Video.Assets.list/1` HEAD-style call against real Mux. **Gated behind `--streaming` opt-in flag** (NOT auto-run). REQUIREMENTS MUX-16 says "5s smoke ping"; gating preserves doctor's offline-friendly default posture and keeps the cassette CI lane passing without live Mux credentials.
- **D-06:** **Profile-discovery gating.** All four streaming checks consult `Rindle.Capability.report/0` (Phase 33 D-30) and emit `ok_result` with summary `"No streaming-enabled profiles discovered."` when no profile has `delivery_policy().streaming` set. Mirrors `check_local_playback`'s vacuous-summary pattern at `runtime_checks.ex:225-233`. When at least one profile opts in but `:mux` dep is absent, return `error_result` with fix `"Add {:mux, \"~> 3.2\", optional: true} and {:jose, \"~> 1.11\", optional: true} to your deps."` This satisfies Phase 34 D-33's deferred PASS/FAIL on missing-`:mux`-dep.
- **D-07:** **`--streaming` flag on the mix task.** `lib/mix/tasks/rindle.doctor.ex` gains an `OptionParser` strict opt `streaming: :boolean` plumbed through to `RuntimeChecks.run/2` via opts. When absent, `doctor.streaming_smoke_ping` returns `ok_result` with summary `"Smoke ping skipped (pass --streaming to enable live API check)."` When present, the smoke ping runs with a hard 5s timeout (Task.await/Task.shutdown pattern). Other three streaming checks always run when streaming-enabled profiles are discovered.
- **D-08:** Smoke-ping failure modes:
  - HTTP 200 → ok_result.
  - HTTP 401/403 → error_result with fix `"Verify RINDLE_MUX_TOKEN_ID and RINDLE_MUX_TOKEN_SECRET in your runtime config."`
  - HTTP 429 → error_result with fix `"Mux rate-limited the smoke ping; retry in a few seconds."`
  - Timeout (>5s) / connection error → error_result with fix `"Could not reach api.mux.com within 5s; check network / proxy / DNS."`
  - All other 4xx/5xx → error_result with fix referencing the response status.

### `guides/streaming_providers.md` (MUX-17)

- **D-09:** **Single new guide, Mux-only, no second-provider scaffolding** (no headings like "Streaming Providers (Mux today, Cloudflare Stream coming)"). v1.6 ships one provider; second-provider docs land with the second adapter. File path: `guides/streaming_providers.md`. Add to `mix.exs` `extras` list adjacent to `guides/secure_delivery.md`.
- **D-10:** Section ordering (locked):
  1. **"Why a streaming provider?"** — one paragraph, links to Phase 33's provider-vs-progressive dispatch tree concept.
  2. **"Add Mux to your dependencies"** — `{:mux, "~> 3.2", optional: true}` + `{:jose, "~> 1.11", optional: true}` in `mix.exs`; `config/runtime.exs` block matching Phase 34 D-29 verbatim.
  3. **"Create your Mux signing key"** — out-of-band steps via Mux dashboard (Settings → Signing Keys → Create); Rindle never auto-creates. Note: download the RSA private key once; Mux does not let you re-download.
  4. **"Configure your profile with `MuxWeb`"** — one-line `use Rindle.Profile.Presets.MuxWeb, storage: ..., allow_mime: ["video/mp4"]` snippet.
  5. **"Wire the webhook plug"** — verbatim copy of `Rindle.Delivery.WebhookPlug` `@moduledoc` Steps 1-3 from `lib/rindle/delivery/webhook_plug.ex:7-23`. Adopter `endpoint.ex` body_reader install + `router.ex` `forward "/webhooks/rindle/mux", Rindle.Delivery.WebhookPlug, ...` + `RINDLE_MUX_WEBHOOK_SECRETS` env var.
  6. **"Schedule the sync coordinator"** — copy the cron snippet from `lib/rindle/workers/mux_sync_coordinator.ex` `@moduledoc` (Phase 34 D-22).
  7. **"Local development with a webhook tunnel"** — leads with `cloudflared tunnel --url http://localhost:4000` (TryCloudflare quick tunnel, free, no signup, no auth token). Mentions ngrok as an alternative for users who want its inspection dashboard, with a callout that ngrok requires signup as of 2026 (research Topic 3).
  8. **"Webhook secret rotation workflow"** — multi-secret list, the `secret_index` telemetry field from Phase 35 D-11, retire-old after 24h grace.
  9. **"Run `mix rindle.doctor --streaming`"** — covers expected PASS output and the four FAIL fix recipes from D-08.
  10. **"Operator runbook: stuck assets"** — links to `mix rindle.runtime_status --provider-stuck` (Phase 35 D-39).
  11. **"Performance note: high-throughput JWT signing"** — documents the `JOSE.JWK.from_pem/1` re-parse footgun (Phase 34 D-09); recommends `:persistent_term` cache for adopters above ~1k playback URLs/sec; notes the cache itself ships in v1.7+.
- **D-11:** **Local-tunnel section recommendation: `cloudflared` primary, ngrok alternative.** External research Topic 3 confirms cloudflared's TryCloudflare quick tunnel (`cloudflared tunnel --url http://localhost:4000`) is free, ephemeral, no-signup, and adequate for Mux webhook volume in 2026. ngrok in 2026 requires account signup + auth-token install before a single tunnel starts. The "ngrok-style" wording in REQUIREMENTS MUX-17 refers to the *concept* (publicly-reachable URL pointing at localhost), not the brand. Single short subsection (5-10 lines), no install instructions for either tool — link out to vendor docs.
- **D-12:** **Style: mirror `guides/secure_delivery.md`.** Private-by-default narrative + locked code blocks + threat-model section + Quick Reference table at the bottom listing every Phase 35 telemetry event the adopter can subscribe to.
- **D-13:** **Source-of-truth: link, do not duplicate.** The webhook plug `@moduledoc` and `MuxSyncCoordinator` `@moduledoc` are the canonical adopter-wiring snippet sources. The guide's Steps 5-6 copy verbatim from those moduledocs (single source of truth — one place to update when the wiring shape evolves). If the guide must inline (for narrative flow), include a `<!-- source: lib/rindle/delivery/webhook_plug.ex @moduledoc -->` HTML comment so a future reader can find the canonical.

### Generated-App `:mux` Profile Mode (MUX-18 part 1 — harness)

- **D-14:** Add `:mux` as a third value to the existing `profile_mode` discriminator in `test/install_smoke/support/generated_app_helper.ex`. Current values: `:image | :video` (lines 14, 19). Extend the guard, the `selected_profiles/0` env-var dispatch (lines 857-864 — add `"mux" -> [:mux]` and `"all" -> [:image, :video, :mux]`), and add a new `lifecycle_test_source(_app_module, :mux)` head-clause (after the existing `:video` head at line 905).
- **D-15:** **`:mux` lane reuses the `:video` profile path's variant assertions verbatim.** Same `["poster", "web_720p"]` ready-variant set; same lifecycle (initiate → verify → attach → render). Layered on top: emit `use Rindle.Profile.Presets.MuxWeb, storage: ..., allow_mime: ["video/mp4"]` instead of `Rindle.Profile.Presets.Web`, and add a single new assertion at the end of the lifecycle test source: "verify cassette-driven `Rindle.Delivery.streaming_url/3` returns a Mux-signed HLS URL whose JWT decodes against the test signing public key."
- **D-16:** **Cassette/fixture replay uses the existing Phase 34 Mox-on-`:http_client`-config seam** (Phase 34 D-34). NOT Bypass against `api.mux.com` (Phase 34 D-35 rejected — Mux SDK base URL is hardcoded). NOT ExVCR (Phase 34 D-35 rejected — record/replay drift; would leak as transitive test dep). NOT Tesla.Mock (Phase 34 D-35 rejected — process-locality fragile).

  Implementation: `patch_test_config!/2` in `generated_app_helper.ex` (the existing test-config patcher at lines 342-382) gets a new appended block when `profile_mode == :mux`:
  ```elixir
  config :rindle, Rindle.Streaming.Provider.Mux,
    http_client: Rindle.Streaming.Provider.Mux.ClientMock
  ```
  The new lifecycle test source sets up Mox stubs by reading the existing `test/fixtures/mux/asset_create_201.json`, `asset_get_ready.json`, `webhook_video_asset_ready.json` fixtures (all committed in Phase 34/35). Fixtures are copied into the generated app's `test/fixtures/mux/` during `patch_test_config!/2` (mirrors how MinIO setup at lines 384-421 stages env state).
- **D-17:** **Fixture env vars in `shared_env/1`** (the env-injector at `generated_app_helper.ex` ~line 90). Set:
  - `RINDLE_MUX_TOKEN_ID` = `"test-token-id"` (literal fixture value)
  - `RINDLE_MUX_TOKEN_SECRET` = `"test-token-secret"`
  - `RINDLE_MUX_SIGNING_KEY_ID` = `"test-signing-key-id"`
  - `RINDLE_MUX_SIGNING_PRIVATE_KEY` = `File.read!("test/fixtures/mux/test_signing_private_key.pem")` (the RSA-2048 keypair already committed by Phase 34 D-37)
  - `RINDLE_MUX_WEBHOOK_SECRETS` = `"whsec_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"`

  These are FIXTURE values only — they exercise the `RINDLE_MUX_*` -> `config :rindle, Rindle.Streaming.Provider.Mux` resolution path without ever hitting real Mux. The Mox-driven `:http_client` shim ensures no `api.mux.com` traffic on the cassette lane.

### CI Lane Wiring (MUX-18 part 2 — workflow)

- **D-18:** **`mux-enabled` cassette step** is added to the existing `package-consumer` job in `.github/workflows/ci.yml` (lines 284-391), inserted **after** the existing `Run built-artifact AV package-consumer proof against MinIO` step (currently line 376-377). Reuses the same MinIO + Postgres services already up for the `:video` lane. Step:
  ```yaml
  - name: Run built-artifact Mux-enabled package-consumer proof (cassette mode)
    run: bash scripts/install_smoke.sh mux
  ```
  No new GitHub Secrets required for cassette mode. `scripts/install_smoke.sh` already takes a profile arg (`PROFILE="${1:-...}"` at line 9, validates `case ... in all|image|video) ;;` at line 19) — Phase 36 extends the `case` to `all|image|video|mux`.
- **D-19:** **`mux-soak` is a separate top-level job** (NOT a step inside `package-consumer`). Label-gated. Workflow trigger declaration at the top of `.github/workflows/ci.yml` extends to:
  ```yaml
  on:
    push:
      branches: [main]
    pull_request:
      branches: [main]
      types: [opened, synchronize, reopened, labeled]
  ```
  External research Topic 1 confirms `labeled` MUST be added explicitly — default types are `[opened, synchronize, reopened]` and applying a label to an existing PR will not fire the workflow without it.
- **D-20:** **`mux-soak` job declaration:**
  ```yaml
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
      postgres: { ... same as package-consumer ... }
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with: { elixir-version: "1.17", otp-version: "27" }
      - run: sudo apt-get install -y libvips-dev
      - run: mix deps.get
      - name: Run real-Mux soak proof
        run: bash scripts/install_smoke.sh mux
  ```
  External research Topic 1 confirms `pull_request` (NOT `pull_request_target`) keeps fork PRs safe — fork PRs labeled `streaming` will fire the lane but secrets resolve to empty strings, the lane fails closed, no leak.
- **D-21:** **`RINDLE_MUX_USE_REAL_API=1` env var flips the generated-app's `:http_client`** from `Rindle.Streaming.Provider.Mux.ClientMock` back to `Rindle.Streaming.Provider.Mux.HTTP` (the real adapter). Implementation: `patch_test_config!/2` reads `System.get_env("RINDLE_MUX_USE_REAL_API")` and conditionally emits the `:http_client` config block. When unset (cassette mode default), emit `http_client: Rindle.Streaming.Provider.Mux.ClientMock`. When set to `"1"` (soak mode), omit the config (defaults to the real `Rindle.Streaming.Provider.Mux.HTTP`).
- **D-22:** **Soak lane delete-on-finally cleanup is MANDATORY.** External research Topic 2 confirms Mux's free tier caps stored on-demand assets at **10**; the soak lane MUST delete the asset at the end of each run or the cap is hit and subsequent PRs fail. Implementation: wrap the soak-lane lifecycle test source in an Elixir `try/after` so `Mux.Video.Assets.delete/2` runs even on test failure, AND add a GitHub Actions `if: always()` cleanup step at the end of the `mux-soak` job that calls a new `scripts/mux_soak_cleanup.sh` script doing a `Mux.Video.Assets.list/1` + delete-all-test-assets sweep as a belt-and-suspenders measure.
- **D-23:** **Soak lane rate-limit budget:** External research Topic 2 confirms Mux's POST limit is 1 RPS sustained, GET/DELETE is 5 RPS. The lane does ONE create per PR + polling at 2-3s cadence + one delete — comfortably under both ceilings. Lane runs ≤90s end-to-end (asset create → ready → playback URL render → delete). At 50 PRs/month the cost is $0 (free-tier delivery quota is 100K minutes/month; the lane never streams bytes).
- **D-24:** **Required new GitHub Secrets** (maintainer setup; document in the new guide as a one-time setup step for adopters who fork & contribute streaming features):
  - `RINDLE_MUX_TOKEN_ID`
  - `RINDLE_MUX_TOKEN_SECRET`
  - `RINDLE_MUX_SIGNING_KEY_ID`
  - `RINDLE_MUX_SIGNING_PRIVATE_KEY`
  - `RINDLE_MUX_WEBHOOK_SECRETS`
  Mirrors Phase 34 D-29 env-var names (single source of truth — same names everywhere).

### README + getting_started.md "Streaming with Mux" Subsection (MUX-19)

- **D-25:** **Both `README.md` and `guides/getting_started.md` gain one new subsection.** Title: `## Streaming with Mux (optional)` (README) / `### Streaming with Mux (optional)` (getting_started, depending on existing heading depth). Length: ≤15 lines max. Placement: **after** the canonical AV-quickstart section and **after** any image-only / AV-enabled subsections — must NOT displace the canonical first-run story.
- **D-26:** **Subsection content** (3 elements only):
  1. One sentence: "For HLS streaming via signed URLs, opt your profile into a streaming provider."
  2. One code snippet:
     ```elixir
     defmodule MyApp.Profiles.Streaming do
       use Rindle.Profile.Presets.MuxWeb,
         storage: Rindle.Storage.S3,
         allow_mime: ["video/mp4"]
     end
     ```
  3. One sentence linking to the new guide: "See [streaming_providers.md](streaming_providers.md) for full setup (Mux dashboard, webhook plug, doctor smoke, secret rotation)."
- **D-27:** **Doc-parity guard extension.** The existing CI doc-parity guard at `.github/workflows/ci.yml:518-545` enforces a list of required strings in README.md and `guides/getting_started.md`. Phase 36 extends the `for REQUIRED in \\` list with one new string: `"Rindle.Profile.Presets.MuxWeb"`. The negative regex check (`Broker\\.initiate_session|Broker\\.verify_completion|Rindle\\.Delivery\\.url`) stays unchanged — MuxWeb does NOT introduce new forbidden patterns.
- **D-28:** **REQUIREMENTS MUX-19 invariant: image and AV onboarding paths remain canonical.** Concretely: the Sections 1-N of `getting_started.md` and the corresponding README "First Run: AV Quickstart" subsection MUST stay byte-identical to v1.5; the streaming subsection is appended only. The doc-parity guard's existing required strings (`Rindle.Profile.Presets.Web`, `Rindle.initiate_upload`, `Rindle.verify_completion`, `Rindle.attach`, `Rindle.url`, `mix rindle.doctor`) all remain enforced.

### Configuration (no new env vars beyond Phase 34's)

- **D-29:** **All adopter-side config keys reuse Phase 34 D-29's block** (`config :rindle, Rindle.Streaming.Provider.Mux, ...`). Phase 36 adds NO new config keys. The five `RINDLE_MUX_*` env vars are the canonical interface; the new guide references them in Step 2 of the locked section ordering.
- **D-30:** **Internal-only flag:** `RINDLE_MUX_USE_REAL_API` (D-21) is a CI-INTERNAL env var read by `patch_test_config!/2` to flip the generated-app's `:http_client` config in soak mode. NOT exposed to adopters; never appears in the new guide; documented only in the test helper module's `@moduledoc false` block.

### Module / File Layout

- **D-31:** **Files added in Phase 36:**
  - `lib/rindle/profile/presets/mux_web.ex` — PUBLIC preset (D-01..D-04).
  - `guides/streaming_providers.md` — PUBLIC adopter guide (D-09..D-13).
  - `scripts/mux_soak_cleanup.sh` — soak-lane belt-and-suspenders cleanup (D-22).
  - `test/fixtures/mux/test_signing_public_key.pem` — public half of the existing private key (D-15 JWT-decode assertion needs the public key for verification). Generate via `openssl rsa -in test/fixtures/mux/test_signing_private_key.pem -pubout -out test/fixtures/mux/test_signing_public_key.pem` once and commit.
  - `test/rindle/profile/presets/mux_web_test.exs` — preset compile + DSL validation tests.
  - `test/rindle/ops/runtime_checks_streaming_test.exs` — the four new check tests, profile-discovery-gating, smoke-ping flag-gating.
- **D-32:** **Files modified in Phase 36:**
  - `mix.exs` — add `guides/streaming_providers.md` to the `extras` list (alphabetical position: between `secure_delivery.md` and `troubleshooting.md`).
  - `lib/rindle/ops/runtime_checks.ex` — append the four streaming checks to the `checks` list (D-05); add the `defp check_streaming_*` clauses; consume `Rindle.Capability.report/0` for profile-discovery gating (D-06).
  - `lib/mix/tasks/rindle.doctor.ex` — add `--streaming` boolean opt to OptionParser strict opts; plumb through `RuntimeChecks.run/2` opts (D-07).
  - `test/install_smoke/support/generated_app_helper.ex` — extend `profile_enabled?/1` and `prove_package_install!/1` guards from `:image | :video` to `:image | :video | :mux` (D-14); extend `selected_profiles/0` env-var dispatch (D-14); add `lifecycle_test_source(_app_module, :mux)` head-clause (D-15); extend `patch_test_config!/2` to emit Mux config block conditional on `RINDLE_MUX_USE_REAL_API` (D-16, D-21); extend `shared_env/1` with the five fixture-value `RINDLE_MUX_*` env vars (D-17).
  - `test/install_smoke/generated_app_smoke_test.exs` — add `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` module mirroring the existing `Image`/`Video` test module shape; gated by `GeneratedAppHelper.profile_enabled?(:mux)`.
  - `scripts/install_smoke.sh` — extend the `case "$PROFILE" in all|image|video) ;;` line (line 19) to `all|image|video|mux) ;;` (D-18).
  - `.github/workflows/ci.yml` — add `labeled` to `pull_request.types` (D-19); add `mux-enabled` cassette step inside `package-consumer` job (D-18); add new top-level `mux-soak` job with label-gate + secrets + cleanup-always step (D-20, D-22); extend doc-parity guard's required-strings list with `Rindle.Profile.Presets.MuxWeb` (D-27).
  - `README.md` — append "Streaming with Mux (optional)" subsection (D-25, D-26) after the canonical AV path.
  - `guides/getting_started.md` — append "Streaming with Mux (optional)" subsection (D-25, D-26) after Section 10 / canonical AV path.

### Documentation Touch (Phase 36 IS the docs phase)

- **D-33:** **CHANGELOG entry** — add a v0.2.0-targeted entry (since `STATE.md` notes the next hex release is cut at v1.6 close): "Public adopter onboarding for streaming providers — `Rindle.Profile.Presets.MuxWeb`, `mix rindle.doctor --streaming`, `guides/streaming_providers.md`, generated-app `mux-enabled` package-consumer lane (cassette default + label-gated `mux-soak` lane against real Mux)."
- **D-34:** **No release note rewrites for v1.4-v1.5 surfaces.** Phase 36 is additive — existing AV onboarding language stays.

### Decision-Making Preference

- **D-35:** Reinforce: per `STATE.md` and the user feedback memo (`memory/feedback_research_driven_one_shot.md`), downstream researchers, planners, and executors decide by default and produce coherent recommendation sets. Escalate only for genuinely high-blast-radius decisions (semver-significant public API reshapes, destructive or irreversible operations, security/compliance boundary changes, real-cost surprises). The `mux-soak` fork-secret boundary (D-19, D-20) was the single security-critical decision in this phase; external research Topic 1 confirmed `pull_request` (not `_target`) is the locked safe pattern, and no further user input is required.

### Claude's Discretion (Planner / Executor)

The candidate memo + this CONTEXT lock the contract surface; the items below are implementation choices the planner / executor should make autonomously without asking the user, so long as the locked decisions above are preserved.

- Exact preset macro internals (e.g., whether `MuxWeb.__using__/1` calls `Rindle.Profile.Presets.Web.variants/1` directly or copies the keyword list inline; D-01 prefers calling the helper).
- Exact phrasing of `mix rindle.doctor --streaming` PASS/FAIL summaries and fix recipes (D-08 lists the failure-mode taxonomy; planner picks the wording).
- Whether the new guide's Section 5 "Wire the webhook plug" inlines the moduledoc snippet or links via `<!-- source: ... -->` HTML comment (D-13 expresses preference; planner picks).
- Whether `scripts/mux_soak_cleanup.sh` is a thin Bash shell-out to `mix` or a standalone Elixir script — either is fine.
- Test file organization for the `mux_web_test.exs` and `runtime_checks_streaming_test.exs` (one file per concern mirrors existing `test/rindle/profile/presets/`).
- Exact wording of the `RINDLE_MUX_USE_REAL_API` env-var conditional in `patch_test_config!/2` (D-21).
- Whether the doc-parity guard extension goes in the existing `for REQUIRED in \\` list or a new sibling list (D-27 prefers extending the existing list).
- Internal helper organization for the four new `defp check_streaming_*` clauses (D-05) — single file `runtime_checks.ex` is fine; planner may extract a `Rindle.Ops.RuntimeChecks.Streaming` private module if it improves cohesion (still `@moduledoc false`).
- Whether the soak-lane cleanup script lists assets by name pattern (`test-asset-*`) or by metadata tag (`{"meta": {"rindle_soak": "true"}}`) — the latter is more robust if the cassette and soak fixtures share the create payload.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Source of truth (locked recommendation)
- `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` — the locked recommendation memo. Section index for Phase 36: §2 MUX-15..19 (line 91-101); §11 CI proof and `mux-soak` lane discipline; §13 deferred items (second provider, direct creator upload, replay tooling, configurable redaction, persistent_term JOSE cache); §12 effort estimate (Phase 36: 1.5d MEDIUM; CI infra is the bulk).

### Phase scope and milestone constraints
- `.planning/ROADMAP.md` (lines 208-246) — Phase 36 goal, success criteria, v1.6 phase summary.
- `.planning/REQUIREMENTS.md` (lines 114-133) — MUX-15..19 phase-36 requirements.
- `.planning/PROJECT.md` — current milestone posture, adopter-first runtime ownership, security invariants 1-14 (invariant 14 directly applies to telemetry/log redaction in the new guide and the soak-lane cleanup logs).
- `.planning/STATE.md` — Decision-Making Preference (decide-by-default, escalate-only-impactful), and the v0.2.0 release-cut-at-milestone-close note.

### Prior phase contracts Phase 36 must consume verbatim
- `.planning/phases/33-provider-boundary-state-schema/33-CONTEXT.md` — Phase 33 capability vocabulary, `:streaming` DSL schema, `Rindle.Capability.report/0` shape.
- `.planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md` — D-01 (optional dep posture), D-09 (JOSE perf footgun for guide), D-29 (the five env-mapped config keys), D-31 (optional-dep guard pattern), D-33 (deferred missing-`:mux`-dep PASS/FAIL — Phase 36 ships it), D-34 (Mox + behaviour test pattern), D-37 (test signing private key fixture — Phase 36 adds the public half).
- `.planning/phases/35-signed-webhook-plug-idempotent-ingest/35-CONTEXT.md` — D-09 (global body reader install — guide Step 5), D-11 (multi-secret rotation `secret_index` telemetry — guide Step 8), D-39/D-40 (`mix rindle.runtime_status --provider-stuck` — guide Step 10), webhook plug `@moduledoc` snippet shape (guide Step 5 source-of-truth).
- `.planning/phases/33-provider-boundary-state-schema/33-VERIFICATION.md`, `34-mux-rest-adapter-server-push-sync/34-VERIFICATION.md`, `35-signed-webhook-plug-idempotent-ingest/35-VERIFICATION.md` — what each phase actually shipped (sanity-check the contracts Phase 36 references are the live shape).

### Existing code seams Phase 36 must extend / consume

#### MuxWeb preset
- `lib/rindle/profile/presets/web.ex` — the literal template (lines 18-43 the `__using__/1` macro, lines 38-43 the `variants/1` helper). MuxWeb mirrors this shape.
- `lib/rindle/profile/validator.ex` (Phase 33 `@streaming_schema`) — validates the `:streaming` block at compile time.
- `lib/rindle/profile.ex` — the `use Rindle.Profile, ...` macro entry point.

#### Doctor extension
- `lib/rindle/ops/runtime_checks.ex` (lines 33-251) — the canonical single-file pipeline; `run/2` at line 33; the `checks` list at lines 44-54 is the literal append point; `defp check_local_playback` at lines 220-251 is the "no relevant profiles → ok_result" precedent; `ok_result`/`error_result` helpers at the bottom of the file.
- `lib/mix/tasks/rindle.doctor.ex` (lines 1-50) — thin shell over `RuntimeChecks.run/2`; `OptionParser` strict-opts surface for the new `--streaming` flag.
- `lib/rindle/capability.ex` (lines 30-95) — `report/0` returns `streaming.configured_profiles` Phase 36 doctor consumes for profile-discovery gating.
- `lib/rindle/streaming/provider/mux.ex` (the optional-dep-guarded module) — the smoke-ping check calls into the real `Mux.Video.Assets.list/1` via this adapter.

#### Generated-app harness
- `test/install_smoke/support/generated_app_helper.ex` — `profile_enabled?/1` (line 14), `prove_package_install!/1` guard (line 19), `selected_profiles/0` env-var dispatch (lines 857-864), `lifecycle_test_source/2` head-clauses (lines 866 image, 905 video — Phase 36 adds 944 mux), `patch_test_config!/2` test-config patcher, `shared_env/1` env-var injector, MinIO setup pattern (lines 384-421).
- `test/install_smoke/generated_app_smoke_test.exs` — image/video test module template Phase 36 mirrors for `Mux`.
- `scripts/install_smoke.sh` — `case "$PROFILE" in all|image|video) ;;` validation at line 19; the literal one-line extension point.

#### CI workflow
- `.github/workflows/ci.yml` (lines 1-545):
  - lines 1-7: `on:` trigger declaration — extend `pull_request.types` with `labeled` (D-19).
  - lines 284-391: existing `package-consumer` job — append `mux-enabled` cassette step after line 376-377 (D-18).
  - lines 218-225 (the `needs:` propagation comment) — context for why `mux-soak` is a sibling job, not a step.
  - lines 393-545: existing `adopter` job — template for the new `mux-soak` job's structure (`needs:`, services, steps).
  - lines 491-545: doc-parity guard — extend the required-strings list (D-27).
  - lines 524-541: the literal `for REQUIRED in \\` list MuxWeb gets appended to.

#### Onboarding docs
- `README.md` (current AV quickstart section ~lines 101-120) — the existing canonical first-run story Phase 36 must NOT displace.
- `guides/getting_started.md` (Sections 1-10) — the existing AV-canonical narrative that stays byte-identical (D-28).
- `guides/secure_delivery.md` — the style template for `streaming_providers.md` (D-12).
- `guides/profiles.md` — preset documentation pattern.
- `guides/operations.md` — operator runbook pattern (D-10 Step 10 source).

### Mux references (verified per Phase 34/35 and external research)
- `https://www.mux.com/docs/core/listen-for-webhooks` — webhook event catalog (Phase 35 dispatch table).
- `https://www.mux.com/docs/guides/secure-video-playback` — signed playback flow (Phase 34 D-08 sign-call shape).
- `https://www.mux.com/docs/api-reference/video/assets` — `Mux.Video.Assets.list/1` (the smoke-ping target).
- `https://www.mux.com/docs/core/make-api-requests` — rate limits (1 RPS POST, 5 RPS GET/DELETE; D-23 budget verification).
- `https://www.mux.com/pricing` — free-tier policy (10 stored assets, 100K free delivery minutes; D-22 cleanup constraint, D-23 budget).
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/video/assets.ex` — `list/1` signature for the smoke ping.

### GitHub Actions references (external research Topic 1, 2026-verified)
- `https://docs.github.com/en/actions/using-jobs/using-conditions-to-control-job-execution` — job-level `if:` conditions.
- `https://github.com/orgs/community/discussions/26261` — canonical `contains(github.event.pull_request.labels.*.name, '...')` pattern.
- `https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/` — `pull_request` vs `pull_request_target` security boundary; fork PR secret-injection rules; the label-race-condition note (resolved by sticking to `pull_request`).
- `https://github.blog/changelog/2025-11-07-actions-pull_request_target-and-environment-branch-protections-changes/` — recent `pull_request_target` posture (NOT used by `mux-soak`).

### Local-tunnel references (external research Topic 3, 2026-verified)
- `https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/` — `cloudflared tunnel --url` quick tunnel docs (D-11 primary).
- `https://try.cloudflare.com/` — TryCloudflare landing.
- `https://ngrok.com/pricing` — current free-tier signup requirement (D-11 alternative caveat).
- `https://docs.stripe.com/webhooks` — Stripe's `stripe listen` recommendation (analog; not directly applicable but informs the "vendor CLI vs tunnel" framing in the guide).

### Test framework references
- `https://hexdocs.pm/mox/Mox.html` — Mox + behaviour pattern (Phase 34 D-34, reused for the cassette lane in D-16).
- `https://hexdocs.pm/oban/Oban.Testing.html` — `perform_job/2` (Phase 34 D-34 process-locality argument; not directly used by Phase 36 but informs the lifecycle-test shape).

### Prior milestone references (read-only, supports decisions)
- `.planning/milestones/v1.5-phases/29-package-consumer-proof/29-CONTEXT.md` — adopter-first runtime ownership posture; the `:image | :video` package-consumer pattern Phase 36 extends.
- `.planning/milestones/v1.4-phases/28-public-onboarding/28-CONTEXT.md` (if exists) — the AV-onboarding pattern Phase 36's MUX-19 must not displace.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `lib/rindle/profile/presets/web.ex` — **direct template for `MuxWeb`**: `__using__/1` macro shape (lines 18-31), `variants/1` helper (lines 38-43), passthrough opts (lines 22-30). Phase 36's `MuxWeb` calls `Web.variants/1` directly to inherit the variant set verbatim, then merges the streaming `:delivery` block.

- `lib/rindle/ops/runtime_checks.ex` — **direct template for the four new streaming checks**: pipeline shape (lines 33-78), `defp check_local_playback` for the "no relevant profiles → ok_result" pattern (lines 220-251), `ok_result`/`error_result` helpers, telemetry emission per check (line 65-72), check-id naming convention (`doctor.<id>`).

- `lib/mix/tasks/rindle.doctor.ex` — **direct template for the `--streaming` flag**: thin task shell (lines 33-50), `OptionParser` integration via `args` parsing, exit-code semantics, shell output formatting.

- `test/install_smoke/support/generated_app_helper.ex` — **direct template for the `:mux` profile mode**: `profile_enabled?/1` guard (line 14), `selected_profiles/0` env-var dispatch (lines 857-864), `lifecycle_test_source/2` head-clauses (lines 866 + 905), `patch_test_config!/2` test-config patcher (lines 342-382), `shared_env/1` env-var injector, MinIO staging pattern (lines 384-421) — the Mux fixture-value env vars follow the same shape.

- `test/install_smoke/generated_app_smoke_test.exs` — **direct template for `GeneratedAppSmokeMuxTest`**: `GeneratedAppSmokeImageTest` (lines 36-62) and `GeneratedAppSmokeVideoTest` define the test-module shape Phase 36's `MuxTest` mirrors. Each gated by `GeneratedAppHelper.profile_enabled?/1`.

- `scripts/install_smoke.sh` — **direct template for the `mux` case extension**: profile dispatch at lines 9 + 19; one-line extension to `case ... in all|image|video|mux) ;;`.

- `.github/workflows/ci.yml` — **direct templates**:
  - `package-consumer` job (lines 284-391) — `mux-enabled` cassette step extends here.
  - `adopter` job (lines 393-545) — structural template for the `mux-soak` job (services, `needs:`, steps).
  - doc-parity guard (lines 518-545) — required-strings list extension point.

- `lib/rindle/delivery/webhook_plug.ex` `@moduledoc` (Phase 35 D-43) — **canonical adopter-wiring snippet source for guide Step 5**. Guide must reference this verbatim; do not fork.

- `lib/rindle/workers/mux_sync_coordinator.ex` `@moduledoc` (Phase 34 D-22) — **canonical cron-snippet source for guide Step 6**.

- `test/fixtures/mux/test_signing_private_key.pem` (Phase 34 D-37) — already committed; Phase 36 generates and commits the public half (`test_signing_public_key.pem`) for the JWT-decode assertion in the `:mux` lifecycle test (D-15).

- `lib/rindle/capability.ex` `report/0` (Phase 33 D-30) — **the consumer surface** for Phase 36 doctor's profile-discovery gating (D-06). Returns `streaming.configured_profiles` Phase 36 reads to decide whether to run streaming checks at all.

### Established Patterns

- **Adopter-owned config posture:** Rindle ships modules + documented snippets; the adopter wires their `endpoint.ex`, `router.ex`, `config/runtime.exs`, and `Oban.Plugins.Cron`. Phase 36's guide is the canonical "how to wire it" surface; Rindle never auto-installs into adopter modules.

- **Optional-dep posture:** `:mux` and `:jose` are `optional: true` deps (Phase 34 D-01). Adopters who don't enable streaming pay zero transitive cost. The `MuxWeb` preset and the four doctor checks both honor this — the preset DSL stores only the provider-module atom; the doctor checks gate on profile discovery.

- **Single-source-of-truth for adopter snippets:** Webhook-plug wiring lives in the moduledoc; cron snippet lives in the moduledoc. The guide LINKS to / copies from these single sources. Two sources of truth fork on first signature change (D-13).

- **Single-file pipeline for runtime checks:** `Rindle.Ops.RuntimeChecks` is the one-pipeline-many-checks shape. New checks go in this file (D-05). No sibling modules per check family.

- **Profile-discovery gating for "kind"-specific checks:** existing `check_local_playback` (lines 220-251) is the precedent — when no profile of a kind is discovered, return `ok_result` with vacuous summary, NOT `error_result`. Phase 36 mirrors this for streaming.

- **`:image | :video` profile mode dispatch (v1.5):** `selected_profiles/0` env-var control, `profile_mode` discriminator, `lifecycle_test_source/2` head-clauses. Phase 36 extends to `:image | :video | :mux`.

- **Cassette mode default + secret-gated soak mode:** v1.2's protected-publish lane is the precedent (memo §1 #11). Phase 36's `mux-enabled` is unconditional cassette; `mux-soak` is label-gated real-API. Same pattern, different layer of the stack.

- **Doc-parity guard enforces canonical onboarding strings:** `.github/workflows/ci.yml:518-545` is the byte-level guard. Phase 36 ADDS to the required-strings list; never removes (D-28 invariant).

- **Telemetry / security invariant 14:** the `provider_asset_id` is the last-4-char tag in any new log/telemetry surface Phase 36 introduces (e.g., the soak-lane cleanup script's logs MUST redact). Reuse `MediaProviderAsset.redact_id/1`.

### Integration Points

- `Rindle.Profile.Presets.MuxWeb` → `use Rindle.Profile` → `Rindle.Profile.Validator` (Phase 33) → adopter compile-time validation. Compile path is unchanged; only the validator's `:streaming` schema is exercised.

- `mix rindle.doctor [--streaming] [profile_module ...]` → `Rindle.Ops.RuntimeChecks.run/2` → four new `defp check_streaming_*` clauses → emits the existing `[:rindle, :runtime, :check, :stop]` telemetry per check.

- `bash scripts/install_smoke.sh mux` → `RINDLE_INSTALL_SMOKE_PROFILE=mux` env var → `selected_profiles/0` returns `[:mux]` → `prove_package_install!(:mux)` → generates a Phoenix app with `MuxWeb` profile + Mox-on-`:http_client` config + fixture env vars → runs the `:mux` lifecycle test source against MinIO + cassette Mux fixtures → asserts (`["poster", "web_720p"]` ready + Mux-signed-HLS-URL JWT decodes).

- `mux-soak` job (CI) → label-gated `streaming` PR → `RINDLE_MUX_USE_REAL_API=1` → `patch_test_config!/2` omits the `:http_client` mock → real `Rindle.Streaming.Provider.Mux.HTTP` → `api.mux.com` → asset create + poll + delete → `if: always()` cleanup step → `scripts/mux_soak_cleanup.sh` → safety-net delete-all-test-assets.

- `guides/streaming_providers.md` → `mix.exs` `extras` list → published to HexDocs at hex publish time → reachable via `hexdocs.pm/rindle/streaming_providers.html`. Phase 21's HexDocs reachability probe (v1.3) verifies the URL after publish.

### Operational Boundaries Phase 36 Must Not Cross

- **No changes to the Phase 33 behaviour contract.** `Rindle.Streaming.Provider` callbacks unchanged; `Rindle.Streaming.Capabilities` vocabulary unchanged.

- **No changes to the Phase 34 Mux adapter surface.** `Rindle.Streaming.Provider.Mux` API unchanged; `MuxIngestVariant`, `MuxSyncCoordinator`, `MuxSyncProviderAsset` workers unchanged. Phase 36 only references them in docs and tests.

- **No changes to the Phase 35 webhook plug.** `WebhookPlug`, `WebhookBodyReader`, `IngestProviderWebhook` unchanged. Phase 36 documents them.

- **No `Rindle.Streaming.Provider.Mux.create_direct_upload/2` impl.** Reserved for Phase 37 / v1.7. Phase 36 must NOT add the create-direct-upload onboarding section to the new guide; only mention as "see Phase 37 / v0.3+" if at all.

- **No changes to `Rindle.Profile.Presets.Web`.** v1.5 image/AV adopters' onboarding stays byte-identical (D-28).

- **No new public modules outside `Rindle.Profile.Presets.MuxWeb`.** Internal helpers (e.g., the four `defp check_streaming_*` clauses inside `RuntimeChecks`) stay private; the `--streaming` task flag is the only new public CLI surface.

- **No new env vars beyond Phase 34's five `RINDLE_MUX_*` set + the CI-internal `RINDLE_MUX_USE_REAL_API`** (D-29, D-30). Adopters never see `RINDLE_MUX_USE_REAL_API`.

- **No README structural rewrite.** Subsection appended only (D-25..D-28).

</code_context>

<specifics>
## Specific Ideas

- **The single most important Phase 36 invariant: image and AV onboarding paths remain canonical.** REQUIREMENTS MUX-19 is explicit and the doc-parity guard at `.github/workflows/ci.yml:518-545` is the byte-level enforcement. Streaming is a *peripheral* opt-in; image and AV are the *first-run story*. The "(optional)" suffix in the new subsection heading and the placement-after-canonical-AV rule (D-25) are the locked invariants.

- **The `mux-soak` fork-secret boundary is the only security-critical decision in this phase.** External research Topic 1 confirmed that `pull_request` (NOT `pull_request_target`) + label-gating + secrets is the safe pattern: fork PRs labeled `streaming` will fire the lane but secrets resolve to empty strings → lane fails closed → no leak. The known label-race-condition (attacker pushes new code after labeling) does NOT apply here because we use `pull_request`, not `pull_request_target` — the lane runs against the PR head SHA in a forked-secret-free environment.

- **The Mux free-tier 10-stored-asset cap is the only operational cliff.** External research Topic 2 confirmed $0/PR cost AND $0/month at 50 PRs, but the 10-asset stored ceiling means a leaked test asset (lane crashes mid-run, asset never deleted) blocks the next PR. D-22's belt-and-suspenders cleanup (`try/after` Elixir + `if: always()` GitHub Actions step + `scripts/mux_soak_cleanup.sh` safety-net sweep) is mandatory.

- **The 2026 ngrok regression matters for adopter onboarding.** External research Topic 3 confirmed ngrok's free tier now requires signup + auth-token install before a single tunnel will start; cloudflared's TryCloudflare quick tunnel is signup-free. D-11 leads with cloudflared and demotes ngrok to alternative-with-caveat. This inverts the historical 2020-2023 default but matches 2026 reality. Don't let a stale "everyone uses ngrok" assumption sneak into the guide.

- **The `Rindle.Profile.Presets.MuxWeb` preset is the SECOND public preset in the library** (after `Web`). The naming pattern (`Rindle.Profile.Presets.<Name>`) is now load-bearing — `Rindle.Profile.Presets.GcsWeb` (v1.7) and `Rindle.Profile.Presets.CloudflareWeb` (v1.7+) are the implied future shape. Phase 36's preset shape sets the precedent; D-01..D-04 lock the wrap-`Web`-and-add-streaming pattern, which is the right shape for any future signed-playback provider preset.

- **The `--streaming` flag on `mix rindle.doctor` is the THIRD adopter-CLI flag** (after `--full` and `--raise` documented in the moduledoc). Adding it is uncontroversial; the failure-mode taxonomy (D-08) is the load-bearing detail. Wrong fix-recipes here are what generate "doctor passed in CI but Mux still 401s in prod" tickets.

- **The cassette-mode `:mux` lane is the canonical "Mux is enabled" smoke proof; the soak lane is the canonical "real Mux integration is healthy" smoke proof.** Both are required by REQUIREMENTS MUX-18. Splitting them across two CI jobs (D-18 step + D-19 separate job) is what makes the per-PR cost zero and the maintainer-ondemand verification cheap.

- **The new guide is the SECOND adopter-facing onboarding guide** (after `getting_started.md`). All other guides (`secure_delivery.md`, `profiles.md`, etc.) are reference / how-to. `streaming_providers.md` is end-to-end onboarding, modeled on `getting_started.md`'s tone. D-09..D-13 lock the section ordering and source-of-truth posture.

- **The v0.2.0 hex release cuts at v1.6 close** (per `STATE.md` and `memory/project_v0_2_0_release_plan.md`). Phase 36's CHANGELOG entry (D-33) feeds the release-please auto-bump; the new guide ships in the v0.2.0 HexDocs publish; Phase 21's HexDocs reachability probe (v1.3) verifies the URL post-publish. Don't ship Phase 36 without verifying the new `extras` entry in `mix.exs` builds the doc.

</specifics>

<deferred>
## Deferred Ideas

- **`Rindle.Streaming.Provider.Mux.create_direct_upload/2` adopter onboarding section** — Phase 37 / v0.3+. Phase 36's guide must NOT include direct-creator-upload narrative; the behaviour callback exists from Phase 33 with `@optional_callbacks`, the v1.6 Mux adapter doesn't implement it, and the LiveView `:provider_asset_created` PubSub event is reserved for Phase 37 (Phase 35 D-33 broadcasts the other three but explicitly NOT this one).

- **Second-streaming-provider scaffolding in `streaming_providers.md`** — v1.7+ (Cloudflare Stream / Bunny Stream / Cloudinary Video). The candidate memo §1 #2 + §13 lock single-provider scope for v1.6; multi-provider docs land with the second adapter, not before.

- **`JOSE.JWK.from_pem/1` `:persistent_term` cache for high-throughput JWT signing** — v1.7+. Phase 34 D-09 deferred the implementation; Phase 36 documents the optimization in the new guide's Section 11 ("Performance note") for adopters above ~1k playback URLs/sec, so they can patch their own cache if needed before v1.7 ships.

- **Multi-provider doctor checks** — v1.7+. Phase 36's four new checks (D-05) are Mux-specific in their fix-recipes ("Verify RINDLE_MUX_TOKEN_ID..."); v1.7's second provider triggers a refactor to per-provider check namespacing. Acceptable v1.6 debt — single-provider scope makes per-provider namespacing premature.

- **Automated Mux-dashboard signing-key creation via API** — v1.7+ if real adopter demand surfaces. Phase 36's guide Step 3 instructs out-of-band creation via Mux dashboard. Mux's API does support programmatic signing-key creation (`POST /system/v1/signing-keys`), but auto-creating from `mix rindle.setup` (which doesn't exist) would require a brand-new task. Out of scope.

- **`mix rindle.webhook.replay` event-replay tooling** — v1.7+ per memo §13. Phase 36's guide Step 10 (operator runbook) covers `mix rindle.runtime_status --provider-stuck` (the v1.5+Phase 35 surface) as the recovery path; replay tooling is a separate phase.

- **Configurable telemetry redaction posture** — v1.7+ per memo §13. v1.6 hardcodes last-4-char `provider_asset_id` redaction; the new guide documents this invariant (security invariant 14) but does NOT promise configurability.

- **Cancellation surface for in-flight provider ingest (`Rindle.cancel_provider_ingest/1`)** — v1.7+ per memo §13. Oban's `cancel_jobs/1` is the v1.6 workaround; the new guide's Step 10 mentions this as "use `Oban.cancel_jobs/1` for in-flight cancellation; a higher-level API ships in v0.3+."

- **DASH playback kind support in MuxWeb / guide** — v1.7+. v1.6 ships `:hls` only (Phase 34 D-08 sign-call returns `kind: :hls`). The guide's Step 4 / 5 examples reference `<video>` tag with HLS; DASH coverage waits on the SDK's DASH support shape.

- **Per-adopter cost estimator in `mix rindle.doctor --streaming`** — v1.7+ if adopters request it. Mux's pricing is per-stored-minute + per-delivery-minute; surfacing a cost estimate from the doctor would require crawling `media_provider_assets` rows. Out of scope.

- **`mix rindle.streaming.test_webhook` synthetic-event task** — v1.7+ if adopters request it. Phase 36's guide Step 7 (local cloudflared tunnel) is the recommended dev-time webhook validation; a built-in synthetic event task would be nice but isn't in scope.

- **Multi-tunnel guidance in the local-dev section** (e.g., separate sections for cloudflared, ngrok, tailscale funnel, smee.io) — out of scope. D-11 limits the section to 5-10 lines with cloudflared primary + ngrok alternative-with-caveat. Adopters using exotic tunnels know what they're doing.

- **Reviewed Todos (not folded):** none — `gsd-sdk query todo.match-phase 36` returned `todo_count: 0`.

</deferred>

---

*Phase: 36-public-dx-onboarding-ci-proof*
*Context gathered: 2026-05-07*
*Source of truth: `.planning/research/v1.6-CANDIDATE-PROVIDER-MUX.md` + Phase 33/34/35 CONTEXT.md files + this CONTEXT.md (the latter supersedes at any drift between memo and verified shipped contracts).*
</content>
</invoke>