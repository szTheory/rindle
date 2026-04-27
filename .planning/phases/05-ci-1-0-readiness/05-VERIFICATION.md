---
phase: 05-ci-1-0-readiness
verified: 2026-04-26T23:05:00Z
status: gaps_found
score: 11/17 must-haves verified
overrides_applied: 0
gaps:
  - truth: "CI quality lane passes mix format --check-formatted on every PR (CI-01)"
    status: failed
    reason: "`mix format --check-formatted` exits 1 against the current tree — pre-existing whitespace and long-line violations in test/rindle/upload/broker_test.exs (lines 28, 54, 56-58, 73, 86, 98, 106, 109), test/rindle/delivery_test.exs, and test/rindle/upload/proxied_test.exs (acknowledged in deferred-items.md from Plan 01) were never cleaned up. With the format step wired in CI by Plan 03, the Quality lane will fail on every PR — directly contradicting phase 5 success criterion 1 (CI passes all five lanes on every PR)."
    artifacts:
      - path: "test/rindle/upload/broker_test.exs"
        issue: "Trailing whitespace + long expect lines (lines 28, 54, 56-58, 73, 86, 98, 106, 109)"
      - path: "test/rindle/delivery_test.exs"
        issue: "Long expect lines flagged by mix format"
      - path: "test/rindle/upload/proxied_test.exs"
        issue: "Trailing whitespace (lines 23, 27)"
    missing:
      - "Run `mix format` against the listed files (or all files) and commit the result before merging phase 5"
      - "Without this fix, every PR opened against main will fail the Quality lane on CI-01"

  - truth: "CI quality lane test coverage threshold passes on every PR (CI-03)"
    status: failed
    reason: "`mix coveralls` reports 69.9% line coverage against the configured 80% minimum and exits 1 (FAILED: Expected minimum coverage of 80%, got 69.9%). Plan 03 SUMMARY noted local coverage at 71.5% and held the threshold at 80% expecting Plans 01 and 04 to close the gap; the gap actually widened. The gate is wired correctly but the lane fails on every PR until coverage rises (or the threshold is recalibrated and documented). Lowest-coverage modules: lib/rindle/storage/s3.ex 13.8%, lib/rindle/live_view.ex 15.0%, lib/rindle/workers/purge_storage.ex 0.0%, lib/rindle/workers/abort_incomplete_uploads.ex 50.0%, lib/rindle/storage/local.ex 52.3%, lib/rindle/profile/digest.ex 52.3%."
    artifacts:
      - path: "coveralls.json"
        issue: "minimum_coverage: 80 — gate is correct, but the codebase does not satisfy it"
      - path: "lib/rindle/workers/purge_storage.ex"
        issue: "0.0% covered (10 relevant lines, 10 missed)"
      - path: "lib/rindle/storage/s3.ex"
        issue: "13.8% covered (36 relevant, 31 missed) — drives the gap"
      - path: "lib/rindle/live_view.ex"
        issue: "15.0% covered (20 relevant, 17 missed)"
    missing:
      - "Either raise actual coverage above 80% (add tests for purge_storage, s3 adapter, live_view, profile/digest, abort_incomplete_uploads) OR document a temporary lower threshold per Plan 03 'coverage window' note (Warning 6) with an explicit ratchet plan back to 80%"
      - "Without this resolution every PR fails the Quality lane on CI-03"

  - truth: "CI integration lane runs upload → processing → delivery → cleanup against real MinIO + PostgreSQL and exits zero (CI-07)"
    status: partial
    reason: "The integration job exists with MinIO + Postgres services and runs the lifecycle and storage-adapter tests, but it does NOT install libvips-dev — the lifecycle integration test exercises the variant pipeline which loads the Image/Vix NIF. Without libvips the test either crashes loading or skips silently. CR-05 / WR-08 in 05-REVIEW.md flag this as a CI hygiene defect that the Quality and Adopter lanes both avoid by installing libvips. The integration lane therefore does not actually exercise the full upload → processing → delivery path it advertises."
    artifacts:
      - path: ".github/workflows/ci.yml"
        issue: "`integration` job (lines 109-192) has no `Install libvips` step before `mix test` — Quality (line 72) and Adopter (line 287) jobs both install libvips explicitly"
      - path: "test/rindle/upload/lifecycle_integration_test.exs"
        issue: "Exercises the Image/Vix processing path; requires libvips at runtime"
    missing:
      - "Add `- name: Install libvips\\n  run: sudo apt-get install -y libvips-dev` to the integration job before `mix test`"
      - "Verify the integration test isn't silently skipping the variant pipeline (audit `--include integration` filter behavior)"

  - truth: "Broker.verify_completion FSM gate is honored (UploadSession transitions are valid + persisted; Asset state machine respected)"
    status: failed
    reason: "CR-03 in 05-REVIEW.md is a real bug in code that phase 5 explicitly modified (lib/rindle/upload/broker.ex emits :upload :stop telemetry from this same `verify_completion/2` function, so the file is in phase 5's modification scope per 05-01-PLAN must_haves). The `with` chain runs `UploadSessionFSM.transition(session.state, \"verifying\", ...)` and `AssetFSM.transition(asset.state, \"validating\", ...)`, but the Multi then updates the session DIRECTLY from current state to `\"completed\"` without persisting `\"verifying\"` and without gating the actual `signed → completed` (or `uploading → completed`) transition. The locked telemetry contract emits `[:rindle, :asset, :state_change]` for a state the DB never sees; the contract test passes because it manually populates context but real Broker calls produce a corrupt state-history surface. This affects the credibility of TEL-02/03 emission semantics and breaks the FSM invariant phase 5's contract lane was supposed to lock down."
    artifacts:
      - path: "lib/rindle/upload/broker.ex"
        issue: "Lines 146-165: `verify_completion/2` gates on `verifying` then writes `completed`, bypassing the canonical `verifying → completed` transition"
    missing:
      - "Either persist `verifying` first (two-step transaction) OR run the real `signed → verifying → completed` (or `uploading → verifying → completed`) inside the multi with FSM gating for each step"
      - "Add an integration test that asserts the DB records `verifying` as an observable state (or removes `verifying` from the public state list if the intent is to skip it)"

  - truth: "Broker.profile_name_to_module/1 fails cleanly on unknown profile rather than crashing the caller"
    status: failed
    reason: "CR-04 in 05-REVIEW.md is a real bug in code phase 5 modified (lib/rindle/upload/broker.ex telemetry emission lives in this same file). `defp profile_name_to_module(name) do String.to_existing_atom(name) rescue _ -> nil end` (lines 195-199) returns `nil` on bad input. The `with` chain at line 142 then calls `nil.storage_adapter()` raising `UndefinedFunctionError` — bypassing the chain's `else` arm. This is the same code path the adopter integration test exercises; a flaky atom-table state (e.g., dropped profile module after redeploy) surfaces as a crash, not a clean `{:error, :unknown_profile}`. Phase 5's adopter lane was supposed to prove the public API is exercised end-to-end in CI; the error path is broken."
    artifacts:
      - path: "lib/rindle/upload/broker.ex"
        issue: "Lines 195-199: `profile_name_to_module/1` returns `nil` on unknown profile, propagated into `nil.storage_adapter()`"
    missing:
      - "Return `{:error, :unknown_profile}` from the helper and pattern-match in the with chain"
      - "Add a unit test exercising the unknown-profile path (assert `{:error, :unknown_profile}` not `UndefinedFunctionError`)"

  - truth: "Adopter lifecycle test exercises the full end-to-end flow (CI-08; success criterion 5.4)"
    status: partial
    reason: "test/adopter/canonical_app/lifecycle_test.exs exists with @moduletag :adopter, contains all required public API calls (Broker.initiate_session, Broker.verify_completion, Rindle.Delivery.url, Rindle.attach, Rindle.detach, :httpc.request to presigned URL), declares the D-09 TODO comment, and is wired into the CI adopter job. However: (a) the lifecycle test was not run end-to-end during this verification (requires MinIO + Postgres; CI-only), so the proof of `mix test --only adopter` exiting 0 against real services is not observable here, and (b) the upstream FSM bug (CR-03) and unknown-profile crash (CR-04) flagged above will likely affect this test path. The adopter lane wiring is real; the runtime proof is human-verification-deferred."
    artifacts:
      - path: "test/adopter/canonical_app/lifecycle_test.exs"
        issue: "Test compiled and structurally complete; runtime success against MinIO/Postgres only verifiable in CI"
    missing:
      - "Confirm the adopter lane CI job exits 0 against MinIO + Postgres on a real PR run (not just local fixture compilation)"
      - "Once CR-03 and CR-04 are fixed, re-run the adopter lane to confirm the full lifecycle still passes"

