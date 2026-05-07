---
phase: 36-public-dx-onboarding-ci-proof
verified: 2026-05-07T13:59:35Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
gaps: []
human_verification:
  - test: "Run cassette package-consumer lane end-to-end on a real PR build"
    expected: "`bash scripts/install_smoke.sh mux` exits 0 inside CI's `package-consumer` job: fresh `mix phx.new` + Rindle install + `mix rindle.doctor` + sample upload + `<video>` rendered with Mux-signed HLS URL. The cassette path never reaches `api.mux.com` (Mox-on-:http_client). This is SC #3 + SC #4 (cassette lane) and the Plan 03 SUMMARY explicitly defers item 1 of its verification matrix to CI."
    why_human: "Full E2E lane requires `mix phx.new` + DB + MinIO + a 10+ min run; per Plan 03 SUMMARY this is the package-consumer step's purpose and was intentionally not run in the worktree."
  - test: "Run `mux-soak` lane against real Mux on a `streaming`-labelled PR"
    expected: "Real-Mux API hit succeeds end-to-end; ingested asset appears + ready; signed HLS URL plays; cleanup deletes the asset; soak-asset count on the Mux account stays at 0 across consecutive labelled PRs."
    why_human: "Soak lane needs five GitHub Secrets configured by maintainer (one-time bootstrap documented in Plan 03 SUMMARY); also exercises CR-01/CR-02 paths whose effect can only be observed against the real Mux account."
  - test: "Verify HexDocs publish wire — `mix docs` rendering of `streaming_providers.md` + `MuxWeb` module"
    expected: "On hexdocs.pm (or local `mix docs` preview), `Rindle.Profile.Presets.MuxWeb` module page renders, `guides/streaming_providers.md` is in the sidebar, intra-doc links resolve."
    why_human: "Visual rendering / link resolution behavior is observable only in a HexDocs build, not via grep."
  - test: "Confirm no fork-secret leak when a fork PR is labelled `streaming`"
    expected: "Fork PR labelled `streaming` fires `mux-soak` job; `${{ secrets.RINDLE_MUX_* }}` resolve to empty strings; the lane fails closed (no real-Mux call); cleanup step's no-credential branch (`exit 0`) hits."
    why_human: "Behavior depends on GitHub Actions secret-resolution semantics which can only be observed by running a real fork PR with the label applied."
  - test: "Confirm the cassette lane's WebM upload + variant fan-out yields the byte-identical `[poster, web_720p]` ready-variant assertion in the generated app"
    expected: "Generated-app smoke test (`Rindle.InstallSmoke.GeneratedAppSmokeMuxTest`) passes — same as the `:video` lane plus the two new streaming-URL assertions (regex match + `JOSE.JWT.verify_strict/3` returning `{true, _, _}`)."
    why_human: "Generated app spawns a separate Phoenix project; library-side `mix test` does not include this, only the package-consumer step does."
