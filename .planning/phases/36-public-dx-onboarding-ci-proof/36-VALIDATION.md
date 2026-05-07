---
phase: 36
slug: public-dx-onboarding-ci-proof
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-07
---

# Phase 36 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 36-RESEARCH.md `## Validation Architecture` (23 requirement→test rows).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.17 / OTP 27); generated-app smoke = bash + ExUnit |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `scripts/install_smoke.sh` |
| **Quick run command** | `mix test test/rindle/profile/presets/mux_web_test.exs test/rindle/ops/runtime_checks_streaming_test.exs` (~2s, Plan 01); `mix test --include doc_parity` (~5s, Plan 02) |
| **Full suite command** | `mix test` for unit/integration; `bash scripts/install_smoke.sh mux` for cassette lane (~90s, Plan 03) |
| **Estimated runtime** | Plan 01 ~2s · Plan 02 ~5s · Plan 03 ~90s (cassette) / ~120s (real-Mux soak) |

---

## Sampling Rate

- **After every task commit:** Run the plan-specific quick command (Plan 01 ~2s, Plan 02 ~5s, Plan 03 ~90s)
- **After every plan wave:** Run `mix test` (unit/integration full suite)
- **Before `/gsd-verify-work`:** Full suite green + `bash scripts/install_smoke.sh all` cassette mode green
- **Max feedback latency:** 90s (Plan 03 cassette is the long pole; Plans 01/02 are sub-10s)

---

## Per-Task Verification Map

