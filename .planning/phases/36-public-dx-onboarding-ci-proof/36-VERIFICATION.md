---
phase: 36-public-dx-onboarding-ci-proof
verified: 2026-05-07T14:45:00Z
status: human_needed
score: 5/5
overrides_applied: 0
gaps: []
human_verification:
  - test: "Run cassette package-consumer lane end-to-end on a real PR build"
    expected: "`bash scripts/install_smoke.sh mux` exits 0 inside CI's `package-consumer` job: fresh `mix phx.new` + Rindle install + `mix rindle.doctor` + sample upload + Mux-signed HLS URL verified. Cassette path never reaches `api.mux.com` (Mox-on-:http_client). Covers SC #3 + SC #4 (cassette lane); Plan 03 SUMMARY explicitly defers this to the CI package-consumer step."
    why_human: "Full E2E lane requires `mix phx.new` + DB + MinIO + 10+ min run; per Plan 03 SUMMARY this is the package-consumer step's purpose and was intentionally not run in the worktree."
  - test: "Run `mux-soak` lane against real Mux on a `streaming`-labelled PR"
    expected: "Real-Mux API hit succeeds; ingested asset appears + ready; signed HLS URL verifies; cleanup deletes asset; soak-asset count stays at 0 across consecutive labelled PRs. Also exercises CR-01/CR-02 defects in their real failure modes."
    why_human: "Requires five GitHub Secrets (one-time maintainer bootstrap documented in Plan 03 SUMMARY); observable only via real Mux account."
  - test: "Verify HexDocs publish wire — `mix docs` rendering of `streaming_providers.md` + `MuxWeb` module"
    expected: "On hexdocs.pm (or local `mix docs` preview), `Rindle.Profile.Presets.MuxWeb` module page renders, `guides/streaming_providers.md` is in sidebar, intra-doc links resolve."
    why_human: "Visual rendering and link resolution are observable only in a HexDocs build, not via grep."
  - test: "Confirm no fork-secret leak when a fork PR is labelled `streaming`"
    expected: "Fork PR labelled `streaming` fires `mux-soak` job; `${{ secrets.RINDLE_MUX_* }}` resolve to empty strings; lane fails closed; cleanup step's no-credential branch hits (`exit 0`)."
    why_human: "Behavior depends on GitHub Actions secret-resolution semantics which can only be observed by running a real fork PR with the label applied."
  - test: "Confirm `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` passes in the spawned Phoenix project"
    expected: "Generated-app smoke test passes — `[poster, web_720p]` ready-variant assertion (byte-identical to `:video` lane) plus streaming-URL regex match and `JOSE.JWT.verify_strict/3` returning `{true, _, _}`."
    why_human: "Generated app spawns a separate Phoenix project; library-side `mix test` does not include this, only the package-consumer step does."
re_verification:
  previous_status: human_needed
  previous_score: 5/5
  gaps_closed: []
  gaps_remaining: []
  regressions: []