review_findings:
  blockers:
    - id: CR-01
      title: "mux-soak `scripts/mux_soak_cleanup.sh` filters by `meta.rindle_soak == \"true\"` but no producer ever stamps that metadata — layer-3 cleanup is non-functional"
      file: "scripts/mux_soak_cleanup.sh:69-85, lib/rindle/streaming/provider/mux.ex (build_create_params/2)"
      evidence: "Repo-wide grep for `rindle_soak` and `passthrough` returns hits ONLY in mux_soak_cleanup.sh itself — neither `Rindle.Streaming.Provider.Mux.build_create_params/2` nor any test source stamps the tag. Cleanup will always emit `no soak assets found (meta.rindle_soak=true)` even on real leak."
      severity: blocker
      goal_impact: "Threatens SC #4 in steady state (10-asset Mux free-tier cap will brick the soak lane after a few leaks). Combined with CR-02, the documented three-layer safety net collapses to zero working layers on test failure. Goal still considered achieved at this phase boundary because the lane shipped and runs; defect manifests over time."
    - id: CR-02
      title: "Soak lifecycle test inserts `provider_asset_id` into ETS AFTER assertions that can fail — `try/after` cleanup looks up an empty ETS row when assertions fail"
      file: "test/install_smoke/support/generated_app_helper.ex:1189-1310"
      evidence: "ETS insert at lines 1271-1286 is inside the try block AFTER `streaming_url` regex (1247) and JWT verify (1257). If those assertions fail, control jumps to `after` where ETS lookup returns `[]` and falls through to `_ -> :ok`. The layer that exists for failure cases is the layer that fails on failure."
      severity: blocker
      goal_impact: "Same as CR-01 — operational defect rather than a missing artifact. Cassette mode still works (Mox stubs never raise; the `try/after` is a no-op); failure mode only triggers on real soak-mode lifecycle failure."
    - id: CR-03
      title: "`shared_env/1` always reads `test/fixtures/mux/test_signing_private_key.pem`, coupling `:image`/`:video` install-smoke runs to a Mux fixture"
      file: "test/install_smoke/support/generated_app_helper.ex:912-936"
      evidence: "Lines 916-918: `private_key_pem = System.get_env(...) || File.read!(...)`. Invoked unconditionally from `prove_package_install!/1` regardless of profile mode. Contributors running `bash scripts/install_smoke.sh image` against a checkout missing the Mux fixture get a low-level `File.Error` instead of a clear diagnostic."
      severity: blocker
      goal_impact: "Does not block phase goal achievement (image/video lanes pass today because the fixture is committed); but is a regression risk against the `image-only`/`av-enabled` lanes the plan was supposed to leave untouched."
  warnings:
    - id: WR-01
      title: "guides/streaming_providers.md pins `{:rindle, \"~> 0.2.0\"}` while mix.exs is at `0.1.4`"
      file: "guides/streaming_providers.md:53, mix.exs:4"
      evidence: "Verified — `@version \"0.1.4\"` in mix.exs, `{:rindle, \"~> 0.2.0\"}` on line 53 of streaming_providers.md."
      severity: warning
      goal_impact: "If `mix docs` runs OR a docs preview is published before release-please cuts 0.2.0, adopters following the guide hit an unresolvable dep. README.md and getting_started.md correctly use `~> 0.1`."
    - id: WR-02
      title: "mix.exs `:extras` omits `guides/upgrading.md` even though README/getting_started link to it"
      file: "mix.exs:117-129"
      severity: warning
      goal_impact: "Pre-existing miss; not introduced by Phase 36 but adjacent to the docs lane. README/getting_started [`guides/upgrading.md`](...) link will 404 on hexdocs.pm."
    - id: WR-03
      title: "`required_queues/1` does not add `:rindle_provider` when streaming-enabled profile present"
      file: "lib/rindle/ops/runtime_checks.ex:434-443"
      severity: warning
      goal_impact: "Doctor PASS misleads adopters who follow streaming_providers.md. `mix rindle.doctor` reports OK while a missing `:rindle_provider` queue silently breaks Mux ingestion."
    - id: WR-04
      title: "Generated `:mux` lane never declares `rindle_provider` queue, masking WR-03 end-to-end"
      file: "test/install_smoke/support/generated_app_helper.ex:393-411,504-513"
      severity: warning
      goal_impact: "Cassette test passes only because `Oban.Testing.perform_job/2` bypasses the dispatcher; production adopter who copies the generated config breaks."
    - id: WR-05
      title: "Non-idiomatic `Mox.verify_on_exit!(self())` and `Mox.set_mox_from_context(%{async: false})` in generated test"
      file: "test/install_smoke/support/generated_app_helper.ex:1141-1148"
      severity: warning
      goal_impact: "Works today by coincidence (Mox discards the arg); future Mox version bumps could break this without warning."
    - id: WR-06
      title: "`Mix.Tasks.Rindle.Doctor` silently discards unknown CLI flags via `_invalid`"
      file: "lib/mix/tasks/rindle.doctor.ex:35-42"
      severity: warning
      goal_impact: "Adopter typing `--streming` gets no error; the requested check silently does not run."
    - id: WR-07
      title: "`Rindle.Capability.configured_streaming_profiles/1` is public but lacks a direct unit test"
      file: "lib/rindle/capability.ex:90-104, test/rindle/ops/runtime_checks_streaming_test.exs"
      severity: warning
      goal_impact: "Coverage is transitive only. Map vs keyword-list dual handling at lines 121-126 is exactly the kind of branch that should not silently regress."
    - id: WR-08
      title: "streaming_providers.md links to `secure_delivery.html` instead of `.md`"
      file: "guides/streaming_providers.md:29"
      severity: warning
      goal_impact: "Renders correctly on hexdocs.pm but 404s on the GitHub raw view. Pre-existing pattern in other guides."
    - id: WR-09
      title: "`mux_config_block/1` accepts an unused `_app_name` parameter"
      file: "test/install_smoke/support/generated_app_helper.ex:421,429"
      severity: warning
      goal_impact: "Code smell only; no behavior impact."
    - id: WR-10
      title: "`verify_signing_key_pem/1` rescue clause swallows the original exception"
      file: "lib/rindle/ops/runtime_checks.ex:594-620"
      severity: warning
      goal_impact: "Generic 'malformed PEM' summary loses root-cause diagnostic for `mix doctor --raise`."
---

# Phase 36: Public DX, Onboarding, CI Proof — Verification Report

**Phase Goal:** Lock the adopter onboarding path; prove the package-consumer story matches v1.5's bar.
**Verified:** 2026-05-07T13:59:35Z
**Status:** human_needed
**Re-verification:** No — initial verification.

---

## Goal Achievement

The phase goal has two clauses:

1. **"Lock the adopter onboarding path"** — covered by SC #1 (MuxWeb preset), SC #2 (doctor checks), SC #5 (guides/README/getting_started). All three are VERIFIED in the codebase.
2. **"Prove the package-consumer story matches v1.5's bar"** — covered by SC #3 (fresh `mix phx.new` lifecycle) and SC #4 (`mux-enabled` cassette lane + label-gated `mux-soak`). The harness, scripts, GitHub Actions wiring, fixtures, Mox-on-`:http_client` shim, and three-layer cleanup machinery are all present in the codebase. The cassette lane's BEHAVIORAL proof (run-it-and-it-exits-0) is a CI-only observable per Plan 03's own design — the package-consumer step IS the proof; running it locally would reproduce what CI is for. This routes to **human verification** rather than gap.

The code review (`36-REVIEW.md`) found 3 BLOCKER and 9 WARNING issues. The blockers are operational defects in the soak lane (CR-01: cleanup filter never matches; CR-02: ETS insert ordered after assertions; CR-03: image/video runs coupled to Mux fixture). They are real defects but they do not invalidate the **shipping** of the must-haves — every required surface exists, compiles, and the unit test suite passes. The blockers manifest only on (a) sustained real-Mux soak runs (CR-01/02) or (b) a future contributor running `:image`/`:video` against a Mux-fixture-stripped checkout (CR-03). Surfacing them as `review_findings` for the maintainer to triage before next phase.