deferred:
  - truth: "Pre-existing format violations in test/rindle/upload/proxied_test.exs"
    addressed_in: "Documented in deferred-items.md as out-of-scope for Plan 01"
    evidence: "deferred-items.md notes these were pre-existing on the base commit and not introduced by Plan 01 — but the gate is now active and the violations are still present, so they have rolled forward into a phase-5 visible CI failure"

human_verification:
  - test: "Open a PR against main and confirm CI runs all five lanes (Quality, Integration, Contract, Adopter, Release dry-run)"
    expected: "All five lanes succeed end-to-end on a real PR — Quality on the matrix (1.15/26 + 1.17/27), Integration with libvips fix, Contract on 1.17/27, Adopter against MinIO + Postgres + drift gate, Release dry-run on tag-push"
    why_human: "Lane wiring is verifiable statically; lane SUCCESS requires real GitHub Actions runtime — cannot be verified locally without service containers and runner orchestration"

  - test: "Configure the `release` GitHub Actions environment in repo settings (Blocker 6 follow-up from Plan 05 SUMMARY)"
    expected: "Settings → Environments → release with required reviewers + branch restriction to `main` and `v*` tags. No HEX_API_KEY secret bound until 1.0 cutover."
    why_human: "Repo admin action — cannot be performed by a code change; required before any real Hex API key is added"

  - test: "Render mix docs HTML and visually confirm the seven guides + Mermaid stateDiagram-v2 blocks render correctly"
    expected: "doc/index.html shows all seven guides under the Guides group, and the three FSM diagrams in core_concepts.md render as interactive SVG"
    why_human: "Mermaid renders client-side via the CDN script — visual confirmation requires a browser; the `mix docs` build success only proves the markdown was emitted to HTML"

  - test: "Run mix test --only contract on a clean checkout and confirm a name-rename mutation breaks the lane"
    expected: "Renaming any of the six locked telemetry events in lib/rindle/domain/*_fsm.ex or lib/rindle/upload/broker.ex causes mix test --only contract to fail with a clear assertion message; reverting restores the green state"
    why_human: "Plan 02 SUMMARY claims this was verified locally and reverted before commit; re-running on the latest tree is the human ratchet that the contract test still detects drift"