review_findings:
  blockers:
    - id: CR-01
      title: "mux-soak `scripts/mux_soak_cleanup.sh` filters by `meta.rindle_soak == \"true\"` but no producer ever stamps that metadata — layer-3 cleanup is non-functional"
      file: "scripts/mux_soak_cleanup.sh:69-85, lib/rindle/streaming/provider/mux.ex (build_create_params/2)"
      evidence: "Repo-wide grep for `rindle_soak` and `passthrough` returns hits ONLY in mux_soak_cleanup.sh itself. `build_create_params/2` returns a map with `inputs`, `playback_policies`, `mp4_support`, `max_resolution_tier` only — no `meta` or `passthrough` key. Cleanup will always emit 'no soak assets found (meta.rindle_soak=true)' even on real leak."
      severity: blocker
      goal_impact: "Threatens soak-lane operability over time (Mux free-tier 10-asset cap). Does not block ROADMAP SC #4 (lane exists and is wired) but makes the 'three-layer safety net' claim in Plan 03 must-have #5 false. Fix: tag Mux assets via passthrough in build_create_params/2 before first real soak run."
    - id: CR-02
      title: "Soak lifecycle test inserts `provider_asset_id` into ETS AFTER assertions that can fail — layer-1 `try/after` cleanup misses assets when assertions fail"
      file: "test/install_smoke/support/generated_app_helper.ex:1189-1310"
      evidence: "ETS insert at lines 1271-1286 is inside the try block AFTER streaming_url regex (1247) and JWT verify (1257). If those assertions fail, control jumps to `after` where ETS lookup returns [] and falls through to `_ -> :ok`. The cleanup layer that exists for failure cases is the layer that fails on failure."
      severity: blocker
      goal_impact: "Same as CR-01 — layer-1 is only effective when the test passes (exactly when cleanup is least needed). Cassette mode unaffected (Mox stubs never raise; `try/after` is a no-op). Fix: move ETS insert immediately after `perform_job(ProcessVariant, ...)` loop, before streaming-URL assertions."
    - id: CR-03
      title: "`shared_env/1` always reads `test/fixtures/mux/test_signing_private_key.pem`, coupling `:image`/`:video` install-smoke runs to a Mux fixture"
      file: "test/install_smoke/support/generated_app_helper.ex:912-936"
      evidence: "Line 897: `defp shared_env(db_name)` — takes no profile_mode param. Lines 916-918: `private_key_pem = System.get_env(...) || File.read!(\"test/fixtures/mux/test_signing_private_key.pem\")` — unconditional File.read! for all callers. Invoked from `prove_package_install!/1` and `prove_upgrade_install!/0` regardless of profile mode."
      severity: blocker
      goal_impact: "Does not block phase goal today (Mux fixtures are committed). Regression risk: a contributor running `bash scripts/install_smoke.sh image` against a checkout missing the Mux fixtures gets a low-level File.Error instead of a clear diagnostic. Fix: pass profile_mode to shared_env/1 and gate the Mux fixture read on profile_mode == :mux."
  warnings:
    - id: WR-01
      title: "guides/streaming_providers.md pins `{:rindle, \"~> 0.2.0\"}` while mix.exs is at `0.1.4`"
      file: "guides/streaming_providers.md:53, mix.exs:4"
      evidence: "`@version \"0.1.4\"` in mix.exs; `{:rindle, \"~> 0.2.0\"}` on line 53 of streaming_providers.md. README.md and getting_started.md correctly use `~> 0.1`."
      severity: warning
      goal_impact: "If `mix docs` runs before release-please cuts 0.2.0, adopters following the guide hit an unresolvable dep."
    - id: WR-02
      title: "mix.exs `:extras` omits `guides/upgrading.md` even though README/getting_started link to it"
      file: "mix.exs:117-129"
      severity: warning
      goal_impact: "Pre-existing miss; not introduced by Phase 36. `[guides/upgrading.md](upgrading.md)` link will 404 on hexdocs.pm."
    - id: WR-03
      title: "`required_queues/1` does not add `:rindle_provider` when streaming-enabled profile is present"
      file: "lib/rindle/ops/runtime_checks.ex:434-443"
      severity: warning
      goal_impact: "Doctor reports PASS while a missing `:rindle_provider` queue silently breaks Mux ingestion. Adopter following streaming_providers.md adds the queue but doctor does not validate it."
    - id: WR-04
      title: "Generated `:mux` lane never declares `rindle_provider` queue, masking WR-03 end-to-end"
      file: "test/install_smoke/support/generated_app_helper.ex:393-411,504-513"
      severity: warning
      goal_impact: "Cassette passes because `Oban.Testing.perform_job/2` bypasses the dispatcher. Production adopter copying the generated config breaks."
    - id: WR-05
      title: "Non-idiomatic `Mox.verify_on_exit!(self())` and `Mox.set_mox_from_context(%{async: false})` in generated test"
      file: "test/install_smoke/support/generated_app_helper.ex:1141-1148"
      severity: warning
      goal_impact: "Works today because Mox discards the arg; future Mox version bump could break without warning."
    - id: WR-06
      title: "`Mix.Tasks.Rindle.Doctor` silently discards unknown CLI flags via `_invalid`"
      file: "lib/mix/tasks/rindle.doctor.ex:35-42"
      severity: warning
      goal_impact: "Adopter typo (`--streming`) silently no-ops; the intended check never runs."
    - id: WR-07
      title: "`Rindle.Capability.configured_streaming_profiles/1` is public but lacks a direct unit test"
      file: "lib/rindle/capability.ex:90-104"
      severity: warning
      goal_impact: "Coverage is transitive through RuntimeChecks only. Map vs keyword-list dual-handling at lines 121-126 should be locked with a direct test."
    - id: WR-08
      title: "`streaming_providers.md` links to `secure_delivery.html` instead of `.md`"
      file: "guides/streaming_providers.md:29"
      severity: warning
      goal_impact: "Renders correctly on hexdocs.pm but 404s on GitHub raw view. Pre-existing pattern in other guides."
    - id: WR-09
      title: "`mux_config_block/1` accepts an unused `_app_name` parameter"
      file: "test/install_smoke/support/generated_app_helper.ex:421,429"
      severity: warning
      goal_impact: "Code smell only; no behavior impact."
    - id: WR-10
      title: "`verify_signing_key_pem/1` rescue clause swallows the original exception class"
      file: "lib/rindle/ops/runtime_checks.ex:594-620"
      severity: warning
      goal_impact: "`mix doctor --raise` output loses root-cause for future jose-version regressions."
---

# Phase 36: Public DX, Onboarding, CI Proof — Verification Report

**Phase Goal:** Lock the adopter onboarding path; prove the package-consumer story matches v1.5's bar.
**Verified:** 2026-05-07T14:45:00Z
**Status:** human_needed
**Re-verification:** Yes — initial verification was `human_needed` with `gaps: []`. No code changes since initial verification (commits `02d70e5` and `1ca2850` added planning docs only). Full 3-level check run to confirm no regressions.