### Observable Truths

The merged must-haves below are taken from ROADMAP.md Phase 36 Success Criteria (5 items, all included verbatim where they restate the contract) plus the per-plan PLAN frontmatter must-haves where they add specificity.

| #   | Truth (from ROADMAP SC + plan must_haves)                                                                                                                                                                                                                                            | Status     | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **SC #1 — `Rindle.Profile.Presets.MuxWeb` ships alongside `Rindle.Profile.Presets.Web` with `:streaming` opt-in + `:signed` named playback policy.** Adopter `use Rindle.Profile.Presets.MuxWeb, ...` produces a profile whose `delivery_policy().streaming` exposes the locked four-key block. | ✓ VERIFIED | `lib/rindle/profile/presets/mux_web.ex` (79 lines) defines `defmacro __using__/1` that delegates variants to `Rindle.Profile.Presets.Web.variants/1` and overlays a locked `streaming: [provider: Rindle.Streaming.Provider.Mux, playback_policy: :signed, ingest_mode: :server_push, source_variant: :web_720p]` block via `Keyword.merge(adopter_delivery, locked_streaming)`. Test `test/rindle/profile/presets/mux_web_test.exs` (4 tests) covers variant inheritance, locked streaming block, scrub_strip passthrough, and adopter-delivery merge. PASSES (28/28). |
| 2   | **SC #2 — `mix rindle.doctor` validates streaming configuration with PASS/FAIL.** Four checks (`doctor.streaming_credentials`, `doctor.streaming_signing_key`, `doctor.streaming_webhook_secrets`, `doctor.streaming_smoke_ping`); 5s smoke ping to `Mux.Video.Assets.list/1` behind `--streaming`. | ✓ VERIFIED | `lib/rindle/ops/runtime_checks.ex:502-740` adds the four checks; profile-discovery-gated via `Rindle.Capability.configured_streaming_profiles/1`; optional-dep-gated via `Code.ensure_loaded?(Mux.Video.Assets)`; pitfall-1 mitigation present (`%JOSE.JWK{}` struct match, NOT truthy). `lib/mix/tasks/rindle.doctor.ex` plumbs `--streaming` via `OptionParser.parse(args, strict: [streaming: :boolean])`. Smoke ping uses `Task.async + Task.yield(5_000) || Task.shutdown(:brutal_kill)`. 12-check deterministic-id assertion in `runtime_checks_test.exs` PASSES. Doctor never echoes credential VALUES — only env-var NAMES (verified by reading every error_result/ok_result in the four checks). |
| 3   | **SC #3 — Fresh `mix phx.new` adopter app harness installs Rindle, declares `Rindle.Profile.Presets.MuxWeb`, runs `mix rindle.doctor`, uploads sample mp4, renders `<video>` with Mux-signed HLS URL — from CI, from published artifact.** | ⚠ ARTIFACTS VERIFIED, BEHAVIOR DEFERRED TO CI | All harness pieces exist: `test/install_smoke/support/generated_app_helper.ex` lines 1133-1310 emit the `:mux` lifecycle test source with cassette-mode Mox stubs, `["poster", "web_720p"]` ready-variant assertion (line 1214), Mux-signed HLS URL regex (line 1247), `JOSE.JWT.verify_strict/3` against the committed `test_signing_public_key.pem` fixture (line 1257). `test/install_smoke/generated_app_smoke_test.exs:97-141` defines `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest`. `scripts/install_smoke.sh` line 20 dispatches `all\|image\|video\|mux`. New `package-consumer` step at `.github/workflows/ci.yml:384-385` runs `bash scripts/install_smoke.sh mux`. The end-to-end run exits 0 ONLY on a real PR build (Plan 03 explicitly deferred item 1 of its verification matrix to CI). Routed to human-verification rather than failed because every artifact, key link, and code path exists; the BEHAVIOR is observable only in CI. |
| 4   | **SC #4 — Generated-app proof harness has `mux-enabled` lane alongside `image-only` and `av-enabled`; PR builds run cassette-based fixtures; gated `mux-soak` lane runs against real Mux on PRs labelled `streaming`.** | ⚠ STRUCTURE VERIFIED, OPERATIONAL DEFECTS FLAGGED | Cassette `mux-enabled` step lives inside `package-consumer` job (`.github/workflows/ci.yml:384-385`) — runs every PR, zero new GitHub Secrets required. Sibling top-level `mux-soak` job (lines 555-647) is `if: contains(...labels.*.name, 'streaming')`-gated, `needs: quality`, references all five `RINDLE_MUX_*` secrets, uses safe `pull_request` trigger with `types: [opened, synchronize, reopened, labeled]`, ends with `if: always()` cleanup running `bash scripts/mux_soak_cleanup.sh`. **Operational defects (CR-01/02/03) flagged in `review_findings`** — they do not block shipping the lanes but threaten steady-state operability. Cassette behavioral confirmation also routes to human (CI-only observable). |
| 5   | **SC #5 — `guides/streaming_providers.md` ships Mux-only section (env vars, signing-key creation, secret rotation, raw-body cache wiring, ngrok-style local tunnel, doctor smoke); README + getting_started gain "Streaming with Mux" subsection.** | ✓ VERIFIED | `guides/streaming_providers.md` exists (341 lines) with all 11 D-10 sections in correct order: Why → deps → signing key → MuxWeb → webhook → cron → tunnel (cloudflared PRIMARY, ngrok with 2026 signup caveat) → secret rotation → doctor smoke → stuck-asset runbook → JOSE perf footgun. Wired into `mix.exs:124` extras list. `README.md:242-255` and `guides/getting_started.md:364-377` each have a 14-line "Streaming with Mux (optional)" subsection (≤15-line cap per D-25). Doc-parity guard at `.github/workflows/ci.yml:532-545` adds `"Rindle.Profile.Presets.MuxWeb"` to required strings; existing required strings (`mix rindle.doctor`, `Rindle.Profile.Presets.Web`, `Rindle.initiate_upload`, `Rindle.verify_completion`, `Rindle.attach`, `Rindle.url`) preserved verbatim. Negative regex (`Broker\.initiate_session\|Broker\.verify_completion\|Rindle\.Delivery\.url`) unchanged; new content uses `Rindle.Delivery.streaming_url` exclusively. `CHANGELOG.md:9-17` `[Unreleased] ### Added` has the v1.6 streaming-onboarding bullet. |