> Authoritative source: `36-RESEARCH.md` § "Validation Architecture (Nyquist Dimension 8)". Planner refines task IDs once PLAN.md files are emitted.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 36-01-* | 01 | 1 | MUX-15 (D-01..D-04) | — | MuxWeb compiles + DSL accepts streaming block; `web_720p`+`poster` variants identical to `Web` | unit | `mix test test/rindle/profile/presets/mux_web_test.exs` | ❌ W0 | ⬜ pending |
| 36-01-* | 01 | 1 | MUX-16 (D-05) | — | Four `defp check_streaming_*` clauses appended to checks list (44-54) | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs --only streaming_checks` | ❌ W0 | ⬜ pending |
| 36-01-* | 01 | 1 | MUX-16 (D-06) | — | Profile-discovery gate: emits `ok_result` with `"No streaming-enabled profiles discovered."` when `Capability.report/0.streaming.configured_profiles == []` | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs --only profile_gate` | ❌ W0 | ⬜ pending |
| 36-01-* | 01 | 1 | MUX-16 (D-07) | — | `--streaming` opt: smoke ping skipped when absent ("Smoke ping skipped..."); runs with 5s Task.shutdown timeout when present | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs --only flag_gate` | ❌ W0 | ⬜ pending |
| 36-01-* | 01 | 1 | MUX-16 (D-08) | — | All five smoke-ping branches (200/401-403/429/timeout/other) match the locked fix-recipe taxonomy | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs --only smoke_ping_branches` | ❌ W0 | ⬜ pending |
| 36-01-* | 01 | 1 | MUX-16 (D-05 signing-key) | — | `JOSE.JWK.from_pem/1` parse smoke against fixture key returns `%JOSE.JWK{}` not `[]` (pitfall #1) | unit | `mix test test/rindle/ops/runtime_checks_streaming_test.exs --only signing_key_parse` | ❌ W0 | ⬜ pending |
| 36-02-* | 02 | 1 | MUX-17 (D-09..D-13) | — | `guides/streaming_providers.md` exists; appears in `mix.exs` extras; `cloudflared` mentioned before `ngrok` in tunnel section | doc | `mix docs --formatter html && grep -q "Streaming Providers" doc/index.html` | ❌ W0 | ⬜ pending |
| 36-02-* | 02 | 1 | MUX-19 (D-25..D-26) | — | README.md and `guides/getting_started.md` each contain "Streaming with Mux (optional)" subsection ≤15 lines, placed after canonical AV path | doc | `awk '/Streaming with Mux \(optional\)/{flag=1;next}/^##/{flag=0}flag' README.md \| wc -l` (≤15) | ❌ W0 | ⬜ pending |
| 36-02-* | 02 | 1 | MUX-19 (D-27) | — | doc-parity guard CI step contains `Rindle.Profile.Presets.MuxWeb` in required-strings list | doc | `grep -E "REQUIRED in .*Rindle\.Profile\.Presets\.MuxWeb" .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 36-02-* | 02 | 1 | MUX-19 (D-28) | — | doc-parity guard's existing required strings (`Rindle.Profile.Presets.Web`, `Rindle.initiate_upload`, …) untouched | doc | `git diff main -- .github/workflows/ci.yml \| grep -E "^-.*REQUIRED in"` (must be empty) | ✅ | ⬜ pending |
| 36-02-* | 02 | 1 | MUX-19 (negative regex) | T-36-DOC-PARITY | doc-parity negative regex still bans `Rindle\.Delivery\.url`; new content uses `streaming_url` (pitfall #4) | doc | `! grep -E 'Rindle\.Delivery\.url\b' guides/streaming_providers.md README.md guides/getting_started.md` | ✅ | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-14, D-15) | — | `:mux` profile mode dispatches; `selected_profiles/0` returns `[:mux]` for `RINDLE_INSTALL_SMOKE_PROFILE=mux`; lifecycle assertions include `["poster", "web_720p"]` and Mux-signed-HLS-URL JWT-decode | smoke | `RINDLE_INSTALL_SMOKE_PROFILE=mux bash scripts/install_smoke.sh mux` | ❌ W0 | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-16) | — | Mox-on-`:http_client`-config seam wires `Rindle.Streaming.Provider.Mux.ClientMock`; `set_mox_from_context` set for cross-process worker stubs (pitfall #2) | smoke | `RINDLE_INSTALL_SMOKE_PROFILE=mux mix test test/install_smoke/generated_app_smoke_test.exs` | ❌ W0 | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-17) | T-36-FIXTURE-LEAK | `shared_env/1` sets the five `RINDLE_MUX_*` fixture env vars; private key from `test/fixtures/mux/test_signing_private_key.pem`; lane never hits `api.mux.com` in cassette mode | smoke | `RINDLE_INSTALL_SMOKE_PROFILE=mux bash scripts/install_smoke.sh mux 2>&1 \| ! grep -q "api.mux.com"` | ❌ W0 | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-18) | — | `scripts/install_smoke.sh` `case` accepts `mux`; `package-consumer` job in `.github/workflows/ci.yml` runs the new step on every PR | smoke | `bash scripts/install_smoke.sh mux` exits 0 | ❌ W0 | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-19, D-20) | T-36-FORK-SECRETS | `mux-soak` job is sibling (not nested step); label-gated `streaming`; uses `pull_request` not `pull_request_target`; `pull_request.types` includes `labeled` | ci-config | `yq '.on.pull_request.types' .github/workflows/ci.yml \| grep -q labeled && yq '.jobs.mux-soak.if' .github/workflows/ci.yml \| grep -q streaming` | ❌ W0 | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-21) | — | `RINDLE_MUX_USE_REAL_API=1` flips `:http_client` to `Rindle.Streaming.Provider.Mux.HTTP`; absent → `ClientMock` | smoke | `RINDLE_MUX_USE_REAL_API=1 grep -q 'http_client: Rindle.Streaming.Provider.Mux.HTTP' generated_app/config/test.exs` (post-patch) | ❌ W0 | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-22) | T-36-ASSET-LEAK | Soak-lane `try/after` deletes asset on failure; `if: always()` cleanup step runs `scripts/mux_soak_cleanup.sh`; both required by Mux 10-asset cap | smoke | (manual: trigger soak with `RINDLE_FORCE_FAIL=1`, confirm asset deleted; `mix run scripts/mux_soak_cleanup.sh` is idempotent) | ❌ W0 | manual |
| 36-03-* | 03 | 1 | MUX-18 (D-23) | — | Soak lane stays under Mux rate-limit budget (1 RPS POST, 5 RPS GET/DELETE); end-to-end ≤90s | smoke | `time bash scripts/install_smoke.sh mux` < 120s | ❌ W0 | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-24) | T-36-FORK-SECRETS | Five required GitHub Secrets are referenced in `mux-soak.env`; fork PRs labeled `streaming` resolve secrets to empty → fail closed (security boundary) | ci-config | `yq '.jobs.mux-soak.env' .github/workflows/ci.yml \| grep -c "RINDLE_MUX_"` == 5 | ❌ W0 | ⬜ pending |
| 36-03-* | 03 | 1 | MUX-18 (D-22 cleanup script) | T-36-ASSET-LEAK | `scripts/mux_soak_cleanup.sh` lists + deletes test-tagged assets idempotently | smoke | `bash scripts/mux_soak_cleanup.sh --dry-run` exits 0 | ❌ W0 | ⬜ pending |
| 36-02-* | 02 | 2 | MUX-17 (D-13 source-of-truth) | — | guide Step 5 references `lib/rindle/delivery/webhook_plug.ex` `@moduledoc` verbatim or via `<!-- source: ... -->` HTML comment | doc | `grep -E 'webhook_plug.ex.*@moduledoc\|<!-- source: lib/rindle/delivery/webhook_plug.ex' guides/streaming_providers.md` | ✅ | ⬜ pending |
| 36-02-* | 02 | 2 | MUX-19 (D-33 changelog) | — | `CHANGELOG.md` v0.2.0 entry mentions `Rindle.Profile.Presets.MuxWeb`, `mix rindle.doctor --streaming`, `streaming_providers.md`, `mux-enabled` lane | doc | `grep -E 'MuxWeb\|--streaming\|streaming_providers\|mux-enabled' CHANGELOG.md` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `test/rindle/profile/presets/mux_web_test.exs` — preset compile + DSL validation tests (D-31)
- [ ] `test/rindle/ops/runtime_checks_streaming_test.exs` — four streaming check tests with `describe` blocks per RESEARCH §Open Question 4 (D-31)
- [ ] `test/fixtures/mux/test_signing_public_key.pem` — public half of existing private key (D-31; or derive in-test via `JOSE.JWK.to_public/1` per RESEARCH Open Question 1)
- [ ] `Rindle.Streaming.Provider.Mux.ClientMock` Mox behaviour stub registration in `test/test_helper.exs` (already present from Phase 34 D-34 — verify it stays)
- [ ] `scripts/mux_soak_cleanup.sh` — soak-lane belt-and-suspenders cleanup (D-22, D-31)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Soak-lane real-Mux end-to-end happy path | MUX-18 (D-22) | Requires real Mux credentials in maintainer's account; cannot run on every PR (10-asset cap pressure). | Apply `streaming` label to a PR; observe `mux-soak` job pass; `if: always()` cleanup step runs to green; verify `Mux.Video.Assets.list/1` shows zero `test-asset-*` survivors after run. |
| HexDocs reachability after v0.2.0 publish | MUX-17 (D-09 + Phase 21 reachability probe) | Requires successful Hex publish first (release-please flow). | After v0.2.0 ships: `curl -fsSL https://hexdocs.pm/rindle/streaming_providers.html` → 200; existing reachability probe verifies. |
| Cassette lane CI run inspection | MUX-18 (D-18) | First-run inspection ensures the new step is wired into the right job, not a dangling step. | Open the first PR after Plan 03 merges; confirm `Run built-artifact Mux-enabled package-consumer proof (cassette mode)` appears in `package-consumer` job logs and exits 0. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (5 items above)
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s (cassette is the long pole; Plans 01/02 sub-10s)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