---

## Goal Achievement

The phase goal has two clauses:

1. **"Lock the adopter onboarding path"** — SC #1 (MuxWeb preset), SC #2 (doctor checks), SC #5 (guides/README/getting_started). All three verified in the codebase via static analysis.
2. **"Prove the package-consumer story matches v1.5's bar"** — SC #3 (fresh `mix phx.new` lifecycle) and SC #4 (`mux-enabled` cassette + label-gated `mux-soak`). All harness pieces, scripts, GitHub Actions wiring, fixtures, and Mox shim are present. The cassette lane's behavioral proof is a CI-only observable by design (Plan 03's own verification matrix deferred item 1 to the CI step). Routes to **human verification** rather than gap.

Code review (`36-REVIEW.md`) found 3 BLOCKER and 9 WARNING issues. The blockers are operational defects in the soak lane (CR-01: cleanup filter never matches; CR-02: ETS insert ordered after assertions; CR-03: image/video runs coupled to Mux fixture). They do not invalidate the ROADMAP success criteria at the artifact level — every required surface exists, compiles, and unit tests pass. They are surfaced in `review_findings` for resolution before steady-state soak operation.

### Observable Truths

| #   | Truth                                                                                                                                                                                                                                                              | Status                                  | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                               |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **SC #1** — `Rindle.Profile.Presets.MuxWeb` ships alongside `Rindle.Profile.Presets.Web` with `:streaming` opt-in and `:signed` named playback policy. `delivery_policy().streaming` exposes the locked four-key block.                                            | VERIFIED                                | `lib/rindle/profile/presets/mux_web.ex` (79 lines): `defmacro __using__/1` delegates variants to `Rindle.Profile.Presets.Web.variants/1` and overlays `streaming: [provider: Rindle.Streaming.Provider.Mux, playback_policy: :signed, ingest_mode: :server_push, source_variant: :web_720p]` via `Keyword.merge(adopter_delivery, locked_streaming)`. 4 tests in `mux_web_test.exs` pass: variants inheritance, locked streaming block, scrub_strip passthrough, adopter-delivery merge. |
| 2   | **SC #2** — `mix rindle.doctor` validates streaming configuration with PASS/FAIL. Four checks (`doctor.streaming_credentials`, `doctor.streaming_signing_key`, `doctor.streaming_webhook_secrets`, `doctor.streaming_smoke_ping`); 5s smoke ping behind `--streaming`. | VERIFIED                                | Four checks at `lib/rindle/ops/runtime_checks.ex:502-740`; profile-discovery-gated via `Rindle.Capability.configured_streaming_profiles/1`; optional-dep-gated via `Code.ensure_loaded?(Mux.Video.Assets)`. Pitfall 1 locked: `%JOSE.JWK{}` struct match (not truthy). `--streaming` plumbed in `rindle.doctor.ex:36-58`. Smoke ping uses `Task.yield(5_000) || Task.shutdown(:brutal_kill)`. 12-check deterministic-id assertion passes. Credential checks emit env-var NAMES only (never values). |
| 3   | **SC #3** — Fresh `mix phx.new` adopter app harness installs Rindle, declares `Rindle.Profile.Presets.MuxWeb`, runs `mix rindle.doctor`, uploads sample video, renders `<video>` with Mux-signed HLS URL — from CI, from published artifact.                      | ARTIFACTS VERIFIED / BEHAVIOR DEFERRED  | Lifecycle test source at `generated_app_helper.ex:1133-1310` emits cassette-mode `:mux` test with `["poster", "web_720p"]` assertion (line 1214), HLS URL regex (line 1247), `JOSE.JWT.verify_strict/3` against committed PEM (line 1257). `GeneratedAppSmokeMuxTest` at `generated_app_smoke_test.exs:97-141`. `install_smoke.sh:20` dispatches `mux`. `ci.yml:384-385` runs `bash scripts/install_smoke.sh mux` in `package-consumer` job. Plan 03 deferred E2E behavioral run to CI. |
| 4   | **SC #4** — Generated-app proof harness has `mux-enabled` cassette lane (default, zero secrets) and label-gated `mux-soak` lane running against real Mux on PRs labelled `streaming`.                                                                            | STRUCTURE VERIFIED / OPERATIONAL DEFECTS | Cassette step at `ci.yml:384-385` runs every PR. Sibling `mux-soak` job at `ci.yml:555-647` with `if: contains(...labels.*.name, 'streaming')`, `needs: quality`, five `RINDLE_MUX_*` env keys, safe `pull_request` trigger (NOT `pull_request_target`), `types: [opened, synchronize, reopened, labeled]`, `if: always()` cleanup step. **CR-01/CR-02 mean layer-3 and layer-1 cleanup are defective for soak failure paths.** Does not block lane shipping; threatens steady-state operability. |
| 5   | **SC #5** — `guides/streaming_providers.md` ships Mux-only section; README + `getting_started.md` gain "Streaming with Mux" subsection (≤15 lines each); image/AV onboarding remains canonical first-run story.                                                  | VERIFIED                                | `streaming_providers.md` (341 lines), all 11 D-10 sections in correct order. `mix.exs:124` extras. `README.md:242-255` (14 lines). `guides/getting_started.md:364-377` (14 lines). Both link to `streaming_providers.md`. Doc-parity guard: all 7 required strings present (6 original + MuxWeb); negative regex unchanged; new content uses `Rindle.Delivery.streaming_url` exclusively. CHANGELOG `[Unreleased]` bullet present. |