**Score:** 5/5 truths verified at the artifact-and-wiring level. SC #3 and SC #4 require CI-time behavioral confirmation (`human_verification` queue).

---

## Required Artifacts

### Plan 01 (MuxWeb preset + doctor checks)

| Artifact                                                       | Expected                                                | Status     | Details                                                                                                                                                                                                                                                                            |
| -------------------------------------------------------------- | ------------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/rindle/profile/presets/mux_web.ex`                        | Public preset macro inheriting Web variants + locked streaming | ✓ VERIFIED | 79 lines, exports `__using__/1`. Streaming-block stored as keyword list (executor decision documented in 36-01-SUMMARY decisions). Compile passes; 4 tests pass.                                                                                                                                  |
| `lib/rindle/ops/runtime_checks.ex`                             | Four streaming checks appended                          | ✓ VERIFIED | Lines 502-740 add `check_streaming_credentials`, `check_streaming_signing_key`, `check_streaming_webhook_secrets`, `check_streaming_smoke_ping` plus 5 fix-recipe attrs. Total check count goes from 8 to 12 (matches `<success_criteria>`).                                          |
| `lib/mix/tasks/rindle.doctor.ex`                               | `--streaming` OptionParser strict opt plumbed into `RuntimeChecks.run/2` | ✓ VERIFIED | Line 36 `OptionParser.parse(args, strict: [streaming: :boolean])`; Keyword.put `:streaming` into `RuntimeChecks.run/2` opts. Default run never hits `api.mux.com`. Updated `@moduledoc` documents the flag. Note WR-06: unknown flags silently discarded.                              |
| `lib/rindle/capability.ex`                                     | `configured_streaming_profiles/1` promoted from defp to def | ✓ VERIFIED | Line 99 `def configured_streaming_profiles(profiles)` with `@spec` and `@doc`. Promoted from `defp` (Rule 2 deviation in 36-01-SUMMARY). Note WR-07: lacks direct unit test.                                                                                                              |
| `test/rindle/profile/presets/mux_web_test.exs`                 | Preset compile + DSL validation tests                   | ✓ VERIFIED | 4 tests, all pass: variants inheritance from Web, locked streaming block in `delivery_policy/0`, scrub_strip passthrough, adopter-delivery merge-last.                                                                                                                                  |
| `test/rindle/ops/runtime_checks_streaming_test.exs`            | Four streaming check tests with describe blocks         | ✓ VERIFIED | 12 tests across 5 describe blocks (profile-discovery gate, credentials, signing-key with Pitfall 1, webhook-secrets, smoke-ping flag-gate). Includes `@valid_pem` (loaded from existing fixture) + `@malformed_pem`. Pass on focused run.                                              |

### Plan 02 (docs lane)

| Artifact                              | Expected                                                | Status     | Details                                                                                                                                                                                                                                                              |
| ------------------------------------- | ------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `guides/streaming_providers.md`       | End-to-end Mux adopter onboarding guide                  | ✓ VERIFIED | 341 lines (≥150 floor), all 11 D-10 sections present in correct order. WR-01 (version pin) and WR-08 (`.html` link) flagged.                                                                                                                                                |
| `mix.exs`                             | extras list extended with streaming_providers.md         | ✓ VERIFIED | Line 124 `"guides/streaming_providers.md"` added immediately after `secure_delivery.md`. WR-02 (missing `upgrading.md`) flagged but pre-existing.                                                                                                                            |
| `README.md`                           | "Streaming with Mux (optional)" subsection (≤15 lines)  | ✓ VERIFIED | 14 lines (`242-255`), placed after `## After First Run...`/Bang Variants and before `## Next Reads`. Three D-26 elements only (intro + snippet + link).                                                                                                                       |
| `guides/getting_started.md`           | "## 10. Streaming with Mux (optional)" subsection (≤15 lines) | ✓ VERIFIED | 14 lines (`364-377`), placed after Section 9 (Bang Variants), before "Next Reads".                                                                                                                                                                                  |
| `.github/workflows/ci.yml` (doc-parity) | Doc-parity guard with MuxWeb required string              | ✓ VERIFIED | Line 539 `"Rindle.Profile.Presets.MuxWeb"` appended; existing six required strings unchanged (lines 533-538); negative regex unchanged (line 547).                                                                                                                          |
| `CHANGELOG.md`                        | v0.2.0-bound entry referencing streaming surface          | ✓ VERIFIED | Lines 9-17 `[Unreleased] ### Added` contains MuxWeb, `mix rindle.doctor --streaming`, streaming_providers.md, `mux-enabled`, `mux-soak`. Existing v1.4-v1.5 entries byte-identical (D-34).                                                                                  |