---

# Phase 5: CI & 1.0 Readiness Verification Report

**Phase Goal:** The public API is validated by a real integration in CI, all quality gates pass on every PR, and documentation is complete enough for a Phoenix developer to ship media features on day one.

**Verified:** 2026-04-26T23:05:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

The phase produced almost all of the structural artifacts the plans called for: six telemetry emission sites, a contract lane, a quality lane with libvips + coveralls, an in-repo adopter fixture and CI job, a release-only workflow with `environment: release`, mix.exs `docs/0` wiring with Mermaid, the DOC-08 audit (`@moduledoc` on five domain schemas, `@moduledoc false` on Repo, `@doc` with `iex>` blocks on every public function in the three public-API files), and seven substantive narrative guides totaling ~1386 lines.

The phase goal, however, is NOT achieved. Two of the five locked CI lanes fail on every PR right now: the Quality lane fails `mix format --check-formatted` (pre-existing violations carried into a now-active gate) and fails `mix coveralls` (actual line coverage is 69.9% against the 80% minimum). The Integration lane is structurally present but missing the libvips-dev install that Quality and Adopter both have, so the variant pipeline it claims to exercise does not actually run. Phase 5's success criterion 1 — "CI passes all five lanes on every PR" — is materially broken.

Two correctness defects in code phase 5 modified (CR-03 broker FSM bypass, CR-04 unknown-profile crash) further weaken the credibility of the public API surface that the contract lane and the adopter lane are supposed to lock down.