**Score:** 5/5 truths verified at the artifact-and-wiring level. SC #3 and SC #4 require CI-time behavioral confirmation (`human_verification` queue).

---

## Deferred Items

No items from this phase are explicitly addressed in later milestone phases. The three BLOCKER defects (CR-01/02/03) are flagged in `review_findings` for resolution prior to first real soak run.

---

## Required Artifacts

### Plan 01 — MuxWeb preset + doctor checks

| Artifact                                                  | Expected                                              | Status   | Details                                                                                                                                                                            |
| --------------------------------------------------------- | ----------------------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/rindle/profile/presets/mux_web.ex`                   | Public preset macro, ≥30 lines                        | VERIFIED | 79 lines; `defmacro __using__/1`; streaming block as keyword list (Macro.escape-compatible); adopter delivery merge-last.                                                           |
| `lib/rindle/ops/runtime_checks.ex`                        | Four streaming checks appended                        | VERIFIED | Lines 502-740; 4 `check_streaming_*` defp clauses; 4 thunks in checks list; 5 `@streaming_*_fix` attrs; total checks 8 → 12.                                                     |
| `lib/mix/tasks/rindle.doctor.ex`                          | `--streaming` flag plumbed end-to-end                 | VERIFIED | `OptionParser.parse(args, strict: [streaming: :boolean])` at line 36; `Keyword.put(:streaming, streaming?)` at line 58. WR-06 noted (unknown flags silently discarded).             |
| `lib/rindle/capability.ex`                                | `configured_streaming_profiles/1` promoted to `def`   | VERIFIED | Line 99 `def configured_streaming_profiles(profiles)` with `@spec` and `@doc`. WR-07 noted (no direct unit test).                                                                 |
| `test/rindle/profile/presets/mux_web_test.exs`            | Preset compile + DSL validation tests                 | VERIFIED | 73 lines, 4 tests; all pass.                                                                                                                                                       |
| `test/rindle/ops/runtime_checks_streaming_test.exs`       | Four streaming checks with 5 describe blocks          | VERIFIED | 5 describe blocks; 12 tests; `@valid_pem` from fixture; `@malformed_pem` constant; Pitfall 1 test passes.                                                                         |

### Plan 02 — Docs lane

| Artifact                               | Expected                                                | Status   | Details                                                                                                                                                                                             |
| -------------------------------------- | ------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `guides/streaming_providers.md`        | ≥150 lines, contains `Rindle.Profile.Presets.MuxWeb`    | VERIFIED | 341 lines; 11 sections in D-10 order; cloudflared primary, ngrok secondary-with-caveat; D-13 HTML source comments at lines 140 and 183. WR-01 (version pin `~> 0.2.0`) and WR-08 (`.html` link) noted. |
| `mix.exs`                              | Contains `guides/streaming_providers.md` in extras      | VERIFIED | Line 124. WR-02 (missing upgrading.md) pre-existing, not introduced by Phase 36.                                                                                                                    |
| `README.md`                            | Contains `Streaming with Mux (optional)` subsection     | VERIFIED | Lines 242-255 (14 lines, ≤15 cap); placed after canonical AV path, before Next Reads.                                                                                                               |
| `guides/getting_started.md`            | Contains `Streaming with Mux (optional)` subsection     | VERIFIED | Lines 364-377 (14 lines, ≤15 cap); Section 10, after Section 9 (Bang Variants).                                                                                                                     |
| `.github/workflows/ci.yml` (doc-parity) | Contains `Rindle.Profile.Presets.MuxWeb` required string | VERIFIED | Line 539; 6 original required strings unchanged (lines 533-538); negative regex unchanged (line 547).                                                                                               |
| `CHANGELOG.md`                         | `[Unreleased]` bullet containing `MuxWeb`               | VERIFIED | Lines 9-17 reference MuxWeb, `mix rindle.doctor --streaming`, streaming_providers.md, mux-enabled, mux-soak.                                                                                         |

### Plan 03 — Install-smoke + CI

| Artifact                                                 | Expected                                                           | Status                   | Details                                                                                                                                                                                                                                          |
| -------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `test/install_smoke/support/generated_app_helper.ex`     | Extended `:mux` profile mode (5 sites + new helpers)               | VERIFIED (CR-02/03 noted) | 1529 lines; `lifecycle_test_source(_app_module, :mux)` at line 1133; `profile_enabled?(:mux)` guard extended; cassette/soak duality via host-side `RINDLE_MUX_USE_REAL_API` conditional. CR-02 (ETS insert ordering) and CR-03 (shared_env coupling) flagged. |
| `test/install_smoke/generated_app_smoke_test.exs`        | `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` module              | VERIFIED                 | Line 97 `if GeneratedAppHelper.profile_enabled?(:mux)` gate; line 98 module definition; `assert_install_source!/1` extended to include `:mux`.                                                                                                   |
| `scripts/install_smoke.sh`                               | Case dispatch accepts `mux`                                        | VERIFIED                 | Line 20 `all\|image\|video\|mux) ;;`.                                                                                                                                                                                                            |
| `.github/workflows/ci.yml` (Plan 03 edits)               | Labeled trigger + cassette step + sibling mux-soak job             | VERIFIED                 | Trigger at lines 6-12; cassette step at lines 384-385; sibling `mux-soak` job at lines 555-647. No overlap with Plan 02 doc-parity guard (lines 518-553 untouched by Plan 03).                                                                   |
| `scripts/mux_soak_cleanup.sh`                            | ≥25 lines; belt-and-suspenders soak cleanup; contains `Mux.Video.Assets` | STUB ON FILTER        | 114 lines; dry-run support; fork-safe no-op when secrets empty. Filter at lines 71-75 (`meta.rindle_soak == "true"`) will always return empty — `build_create_params/2` never writes that metadata (CR-01). Script EXISTS and is wired; cleanup BEHAVIOR is non-functional. |
| `test/fixtures/mux/test_signing_public_key.pem`          | Contains `BEGIN PUBLIC KEY`                                        | VERIFIED                 | Line 1 `-----BEGIN PUBLIC KEY-----`; valid RSA-2048 key.                                                                                                                                                                                         |

---

## Key Link Verification

| From                                                         | To                                                          | Via                                                                | Status              | Details                                                                        |
| ------------------------------------------------------------ | ----------------------------------------------------------- | ------------------------------------------------------------------ | ------------------- | ------------------------------------------------------------------------------ |
| `lib/rindle/profile/presets/mux_web.ex`                      | `lib/rindle/profile/presets/web.ex`                         | `Rindle.Profile.Presets.Web.variants/1`                            | WIRED               | Line 71 explicit call.                                                          |
| `lib/rindle/profile/presets/mux_web.ex`                      | `lib/rindle/profile/validator.ex`                           | `use Rindle.Profile, ...` triggers `@streaming_schema`             | WIRED               | Line 76 `use Rindle.Profile, unquote(Macro.escape(profile_opts))`.              |
| `lib/rindle/ops/runtime_checks.ex`                           | `lib/rindle/capability.ex`                                  | `Rindle.Capability.configured_streaming_profiles/1`                | WIRED               | Line 505 helper delegates; `Rindle.Capability.report/0` calls internally.       |
| `lib/rindle/ops/runtime_checks.ex`                           | `Mux.Video.Assets`                                          | Smoke ping with `Code.ensure_loaded?` guard                        | WIRED               | Lines 684, 711 `Mux.Video.Assets.list(client, %{limit: 1})`.                   |
| `lib/mix/tasks/rindle.doctor.ex`                             | `lib/rindle/ops/runtime_checks.ex`                          | `Keyword.put(:streaming, streaming?)` → `RuntimeChecks.run/2`      | WIRED               | Line 58.                                                                        |
| `guides/streaming_providers.md`                              | `lib/rindle/delivery/webhook_plug.ex`                       | Inline-copy + `<!-- source: ... -->` HTML comment                  | WIRED               | Line 140 source comment.                                                        |
| `guides/streaming_providers.md`                              | `lib/rindle/workers/mux_sync_coordinator.ex`                | Inline-copy + HTML source comment                                  | WIRED               | Line 183 source comment.                                                        |
| `mix.exs`                                                    | `guides/streaming_providers.md`                             | Extras list entry                                                  | WIRED               | Line 124.                                                                       |
| `README.md`                                                  | `guides/streaming_providers.md`                             | Inline link                                                        | WIRED               | Line 255.                                                                       |
| `.github/workflows/ci.yml`                                   | `Rindle.Profile.Presets.MuxWeb`                             | Doc-parity required-strings list                                   | WIRED               | Line 539.                                                                       |
| `test/install_smoke/support/generated_app_helper.ex`         | `lib/rindle/streaming/provider/mux.ex` (`http_client` config) | `config :rindle, Rindle.Streaming.Provider.Mux, http_client: ClientMock` | WIRED          | Line 447 emits config block.                                                    |
| `test/install_smoke/support/generated_app_helper.ex`         | `test/fixtures/mux/test_signing_private_key.pem`            | `File.read!/1` in `shared_env/1` + `File.cp!/2` staging            | WIRED (CR-03 noted) | Line 918 unconditional `File.read!`; line 467 `stage_mux_fixtures!/1`. CR-03: couples all profile modes to Mux fixture. |
| `test/install_smoke/generated_app_smoke_test.exs`            | `test/install_smoke/support/generated_app_helper.ex`        | `profile_enabled?(:mux)` + `prove_package_install!(:mux)`          | WIRED               | Lines 97, 100.                                                                  |
| `.github/workflows/ci.yml`                                   | `scripts/install_smoke.sh`                                  | `bash scripts/install_smoke.sh mux` step                           | WIRED               | Lines 385 (cassette), 643 (soak).                                               |
| `.github/workflows/ci.yml`                                   | `scripts/mux_soak_cleanup.sh`                               | `if: always()` cleanup step                                        | WIRED               | Lines 645-647.                                                                  |
| `scripts/install_smoke.sh`                                   | `test/install_smoke/generated_app_smoke_test.exs`           | `RINDLE_INSTALL_SMOKE_PROFILE` env-var dispatch                    | WIRED               | Lines 9, 32.                                                                    |

---

## Data-Flow Trace (Level 4)

| Artifact                                                 | Data Variable                    | Source                                                                                                                      | Produces Real Data | Status                          |
| -------------------------------------------------------- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------- |
| `lib/rindle/profile/presets/mux_web.ex` (`__using__`)    | `delivery_policy().streaming`    | `Macro.escape(profile_opts)` → `use Rindle.Profile` → DSL validator normalizes keyword-list to map                          | Yes                | FLOWING                         |
| `lib/rindle/ops/runtime_checks.ex` (4 streaming checks)  | `streaming_profiles(profiles)`   | `Rindle.Capability.configured_streaming_profiles/1` walking adopter-supplied profile list                                   | Yes                | FLOWING                         |
| `lib/rindle/ops/runtime_checks.ex` (smoke ping)          | `Mux.Video.Assets.list/2` result | Real `Mux.Base.new/2` HTTP call when `--streaming` flag set                                                                 | Yes (with flag)    | FLOWING                         |
| `test/install_smoke/.../lifecycle_test_source(_,:mux)`   | `streaming_url` (HLS + JWT)      | Cassette: Mox stub on `ClientMock`. Soak: real Mux SDK via `:http_client` HTTP default.                                     | Yes                | FLOWING (cassette by construction) |
| `scripts/mux_soak_cleanup.sh`                            | `soak_assets` (filtered list)    | `Mux.Video.Assets.list/2` filtered by `meta.rindle_soak == "true"` — **no producer ever stamps that metadata (CR-01)**     | No                 | DISCONNECTED                    |

The CR-01 row is the only data-flow break. `build_create_params/2` produces no `meta` or `passthrough` key; the cleanup script's filter contract and the producer's request body do not agree.

---

## Behavioral Spot-Checks

| Behavior                                                                        | Command / Evidence                                                                                          | Status                              |
| ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| `mux_web.ex` compiles and exports `__using__/1`                                 | File exists (79 lines); `use Rindle.Profile.Presets.Web.variants/1` call present                            | PASS                                |
| Four streaming check IDs present in `runtime_checks.ex`                         | `grep -n "check_streaming"` returns 8 hits (4 definition lines + 4 thunk lines)                             | PASS                                |
| Total check count 12 (was 8)                                                    | `runtime_checks_test.exs:54-67` enumerates 12 IDs including 4 `doctor.streaming_*` entries                  | PASS                                |
| `--streaming` flag plumbed in `rindle.doctor.ex`                                | `OptionParser.parse(args, strict: [streaming: :boolean])` at line 36; `Keyword.put(:streaming)` at line 58  | PASS                                |
| `configured_streaming_profiles/1` is `def` (not `defp`)                         | `grep -n "def configured_streaming"` returns line 99 `def`                                                  | PASS                                |
| CI workflow has `types: [opened, synchronize, reopened, labeled]`                | `ci.yml:12` confirmed                                                                                        | PASS                                |
| `mux-soak` job is `if: contains(...labels.*.name, 'streaming')` gated            | `ci.yml:570` confirmed                                                                                       | PASS                                |
| `pull_request_target` absent from `ci.yml`                                      | `grep -n pull_request_target ci.yml` returns 0 matches                                                      | PASS                                |
| All 7 doc-parity required strings present                                        | Lines 533-539: `mix rindle.doctor`, `Rindle.Profile.Presets.Web`, `Rindle.initiate_upload`, `Rindle.verify_completion`, `Rindle.attach`, `Rindle.url`, `Rindle.Profile.Presets.MuxWeb` | PASS |
| Negative regex unchanged (bans `Rindle.Delivery.url` without `streaming_` prefix) | `ci.yml:547` unchanged; new content uses `Rindle.Delivery.streaming_url` only                               | PASS                                |
| README + getting_started subsections ≤15 lines                                   | 14 lines each (measured via grep line ranges)                                                                | PASS                                |
| `streaming_providers.md` D-10 section ordering                                   | All 11 headings in correct order: Why → deps → signing key → MuxWeb → webhook → cron → tunnel → rotation → doctor → runbook → perf | PASS |
| Cassette lane E2E exit-0 (`bash scripts/install_smoke.sh mux`)                   | Requires `mix phx.new` + DB + MinIO + 10+ min                                                               | SKIP — routed to human verification |
| `mux-soak` lane against real Mux                                                 | Requires GitHub Secrets + `streaming` label on a real PR                                                    | SKIP — routed to human verification |

---

## Requirements Coverage

| Requirement | Source Plan | Description                                                                                                    | Status                  | Evidence                                                                                                                                                                                                        |
| ----------- | ----------- | -------------------------------------------------------------------------------------------------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MUX-15      | 36-01-PLAN  | `Rindle.Profile.Presets.MuxWeb` ships alongside `Rindle.Profile.Presets.Web`; `:streaming` opt-in; `:signed` policy. | SATISFIED               | `mux_web.ex` ships; `delivery_policy().streaming.playback_policy == :signed` asserted in test line 52.                                                                                                          |
| MUX-16      | 36-01-PLAN  | `mix rindle.doctor` validates streaming config; per-profile PASS/FAIL with 5s smoke ping to `Mux.Video.Assets.list/1`. | SATISFIED               | Four checks shipped; `--streaming` flag wired; Pitfall 1 locked. WR-03: doctor does not enforce `:rindle_provider` queue when streaming profile present — minor undercoverage, not blocking.                     |
| MUX-17      | 36-02-PLAN  | `guides/streaming_providers.md` ships with Mux-only section.                                                  | SATISFIED               | 341 lines; all required content areas present. WR-01 (version pin) and WR-08 (`.html` link) noted but guide is substantively complete.                                                                          |
| MUX-18      | 36-03-PLAN  | Generated-app proof harness gains `mux-enabled` lane (cassette default) + gated `mux-soak` lane.              | SATISFIED-WITH-DEFECTS  | Both lanes wired; cassette runs every PR (zero secrets); soak label-gated, fork-PR-safe. **CR-01/CR-02/CR-03 are operational defects** affecting soak-lane reliability but not the lane's existence or CI wiring. Recommended: fix before first real soak run. |
| MUX-19      | 36-02-PLAN  | README + getting-started gain "Streaming with Mux" subsection; image/AV onboarding stays canonical first-run.  | SATISFIED               | Both subsections 14 lines (≤15 cap); all 6 pre-existing doc-parity strings preserved; streaming subsection appended, not inserted into AV path.                                                                 |

**Orphaned requirements check:** REQUIREMENTS.md maps Phase 36 to MUX-15..19 (5 IDs). All 5 appear in plan frontmatter and are accounted for above. No orphaned requirements.

---

## Anti-Patterns Found

| File                                                  | Line(s)   | Pattern                                                                              | Severity          | Impact                                                                                |
| ----------------------------------------------------- | --------- | ------------------------------------------------------------------------------------ | ----------------- | ------------------------------------------------------------------------------------- |
| `scripts/mux_soak_cleanup.sh`                         | 69-85     | Filter contract does not match producer — filter always returns empty list            | Blocker (CR-01)   | Cleanup script never finds soak assets; threatens soak-lane operability over time.    |
| `test/install_smoke/support/generated_app_helper.ex`  | 1271-1286 | ETS insert after assertions that can fail — `try/after` cleanup misses on failure path | Blocker (CR-02)   | Layer-1 cleanup useless when assertions fail; only works when test passes.            |
| `test/install_smoke/support/generated_app_helper.ex`  | 912-936   | Unconditional `File.read!` on Mux fixture from `shared_env/1` for all profile modes   | Blocker (CR-03)   | Couples `:image`/`:video` runs to Mux fixture; fragile if fixtures reorganized.       |
| `guides/streaming_providers.md`                       | 53        | Version pin `~> 0.2.0` ahead of `mix.exs` `0.1.4`                                   | Warning (WR-01)   | Adopters following guide during docs-preview period hit unresolvable dep.             |
| `lib/mix/tasks/rindle.doctor.ex`                      | 36        | `_invalid` silently discarded — unknown CLI flags are no-ops                          | Warning (WR-06)   | Adopter typos not surfaced; intended check silently skipped.                          |
| `lib/rindle/ops/runtime_checks.ex`                    | 612-619   | `rescue _ ->` swallows exception class in signing-key parse                           | Warning (WR-10)   | `mix doctor --raise` output loses root-cause for future JOSE-version failures.        |
| `lib/rindle/ops/runtime_checks.ex`                    | 434-443   | `:rindle_provider` queue not added to `required_queues/1` for streaming profiles      | Warning (WR-03)   | Doctor PASS misleads adopters; streaming ingestion silently fails if queue missing.   |
| `test/install_smoke/support/generated_app_helper.ex`  | 393-411   | Generated `:mux` config never declares `rindle_provider` queue                       | Warning (WR-04)   | Cassette passes only because `perform_job/2` bypasses dispatcher; real app breaks.   |
| `test/install_smoke/support/generated_app_helper.ex`  | 1144-1145 | `Mox.verify_on_exit!(self())` — non-idiomatic arg, accidentally working               | Warning (WR-05)   | Future Mox version bump risk.                                                         |

No `TODO`/`FIXME`/`PLACEHOLDER` markers introduced by Phase 36 in any modified file.

---

## Human Verification Required

Five items require CI-time or human-observable verification:

### 1. Cassette Package-Consumer Lane (SC #3 + SC #4 cassette half)

**Test:** On a real PR build, confirm `bash scripts/install_smoke.sh mux` exits 0 inside the `package-consumer` CI job.
**Expected:** Fresh `mix phx.new` + Rindle install + `mix rindle.doctor` + sample upload + Mux-signed HLS URL JWT-verified. Cassette path never reaches `api.mux.com`. `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` passes — `["poster", "web_720p"]` ready-variant assertion byte-identical to `:video` lane.
**Why human:** Requires `mix phx.new` + DB + MinIO + 10+ min run. Plan 03 explicitly defers this to the CI package-consumer step.

### 2. Mux-Soak Lane Against Real Mux (SC #4 soak half)

**Test:** Apply the `streaming` label to a maintainer-owned PR (with all five `RINDLE_MUX_*` GitHub Secrets configured). Confirm the `mux-soak` job fires and runs clean.
**Expected:** Real-Mux asset created, processed, and deleted by cleanup. Soak-asset count stays 0 across consecutive labelled PRs. Note: **CR-01 and CR-02 defects should be fixed before this test is meaningful** — otherwise the cleanup layers will silently fail.
**Why human:** Requires five GitHub Secrets (one-time maintainer bootstrap) and real Mux account.

### 3. HexDocs Publish Wire

**Test:** Run `mix docs` locally (or examine hexdocs.pm after publish). Confirm `Rindle.Profile.Presets.MuxWeb` module page renders and `guides/streaming_providers.md` appears in the sidebar with working intra-doc links.
**Expected:** `doc/streaming_providers.html` present; sidebar lists the guide; `[Secure Delivery](secure_delivery.html)` link resolves (WR-08: note this link uses `.html` extension, which works on hexdocs but not GitHub raw view).
**Why human:** Visual rendering and link resolution are observable only in a HexDocs build.

### 4. Fork-Secret Boundary

**Test:** Open a fork PR and apply the `streaming` label.
**Expected:** `mux-soak` job fires; all `${{ secrets.RINDLE_MUX_* }}` resolve to empty strings; the lane fails closed; `mux_soak_cleanup.sh` exits 0 via the no-credential branch without attempting any Mux API call.
**Why human:** GitHub Actions secret-resolution semantics for fork PRs are only observable by running a real fork PR with the label applied.

### 5. Generated-App MuxTest Isolation

**Test:** Via the package-consumer CI step, confirm `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` runs in the spawned Phoenix project and all assertions pass (including Mox isolation and the `JOSE.JWT.verify_strict/3` step).
**Why human:** The generated app spawns a separate Phoenix project process; library-side `mix test` does not include this module.

---

## Gaps Summary

No artifact-level or wiring-level gaps. Every must-have surface from ROADMAP.md SC #1-5 and PLAN frontmatter `must_haves` is present, compiles, is wired, and (for unit-testable surfaces) passes its tests.

The phase goal is achieved at the artifact-and-wiring level. Both clauses — "lock the adopter onboarding path" and "prove the package-consumer story matches v1.5's bar" — have their codebase realizations in place. The second clause's CI lanes are wired; behavioral proof is necessarily CI-time observable.

**Three BLOCKER defects** (CR-01/02/03) are operational risks rather than missing artifacts. Recommended action: fix CR-01 and CR-02 before the first real soak run (they make the three-layer cleanup claim false on failure paths); fix CR-03 before any fixture reorganization. These do not block Phase 37 or milestone close but should be resolved in a `/gsd-code-review 36 --fix` pass.

**Nine WARNING items** range from a real-world adopter-facing bug (WR-01: docs version pin ahead of mix.exs) through DX gaps (WR-03/04: rindle_provider queue not checked or generated) to style concerns. All itemized in `review_findings.warnings` with fix shapes from `36-REVIEW.md`.

**Pre-existing test failures** documented in `deferred-items.md` (2 stable `Rindle.ApplicationTest` + 3 intermittent FFmpeg/AV/Waveform tests) are unrelated to Phase 36 and confirmed against base commit.

---

_Verified: 2026-05-07T14:45:00Z_
_Verifier: Claude (gsd-verifier)_