### Plan 03 (install-smoke + CI)

| Artifact                                                | Expected                                                       | Status     | Details                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------------- | -------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `test/install_smoke/support/generated_app_helper.ex`    | Extended `:mux` profile mode (5 sites + 3 helpers)              | ✓ VERIFIED | Line 14 `profile_enabled?/1` extended; line 20 `prove_package_install!/1` extended; line 990 `selected_profiles/0` adds `"mux" -> [:mux]`; lines 308/319/336/344 `patch_test_helper!/2` defines `Mox.defmock(...)` against `Rindle.Streaming.Provider.Mux.Client` behaviour; lines 458-505 `stage_mux_fixtures!/1`; lines 421/429 `mux_config_block/1`; lines 1133-1310 `lifecycle_test_source(_, :mux)` head clause with cassette/soak duality. WR-03/04/05/09/CR-02/CR-03 flagged. |
| `test/install_smoke/generated_app_smoke_test.exs`       | `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` module           | ✓ VERIFIED | Line 97 `if GeneratedAppHelper.profile_enabled?(:mux) do`; line 98 `defmodule Rindle.InstallSmoke.GeneratedAppSmokeMuxTest`. `assert_install_source!/1` extended to `[:image, :video, :upgrade, :mux]`.                                                                                                                                                                                                                                                                                       |
| `scripts/install_smoke.sh`                              | case dispatch accepts `mux`                                     | ✓ VERIFIED | Line 20 `all\|image\|video\|mux) ;;`. One-line edit; `mix test` invocation profile-agnostic.                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `.github/workflows/ci.yml` (Plan 03 edits)              | labeled trigger + mux-enabled cassette step + mux-soak sibling job | ✓ VERIFIED | Lines 6-12 `pull_request: types: [opened, synchronize, reopened, labeled]`; lines 384-385 `Run built-artifact Mux-enabled package-consumer proof (cassette mode)`; lines 555-647 sibling `mux-soak` job. Doc-parity guard at lines 525-553 untouched by Plan 03 (Plan 02 owns it).                                                                                                                                                                |
| `scripts/mux_soak_cleanup.sh`                           | Belt-and-suspenders soak-lane cleanup invokable from `if: always()` step | ⚠ STUB ON FILTER | 115 lines, executable, dry-run support, fork-safe no-op when `RINDLE_MUX_TOKEN_ID/SECRET` empty. Filters by `meta.rindle_soak == "true"` BUT no producer ever stamps that metadata (CR-01) — script will always emit "no soak assets found". File EXISTS and is wired; the cleanup BEHAVIOR is non-functional.                                                                                                                                                                          |
| `test/fixtures/mux/test_signing_public_key.pem`         | RSA-2048 public key fixture for cassette-mode JWT-decode         | ✓ VERIFIED | 9 lines, valid 2048-bit RSA public key (`openssl rsa -pubin -in ... -text -noout` parses; modulus correct length).                                                                                                                                                                                                                                                                                                                                |

---

## Key Link Verification