The documentation surface (DOC-01..08), the contract lane (CI-06), the release lane scaffolding (CI-09), and the adopter lane structural wiring (CI-08) are all in place — those parts of the goal ARE achieved. What's broken is the "every quality gate passes on every PR" portion.

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | CI passes mix format --check-formatted on every PR (CI-01) | FAILED | `mix format --check-formatted` locally exits 1 — pre-existing violations in test/rindle/upload/broker_test.exs, delivery_test.exs, proxied_test.exs |
| 2  | CI compiles with --warnings-as-errors (CI-02) | VERIFIED | `mix compile --warnings-as-errors` exits 0; ci.yml step "Compile (warnings as errors)" present in quality job |
| 3  | CI runs mix test with coverage and fails below 80% threshold (CI-03) | FAILED | Gate is wired (coveralls.json minimum_coverage: 80, mix.exs test_coverage: ExCoveralls) but `mix coveralls` reports 69.9% and exits 1; quality lane fails on every PR |
| 4  | CI runs Credo and fails on any issue at strict level (CI-04) | VERIFIED | `mix credo --strict` exits 0; ci.yml step "Credo (strict)" present |
| 5  | CI runs Dialyzer and fails on any type error (CI-05) | VERIFIED | ci.yml step "Dialyzer" with `mix dialyzer --format github` present (PLT cache also wired) |
| 6  | CI contract lane validates telemetry event names + metadata (CI-06; success criterion 5.2) | VERIFIED | test/rindle/contracts/telemetry_contract_test.exs has @moduletag :contract, attaches handlers via :telemetry_test.attach_event_handlers/2, asserts the locked allowlist of 6 events + required :profile/:adapter metadata + numeric measurements; `mix test --only contract` passes (5 tests, 0 failures); contract job declares needs: quality |
| 7  | CI integration lane exercises upload → processing → delivery → cleanup against MinIO + Postgres (CI-07; success criterion 5.3) | PARTIAL | Job exists with services + tests, BUT does not install libvips-dev — variant pipeline cannot actually run (CR-05 / WR-08) |
| 8  | CI adopter lane verifies end-to-end media lifecycle (CI-08; success criterion 5.4) | PARTIAL | Job + test fixture wired (test/adopter/canonical_app/{repo,profile,lifecycle_test}.exs); compiles cleanly; uses :httpc.request to PUT to presigned URL; D-09 TODO comment present; runtime success against MinIO/Postgres only verifiable in CI |
| 9  | CI release lane runs hex.publish dry-run + post-publish parity check (CI-09) | VERIFIED | .github/workflows/release.yml triggers ONLY on workflow_dispatch + push tags v*; runs mix hex.build --unpack; asserts presence of lib/, mix.exs, README.md, LICENSE; asserts absence of _build, .planning, priv/plts, test, coveralls.json, .github; declares `environment: release` for Blocker 6 |
| 10 | Getting started guide is copy-pasteable upload→variant→delivery (DOC-01; success criterion 5.5) | VERIFIED | guides/getting_started.md (142 lines) contains Broker.initiate_session, Broker.verify_completion, Rindle.Delivery.url; CI drift gate (D-16) at the end of the adopter job greps for these three calls |
| 11 | Core concepts guide explains FSM lifecycles with state diagrams (DOC-02) | VERIFIED | guides/core_concepts.md (208 lines) contains 3 Mermaid stateDiagram-v2 blocks (asset / variant / upload-session); references AssetFSM, VariantFSM, UploadSessionFSM modules |
| 12 | Profiles, secure delivery, background processing, operations, troubleshooting guides (DOC-03/04/05/06/07) | VERIFIED | All five guides exist (175/197/248/177/239 lines); operations.md cross-links all five Mix tasks per D-18; troubleshooting.md covers quarantine + stale + missing + expired |
| 13 | All public modules have @moduledoc; all public functions have @doc with at least one example (DOC-08) | VERIFIED | 5 domain schemas with full @moduledoc; lib/rindle/repo.ex has @moduledoc false; lib/rindle.ex has 16 public defs with 30 iex> blocks; broker.ex has 3 public defs with 8 iex> blocks; delivery.ex has 6 public defs with 9 iex> blocks |
| 14 | All telemetry emission sites fire :telemetry.execute/3 with required profile + adapter metadata (TEL-01..08, scope addition) | VERIFIED | All 6 sites grep-confirmed (asset_fsm, variant_fsm, broker × 2, delivery, cleanup_orphans, abort_incomplete_uploads); ops/upload_maintenance.ex has 0 emission calls (worker-layer-only invariant) |
| 15 | Broker.verify_completion honors the FSM transition contract (no silent gate bypass) | FAILED | CR-03 confirmed: `verifying` is gated then never persisted, and `verifying → completed` is bypassed entirely — affects credibility of TEL-02/03 emissions phase 5 wired |
| 16 | Broker.profile_name_to_module returns a clean error tuple on unknown profile | FAILED | CR-04 confirmed: returns `nil` and the with-chain's next call `nil.storage_adapter()` raises UndefinedFunctionError — affects the same module phase 5 modified for telemetry |
| 17 | Quality matrix preserved (1.15/26 + 1.17/27); contract + adopter `needs:` waits for both matrix variants (Blocker 4) | VERIFIED | quality job has matrix.include with both Elixir/OTP combos; contract job declares `needs: quality`; adopter job declares `needs: [quality, integration, contract]` |

