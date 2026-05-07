# Phase 36: Public DX, Onboarding, CI Proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-07
**Phase:** 36-public-dx-onboarding-ci-proof
**Mode:** assumptions (research-driven one-shot per `STATE.md` Decision-Making Preference and `memory/feedback_research_driven_one_shot.md`)
**Areas analyzed:** MuxWeb Preset Shape, `mix rindle.doctor` Streaming Checks, `guides/streaming_providers.md` Structure, Generated-App `:mux` Profile Mode, CI Lane Wiring, README + getting_started.md Subsection Placement

## Assumptions Presented

### MuxWeb Preset Shape

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Wrap `Rindle.Profile.Presets.Web` verbatim, inject locked 4-key `:streaming` block, passthrough opts | Confident | `lib/rindle/profile/presets/web.ex:18-43`, Phase 33 D-15 schema, `lib/rindle/profile/validator.ex:283-312`, candidate memo §2 MUX-15 |
| No `__using__/1` opt-out for streaming; preset compiles when `:mux` absent | Confident | Phase 34 D-31 optional-dep guard, `lib/rindle/profile/validator.ex:62-65`, `lib/rindle/capability.ex:121-133` |

### `mix rindle.doctor` Streaming Checks

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Four checks added to `Rindle.Ops.RuntimeChecks.run/2`; smoke ping `--streaming` opt-in | Likely | `lib/rindle/ops/runtime_checks.ex:33-251`, `lib/mix/tasks/rindle.doctor.ex:33-50`, REQUIREMENTS MUX-16 |
| Profile-discovery gating; emits ok_result when no streaming-enabled profile | Confident | `runtime_checks.ex:225-233` (`check_local_playback` precedent), Phase 33 D-30, Phase 34 D-33 |

### `guides/streaming_providers.md` Structure

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Single Mux-only guide, 11 locked sections, mirrors `secure_delivery.md` style | Likely | REQUIREMENTS MUX-17, `lib/rindle/delivery/webhook_plug.ex:5-23` moduledoc, candidate memo §1 #2 single-provider scope |
| Local-tunnel section: cloudflared primary, ngrok alternative-with-caveat | Likely → **Confident after research** | REQUIREMENTS MUX-17 "ngrok-style" (concept, not brand); 2026 ngrok signup wall + cloudflared TryCloudflare free path |

### Generated-App `:mux` Profile Mode

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `:mux` as third value to `profile_mode`; reuse `:video` lane assertions verbatim | Confident | `test/install_smoke/support/generated_app_helper.ex:14-19, 866-981, 857-864`, REQUIREMENTS MUX-19 |
| Cassette/replay via Phase 34 Mox-on-`:http_client`-config seam (NOT Bypass, NOT ExVCR) | Confident | Phase 34 D-34/D-35 (rejected alternatives explicitly), `lib/rindle/streaming/provider/mux.ex:46-49`, `test/fixtures/mux/*.json` already committed |

### CI Lane Wiring

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `mux-enabled` cassette step added to `package-consumer` job | Likely | `.github/workflows/ci.yml:284-391`, `scripts/install_smoke.sh:9, 19`, REQUIREMENTS MUX-18 |
| Separate top-level `mux-soak` job, label-gated `streaming`, `pull_request` (NOT `_target`) | Likely → **Confident after research** | `.github/workflows/ci.yml:393-545` template, GitHub Security Lab pull_request vs pull_request_target boundary, candidate memo §1 #11 |
| Mandatory `try/after` + `if: always()` cleanup; Mux free-tier 10-asset cap | **Confident after research** | Mux pricing page 2026; per-PR cost $0; 10-stored-asset hard cap |

### README + getting_started.md "Streaming with Mux" Subsection

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Both files gain ≤15-line subsection AFTER canonical AV path; doc-parity guard adds `Rindle.Profile.Presets.MuxWeb` | Confident | REQUIREMENTS MUX-19, `.github/workflows/ci.yml:518-545` doc-parity guard, `guides/secure_delivery.md:64` "(Explicit Opt-In)" naming pattern |

## Corrections Made

No corrections — all assumptions confirmed by research. Three Likely → Confident promotions via external research subagent.

## External Research

External research subagent was spawned to resolve three open gaps flagged by the assumptions analyzer. All three resolved to actionable findings:

### Topic 1 — GitHub Actions PR-label-gated job pattern (security-critical)

- **Finding:** `pull_request` (NOT `pull_request_target`) + `if: contains(github.event.pull_request.labels.*.name, 'streaming')` at the **job** level + `on.pull_request.types: [opened, synchronize, reopened, labeled]` is the canonical 2026 syntax. Fork PRs labeled `streaming` will fire the lane but secrets resolve to empty strings → lane fails closed → no leak. The `labeled` activity type MUST be added to `types:` explicitly (default does not include it). The known label-race-condition (attacker pushes new code after labeling) does NOT apply because `pull_request` runs in a fork-secret-free environment, unlike `pull_request_target`.
- **Sources:**
  - https://docs.github.com/en/actions/using-jobs/using-conditions-to-control-job-execution
  - https://github.com/orgs/community/discussions/26261
  - https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/
  - https://github.blog/changelog/2025-11-07-actions-pull_request_target-and-environment-branch-protections-changes/
- **Confidence impact:** "label-gated `mux-soak` lane is safe for fork PRs" Likely → **Confident**. Locked into D-19, D-20.

### Topic 2 — Mux developer free-tier limits (2026)

- **Finding:** Mux's free plan in 2026 supports up to 10 stored on-demand videos, 100K free monthly delivery minutes, no credit card required. Per-PR soak-lane cost (one create + poll + delete cycle, ~10MB mp4): **$0**. At 50 PRs/month: $0. The 10-stored-asset hard cap means failed cleanup blocks subsequent PRs. Rate limits: POST sustained 1 RPS (asset create fits — one per PR), GET/DELETE sustained 5 RPS (polling cadence ~1/sec is fine).
- **Sources:**
  - https://www.mux.com/pricing
  - https://www.mux.com/docs/pricing.txt
  - https://www.mux.com/docs/core/make-api-requests
  - https://www.mux.com/docs/api-reference/video/assets
- **Confidence impact:** "soak lane fits within Mux free tier" Likely → **Confident**. Locked into D-22 (mandatory delete-on-finally + `if: always()` cleanup step + safety-net sweep script) and D-23 (rate-limit budget verification).

### Topic 3 — Local webhook tunnel: cloudflared vs ngrok (2026)

- **Finding:** ngrok's free tier (Feb 2026) requires signup + auth-token install before a single tunnel will start; 2-hour session cap; random URLs only; 1GB bandwidth; 40 req/min throttle. cloudflared's TryCloudflare quick tunnel (`cloudflared tunnel --url http://localhost:4000`) is still free, ephemeral, no signup, no auth token; limits are 200 concurrent in-flight requests + no SSE — both fine for Mux webhook volume. Mux has no first-party "Mux CLI" (unlike Stripe's `stripe listen`); the most-linked Mux+webhook tutorial historically lived on ngrok's own integration docs but ngrok's 2026 friction inverts the historical default.
- **Sources:**
  - https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/
  - https://try.cloudflare.com/
  - https://ngrok.com/pricing
  - https://ngrok.com/docs/integrations/webhooks/mux-webhooks
  - https://docs.stripe.com/webhooks
- **Confidence impact:** "lead with cloudflared in webhook tunnel guide" Likely → **Confident**. Locked into D-11.
</content>
</invoke>