| From                                                              | To                                                            | Via                                                           | Status   | Details                                                                                                  |
| ---------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------- |
| `lib/rindle/profile/presets/mux_web.ex`                           | `lib/rindle/profile/presets/web.ex`                            | `Rindle.Profile.Presets.Web.variants/1`                       | ✓ WIRED  | Line 71 explicit call.                                                                                    |
| `lib/rindle/profile/presets/mux_web.ex`                           | `lib/rindle/profile/validator.ex`                              | `use Rindle.Profile, ...` triggers `@streaming_schema`        | ✓ WIRED  | Line 76 `use Rindle.Profile, unquote(Macro.escape(profile_opts))`.                                        |
| `lib/rindle/ops/runtime_checks.ex`                                | `lib/rindle/capability.ex`                                     | `Rindle.Capability.configured_streaming_profiles/1`           | ✓ WIRED  | Line 505 helper delegates; `Rindle.Capability.report/0` continues to call internally.                                                                                                          |
| `lib/rindle/ops/runtime_checks.ex`                                | `Mux.Video.Assets`                                             | smoke ping (Code.ensure_loaded? guard)                        | ✓ WIRED  | Lines 684, 711 `Mux.Video.Assets.list(client, %{limit: 1})`.                                                                                                                                  |
| `lib/mix/tasks/rindle.doctor.ex`                                  | `lib/rindle/ops/runtime_checks.ex`                             | `Keyword.put(opts, :streaming, ...)` → `RuntimeChecks.run/2`  | ✓ WIRED  | Line 58 `Keyword.put(:streaming, streaming?)`.                                                                                                                                                |
| `guides/streaming_providers.md`                                   | `lib/rindle/delivery/webhook_plug.ex`                          | inline-copy + `<!-- source: ... -->` HTML comment             | ✓ WIRED  | Line 140 source comment present.                                                                                                                                                                                |
| `guides/streaming_providers.md`                                   | `lib/rindle/workers/mux_sync_coordinator.ex`                   | inline-copy + HTML source comment                             | ✓ WIRED  | Line 183 source comment present.                                                                                                                                                                                |
| `mix.exs`                                                         | `guides/streaming_providers.md`                                | extras list                                                   | ✓ WIRED  | Line 124.                                                                                                                                                                                                                                                              |
| `README.md`                                                       | `guides/streaming_providers.md`                                | inline link                                                   | ✓ WIRED  | Line 255.                                                                                                                                                                                                                                                                  |
| `.github/workflows/ci.yml`                                        | `Rindle.Profile.Presets.MuxWeb`                                | doc-parity required-strings list                              | ✓ WIRED  | Line 539.                                                                                                                                                                                                                                                              |
| `test/install_smoke/support/generated_app_helper.ex`              | `lib/rindle/streaming/provider/mux.ex` (`http_client` config)   | `config :rindle, Rindle.Streaming.Provider.Mux, http_client: ClientMock` | ✓ WIRED  | Line 447 emits config block.                                                                                                                                                                                                                                                                                              |
| `test/install_smoke/support/generated_app_helper.ex`              | `test/fixtures/mux/test_signing_private_key.pem`               | `File.read!/1` in `shared_env/1` + `File.cp!/2` staging        | ✓ WIRED but COUPLED | Line 918 `File.read!/1` + line 467 `stage_mux_fixtures!/1` `File.cp!`. CR-03 flag — invoked unconditionally for all profile modes.                                                                                                                                                                                              |
| `test/install_smoke/generated_app_smoke_test.exs`                 | `test/install_smoke/support/generated_app_helper.ex`           | `GeneratedAppHelper.profile_enabled?(:mux)` + `prove_package_install!(:mux)` | ✓ WIRED  | Line 97 + line 100.                                                                                                                                                                                                                                                                                              |
| `.github/workflows/ci.yml`                                        | `scripts/install_smoke.sh`                                     | `bash scripts/install_smoke.sh mux` step                       | ✓ WIRED  | Lines 385 (cassette), 643 (soak).                                                                                                                                                                                                                                                                                                                                              |
| `.github/workflows/ci.yml`                                        | `scripts/mux_soak_cleanup.sh`                                  | `if: always()` cleanup step                                    | ✓ WIRED  | Lines 645-647.                                                                                                                                                                                                                                                                                                                                                                                                              |
| `scripts/install_smoke.sh`                                        | `test/install_smoke/generated_app_smoke_test.exs`              | `RINDLE_INSTALL_SMOKE_PROFILE` env-var dispatch                | ✓ WIRED  | Lines 9 + 32.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |

---

## Data-Flow Trace (Level 4)

| Artifact                                                | Data Variable                                              | Source                                                                                                                  | Produces Real Data | Status     |
| ------------------------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------ | ---------- |
| `lib/rindle/profile/presets/mux_web.ex` (`__using__`)    | `delivery_policy().streaming` map                          | `Macro.escape(profile_opts)` → `use Rindle.Profile` runtime expansion → DSL validator normalizes to map                   | Yes                | ✓ FLOWING  |
| `lib/rindle/ops/runtime_checks.ex` (4 streaming checks)  | `streaming_profiles(profiles)`                             | `Rindle.Capability.configured_streaming_profiles/1` walking adopter-supplied profile list                                 | Yes                | ✓ FLOWING  |
| `lib/rindle/ops/runtime_checks.ex` (smoke ping)          | `Mux.Video.Assets.list/2` response                          | Real `Mux.Base.new/2` HTTP call when `--streaming` flag set                                                              | Yes (with flag)    | ✓ FLOWING  |
| `test/install_smoke/.../lifecycle_test_source(_,:mux)`   | `streaming_url` (HLS m3u8 + JWT)                            | Cassette: Mox stub on `Rindle.Streaming.Provider.Mux.ClientMock`. Soak: real Mux SDK via `:http_client` HTTP default      | Yes                | ✓ FLOWING (CASSETTE BY CONSTRUCTION) |
| `scripts/mux_soak_cleanup.sh`                            | `soak_assets` (filtered list)                               | `Mux.Video.Assets.list/2` filtered by `meta.rindle_soak == "true"` — **but no producer ever stamps that metadata (CR-01)** | NO                 | ✗ DISCONNECTED |

The CR-01 row is the only data-flow break. The cleanup script's filter and the producer's request body do not agree on a tagging convention; the producer (`Rindle.Streaming.Provider.Mux.build_create_params/2`) does not write `passthrough` or `meta`.

---

## Behavioral Spot-Checks