**Score:** 11/17 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/ci.yml` | Five-lane workflow (quality matrix, integration, contract, adopter, plus drift gate) | VERIFIED (with gap) | All four jobs present + D-16 drift gate appended; quality + adopter install libvips; integration does NOT install libvips (CR-05 / Truth 7 partial) |
| `.github/workflows/release.yml` | workflow_dispatch + push tags v*; hex.build --unpack + path assertions; environment: release | VERIFIED | All required keys present, including environment: release (Blocker 6) and dry-run auth-fallback comment |
| `mix.exs` | excoveralls dep, test_coverage tool, preferred_cli_env, ex_doc 0.40, package files allowlist, docs/0 with extras + groups + Mermaid, elixirc_paths(:test) includes test/adopter | VERIFIED | All wiring present; package files allowlist verified; docs build succeeds |
| `coveralls.json` | minimum_coverage: 80 + skip_files | VERIFIED (gate works; coverage is below threshold) | File correct; current coverage 69.9% — see Truth 3 gap |
| `test/test_helper.exs` | excludes :integration, :minio, :contract, :adopter | VERIFIED | `ExUnit.start(exclude: [:integration, :minio, :contract, :adopter])` |
| `test/rindle/contracts/telemetry_contract_test.exs` | @moduletag :contract; allowlist + metadata + numeric measurement assertions | VERIFIED | 192 lines; passes locally with `mix test --only contract` |
| `test/adopter/canonical_app/{repo,profile,lifecycle_test}.exs` | Adopter Repo + Profile + lifecycle test with @moduletag :adopter, :httpc PUT, D-09 TODO | VERIFIED | All three files exist and compile; lifecycle test contains canonical adopter calls + httpc PUT + TODO comment |
| `guides/*.md` (7 files) | Substantive narrative guides per DOC-01..07 | VERIFIED | All seven files present, 142–248 lines each; content markers present |
| `LICENSE` | Required for Hex package files allowlist | VERIFIED | Present at repo root; included in package |
| Domain schemas (5 files) | Full @moduledoc per D-17 | VERIFIED | All five domain schema files have `@moduledoc """` blocks |
| `lib/rindle/repo.ex` | @moduledoc false | VERIFIED | grep -c "@moduledoc false" returns 1 |
| Six telemetry emission sites | :telemetry.execute/3 calls | VERIFIED | All six sites grep-confirmed; worker-layer-only invariant intact |
| Public API @doc coverage (rindle.ex, broker.ex, delivery.ex) | At least one iex> per public def | VERIFIED | 30/16, 8/3, 9/6 (iex>/public defs) — exceeds 1:1 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| FSM modules + broker + delivery + workers | :telemetry | `:telemetry.execute/3` calls in success branches | WIRED | All six emission sites grep-confirmed; ops/upload_maintenance has zero emissions (worker-layer-only) |
| test/rindle/contracts/telemetry_contract_test.exs | FSM modules + delivery | In-process function calls + assert_received | WIRED | Contract test passes locally; mutation acceptance documented in 05-02-SUMMARY |
| .github/workflows/ci.yml (contract job) | telemetry contract test | `mix test --only contract` step | WIRED | Step present; needs: quality preserves matrix gating |
| .github/workflows/ci.yml (adopter job) | adopter lifecycle test | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs` | WIRED (runtime unverified) | Step present; runtime success only verifiable on a real PR run |
| .github/workflows/ci.yml (adopter job) | guides/getting_started.md | grep step (D-16 drift gate) | WIRED | Drift gate appended after `Run adopter tests`; greps Broker.initiate_session, Broker.verify_completion, Rindle.Delivery.url |
| .github/workflows/release.yml | mix.exs package/0 | mix hex.build --unpack reads files: allowlist | WIRED | Local hex.build produces expected tarball with required + no forbidden paths |
| mix.exs docs/0 | guides/*.md | extras: explicit list (no glob — Pitfall 6) | WIRED | All seven guides listed; mix docs builds 0 |
| mix.exs docs/0 | Mermaid CDN | before_closing_head_tag/1 returns inline JS | WIRED | Function defined; ExDoc emits the script tag in HTML target |
| .github/workflows/ci.yml (integration job) | libvips system dep | (none — gap) | NOT_WIRED | No `Install libvips` step in integration job (CR-05); compare to lines 72 and 287 of the file where libvips is installed for quality and adopter |
| Broker.verify_completion FSM gate | UploadSessionFSM | `with :ok <- UploadSessionFSM.transition(session.state, "verifying", ...)` | PARTIAL | Gate is called but `verifying` state is never persisted; subsequent `signed → completed` (or `uploading → completed`) is not gated (CR-03) |
| Broker.profile_name_to_module | profile_module | `String.to_existing_atom + rescue → nil` | NOT_WIRED | Returns nil instead of an error tuple; the next call in the with-chain raises (CR-04) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| Telemetry contract test | measurements / metadata | Real `:telemetry.execute/3` calls in lib/rindle/* (Plan 01) | Yes — verified by `mix test --only contract` | FLOWING |
| Adopter lifecycle test | session, asset, variant, attachment | Broker.initiate_session → S3 PUT → verify_completion → PromoteAsset → ProcessVariant → Delivery.url → attach/detach | Cannot run locally without MinIO + Postgres; runtime data-flow unverified | UNCERTAIN |
| coveralls.json gate | minimum_coverage threshold | mix coveralls computes against actual test execution | 69.9% measured against 80% threshold | STATIC (gate works; coverage source is real but value below threshold) |
| guides/getting_started.md snippet | Broker.initiate_session / verify_completion / Rindle.Delivery.url | Author-typed prose mirrored from adopter test | Snippet text matches CI grep regex | FLOWING (drift gate enforces) |
| guides/core_concepts.md state diagrams | Mermaid stateDiagram-v2 blocks | Author-typed prose; states should match @allowed_transitions in FSM modules | Visual rendering depends on browser + CDN script (human verification required) | UNCERTAIN |
| Release lane file allowlist | files: ~w(...) in mix.exs package/0 | mix hex.build reads allowlist; release.yml asserts | Local hex.build confirms required + forbidden paths | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Default `mix test` excludes gated lanes and passes | `mix test` | 160 tests, 0 failures, 11 excluded | PASS |
| Contract lane runs and passes | `mix test --only contract` | 5 tests, 0 failures, 166 excluded | PASS |
| Telemetry emission unit tests pass | `mix test test/rindle/telemetry/emission_test.exs` | 6 tests, 0 failures | PASS |
| Broker tests pass (existing + telemetry additive) | `mix test test/rindle/upload/broker_test.exs` | 8 tests, 0 failures | PASS |
| Delivery tests pass | `mix test test/rindle/delivery_test.exs` | 10 tests, 0 failures | PASS |
| `mix compile --warnings-as-errors` succeeds | `mix compile --warnings-as-errors` | exit 0 | PASS |
| `mix credo --strict` succeeds | `mix credo --strict` | exit 0 | PASS |
| `mix format --check-formatted` succeeds | `mix format --check-formatted` | exit 1 — unformatted files in test/rindle/upload/{broker,proxied}_test.exs and test/rindle/delivery_test.exs | FAIL |
| `mix coveralls` clears 80% threshold | `mix coveralls` | exit 1 — 69.9% < 80% (FAILED: Expected minimum coverage of 80%) | FAIL |
| `mix hex.build --unpack` emits a clean tarball | `mix hex.build --unpack` + `ls rindle-*/lib/rindle.ex rindle-*/mix.exs rindle-*/README.md rindle-*/LICENSE` + absence of _build, .planning, priv/plts, test, coveralls.json, .github | All required paths present; all forbidden paths absent | PASS |
| `mix docs` builds successfully | `mix docs` | exit 0; doc/index.html emitted; one cosmetic warning about Phoenix.LiveView.Upload.allow_upload/3 hidden ref | PASS |
| Adopter lane runs end-to-end against MinIO+Postgres | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs` | Skipped — requires real MinIO + Postgres | SKIP (route to human) |
| Release workflow logic against real tag push | `gh workflow run release` | Skipped — requires GitHub Actions environment + admin | SKIP (route to human) |
| Integration lane libvips presence | `grep -c libvips .github/workflows/ci.yml integration block` | 0 in integration block (compared to 1 in quality, 1 in adopter) | FAIL (gap) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CI-01 | 05-03 | mix format --check-formatted gate | BLOCKED | Gate wired in CI; format check exits 1 locally — Quality lane fails on every PR |
| CI-02 | 05-03 | mix compile --warnings-as-errors | SATISFIED | Step in quality job; clean compile locally |
| CI-03 | 05-03 | mix coveralls 80% line threshold | BLOCKED | Gate wired (coveralls.json + mix.exs test_coverage); actual 69.9% < 80% — fails on every PR |
| CI-04 | 05-03 | Credo strict | SATISFIED | Step in quality job; clean run locally |
| CI-05 | 05-03 | Dialyzer | SATISFIED | Step in quality job; PLT cache wired |
| CI-06 | 05-02 | Telemetry contract test | SATISFIED | Contract job + telemetry_contract_test.exs; mutation-tested locally per 05-02 SUMMARY |
| CI-07 | (preserved) | Integration lane against MinIO + Postgres | BLOCKED | Job exists and runs lifecycle test; missing libvips means the variant pipeline cannot actually run (CR-05) |
| CI-08 | 05-04 | Adopter lane canonical lifecycle | SATISFIED (structurally) — runtime needs human | All structural artifacts present; runtime CI run needs to be observed |
| CI-09 | 05-05 | Release lane dry-run + parity | SATISFIED | release.yml triggers + hex.build inspection + environment: release |
| DOC-01 | 05-07 | Getting started guide | SATISFIED | guides/getting_started.md (142 lines) with canonical adopter calls; D-16 drift gate active |
| DOC-02 | 05-07 | Core concepts + state diagrams | SATISFIED | 3 Mermaid stateDiagram-v2 blocks; references all three FSMs |
| DOC-03 | 05-07 | Profile DSL guide | SATISFIED | guides/profiles.md (175 lines) with `use Rindle.Profile` |
| DOC-04 | 05-07 | Secure delivery guide | SATISFIED | guides/secure_delivery.md (197 lines); covers signed URLs and authorizer |
| DOC-05 | 05-07 | Background processing guide | SATISFIED | guides/background_processing.md (248 lines); Oban + telemetry coverage |
| DOC-06 | 05-07 | Operations guide | SATISFIED | guides/operations.md (177 lines); cross-links all 5 Mix tasks |
| DOC-07 | 05-07 | Troubleshooting guide | SATISFIED | guides/troubleshooting.md (239 lines); covers quarantine + stale + missing + expired |
| DOC-08 | 05-06 | All public modules + functions documented | SATISFIED | 5 domain schemas, repo.ex (@moduledoc false), 16+3+6 public defs each with iex> example |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| lib/rindle/upload/broker.ex | 195-199 | `rescue _ -> nil` swallows ArgumentError and returns nil into a chain that calls `.storage_adapter()` | BLOCKER | UndefinedFunctionError raised mid-with-chain instead of {:error, :unknown_profile} (CR-04) |
| lib/rindle/upload/broker.ex | 146-165 | FSM transition gated for "verifying" then DB jumps to "completed" without persisting "verifying" | BLOCKER | Telemetry event fires for a state the DB never sees; `verifying → completed` gate bypassed; FSM evasion on the most-exercised path (CR-03) |
| .github/workflows/ci.yml | 109-192 | Integration job lacks `Install libvips` step that quality and adopter jobs both have | BLOCKER | Variant pipeline tests either crash on Image/Vix NIF load or skip silently (CR-05 / WR-08) |
| test/rindle/upload/broker_test.exs | 28, 54, 56-58, 73, 86, 98, 106, 109 | Trailing whitespace + long lines fail mix format --check-formatted | BLOCKER | Quality lane CI-01 fails on every PR until cleaned up |
| test/rindle/delivery_test.exs | (multiple) | Long expect lines fail mix format --check-formatted | BLOCKER | Same as above |
| test/rindle/upload/proxied_test.exs | 23, 27 | Trailing whitespace fails mix format --check-formatted | BLOCKER | Same as above |
| coveralls.json | 4 | `treat_no_relevant_lines_as_covered: true` masks empty / dead modules | INFO | WR-09 — pragmatic exception but documents the trade-off; not a phase-5 blocker on its own |
| guides/troubleshooting.md | 215 | `ago(0, "second")` Ecto fragment is misleading; readers may copy the idiom | INFO | IN-01 in 05-REVIEW — documentation correctness, not CI failure |

### Human Verification Required

1. **CI lanes pass on a real PR run**

**Test:** Open a PR against main and observe all five lanes (Quality matrix, Integration, Contract, Adopter, Release dry-run on tag push) on the GitHub Actions UI.
**Expected:** Every lane is green; Quality runs both 1.15/26 and 1.17/27 matrix variants; Adopter passes the lifecycle + drift gate; Integration runs against MinIO + Postgres without skipping.
**Why human:** Lane wiring is verifiable statically; lane runtime success requires real GitHub Actions runners with service containers. The known gaps (CI-01 format, CI-03 coverage, CI-07 missing libvips) MUST be addressed before this verification will succeed.

2. **`release` GitHub Actions environment configured (Blocker 6 follow-up)**

**Test:** In repo Settings → Environments, create the `release` environment with required reviewers + branch restriction to `main` and `v*` tags.
**Expected:** `release` environment exists with protection rules; no HEX_API_KEY secret bound until 1.0 cutover.
**Why human:** Repo admin action only — cannot be performed by a code change.

3. **Mermaid state diagrams render correctly in HexDocs HTML**

**Test:** Open `doc/index.html` after running `mix docs`; navigate to Core Concepts; visually confirm all three Mermaid `stateDiagram-v2` blocks render as interactive SVG.
**Expected:** Three readable state diagrams (asset / variant / upload-session) with the states matching `@allowed_transitions` in the corresponding FSM modules.
**Why human:** Mermaid rendering happens client-side via the CDN script; the `mix docs` build only emits the markdown to HTML — the visual rendering must be inspected in a browser.