| Behavior                                                                                              | Command                                                                                                  | Result                                                                                                       | Status |
| ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------ |
| Compile clean (warnings-as-errors)                                                                     | `mix compile --warnings-as-errors`                                                                       | Exit 0                                                                                                       | ✓ PASS |
| Phase 36 unit tests pass                                                                               | `mix test test/rindle/profile/presets/mux_web_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs` | 28 tests, 0 failures                                                                                          | ✓ PASS |
| Full test suite remains green (modulo pre-existing deferred items)                                       | `mix test --warnings-as-errors`                                                                          | 791 tests, 5 failures — all 5 are deferred-items.md (2 stable `Rindle.ApplicationTest`, 3 intermittent FFmpeg/probe/AV/Waveform tests pre-existing on base) | ✓ PASS (no Phase 36 regressions) |
| `ci.yml` is valid YAML (parsed)                                                                       | `python3 -c "import yaml; yaml.safe_load(open(...))"`                                                     | Parses; `pull_request.types == ['opened','synchronize','reopened','labeled']`; jobs include `package-consumer` + `mux-soak` | ✓ PASS |
| `mux-soak` job has `if`, `needs`, all 5 RINDLE_MUX_* env keys                                          | YAML inspection                                                                                          | `if: contains(...labels.*.name, 'streaming')`; `needs: quality`; env has all 5 token/key/secret keys + `RINDLE_MUX_USE_REAL_API` | ✓ PASS |
| No `pull_request_target` substring in workflow file                                                    | `grep -n pull_request_target ci.yml`                                                                     | 0 matches                                                                                                    | ✓ PASS |
| `test_signing_public_key.pem` parses as RSA-2048                                                       | `openssl rsa -pubin -in ... -text -noout`                                                                 | `Public-Key: (2048 bit)`                                                                                     | ✓ PASS |
| Doc-parity required-strings list contains all 7 entries                                                 | `grep` for each                                                                                          | 7/7 (mix rindle.doctor, Web, initiate_upload, verify_completion, attach, url, MuxWeb)                          | ✓ PASS |
| README + getting_started "Streaming with Mux" subsection ≤15 lines                                     | line count                                                                                               | 14 lines each                                                                                                | ✓ PASS |
| `streaming_providers.md` contains all 11 D-10 sections in order                                         | section heading grep                                                                                     | 11/11 in correct order                                                                                       | ✓ PASS |
| Forbidden pattern `Rindle.Delivery.url` (without underscore) absent from new content                   | regex grep                                                                                               | 0 matches in new content (only `Rindle.Delivery.streaming_url` used)                                          | ✓ PASS |
| Cassette package-consumer `mux-enabled` step end-to-end (`bash scripts/install_smoke.sh mux` exits 0)   | requires `mix phx.new` + DB + MinIO + 10+ min                                                            | DEFERRED — by Plan 03 design (the CI step IS the verification)                                                 | ? SKIP — routed to human verification |
| `mux-soak` lane against real Mux                                                                        | requires GitHub Secrets + `streaming` label                                                              | DEFERRED — maintainer one-time bootstrap then label                                                          | ? SKIP — routed to human verification |

---

## Requirements Coverage

| Requirement | Source Plan | Description                                                                                                                                                      | Status      | Evidence                                                                                                                                                                                                                                            |
| ----------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MUX-15      | 36-01-PLAN  | `Rindle.Profile.Presets.MuxWeb` ships alongside `Rindle.Profile.Presets.Web` and demonstrates `:streaming` opt-in with `:signed` named playback policy.          | ✓ SATISFIED | `lib/rindle/profile/presets/mux_web.ex` plus 4 passing tests in `test/rindle/profile/presets/mux_web_test.exs`. `delivery_policy().streaming.playback_policy == :signed` asserted (line 53 of test).                                                                |
| MUX-16      | 36-01-PLAN  | `mix rindle.doctor` validates streaming configuration — token id/secret, signing key id + RSA private key, webhook secrets, 5s smoke ping to `Mux.Video.Assets.list/1` — and reports per-profile streaming status with PASS/FAIL. | ✓ SATISFIED | Four checks in `lib/rindle/ops/runtime_checks.ex:502-740`; `--streaming` flag plumbed in `lib/mix/tasks/rindle.doctor.ex:36-58`. Pitfall 1 (`%JOSE.JWK{}` struct match) locked. WR-03 noted: doctor does not yet enforce `:rindle_provider` Oban queue when streaming-enabled — minor gap, not blocking. |
| MUX-17      | 36-02-PLAN  | `guides/streaming_providers.md` ships with a Mux-only section: env vars, signing-key creation, webhook secret rotation, raw-body cache wiring, ngrok-style local webhook tunnel, and the `mix rindle.doctor` smoke check. | ✓ SATISFIED | 341-line guide, 11 sections in correct D-10 order, cloudflared-primary local tunnel (D-11), webhook secret rotation workflow (D-13), JOSE perf footgun (D-09). WR-01 and WR-08 noted (version pin and `.html` link).                                                                |
| MUX-18      | 36-03-PLAN  | The generated-app package-consumer proof harness gains a `mux-enabled` lane (alongside the v1.5 `image-only` and `av-enabled` lanes). PR builds run cassette-based Mux fixtures by default; a gated `mux-soak` lane runs against real Mux every PR labelled `streaming`. | ⚠ SATISFIED-WITH-DEFECTS | Cassette + soak lanes wired. Cassette runs every PR (no Secrets needed); soak label-gated, fork-PR-safe trigger pattern. **CR-01 (cleanup filter), CR-02 (ETS-insert ordering), CR-03 (shared_env coupling) are operational defects** that will manifest in steady-state soak operation but do not block the lane shipping. |
| MUX-19      | 36-02-PLAN  | README and getting-started gain a "Streaming with Mux" subsection that points at `guides/streaming_providers.md`; image and AV onboarding paths remain the canonical first-run story. | ✓ SATISFIED | `README.md:242-255` and `guides/getting_started.md:364-377`; both 14 lines (≤15 cap). All six pre-existing doc-parity required strings remain present in both files.                                                                                                       |

**No orphan requirements.** REQUIREMENTS.md maps Phase 36 to MUX-15..19 (5 IDs); all 5 appear in plan frontmatter and are accounted for above.

---

## Anti-Patterns Found