4. **Contract lane mutation ratchet still works on the latest tree**

**Test:** Rename `[:rindle, :asset, :state_change]` to `[:rindle, :asset, :transitioned]` in lib/rindle/domain/asset_fsm.ex; run `mix test --only contract`; confirm at least 2 assertions fail; revert the mutation.
**Expected:** Contract test fails on the renamed event; revert restores the green state.
**Why human:** Plan 02 SUMMARY says the mutation was verified locally at the time of the plan; phase verification should re-prove the ratchet still functions on the current tree (mutation testing is non-idempotent and the destructive step shouldn't be automated in this verifier).

### Gaps Summary

The structural deliverables of phase 5 are complete. The narrative guides exist and are substantive. The contract lane locks the public telemetry surface. The release workflow is dry-run-safe. The adopter lane is wired into CI with the D-16 drift gate. DOC-08 audit is done across the public API surface. ex_doc 0.40 + Mermaid renderer + groups_for_extras are in place; `mix docs` builds successfully.

What is missing is the lived behavior the phase goal requires:

1. **Quality lane fails on every PR.** Two of the five gates Plan 03 wired (`mix format --check-formatted` and `mix coveralls`) currently exit non-zero locally. The format violations are the same ones documented in deferred-items.md from Plan 01 — they were known to be pre-existing but were left for the format CI job to surface, and Plan 03 wired the gate without cleaning up the violations. The coverage shortfall is more material: 69.9% vs the 80% target (worse than the 71.5% Plan 03 reported). Fixing this requires either raising actual coverage or recalibrating the threshold with documented intent — Plan 03's "Warning 6 coverage window" note anticipated this scenario.

2. **Integration lane is missing libvips.** A code-review finding (CR-05 / WR-08) that the integration job doesn't install libvips-dev even though it tests the variant pipeline. Quality and Adopter both install it. Without libvips the variant pipeline test either crashes loading or silently skips — neither outcome is what the lane should advertise. One-line fix.

3. **Two correctness defects in code phase 5 modified.** CR-03 (broker FSM gate bypass: `verifying` is gated then never persisted; `signed/uploading → completed` is not gated) and CR-04 (`profile_name_to_module` returns nil into a call chain that crashes) are real bugs in lib/rindle/upload/broker.ex — the same file phase 5 added telemetry emission to. They affect the credibility of the public-API surface phase 5 was supposed to lock down. Both have specific fixes in 05-REVIEW.md.

The structural ratio is high (11/17 truths verified; all DOC-01..08 + CI-02/04/05/06/09 satisfied), but the failure surface (CI-01 / CI-03 / CI-07 + two correctness bugs) is exactly what the phase's success criterion 1 forbids: "all quality gates pass on every PR." Until those are resolved, a Phoenix developer cloning the repo and opening a PR will see a red Quality lane immediately, and the canonical adopter-facing flow they're following from `guides/getting_started.md` carries a latent crash on unknown profiles.

Recommended closure plan for `/gsd-plan-phase --gaps`:
- **Plan 08 (CI fix-ups):** mix format the three test files; recalibrate coveralls threshold or add coverage; add libvips install to the integration job. Single PR.
- **Plan 09 (broker correctness):** fix CR-03 (FSM gating in verify_completion) and CR-04 (profile_name_to_module return shape) with the patches in 05-REVIEW.md; add unit tests for both paths.

---

_Verified: 2026-04-26T23:05:00Z_
_Verifier: Claude (gsd-verifier)_