| File                                                  | Line(s)         | Pattern                                                                                                       | Severity | Impact                                                                                                          |
| ----------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------- |
| `scripts/mux_soak_cleanup.sh`                         | 69-85           | Filter logic with no producer side — filter never matches (mismatched contract, not a stub literal)            | 🛑 Blocker (CR-01) | Cleanup script always emits "no soak assets found" even when leaks exist; threatens soak-lane operability over time. |
| `test/install_smoke/support/generated_app_helper.ex`  | 1271-1286       | ETS-insert ordering bug — provider_asset_id recorded AFTER assertions that can fail                             | 🛑 Blocker (CR-02) | `try/after` cleanup looks up empty ETS row when assertions fail; layer-1 cleanup useless on failure path.         |
| `test/install_smoke/support/generated_app_helper.ex`  | 912-936         | Unconditional `File.read!` on Mux fixture from `shared_env/1` regardless of profile mode                        | 🛑 Blocker (CR-03) | `:image`/`:video` runs coupled to a Mux fixture they do not need.                                                |
| `guides/streaming_providers.md`                       | 53              | Hardcoded version `~> 0.2.0` ahead of mix.exs `0.1.4`                                                          | ⚠️ Warning (WR-01) | `mix docs` preview before release-please bump tells adopters to use a non-existent Hex version.                 |
| `lib/mix/tasks/rindle.doctor.ex`                      | 36              | `_invalid` discarded — silent on unknown CLI flags                                                              | ⚠️ Warning (WR-06) | Adopter typos (`--streming`) silently no-op.                                                                    |
| `lib/rindle/ops/runtime_checks.ex`                    | 612-619         | `rescue _ ->` swallows exception class                                                                          | ⚠️ Warning (WR-10) | `mix doctor --raise` loses root-cause for future jose-version regressions.                                       |
| `test/install_smoke/support/generated_app_helper.ex`  | 421, 429        | `mux_config_block(_app_name)` accepts unused parameter                                                          | ⚠️ Warning (WR-09) | Code smell only.                                                                                                |
| `test/install_smoke/support/generated_app_helper.ex`  | 1141-1148       | `Mox.verify_on_exit!(self())` and `Mox.set_mox_from_context(%{async: false})` — non-idiomatic, accidentally working | ⚠️ Warning (WR-05) | Future Mox version-bump risk.                                                                                   |
| `lib/rindle/ops/runtime_checks.ex`                    | 434-443         | `required_queues/1` does not extend with `:rindle_provider` when streaming profile present                       | ⚠️ Warning (WR-03) | Doctor PASS misleads adopters who follow the guide.                                                             |

No `TODO`/`FIXME`/`PLACEHOLDER` markers introduced; all stub-pattern hits in the new code are either type defaults overwritten by data-flow, intentional no-op shape-symmetry blocks (cassette-mode `try/after`), or the three CR-tagged real defects above.

---

## Human Verification Required

See the `human_verification` array in the frontmatter for the structured list. The five items collapse to:

1. **Cassette package-consumer lane behavior on a real PR build** — Plan 03 explicitly defers item 1 of its verification matrix to CI; this is the proof of SC #3 + the cassette half of SC #4.
2. **`mux-soak` lane against real Mux on a `streaming`-labelled PR** — exercises the soak half of SC #4; also the only practical observable for CR-01/02 effects.
3. **HexDocs publish wire** — `mix docs` preview confirming the new `MuxWeb` module page renders and `streaming_providers.md` is in the sidebar.
4. **Fork-secret boundary on a real fork PR** — confirms `${{ secrets.RINDLE_MUX_* }}` empty-string resolution and the `if: always()` cleanup's no-credential branch behavior.
5. **Generated-app smoke test** — confirms `Rindle.InstallSmoke.GeneratedAppSmokeMuxTest` passes in the spawned Phoenix project (only observable via the package-consumer step).

---

## Gaps Summary

**No artifact-level gaps.** Every must-have surface from ROADMAP.md SC #1-5 and PLAN frontmatter must_haves is present, compiles, is wired, and (for unit-testable surfaces) passes its tests.

**The phase goal is achieved at the artifact-and-wiring level.** The two clauses of the goal — "lock the adopter onboarding path" and "prove the package-consumer story matches v1.5's bar" — both have their codebase realizations in place. The first clause is fully verified by static evidence (preset compiles, doctor checks fire, guide ships, README/getting_started updated). The second clause's CI lanes are wired; the BEHAVIORAL proof of those lanes is necessarily a CI-time observable, which is why this phase is `human_needed` rather than `passed`.

**Three review-flagged BLOCKER defects** (CR-01/02/03) are operational risks rather than missing artifacts. They are surfaced in `review_findings:` with file:line citations and fix shapes drawn from the code review. Recommended action: **before merging the v1.6 milestone**, decide whether to fix them in place (a Phase 36 closure plan) OR explicitly carry them forward as known issues (e.g., into a v0.3+ roadmap entry). They do not block proceeding to Phase 37 or to milestone close, but they would compromise the trustworthiness of the soak lane the next time it runs against real Mux with non-trivial usage.

**Nine WARNING items** range from a real-world bug (WR-01: docs pin ahead of mix.exs version) through gaps in transitive coverage (WR-04: queue config drift) to style concerns (WR-09: unused parameter). They are itemized in `review_findings.warnings`.

**Pre-existing test failures** documented in `deferred-items.md` (2 stable + 3 intermittent in `Rindle.ApplicationTest`, `Rindle.AV.FfprobeTest`, `Rindle.Processor.WaveformTest`, `Rindle.Processor.AVTest`) are unrelated to Phase 36 and confirmed against base `4d855127f`.

---

_Verified: 2026-05-07T13:59:35Z_
_Verifier: Claude (gsd-verifier)_
