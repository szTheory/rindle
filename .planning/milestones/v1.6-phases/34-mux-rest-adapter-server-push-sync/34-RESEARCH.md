# Phase 34: Mux REST Adapter + Server-Push Sync — Research

**Researched:** 2026-05-06
**Domain:** Elixir streaming-provider adapter (Mux REST), Oban workers, signed-JWT playback URLs
**Confidence:** HIGH for SDK signatures, Oban contract, and security invariant 14; MEDIUM on a few details flagged below as memo corrections

## Summary

Phase 34 is the first concrete adapter against the Phase 33 `Rindle.Streaming.Provider`
behaviour. CONTEXT.md is unusually comprehensive: 43 locked decisions (D-01..D-43)
covering optional-dep posture, SDK signatures, atomic-promote race protection, telemetry
contracts, the Mox+behaviour test pattern, and security invariant 14 redaction. Two
upstream parallel research subagents already verified Mux SDK 3.2.x and Oban 2.21+ and
folded their findings into CONTEXT.md as four memo corrections (D-04, D-06, D-10, D-21).

This research is **not** a re-derivation of those decisions. It is a focused
verification + gap-fill pass:

1. **Spot-checked SDK signatures** against the live mux-elixir source on GitHub and
   the Mux REST API reference. Three of the four memo corrections hold; **one
   (D-04) is materially inverted** — see Memo Corrections below.
2. **Surfaced gaps the planner needs** — chiefly: the Mox+behaviour test pattern's
   Oban+test-process locality, the `Rindle.Delivery.url/3` TTL plumbing footgun,
   and the source-variant resolution path that CONTEXT.md describes only by
   reference.
3. **Wrote the Validation Architecture section** with a concrete REQ→test map, a
   sampling rate, and a Wave 0 gap list.
4. **Highlighted cross-cutting truths** — security invariant 14 enforcement, the
   optional-dep guard, atomic-promote, and the locked Rindle worker conventions
   the planner must mirror.

**Primary recommendation:** Defer to CONTEXT.md on every locked decision EXCEPT
D-04 — the Mux REST API field is `playback_policies` (PLURAL) per the
authoritative Mux API reference at
`https://www.mux.com/docs/api-reference/video/assets/create-asset`. CONTEXT.md
D-04 inverts singular/plural. Treat this as a memo correction the planner must
fold in. Proceed with everything else as written.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

All 43 decisions in CONTEXT.md `<decisions>` are LOCKED. Quoting the headline
groups verbatim:

- **D-01..D-02 — Optional Dependencies:** `{:mux, "~> 3.2", optional: true}` and
  `{:jose, "~> 1.11", optional: true}` added to `mix.exs`; PLT add_apps for
  Dialyzer.
- **D-03..D-09 — Mux SDK Surface:** `Mux.Base.new/2` per-call construction;
  `playback_policy` translation at the SDK boundary; `Mux.Token.sign_playback_id/2`
  with explicit `:expiration`; `:expiration` is **integer seconds-from-now**, not
  absolute Unix timestamp; JOSE PEM cache deferred (no `:persistent_term` for v1.6).
- **D-10..D-12 — Webhook Verify (callback only, wire-up Phase 35):** Single-secret
  loop in caller; tolerance default 300s.
- **D-13..D-20 — `MuxIngestVariant` Worker:** `:rindle_provider` queue (NEW for
  v1.6); `max_attempts: 5`; `c:timeout/1` returns integer ms; unique on
  `(asset_id, profile, variant_name)` with `period: 86_400`; **atomic-promote
  mirrors `process_variant.ex:244-275` verbatim**; failure normalization
  with `{:snooze, retry_after_seconds}` for 429s.
- **D-21..D-25 — `MuxSyncCoordinator` + `MuxSyncProviderAsset`:** Cron-driven
  coordinator (NEW addition over the candidate memo) + per-row sibling worker;
  `max_attempts: 1` for coordinator; `provider_polling_floor_seconds: 30`;
  `provider_stuck_threshold_seconds: 7200` default.
- **D-26..D-28 — Telemetry:** Three event families; security invariant 14
  redaction in metadata; `[:rindle, :delivery, :streaming, :resolved]` already
  fires from Phase 33 dispatch.
- **D-29..D-30 — Configuration:** All credentials and tunables under
  `config :rindle, Rindle.Streaming.Provider.Mux`; read at call site, no caching.
- **D-31..D-33 — Optional-Dep Guard:** Wrap entire module in
  `if Code.ensure_loaded?(Mux.Video.Assets) do ... end`; mirrors
  `lib/rindle/live_view.ex:1`.
- **D-34..D-38 — Test Strategy:** Mox + internal `Rindle.Streaming.Provider.Mux.Client`
  behaviour; cassette JSON fixtures at `test/fixtures/mux/`; signing-key fixture
  generated via `openssl genrsa`; soak lane deferred to Phase 36.
- **D-39..D-40 — Module Layout:** Files added under
  `lib/rindle/streaming/provider/mux/`, `lib/rindle/workers/mux_*.ex`; mocks
  extension; cassette fixtures.
- **D-41..D-42 — Documentation:** No `guides/streaming_providers.md` (Phase 36);
  no README updates (Phase 36).
- **D-43 — Decision-Making Preference:** Decide-by-default; escalate only for
  high-blast-radius decisions.

### Claude's Discretion

CONTEXT.md `<decisions>` ends with an explicit "Claude's Discretion (Planner /
Executor)" subsection. Implementation choices the planner / executor make
autonomously:

- Exact internal signature for `Rindle.Streaming.Provider.Mux.Client` behaviour
  (callback names + arities).
- File-vs-folder organization for `Rindle.Streaming.Provider.Mux.*` sub-modules.
- Exact wording of Mux-specific error messages routed through `Rindle.Error.message/1`.
- Whether to inline the Mux base URL constant or read from config.
- Cassette JSON file structure (one file per fixture vs one big map; default
  one-file-per-fixture).
- Whether `MuxSyncCoordinator` queries rows itself vs delegates to
  `Rindle.Streaming.Sync` service module.
- Internal queue-config defaults documented in `@moduledoc` blocks (cron snippet
  wording is Phase 36's guide).
- Test file organization for new workers.
- Whether `Mux.Token.sign_playback_id/2` calls happen synchronously in
  `streaming_url/3` or are pre-cached (D-09 says no cache for v1.6).
- Whether `expected_storage_key`/`expected_recipe_digest` args use string-keyed
  vs atom-keyed maps (Oban serialization picks the answer: string-keyed).

### Deferred Ideas (OUT OF SCOPE)

CONTEXT.md `<deferred>` block:

- **Direct creator upload** — `create_direct_upload/2` impl (Phase 37 / v1.7).
- **Webhook plug, raw-body cache, multi-secret rotation routing** — Phase 35.
- **`mix rindle.doctor` streaming validation** — Phase 36.
- **`Rindle.Profile.Presets.MuxWeb` and adopter onboarding guide** — Phase 36.
- **Generated-app `mux-enabled` package-consumer proof lane** — Phase 36 (incl.
  `mux-soak` GitHub Actions lane behind a `MUX_TOKEN_ID` secret).
- **Cached `JOSE.JWK.from_pem/1` parse via `:persistent_term`** — D-09 deferred.
- **Webhook event replay tooling (`mix rindle.webhook.replay`)** — v1.7+.
- **Configurable telemetry redaction** — v1.7+.
- **`cancel_provider_ingest/1` cancellation surface** — v1.7+.
- **Map-keyed error variants** — v1.7+ if real adopter feedback proves a need.
- **DASH support (`kind: :dash`)** — v1.7+.
- **Second provider** (Cloudflare Stream / Bunny Stream / Cloudinary Video) —
  v1.7+.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MUX-01 | `mux ~> 3.2` and `jose ~> 1.11` ship as **optional** deps; zero transitive cost when not enabled | mix.exs entry shape (D-01); optional-dep guard at module top (D-31..D-33); pinned versions verified live on Hex.pm 2026-05-06 |
| MUX-02 | `Rindle.Streaming.Provider.Mux` implements every locked behaviour callback; credential resolution via `Application.get_env` only | Phase 33 behaviour at `lib/rindle/streaming/provider.ex` (read in full); SDK signatures D-03..D-09 (verified via mux-elixir source); credential config shape D-29 |
| MUX-03 | `Rindle.Workers.MuxIngestVariant` Oban worker pushes Rindle-produced AV variant to Mux with private signed storage URL; persists `provider_asset_id` + `playback_id`; FSM `pending → uploading → processing` | Worker shape D-13..D-20; queue `:rindle_provider` is NEW (verified unused); `Mux.Video.Assets.create/2` returns `{:ok, asset_map, %Tesla.Env{}}` (verified); FSM transitions allowlisted in `provider_asset_fsm.ex` (read) |
| MUX-04 | Signed HLS playback URLs mint via `Mux.Token.sign_playback_id/2`; respects v1.4 `signed_url_ttl_seconds` profile policy with NO hidden 7-day default | Memo correction D-06 (`sign_playback_id` not `sign`); SDK source verified at `lib/mux/token.ex`; default expiration **604_800s = 7 days** (FOOTGUN — must always pass `:expiration` explicitly) |
| MUX-05 | `MuxIngestVariant` is idempotent under Oban `unique` keyed on `(asset_id, profile, variant_name)` | Unique opts shape D-16 mirrors `process_variant.ex:408-415`; Oban `:scheduled, :executing, :retryable, :completed` states confirmed valid (verified against Oban 2.22.1 `Oban.Job.@states`) |
| MUX-06 | Atomic-promote on flip-to-`:ready`: re-fetch source asset; abort if `recipe_digest` or `storage_key` changed during ingest (mirrors AV-03-10) | Verbatim mirror of `process_variant.ex:244-275`; D-19; `expected_storage_key`/`expected_recipe_digest` captured at enqueue and re-checked at flip; `{:cancel, {:stale_source, ...}}` returns stop Oban retries |
| MUX-07 | `Rindle.Workers.MuxSyncProviderAsset` defensively polls `processing`/`uploading` rows older than configured floor; transitions to `:errored` with reason `:provider_asset_stuck` past stuck-threshold | Coordinator + per-row split D-21..D-25 (NEW addition over candidate memo); cron-driven enqueuer mirrors `cleanup_orphans.ex` shape; `provider_polling_floor_seconds: 30` and `provider_stuck_threshold_seconds: 7200` defaults |
| MUX-08 | Provider ingest + sync emit telemetry under `[:rindle, :provider, :ingest, :start \| :stop \| :exception]` and `[:rindle, :provider, :sync, :resolved \| :stuck]` with documented schemas | D-26 event shapes; D-27 security-invariant-14 metadata redaction (`provider_asset_id` last-4-char tag only); existing `[:rindle, :delivery, :streaming, :resolved]` already fires from Phase 33 dispatch |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Optional dep declaration & PLT | Build (mix.exs) | — | Compile-time decision; adopters opt in via deps |
| Mux REST adapter (asset CRUD, signed URL, webhook verify) | Adapter (lib/rindle/streaming/provider/mux/) | Phase 33 behaviour | Pure adapter contract; no business logic |
| HTTP client behaviour + Mox testing | Adapter-internal (mux/client.ex) | Test (test/support/mocks.ex) | Process-local Mox needs a behaviour seam; matches Storage/Processor/Analyzer pattern |
| Server-push ingest worker | Background job (Oban) | Adapter (calls into Mux REST) | Rindle owns the side-effect lifecycle; adapter owns the API call |
| Atomic-promote race protection | Background job | Domain (`MediaAsset`/`MediaVariant` re-fetch) | Captured-at-enqueue values vs current-DB compare; mirrors AV-03-10 |
| Cron-driven sync coordinator | Background job (cron) | — | Adopter wires `Oban.Plugins.Cron` per Phase 36; coordinator fans out |
| Per-row defensive sync | Background job | Adapter (calls `get_asset/1`) | Per-row idempotent sibling worker |
| Telemetry contract | Observability | All workers + adapter | Public API; redact at every emit (security invariant 14) |
| Signed playback URL | Adapter (Mux.Token wrapper) | Phase 33 dispatch (`signed_playback_url/3`) | Pure function call from `dispatch_streaming/4` |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `mux` | `~> 3.2` (3.2.2, 2024-07-02) | Mux REST + JWT signing + webhook verification | Official Mux Elixir SDK; ships the three highest-risk pieces (HMAC verify, JOSE JWT signing, `%Tesla.Env{}` access). [VERIFIED: hex.pm/packages/mux] |
| `jose` | `~> 1.11` (1.11.12, 2025-11-20) | RS256 JWT signing primitives (transitive via :mux) | Mux SDK uses JOSE; Joken would be a parallel JWT lib for no benefit. [VERIFIED: hex.pm/packages/jose] |
| `oban` | already pinned `~> 2.21` (2.22.1, 2026-04-30) | Background job runner | Already a hard Rindle dep. [VERIFIED: hex.pm/packages/oban] |
| `tesla` | transitive via `:mux` (1.17.0, 2026-04-18) | HTTP client for Mux SDK | Mux SDK is on Tesla. [VERIFIED: hex.pm/packages/tesla] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `mox` | already pinned `~> 1.2` | Test mocks for `Rindle.Streaming.Provider.Mux.Client` | Existing Rindle pattern (StorageMock, ProcessorMock, AnalyzerMock, ScannerMock, AuthorizerMock) |
| `bypass` | already pinned `~> 2.1` | Real localhost HTTP for integration tests | Reserved for storage tests; rejected for Mux unit tests (D-35) because Mux SDK base URL is overridable but Mox+behaviour is the locked Rindle pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Mux SDK on Tesla | Req | Would require forking the Mux SDK. Rejected per memo §3. |
| JOSE for JWT signing | Joken | Mux SDK uses JOSE; parallel JWT lib is gratuitous risk. |
| Mox + behaviour | Tesla.Mock | Tesla.Mock is process-local via `Application.put_env`; brittle when Oban's job process differs from the test process. **D-35 rejects this.** |
| Mox + behaviour | Bypass for Mux unit tests | Mux SDK base URL **is** overridable via `Mux.Tesla.new/3` opts (verified) — so Bypass is technically possible — but Mox is the locked Rindle pattern (matches StorageMock et al.) and avoids per-test HTTP server lifecycle. |
| Mox + behaviour | ExVCR | Record/replay drift; tests pass when live API has changed. Rejected per D-35. |

**Installation:**
```elixir
# in mix.exs deps:
{:mux, "~> 3.2", optional: true},
{:jose, "~> 1.11", optional: true}

# in mix.exs project/dialyzer:
dialyzer: [plt_add_apps: [:mux, :jose, ...]]
```

**Version verification (2026-05-06):**
- `mux 3.2.2` (2024-07-02) — [VERIFIED: hex.pm/packages/mux]
- `jose 1.11.12` (2025-11-20) — [VERIFIED: hex.pm/packages/jose]
- `oban 2.22.1` (2026-04-30) — [VERIFIED: hex.pm/packages/oban]
- `tesla 1.17.0` (2026-04-18) — [VERIFIED: hex.pm/packages/tesla]

## Memo Corrections (Verified This Session)

CONTEXT.md flagged four memo corrections (D-04, D-06, D-10, D-21). I spot-checked
each against authoritative sources. Findings:

### MEMO CORRECTION #1 (NEW) — D-04 inverts singular/plural

**CONTEXT.md D-04 says:** "Mux REST API uses **`playback_policy`** (singular,
string list), NOT `playback_policies` (plural, atom list)."

**Authoritative source disagrees:** the Mux Create-Asset API reference
(`https://www.mux.com/docs/api-reference/video/assets/create-asset`) lists
**`playback_policies`** (PLURAL) as current and **`playback_policy`** (singular)
as **DEPRECATED**. Same for `inputs` (plural, current) vs `input` (singular,
deprecated). Direct quote from the API ref docstring:

> "Deprecated. Use `playback_policies` instead, which accepts an identical type."
> "Deprecated. Use `inputs` instead, which accepts an identical type."

cURL example from the API reference:
```
curl https://api.mux.com/video/v1/assets \
  -X POST \
  -d '{ "inputs": [{ "url": "..." }], "playback_policies": ["public"], "video_quality": "basic" }'
```

[VERIFIED: https://www.mux.com/docs/api-reference/video/assets/create-asset]

**Important nuance — this does NOT change the Rindle DSL:** Phase 33 already
shipped `playback_policy` (singular, atom `:signed | :public`) as the **DSL
key** in the profile streaming schema and as the **DB column name** in
`media_provider_assets`. Both are Rindle-internal naming choices; the adapter
translates Rindle DSL atoms → Mux REST API plural-string-list at the SDK call
boundary. The Phase 34 adapter MUST use the **plural, current** REST API key:

```elixir
# CORRECT — what Phase 34 must build:
%{
  "inputs" => [%{"url" => signed_storage_url}],     # PLURAL "inputs", list of objects
  "playback_policies" => ["signed"],                  # PLURAL "playback_policies"
  "mp4_support" => "standard",
  "max_resolution_tier" => "1080p"
}
```

The Mux Elixir SDK's `Mux.Video.Assets.create/2` is a thin pass-through
(`def create(client, params), do: Base.post(client, @path, params)` —
[VERIFIED: github.com/muxinc/mux-elixir/blob/master/lib/mux/video/assets.ex]) so
whatever shape Rindle hands it goes straight to the Mux REST API. Singular keys
will continue to work as long as Mux honors the deprecation; using the current
(plural) keys is the safer long-term choice and matches the published Mux cURL
examples.

**Recommendation for the planner:** Treat D-04 as a memo *correction-of-the-correction*.
The DSL atom name (`:playback_policy`, singular) and DB column
(`playback_policy`, singular) stay as-shipped in Phase 33. The SDK boundary
shape (`inputs`, `playback_policies`, both plural) is what the Phase 34 adapter
must use. Document this translation explicitly in the adapter's
`@moduledoc false` comment so future maintainers don't re-flip it.

### MEMO CORRECTION #2 — D-06 confirmed accurate

`Mux.Token.sign_playback_id/2` is current; `Mux.Token.sign/2` is deprecated.
Verified against `lib/mux/token.ex` master:

> "This method has been deprecated in favor of Mux.Token.sign_playback_id"

Default `:expiration` is **604_800 seconds (7 days)**. JWT is returned as a raw
string (no `{:ok, _}` wrap). Source confirms:

```elixir
@spec sign_playback_id(String.t(), options()) :: String.t()
def sign_playback_id(playback_id, opts \\ []) do
  ...
  payload = %{
    "aud" => opts[:type] |> type_to_aud(),
    "sub" => playback_id,
    "exp" => (DateTime.utc_now() |> DateTime.to_unix()) + opts[:expiration]
  }
  ...
  JOSE.JWS.sign(signer, payload, claims) |> JOSE.JWS.compact() |> elem(1)
end
```

The `+ opts[:expiration]` confirms D-07 verbatim: `:expiration` is **integer
seconds-from-now**, NOT an absolute Unix timestamp. The SDK adds it to
`DateTime.utc_now() |> DateTime.to_unix()` internally.

[VERIFIED: github.com/muxinc/mux-elixir/blob/master/lib/mux/token.ex]

`:type` accepts `:video | :gif | :thumbnail | :storyboard`. `:video` is the
default and produces `aud: "v"`. [VERIFIED: hexdocs.pm/mux/Mux.Token.html]

### MEMO CORRECTION #3 — D-10 confirmed accurate

`Mux.Webhooks.verify_header/4` accepts a **single secret**, not a list. Confirmed
function arity and parameter shape:

```elixir
def verify_header(payload, signature_header, secret, tolerance \\ @default_tolerance)
```

The function passes `secret` directly to `compute_signature(signed_payload, secret)`
which then calls `hmac(:sha256, secret, payload)`. Multi-secret rotation must be
performed by the caller. [VERIFIED: github.com/muxinc/mux-elixir/blob/master/lib/mux/webhooks.ex]

### MEMO CORRECTION #4 — D-21 confirmed (architectural addition, not SDK fact)

The candidate memo §7 specified `unique: [period: 60]` for `MuxSyncProviderAsset`
but did not specify who enqueues per-row jobs. CONTEXT.md D-21 adds the
coordinator worker (`MuxSyncCoordinator`) on top. This is an **architectural
addition**, not a memo-vs-API correction. The coordinator pattern mirrors
existing Rindle conventions at `cleanup_orphans.ex` and `abort_incomplete_uploads.ex`
(both verified in repo). No conflict with SDK or Oban contract.

## Architecture Patterns

### System Architecture Diagram

```
                  ┌─────────────────────────────────────┐
                  │   Adopter app (post-`:ready` AV)    │
                  │   (Phase 36 ships the wiring)       │
                  └────────────────┬────────────────────┘
                                   │ Oban.insert/2
                                   ▼
                  ┌─────────────────────────────────────┐
                  │   Rindle.Workers.MuxIngestVariant   │
                  │   queue: :rindle_provider           │
                  │   max_attempts: 5                   │
                  └────────────────┬────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
   ┌─────────────────────┐  ┌─────────────────┐  ┌──────────────────┐
   │ Rindle.Delivery.url │  │ Rindle.Streaming│  │ Rindle.Domain.   │
   │ (private signed     │  │ .Provider.Mux   │  │ MediaProviderAsset│
   │  storage URL,       │  │ .Client.HTTP    │  │ (insert, FSM step)│
   │  TTL ≥ 30 min)      │  │ → Mux REST API  │  │                   │
   └─────────────────────┘  └────────┬────────┘  └──────────────────┘
                                     │
                                     ▼
                            ┌────────────────┐
                            │ Mux.Video      │
                            │ .Assets.create │
                            │ /2 (3-tuple    │
                            │  Tesla return) │
                            └────────┬───────┘
                                     │
                                     ▼
                       ┌──────────────────────────┐
                       │ persist_provider_asset   │
                       │ (atomic-promote rules    │
                       │  on flip-to-:ready —     │
                       │  see process_variant.ex  │
                       │  244-275 mirror)         │
                       └──────────────────────────┘

  Cron tick (1 min)
        │
        ▼
   ┌──────────────────────────────────┐
   │ Rindle.Workers.MuxSyncCoordinator│
   │ queue: :rindle_provider          │
   │ max_attempts: 1                  │
   │ scans (processing, uploading)    │
   │ rows older than 30s              │
   └──────────────┬───────────────────┘
                  │ fan-out per row
                  ▼
   ┌──────────────────────────────────┐
   │ Rindle.Workers.MuxSyncProviderAsset │
   │ queue: :rindle_provider          │
   │ max_attempts: 3                  │
   │ unique: [period: 60]             │
   │ → Mux.Video.Assets.get/2         │
   │ → FSM transition or :stuck       │
   └──────────────────────────────────┘

  Phase 33 read path (already shipped):
   Rindle.Delivery.streaming_url/3
        ▼ (Branch 5: state == "ready")
   Rindle.Streaming.Provider.Mux.signed_playback_url/3
        ▼
   Mux.Token.sign_playback_id/2 (with explicit :expiration)
        ▼
   {:ok, %{url: "https://stream.mux.com/{playback_id}.m3u8?token=...",
           kind: :hls, mime: "application/vnd.apple.mpegurl"}}
```

### Recommended Project Structure

```
lib/rindle/
├── streaming/
│   └── provider/
│       └── mux.ex                  # main adapter (entire module wrapped in Code.ensure_loaded? guard)
│       └── mux/
│           ├── client.ex           # @moduledoc false internal HTTP-client behaviour
│           ├── http.ex             # @moduledoc false real impl (also guard-wrapped)
│           └── event.ex            # @moduledoc false webhook event normalizer
└── workers/
    ├── mux_ingest_variant.ex
    ├── mux_sync_coordinator.ex
    └── mux_sync_provider_asset.ex

test/
├── rindle/
│   ├── streaming/provider/mux/     # adapter tests (cassette-driven via Mox)
│   └── workers/                    # MuxIngestVariant + sync worker tests
├── support/
│   └── mocks.ex                    # extend: Rindle.Streaming.Provider.Mux.ClientMock
└── fixtures/
    └── mux/
        ├── asset_create_201.json
        ├── asset_get_processing.json
        ├── asset_get_ready.json
        ├── webhook_video_asset_ready.json
        ├── webhook_video_asset_errored.json
        └── test_signing_private_key.pem
```

### Pattern 1: Optional-Dep Guard (locked Rindle pattern)

**What:** Wrap entire module body in `if Code.ensure_loaded?(...) do ... end`.
**When to use:** Every module under `lib/rindle/streaming/provider/mux*.ex`.
**Example (mirrors `lib/rindle/live_view.ex:1`, verified):**

```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux do
    @behaviour Rindle.Streaming.Provider
    # ...
  end
end
```

`Rindle.Delivery.dispatch_streaming/4` (Phase 33 shipped) already detects module
presence at runtime via the `@spec`-d `streaming_config.provider` lookup, so an
absent module will not cause runtime crashes — it surfaces as the locked
`:streaming_not_configured` error.

[CITED: lib/rindle/live_view.ex line 1; lib/rindle/html.ex line 1]

### Pattern 2: Mox + Behaviour for External SDK (locked Rindle pattern)

**What:** Define a thin internal HTTP-client behaviour. Real impl delegates to
the SDK. Test impl is a Mox-defined mock.
**When to use:** Every external integration with HTTP-side effect.
**Example (mirrors `Rindle.Storage`, `Rindle.Processor`, etc., verified):**

```elixir
# lib/rindle/streaming/provider/mux/client.ex
defmodule Rindle.Streaming.Provider.Mux.Client do
  @moduledoc false
  @callback create_asset(map()) :: {:ok, map()} | {:error, term()}
  @callback get_asset(String.t()) :: {:ok, map()} | {:error, term()}
  @callback delete_asset(String.t()) :: :ok | {:error, term()}
end

# lib/rindle/streaming/provider/mux/http.ex
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux.HTTP do
    @moduledoc false
    @behaviour Rindle.Streaming.Provider.Mux.Client
    # delegates to Mux.Video.Assets.{create,get,delete}/2
  end
end

# test/support/mocks.ex (extension — one-line addition)
Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock,
  for: Rindle.Streaming.Provider.Mux.Client)
```

**Why process-local Mox works inside Oban tests:** `Oban.Testing.perform_job/2`
runs the worker callback in the **test process** itself, so Mox expectations
set with `:set_mox_from_context` are visible to the worker. Verified in repo:
the existing pattern at `test/rindle/workers/process_variant_test.exs:9-10` uses
`setup :set_mox_from_context; setup :verify_on_exit!`. **Don't use
`set_mox_global`** — it leaks expectations across async tests.

[CITED: test/support/mocks.ex; test/rindle/workers/process_variant_test.exs]

### Pattern 3: Atomic-Promote Race Protection (locked AV-03-10 / D-19 pattern)

**What:** Capture `storage_key` and `recipe_digest` at enqueue. Re-fetch source
asset before flipping FSM to `:ready`. Abort with `{:cancel, ...}` on drift.
**When to use:** Every worker that produces a derivative whose validity depends
on the source still being the same source.
**Example (mirrors `process_variant.ex:244-275` verbatim, verified):**

```elixir
defp persist_ready(repo, source_asset, source_variant, mux_response, args) do
  current_asset = repo.get!(MediaAsset, source_asset.id)
  current_variant = repo.get!(MediaVariant, source_variant.id)

  cond do
    current_asset.storage_key != args["expected_storage_key"] ->
      {:cancel, {:stale_source, :asset_changed}}

    current_variant.recipe_digest != args["expected_recipe_digest"] ->
      {:cancel, {:stale_source, :recipe_changed}}

    true ->
      # transition media_provider_assets row, persist provider_asset_id,
      # advance FSM via Rindle.Domain.ProviderAssetFSM.transition/3
  end
end
```

The `{:cancel, reason}` return value stops Oban retries cleanly (Oban 2.21+;
`{:discard, reason}` is the deprecated alias for the same behavior — verified
on hexdocs.pm/oban). Telemetry must emit `[:rindle, :provider, :ingest, :exception]`
with `kind: :cancelled` to distinguish from genuine errors.

[CITED: lib/rindle/workers/process_variant.ex:244-275; verified Oban
{:cancel, _} via hexdocs.pm/oban/Oban.Worker.html]

### Anti-Patterns to Avoid

- **Storing `MUX_TOKEN_ID` in `Application.put_env` at boot.** D-30 locks
  call-site reads via `Application.get_env/3`. Boot-time caching breaks runtime
  config updates.
- **Calling `Mux.Token.sign_playback_id/2` without `:expiration`.** Default is
  7 days. **Always** pass `expiration: signed_url_ttl_seconds(profile)`. This is
  the highest-risk silent footgun in Phase 34 — see Pitfall 1 below.
- **Using `playback_policy` (singular) for the Mux REST API call.** Even though
  the SDK accepts the deprecated form, use `playback_policies` (plural) at the
  SDK call boundary per the current Mux REST API contract.
- **Setting Oban `:states` to `[:available]`-only on unique constraints.** The
  v1.6 unique-key states are `[:scheduled, :executing, :retryable, :completed]`
  per D-16 — `:available` is intentionally NOT included so a job can be
  re-enqueued after completion (e.g., re-ingest after `:errored` recovery).
- **Logging or emitting telemetry containing the raw `provider_asset_id`.**
  Security invariant 14. Always go through `MediaProviderAsset.redact_id/1` (or
  whatever the Phase 33 helper is exposed as).
- **Using `set_mox_global` in worker tests.** Leaks expectations across async
  tests. Use `set_mox_from_context` (matches existing repo convention).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HMAC-SHA256 webhook signature verification | Custom `:crypto.mac/4` + constant-time compare | `Mux.Webhooks.verify_header/4` | Mux SDK already implements constant-time compare via `secure_equals?/2`; multi-`v1=` parsing handled correctly. Single-secret-only — caller wraps for rotation. |
| RS256 JWT signing for playback URLs | Custom JOSE call + claim assembly | `Mux.Token.sign_playback_id/2` | Builds `aud`, `sub`, `exp`, `kid` claims correctly with the right hashing posture. **Pass `:expiration` explicitly — 7-day default is a footgun.** |
| Mux REST API HTTP client | Custom Tesla setup + auth middleware | `Mux.Base.new/2` (delegates to `Mux.Tesla.new/2`) | Returns a `%Tesla.Client{}` with `Tesla.Middleware.BasicAuth` and `Tesla.Middleware.BaseUrl` pre-configured. Per-call client construction (D-03). |
| 429 `Retry-After` extraction | Read SDK's normalized error | Read `%Tesla.Env{}.headers` directly | **Mux SDK Issue #42**: 429 `Retry-After` is swallowed by the SDK's `simplify_response/1`. The third element of `{:error, msg, %Tesla.Env{}}` exposes raw headers. [CITED: github.com/muxinc/mux-elixir/issues/42] |
| Cron-driven worker enqueue | Custom GenServer with `Process.send_after` | `Oban.Plugins.Cron` (adopter-wired) | Adopter-owned Oban supervision; cron resolution = 1 min; the coordinator's internal query enforces the `provider_polling_floor_seconds: 30` floor. |
| Process-local HTTP test mock | Tesla.Mock or Bypass | Mox + behaviour | Locked Rindle pattern; matches StorageMock, ProcessorMock, AnalyzerMock; survives Oban's test-process boundary. |
| Provider-asset FSM | Custom state-transition table | `Rindle.Domain.ProviderAssetFSM.transition/3` | Phase 33 shipped; the FSM allowlist already enforces `pending → uploading → processing → ready`, `errored → processing` (re-ingest), etc. |

**Key insight:** The Mux Elixir SDK ships the three highest-risk pieces of v1.6
(HMAC verify, RS256 signing, basic-auth REST client). Custom solutions add
gratuitous risk. The adapter's job is to glue these into the Rindle contract,
not to reinvent them.

## Common Pitfalls

### Pitfall 1: Mux.Token 7-day default expiration silently overrides profile policy

**What goes wrong:** A code path mints a signed playback URL without passing
`:expiration`. The JWT carries a 7-day exp claim regardless of the profile's
`signed_url_ttl_seconds: 900` policy.

**Why it happens:** `Mux.Token.sign_playback_id/2` defaults `:expiration` to
`604_800` (7 days) in `default_options/0`. The default is silent — no warning,
no log. The JWT verifies against the signing key just fine. Production Mux URLs
look identical regardless.

**How to avoid:** Three-layer defense:
1. The wrapper `Rindle.Streaming.Provider.Mux.signed_playback_url/3` MUST always
   pass `expiration: signed_url_ttl_seconds(profile)`. Make this a `with` step
   that fails closed if the profile lookup returns `nil`.
2. ExUnit assertion in `mux_test.exs`: decode the returned JWT (via JOSE) and
   assert the `exp` claim is within `signed_url_ttl_seconds + 5s clock skew` of
   `now`. The "+5s" is a reasonable tolerance for test timing variance.
3. Negative test: a deliberately misconfigured profile path (`:expiration`
   accidentally omitted) MUST fail fast with `:streaming_not_configured` or
   raise — never silently mint a 7-day token.

**Warning signs:** A test that asserts `is_binary(jwt)` only and not the `exp`
claim. Logs showing playback URLs with no TTL telemetry context.

[VERIFIED: lib/mux/token.ex `default_options/0`]

### Pitfall 2: `Rindle.Delivery.url/3` does not accept a `:ttl` option

**What goes wrong:** CONTEXT.md D-18 reads as if you can call
`Rindle.Delivery.url(profile, variant.storage_key, ttl: 1_800)` to get a 30-min
signed URL for the Mux ingest source. The current `delivery.ex` signature does
NOT support that — it always uses `signed_url_ttl_seconds(profile)`.

**Why it happens:** D-18 ("call `Rindle.Delivery.url(profile, variant.storage_key,
ttl: 1_800)` to obtain a private signed URL with **30-minute** TTL") is a
hopeful-future signature. The actual delivery.ex code path is:

```elixir
# delivery.ex line 124-145 (read in this session)
@spec url(module(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
def url(profile, key, opts \\ []) do
  # ...
  {:ok, url} <- resolve_url(adapter, key, mode, opts, signed_url_ttl_seconds(profile))
  # ...
end

defp resolve_url(adapter, key, :private, opts, ttl) do
  adapter.url(key, Keyword.put_new(opts, :expires_in, ttl))
end
```

The TTL is hard-bound to the profile policy at `signed_url_ttl_seconds(profile)`.
There is no `:ttl` keyword pass-through.

**How to avoid:** Three options, in order of preference:

1. **(Preferred) Pass `expires_in: 1_800` directly via opts.** `resolve_url/4`
   uses `Keyword.put_new/3`, so adopter-supplied `:expires_in` overrides the
   profile default. Verified at `delivery.ex:resolve_url`. This means the
   worker calls:

   ```elixir
   Rindle.Delivery.url(profile, variant.storage_key, expires_in: 1_800)
   ```

2. **(Acceptable) Configure the streaming profile with
   `signed_url_ttl_seconds: 1_800`.** This affects all signed URLs the profile
   issues, which may be too broad.

3. **(Avoid) Call the storage adapter directly.** Bypasses authorization and
   telemetry; not aligned with the locked Rindle pattern.

**Warning signs:** Mux ingest fails with "URL expired" if the profile's
`signed_url_ttl_seconds` is shorter than the Mux ingest queue depth (Mux
typically holds bytes within seconds; rarely a problem for 900s TTL, but
adopter profiles using 60s TTL will fail).

**Recommendation for the planner:** Either treat D-18 as written (use
`expires_in: 1_800` in the worker call), or update the worker text to be
explicit about the option name. The functional outcome is the same.

[VERIFIED: lib/rindle/delivery.ex:124-145 + resolve_url/4]

### Pitfall 3: Mux SDK 429 Retry-After header is swallowed by simplify_response

**What goes wrong:** Mux SDK normalizes errors via `simplify_response/1`, which
returns `{:error, msg, %Tesla.Env{}}`. The `msg` is a friendly string but
`Retry-After` from the 429 response is consumed before reaching the caller.
Without reading `Retry-After`, retries hammer Mux at Oban's exponential backoff
(5s, 10s, 20s, 40s, 80s) regardless of when Mux says "try again in 60s."

**Why it happens:** Mux SDK Issue #42 documents this as a known behaviour. The
SDK's `Tesla.Env` IS exposed (third element of the error tuple) — adapters
that need `Retry-After` read it directly from `env.headers`.

**How to avoid:** In `MuxIngestVariant`'s error handler:

```elixir
case Mux.Video.Assets.create(client, params) do
  {:ok, asset, _env} -> ...
  {:error, _msg, %Tesla.Env{status: 429, headers: headers}} ->
    retry_after = headers
                  |> List.keyfind("retry-after", 0)  # case-insensitive in some Tesla setups
                  |> case do
                       {_, val} -> String.to_integer(val)
                       _ -> 60  # fallback
                     end
    {:snooze, retry_after}
  {:error, _msg, %Tesla.Env{status: status}} when status in 500..599 ->
    {:error, :provider_sync_failed}  # Oban retry standard backoff
  {:error, _msg, %Tesla.Env{status: status}} when status in 400..499 ->
    # persist last_sync_error truncated to 4096; transition to :errored
    {:error, :provider_sync_failed}  # Oban won't retry past max_attempts
end
```

The `{:snooze, integer_seconds}` return value is verified:
> "mark the job as `snoozed` and schedule it to run again after the specified
> period" with example `{:snooze, 60}`.
[VERIFIED: hexdocs.pm/oban/Oban.Worker.html `{:snooze, _}`]

**Warning signs:** Mux dashboard shows a 429 burst followed by a flood of new
requests at exponential backoff (instead of waiting). Account-level rate-limit
warnings.

[CITED: github.com/muxinc/mux-elixir/issues/42]

### Pitfall 4: Optional-dep guard precedence — module exists at compile time, fails at runtime

**What goes wrong:** A test environment loads `:mux` (because `mix.exs` lists
it as optional and the test runner has it). Production adopters who omit `:mux`
from their deps see a runtime crash from a code path that *should* have been
gated.

**Why it happens:** `if Code.ensure_loaded?(Mux.Video.Assets) do defmodule ... end`
gates **module compilation**. If the entire module is gated, an absent `:mux`
means `Rindle.Streaming.Provider.Mux` simply doesn't exist as an atom at
runtime. Phase 33's `dispatch_streaming/4` checks for module presence via the
locked dispatch path (`streaming_config.provider` is the configured module —
if absent, `Code.ensure_loaded?/1` returns false and the dispatch surfaces
`:streaming_not_configured`).

**How to avoid:**
1. **Guard EVERY top-level module in the Mux subtree** with the same
   `Code.ensure_loaded?(Mux.Video.Assets) do ... end` wrapper. Including:
   - `Rindle.Streaming.Provider.Mux` (main adapter)
   - `Rindle.Streaming.Provider.Mux.HTTP` (real client impl)
   - `Rindle.Streaming.Provider.Mux.Event` (webhook normalizer)

   The behaviour module `Rindle.Streaming.Provider.Mux.Client` does NOT need
   the guard — it's `@moduledoc false` with no Mux references; behaviour
   definitions are pure Elixir.

2. **Workers (`MuxIngestVariant` etc.) should ALSO be guarded.** They reference
   `Rindle.Streaming.Provider.Mux.Client` (no SDK dep) and
   `Rindle.Streaming.Provider.Mux` (which IS guarded). Wrapping the worker in
   the same guard means an adopter who configures the queue but doesn't include
   `:mux` won't compile dead module references.

3. **Smoke test (D-33):** In ExUnit (test env, where `:mux` IS loaded),
   `function_exported?(Rindle.Streaming.Provider.Mux, :create_asset, 3)` MUST
   be `true`.

4. **Phase 36's `mix rindle.doctor` adds the production-time check** (out of
   Phase 34 scope). Phase 34 just needs the smoke test.

**Warning signs:** A `Rindle.Streaming.Provider.Mux.HTTP.create_asset/2`
function exported in a Mix env without `:mux` (i.e., the guard is missing on
some submodule).

[CITED: lib/rindle/live_view.ex:1; lib/rindle/html.ex:1]

### Pitfall 5: Provider asset id leakage through Inspect / telemetry

**What goes wrong:** Logger output, `IO.inspect/1`, or telemetry metadata leaks
the raw `provider_asset_id` (a Mux internal ID, e.g.,
`AbCd1234EfGh5678IjKl9012MnOp3456QrSt`). Security invariant 14 violated.

**Why it happens:** Default Elixir Inspect behavior shows all struct fields.
Telemetry handlers stringify metadata maps for log output. A worker that emits
`%{asset_id: row.provider_asset_id}` (instead of `%{asset_id: redact(row.provider_asset_id)}`)
leaks immediately.

**How to avoid:**
1. **Phase 33 already shipped the schema-layer redaction** — `MediaProviderAsset`
   has a custom `Inspect` impl that redacts to last-4-char tag (`"...abcd"`).
   Verified in `lib/rindle/domain/media_provider_asset.ex:100-118`. As long as
   you log the *struct* (not the field directly), you're protected.

2. **Phase 34 must extend redaction to telemetry metadata.** Helper required
   either as `MediaProviderAsset.redact_id/1` (extract from the Inspect impl
   into a public-internal helper — currently it's `defp`) or inline at each
   emit site:

   ```elixir
   redacted_id = case row.provider_asset_id do
     nil -> nil
     id when byte_size(id) >= 4 -> "..." <> String.slice(id, -4, 4)
     _ -> "...redacted"
   end

   :telemetry.execute(
     [:rindle, :provider, :ingest, :stop],
     %{system_time: System.system_time(), duration: duration},
     %{
       profile: profile,
       provider: :mux,
       asset_id: redacted_id,         # <-- NOT row.provider_asset_id
       variant_name: variant_name
     }
   )
   ```

3. **Locked guidance:** Extract the helper to a module-public function on
   `MediaProviderAsset` (e.g., `def redact_id(id)`). Don't duplicate the
   redaction logic in every worker.

4. **Test:** Add an ExUnit assertion on telemetry capture confirming
   `metadata.asset_id` matches `~r/^\.\.\.[A-Za-z0-9]{4}$/`.

**Warning signs:** A grep for `provider_asset_id` in telemetry handler code
shows raw field references. Log lines containing 30+ char strings starting with
`A-Z`/`a-z`.

[VERIFIED: lib/rindle/domain/media_provider_asset.ex:100-118 — Inspect impl
exists, but `redact_id/1` is `defp`, so Phase 34 must promote it or duplicate
the logic.]

### Pitfall 6: Coordinator floods the queue if many rows are stuck

**What goes wrong:** `MuxSyncCoordinator` runs every minute. If 500
`media_provider_assets` rows are in `:processing` (e.g., after a Mux outage),
each cron tick fans out 500 jobs. The `:rindle_provider` queue floods.

**Why it happens:** D-23 shows a straightforward `Enum.each` over query
results. No batching or backpressure.

**How to avoid:**
1. **Per-row unique constraint deduplicates within 60s window** (D-25:
   `unique: [period: 60]` keyed on `provider_asset_id`). This prevents the
   second cron tick from fanning out duplicate jobs while the first batch is
   still draining.

2. **Queue concurrency is documented as `1`** for `:rindle_provider` per D-25
   memo §7. Adopters who size the queue at `4` get 4-way parallel sync; even
   500-row backlogs drain in ~125 minutes worst-case.

3. **(Optional) Add LIMIT to coordinator query.** A `LIMIT 100` cap with a
   comment "process at most 100 stuck rows per tick; next tick handles the
   rest" is defensive. Whether to add this is a planner-discretion call.

**Recommendation:** Phase 34 ships the unbatched coordinator. If real-world
adopter feedback shows queue floods, add the LIMIT cap in v1.7.

**Warning signs:** Oban dashboard shows hundreds of `MuxSyncProviderAsset` jobs
queued simultaneously. Adopter logs show `[:rindle, :provider, :sync, :resolved]`
spikes.

### Pitfall 7: `:rindle_provider` queue not configured by adopter

**What goes wrong:** Phase 34 ships the workers but does NOT supervise Oban.
An adopter who installs Rindle for the first time and tries to use streaming
sees `MuxIngestVariant` jobs sitting in `:available` state forever — the queue
isn't even configured in their `config :my_app, Oban`.

**Why it happens:** Adopter-owned Oban supervision is a locked Rindle posture
(memo §7, repo verified at `cleanup_orphans.ex` doc block). Rindle ships
worker MODULES; adopters configure queues and crons.

**How to avoid:**
1. **`@moduledoc` on each worker MUST include the queue+cron config snippet**
   (D-22 wording, Phase 36's guide owns the canonical adopter copy):

   ```elixir
   config :my_app, Oban,
     queues: [rindle_provider: 4],
     plugins: [
       {Oban.Plugins.Cron,
        crontab: [
          {"* * * * *", Rindle.Workers.MuxSyncCoordinator},
          # ... existing entries ...
        ]}
     ]
   ```

2. **Phase 36 ships `mix rindle.doctor` validation** that checks
   `:rindle_provider` queue is configured. Phase 34 just needs the docstring.

3. **Phase 34 smoke test (D-33):** Asserts the worker module exists and the
   `Oban.Worker` shape (`queue: :rindle_provider`, `max_attempts: 5`) is set.
   This catches regressions but doesn't catch adopter misconfiguration.

**Warning signs:** Adopters report "Mux jobs never run." First diagnostic step
is always `iex> Oban.config().queues`.

## Code Examples

Verified patterns from official sources.

### Mux SDK Client Construction (D-03)

```elixir
# Source: github.com/muxinc/mux-elixir/blob/master/lib/mux/tesla.ex (verified)
client = Mux.Base.new(token_id, token_secret)
# Returns %Tesla.Client{} with:
#   - {Tesla.Middleware.BaseUrl, "https://api.mux.com"}
#   - {Tesla.Middleware.BasicAuth, %{username: token_id, password: token_secret}}
# Per-call construction; no caching per D-30.
```

### Asset Creation with Current REST API Keys (memo correction #1 applied)

```elixir
# Source: docs.mux.com/api-reference/video/assets/create-asset (verified 2026-05-06)
{:ok, asset, env} =
  Mux.Video.Assets.create(client, %{
    "inputs" => [%{"url" => signed_storage_url}],   # PLURAL — current key
    "playback_policies" => ["signed"],               # PLURAL — current key
    "mp4_support" => "standard",
    "max_resolution_tier" => "1080p"
  })
# asset shape:
# %{"id" => provider_asset_id,
#   "playback_ids" => [%{"id" => playback_id, "policy" => "signed"}, ...],
#   "status" => "preparing",
#   ...}
```

### Signed Playback URL with Explicit Expiration (D-08, Pitfall 1 mitigated)

```elixir
# Source: github.com/muxinc/mux-elixir/blob/master/lib/mux/token.ex (verified)
jwt = Mux.Token.sign_playback_id(playback_id,
  type: :video,                                     # → aud: "v"
  expiration: signed_url_ttl_seconds(profile),      # MUST pass; default is 7 days
  token_id: signing_key_id,                         # → kid header
  token_secret: signing_private_key                 # PEM string
)

url = "https://stream.mux.com/#{playback_id}.m3u8?token=#{jwt}"

{:ok, %{url: url, kind: :hls, mime: "application/vnd.apple.mpegurl"}}
```

### Webhook Verification (D-10, D-11; callback only — Phase 35 wires up)

```elixir
# Source: github.com/muxinc/mux-elixir/blob/master/lib/mux/webhooks.ex (verified)
def verify_webhook(raw_body, headers, secrets) when is_list(secrets) do
  sig_header = Map.fetch!(headers, "mux-signature")
  tolerance = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux)
              |> Keyword.get(:webhook_tolerance_seconds, 300)

  Enum.find_value(secrets, {:error, :provider_webhook_invalid}, fn secret ->
    case Mux.Webhooks.verify_header(raw_body, sig_header, secret, tolerance) do
      :ok -> {:ok, normalize_event(raw_body)}
      {:error, _} -> nil
    end
  end)
end
```

### Atomic-Promote on Flip-to-:Ready (D-19, mirrors AV-03-10)

```elixir
# Source: lib/rindle/workers/process_variant.ex:244-275 (verified, mirrored verbatim)
defp persist_provider_ready(repo, args, mux_response) do
  asset_id = args["asset_id"]
  variant_name = args["variant_name"]

  current_asset = repo.get!(MediaAsset, asset_id)
  current_variant = repo.get_by!(MediaVariant, asset_id: asset_id, name: variant_name)

  cond do
    current_asset.storage_key != args["expected_storage_key"] ->
      {:cancel, {:stale_source, :asset_changed}}

    current_variant.recipe_digest != args["expected_recipe_digest"] ->
      {:cancel, {:stale_source, :recipe_changed}}

    true ->
      with {:ok, row} <- upsert_provider_row(repo, args, mux_response),
           :ok <- ProviderAssetFSM.transition(row.state, "processing",
                    profile: args["profile"], provider: :mux, asset_id: asset_id) do
        # Persist next state via changeset
        :ok
      end
  end
end
```

### Oban Worker Shape (D-13..D-17, mirrors process_variant.ex)

```elixir
defmodule Rindle.Workers.MuxIngestVariant do
  @moduledoc """
  Push a Rindle-produced AV variant to Mux from server context.

  ## Adopter wiring (Phase 36 owns canonical guide)

      config :my_app, Oban,
        queues: [rindle_provider: 4]
  """
  use Oban.Worker,
    queue: :rindle_provider,
    max_attempts: 5

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)   # integer ms only — D-15

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # ...
  end

  @doc false
  def unique_job_opts do
    [
      fields: [:args, :worker, :queue],
      keys: [:asset_id, :profile, :variant_name],
      states: [:scheduled, :executing, :retryable, :completed],
      period: 86_400  # 24h cooldown — D-16
    ]
  end
end
```

## Runtime State Inventory

Phase 34 is **additive** — new module + new workers + new fixtures. No
rename / refactor / migration.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — Phase 33 already shipped `media_provider_assets` table; Phase 34 inserts new rows but does not migrate existing data | none |
| Live service config | None — Phase 34 reads new env vars (`RINDLE_MUX_*`); no Mux dashboard state references existing Rindle data | adopter configures env vars per Phase 36's guide |
| OS-registered state | None — no Windows Task Scheduler, launchd, or systemd registrations affected | none |
| Secrets/env vars | NEW: `RINDLE_MUX_TOKEN_ID`, `RINDLE_MUX_TOKEN_SECRET`, `RINDLE_MUX_SIGNING_KEY_ID`, `RINDLE_MUX_SIGNING_PRIVATE_KEY`, `RINDLE_MUX_WEBHOOK_SECRETS` | adopter sets per `mix rindle.doctor` validation in Phase 36 |
| Build artifacts | None — `mix.exs` change adds optional deps; `mix deps.compile` picks them up; PLT regen needed (`mix dialyzer --plt`) | run `mix dialyzer --plt` once after `mix deps.get` |

**Nothing found in category:** Stored data, Live service config, and
OS-registered state are explicitly empty (verified by code review and grep on
`Rindle.Streaming.Provider.Mux` references — no other module depends on the
adapter's existence pre-Phase-34).

## Validation Architecture

> Nyquist validation is enabled by default per `.planning/config.json`
> (`workflow` block does not set `nyquist_validation: false`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) + Oban.Testing 2.22.1 + Mox 1.2 |
| Config file | `test/test_helper.exs` (verified — starts Repo, Sandbox, ExMarcel, adopter Repo, Oban with `testing: :manual`) |
| Quick run command | `mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_ingest_variant_test.exs test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1` |
| Full suite command | `mix test --max-failures 1` |
| Test exclusions | `:integration, :minio, :contract, :adopter` excluded by default (verified test_helper.exs:24-29) — Phase 34 cassette tests run in default lane |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MUX-01 | Optional dep wiring; PLT additions; `function_exported?(Rindle.Streaming.Provider.Mux, :create_asset, 3) == true` in test env | unit (smoke) | `mix test test/rindle/streaming/provider/mux/optional_dep_test.exs -x` | ❌ Wave 0 |
| MUX-02 | Behaviour callbacks: `capabilities/0`, `create_asset/3`, `get_asset/1`, `delete_asset/1`, `signed_playback_url/3`, `verify_webhook/3` | unit (Mox-driven) | `mix test test/rindle/streaming/provider/mux/mux_test.exs -x` | ❌ Wave 0 |
| MUX-03 | `MuxIngestVariant.perform/1` calls `Rindle.Streaming.Provider.Mux.Client.ClientMock.create_asset/2`, persists `provider_asset_id` + `playback_id`, advances FSM `pending → uploading → processing` | unit (Oban.Testing.perform_job/2 + Mox) | `mix test test/rindle/workers/mux_ingest_variant_test.exs -x` | ❌ Wave 0 |
| MUX-04 | `streaming_url/3` returns Mux-signed JWT whose `exp` claim is `now + signed_url_ttl_seconds(profile)` (±5s tolerance); JWT verifies against test signing-public-key fixture | unit (cassette + JOSE verify) | `mix test test/rindle/streaming/provider/mux/signed_playback_url_test.exs -x` | ❌ Wave 0 |
| MUX-05 | Re-running `MuxIngestVariant` with same `(asset_id, profile, variant_name)` yields the same `media_provider_assets` row, never a duplicate (Oban unique semantics + `unique_constraint` on `(asset_id, profile, provider_name)`) | unit (Oban.Testing) | `mix test test/rindle/workers/mux_ingest_variant_test.exs:idempotent -x` | ❌ Wave 0 |
| MUX-06 | Atomic-promote: capture `expected_storage_key` + `expected_recipe_digest` at enqueue; mutate the source asset's `storage_key`; the next `perform/1` returns `{:cancel, {:stale_source, :asset_changed}}` and emits `[:rindle, :provider, :ingest, :exception]` with `kind: :cancelled` | unit (Oban.Testing + telemetry capture) | `mix test test/rindle/workers/mux_ingest_variant_test.exs:atomic_promote -x` | ❌ Wave 0 |
| MUX-07 | `MuxSyncCoordinator` query returns rows in `(processing, uploading)` older than 30s; fans out per-row jobs unique by `provider_asset_id`. `MuxSyncProviderAsset` past `provider_stuck_threshold_seconds` transitions to `:errored` with `last_sync_error: "..."` and emits `[:rindle, :provider, :sync, :stuck]`. Else emits `[:rindle, :provider, :sync, :resolved]` | unit (Repo + Oban.Testing + telemetry) | `mix test test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs -x` | ❌ Wave 0 |
| MUX-08 | Telemetry events emitted with documented schemas + `provider_asset_id` redacted to last-4-char tag | unit (`:telemetry.attach`) | `mix test test/rindle/streaming/provider/mux/telemetry_test.exs -x` | ❌ Wave 0 |

**Cross-cutting parity test (MUX-08 + invariant 14):** A single ExUnit test
should attach a telemetry handler, drive a 720p sample through `MuxIngestVariant`
end-to-end (with a Mox `create_asset` cassette), and assert that
**every emitted telemetry event** has `metadata.asset_id` matching
`~r/^\.\.\.[A-Za-z0-9]{4}$/` — never a raw 30+ char id. This is the
single highest-leverage parity test for security invariant 14.

### Sampling Rate

- **Per task commit:** Run the file(s) touched by the task — e.g., a task that
  edits `mux_ingest_variant.ex` runs only
  `mix test test/rindle/workers/mux_ingest_variant_test.exs --max-failures 1`.
- **Per wave merge:** Run the full Phase 34 test bundle:
  `mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_ingest_variant_test.exs test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1`.
  Plus a smoke pass on `process_variant_test.exs` and `delivery_test.exs` to
  confirm no regressions in the AV worker or dispatch tree.
- **Phase gate:** Full suite green (`mix test --max-failures 1`) before
  `/gsd-verify-work`. Plus `mix dialyzer` (with PLT regen — `:mux` and `:jose`
  newly added) and `mix credo --strict` (pre-existing repo standard).

### Wave 0 Gaps

All test files are NEW for Phase 34. Wave 0 (or first task in Wave 1) creates
the test scaffolding before implementation tasks land:

- [ ] `test/rindle/streaming/provider/mux/optional_dep_test.exs` — covers MUX-01
  (smoke + `function_exported?/3` assertion in test env)
- [ ] `test/rindle/streaming/provider/mux/mux_test.exs` — covers MUX-02
  (capabilities, create/get/delete asset via Mox, webhook verify pure-function)
- [ ] `test/rindle/streaming/provider/mux/signed_playback_url_test.exs` — covers
  MUX-04 (JOSE-decodes the JWT; asserts `exp` claim within profile TTL)
- [ ] `test/rindle/streaming/provider/mux/telemetry_test.exs` — covers MUX-08
  (`:telemetry.attach`; redaction parity)
- [ ] `test/rindle/workers/mux_ingest_variant_test.exs` — covers MUX-03,
  MUX-05, MUX-06 (worker contract, idempotent re-enqueue, atomic-promote)
- [ ] `test/rindle/workers/mux_sync_coordinator_test.exs` — covers MUX-07
  (cron query + fan-out)
- [ ] `test/rindle/workers/mux_sync_provider_asset_test.exs` — covers MUX-07
  (per-row sync + stuck transition)
- [ ] `test/support/mocks.ex` — extend with one line:
  `Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock, for: Rindle.Streaming.Provider.Mux.Client)`
- [ ] `test/fixtures/mux/asset_create_201.json` — captured Mux response
- [ ] `test/fixtures/mux/asset_get_processing.json`
- [ ] `test/fixtures/mux/asset_get_ready.json`
- [ ] `test/fixtures/mux/webhook_video_asset_ready.json`
- [ ] `test/fixtures/mux/webhook_video_asset_errored.json`
- [ ] `test/fixtures/mux/test_signing_private_key.pem` — generated via
  `openssl genrsa -out test_signing_private_key.pem 2048`; commit verbatim;
  the public half computed via `openssl rsa -in ... -pubout` for verifier
  fixtures (or extracted from the private key at test runtime via JOSE.JWK).

**Framework install:** Mox + Oban.Testing already pinned in `mix.exs`
(`{:mox, "~> 1.2", only: :test}` and `{:oban, "~> 2.21"}`). No new test
framework needed.

## Project Constraints (from PROJECT.md / CLAUDE.md)

`./CLAUDE.md` does **not exist** in the repo (verified). Project constraints
are sourced from `.planning/PROJECT.md` (read in this session). The constraints
binding on Phase 34:

- **Tech stack:** Elixir/Phoenix/Ecto only in core; no non-Elixir runtime in
  the library. Mux SDK + JOSE are pure Elixir — compliant.
- **Repo ownership:** Adopter apps own the runtime Repo and DB credentials.
  Phase 34 inserts into `media_provider_assets` via `Rindle.Config.repo()`
  (already used by `process_variant.ex` — verified).
- **Background jobs:** Oban remains the required job backend. Phase 34 adds
  three workers; all use `Oban.Worker` macro per existing convention.
- **Security defaults:** Private delivery remains the default. Signed-URL
  playback policy is the default Phase 34 ships (memo §2; profile preset
  defers to Phase 36, but the adapter contract and DSL atom support `:signed`
  as a first-class case).
- **Capability honesty:** Adapter advertises `[:signed_playback,
  :webhook_ingest, :server_push_ingest]` only. Does NOT advertise
  `:public_playback` (deferred — playback policy `:public` works through the
  same adapter but capability advertisement stays focused) or
  `:direct_creator_upload` (Phase 37).
- **Backward compatibility:** No changes to `media_assets`, `media_variants`,
  or `Rindle.Processor.AV`. Mux is additive.
- **Security invariants 1-13 (FFmpeg / shell / temp files / etc.):** Unchanged
  by Phase 34. Phase 34 reads an already-produced variant's storage URL.
- **Security invariant 14 (NEW v1.6):** Phase 34's PRIMARY new responsibility.
  Already enforced at the schema layer (Phase 33 Inspect impl). Phase 34
  extends to telemetry metadata + worker logging. Three-layer defense per
  Pitfall 5.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Mux REST `playback_policy` (singular) | `playback_policies` (plural) | Mux API deprecation announcement (date not specified in API ref; current ref 2026-05-06) | SDK pass-through accepts both; adapter should use plural for forward compatibility |
| Mux REST `input` (singular) | `inputs` (plural, list of objects) | Mux API deprecation (current ref 2026-05-06) | Same as above — adapter should use plural |
| `Mux.Token.sign/2` | `Mux.Token.sign_playback_id/2` | Mux Elixir SDK deprecation in `lib/mux/token.ex` master | sign_playback_id is current; sign carries deprecation notice |
| Oban `{:discard, reason}` | `{:cancel, reason}` | Oban 2.x deprecated `:discard` form in favor of `:cancel` (verified hexdocs.pm/oban) | Same semantics; planner uses `:cancel` |

**Deprecated/outdated:**
- **Don't use `Mux.Token.sign/2`** — deprecated in SDK docstring.
- **Don't use `playback_policy` (singular) for new Mux REST calls** — accepted
  but deprecated by Mux REST API.
- **Don't use `{:discard, reason}` from Oban worker `perform/1`** — deprecated
  alias for `{:cancel, reason}`.
- **Don't use `Mux.Token` defaults for `:expiration`** — 7-day footgun.

## Assumptions Log

> All claims tagged `[ASSUMED]` in this research. The planner and discuss-phase
> use this section to identify decisions that need user confirmation before
> execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Mux Elixir SDK 3.2.2 will accept `playback_policies` (plural, current API key) without rejection — the SDK's `Mux.Video.Assets.create/2` is a thin pass-through (verified). The legacy SDK fixture-test in the SDK repo could not be loaded for direct verification of pass-through behavior with plural keys, but the `def create(client, params), do: Base.post(client, @path, params)` source confirms no key rewriting. | Memo Correction #1 | Adapter must rewrite to singular if SDK rejects — but no rewriting evidence. LOW risk. |
| A2 | `Rindle.Delivery.url(profile, key, expires_in: 1_800)` overrides the profile's `signed_url_ttl_seconds` via `Keyword.put_new/3` in `resolve_url/4` — verified in source — but the public docstring at `delivery.ex:124-145` does not document this. | Pitfall 2 | Adopter-facing public contract doesn't promise this; Phase 34 worker uses an undocumented option. Recommend planner either (a) document `expires_in:` in `Rindle.Delivery.url/3` `@spec` & `@doc`, or (b) add the planner discretion call to use a different mechanism. MEDIUM risk to adopter contract clarity. |
| A3 | Test signing key fixture (`test/fixtures/mux/test_signing_private_key.pem`) is a fresh RSA-2048 keypair generated at the moment of Phase 34 implementation — not committed yet. The Phase 34 plan will need a one-time setup step to generate this. | Wave 0 Gaps | Setup task can be embedded in Wave 0; LOW risk. |
| A4 | The `MediaProviderAsset` Inspect impl's `redact_id/1` helper is currently `defp` (verified at line 111-117). Phase 34 needs either to extract this to a public function or duplicate the logic in worker telemetry emit sites. The extracted-to-public approach is cleaner; the planner should choose. | Pitfall 5 | LOW risk if extracted; MEDIUM if duplicated (drift across emit sites). |
| A5 | The Mux Elixir SDK does not expose the `Mux.Tesla` module documentation publicly via Hexdocs. The `base_url` override mechanism is verified via the SDK source on GitHub but not via Hexdocs. Adopters who debug from Hexdocs may not realize `Mux.Base.new/3` accepts `base_url:` opts. | Code Examples | LOW risk — Phase 34 doesn't override; only relevant if a future test wants to point at a Bypass server (deferred per D-35 anyway). |
| A6 | Oban 2.21+ accepts `{:cancel, reason}` from `perform/1` to stop retries (verified docs). The `process_variant.ex:248-275` mirror uses `{:cancel, ...}` already in production — verified in code, but the actual Oban version in use may differ from Hex tag. mix.exs pins `~> 2.21`; current tag 2.22.1 confirmed. | Pattern 3 | LOW risk; Oban 2.x semantics are stable. |

## Open Questions

1. **Should `MediaProviderAsset.redact_id/1` be promoted to public?**
   - What we know: Phase 33 shipped it as `defp` inside the Inspect impl
     (`lib/rindle/domain/media_provider_asset.ex:111-117`).
   - What's unclear: Phase 34's three workers + adapter all need to redact in
     telemetry emits. Public function avoids duplication.
   - Recommendation: Extract to `def redact_id(id)` on `MediaProviderAsset` as
     a one-line addition. This is a Plan-01 micro-task. Not a semver concern;
     `MediaProviderAsset` is `@moduledoc false`-friendly internal but
     functions on schemas tend to leak through Inspect. Treat as Phase 34
     Wave 0 prep, not a Phase 33 retrofit.

2. **Should `Rindle.Delivery.url/3` document the `:expires_in` option?**
   - What we know: The option exists and works (`delivery.ex:resolve_url/4`).
     The `@spec` does not enumerate it; the `@doc` doesn't mention it.
   - What's unclear: Adding documentation expands the public contract surface.
     Phase 34 uses the option in a private worker — could justify staying
     undocumented.
   - Recommendation: Phase 34 uses the option without documenting publicly.
     If Phase 36's adopter-onboarding guide needs it, document there. This is
     within "Claude's Discretion" per CONTEXT.md.

3. **Cassette fixtures: real Mux capture vs hand-derived?**
   - What we know: D-36 says "Captured from real Mux (or hand-derived from
     https://docs.mux.com/api-reference) and committed verbatim."
   - What's unclear: Real Mux capture requires a Mux test account + token —
     not in CI scope (D-38 defers soak lane to Phase 36).
   - Recommendation: Hand-derive from API ref (verified at MEMO CORRECTION #1
     — concrete example shape known). Phase 36 swaps to captured-real cassettes
     when the soak lane lands. Phase 34 should be hand-derived.

4. **`MuxSyncCoordinator` LIMIT cap on row scan?**
   - What we know: D-23 shows unbounded `Enum.each` over query results.
     Per-row unique constraint deduplicates within 60s window.
   - What's unclear: Production behavior at 1000+ stuck rows. Pitfall 6 documents.
   - Recommendation: Phase 34 ships unbounded. If real-world load shows
     queue-flood, add LIMIT in v1.7. This is "Claude's Discretion" — the
     planner may add `LIMIT 1000` defensively without ceremony.

## Environment Availability

> Phase 34 is pure Elixir code + tests. No external runtime tools required.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir 1.15+ | Compiling | ✓ (per mix.exs) | mix.exs `elixir: "~> 1.15"` | — |
| Erlang/OTP 24+ | Erlang runtime | ✓ (assumed; not phase-specific) | per repo convention | — |
| openssl | Generating test signing key fixture (`test/fixtures/mux/test_signing_private_key.pem`) | check before Wave 0 | any modern (LibreSSL/OpenSSL 1.1+) | hand-derive a key from Mux API docs / use a previously-generated fixture |
| PostgreSQL 14+ | Test DB (Repo) | ✓ (already in use) | per `config/test.exs` | — |
| Mux account (test token) | NOT required for Phase 34 cassette tests; required for Phase 36 soak lane | ✗ (not used by Phase 34) | — | Phase 34 is cassette-only |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** `openssl` for keygen — fallback is to
hand-derive (not actually viable; openssl is universally installed). LOW risk.

## Security Domain

> Required per `security_enforcement` default.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Mux REST: HTTP Basic Auth via Tesla.Middleware.BasicAuth (per `Mux.Base.new/2`); never hand-roll. Webhook signatures: HMAC-SHA256 via `Mux.Webhooks.verify_header/4` (Phase 35 wires; Phase 34 ships callback). |
| V3 Session Management | n/a | No session state in Phase 34; adopter app owns sessions. |
| V4 Access Control | yes | `dispatch_streaming/4` already enforces `authorize_delivery/4` (Phase 33 verified). Phase 34 adapter does NOT bypass this. |
| V5 Input Validation | yes | NimbleOptions on profile DSL (Phase 33). Webhook event normalizer (Phase 34's `event.ex`) validates Mux event schema before crossing into core. |
| V6 Cryptography | yes | RS256 JWT signing via JOSE (`Mux.Token.sign_playback_id/2`); HMAC-SHA256 webhook verify via `Mux.Webhooks.verify_header/4`. **Never hand-roll either.** |

### Known Threat Patterns for Mux REST + Webhook Adapter

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Provider-asset-id leakage to client (URL, log, telemetry) | Information Disclosure | Schema Inspect impl redaction (shipped Phase 33); telemetry redact helper (Phase 34, this research recommends extracting `MediaProviderAsset.redact_id/1` to public). Security invariant 14. |
| Signed-URL TTL bypass (7-day default) | Spoofing | Always pass `expiration: signed_url_ttl_seconds(profile)`; ExUnit assertion on `exp` claim. Pitfall 1 above. |
| Webhook replay | Spoofing | 300s tolerance default in `Mux.Webhooks.verify_header/4`; configurable bounds in Phase 35. Phase 34's callback respects tolerance. |
| Webhook secret rotation gap (only-old-secret-checked outage) | Tampering | Phase 35 multi-secret loop; Phase 34's callback supports the loop API in its signature (`secrets :: [String.t()]`). |
| 429 retry storm | Denial of Service (self-inflicted) | `{:snooze, retry_after}` reads `Retry-After` from `%Tesla.Env{}.headers` directly. Pitfall 3 above. |
| Atomic-promote race (source mutates during ingest) | Tampering / Data Integrity | Capture `expected_storage_key`/`expected_recipe_digest` at enqueue; `{:cancel, {:stale_source, _}}` on flip-to-:ready. Pattern 3 above; mirrors AV-03-10. |
| Optional-dep guard miss → adopter crash | Availability | Wrap every Mux module in `Code.ensure_loaded?(Mux.Video.Assets)`; `dispatch_streaming/4` surfaces `:streaming_not_configured` cleanly. Pitfall 4 above. |
| Mux REST API key leakage (`MUX_TOKEN_SECRET` in logs) | Information Disclosure | Read at call site via `Application.get_env`; never `IO.inspect/1` the credentials map. Mox tests should never embed the real secret. |
| Webhook payload injection (DoS via large payload) | Denial of Service | Plug body cache size limits — Phase 35 owns. Phase 34 webhook callback receives `raw_body :: binary()`; assumes Plug already enforced size cap. |

## Sources

### Primary (HIGH confidence)
- `lib/rindle/streaming/provider.ex` — Phase 33 behaviour (read in full this session)
- `lib/rindle/workers/process_variant.ex` — Atomic-promote template (lines 1-120, 240-340, 400-500 read)
- `lib/rindle/workers/cleanup_orphans.ex` — Cron-driven worker template (read in full)
- `lib/rindle/live_view.ex` — Optional-dep guard pattern (line 1)
- `lib/rindle/delivery.ex` — `streaming_url/3` dispatch tree + `url/3` TTL handling (lines 100-300, 350-400)
- `lib/rindle/domain/media_provider_asset.ex` — Schema + Inspect redaction (read in full)
- `lib/rindle/domain/provider_asset_fsm.ex` — FSM allowlist (read in full)
- `lib/rindle/streaming/capabilities.ex` — Capability vocabulary (read in full)
- `lib/rindle/profile/validator.ex` — `:streaming` DSL schema (lines 40-90)
- `test/support/mocks.ex` — Existing Mox+behaviour pattern (read in full)
- `test/test_helper.exs` — Test framework setup (read in full)
- `test/rindle/workers/process_variant_test.exs` — Test shape template (lines 1-80)
- `mix.exs` — Current dep posture (read in full)
- `config/test.exs` — Test config including `config :oban, Oban, testing: :inline`
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/video/assets.ex` — `create/2`, `get/2`, `delete/2` source verified verbatim
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/token.ex` — `sign_playback_id/2` source verified verbatim including 604_800 default
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/webhooks.ex` — `verify_header/4` arity confirmed; single-secret signature confirmed
- `https://github.com/muxinc/mux-elixir/blob/master/lib/mux/tesla.ex` — `Mux.Tesla.new/3` source verified (BasicAuth + BaseUrl middleware)
- `https://hex.pm/packages/mux` — version `3.2.2`, 2024-07-02 confirmed
- `https://hex.pm/packages/jose` — version `1.11.12`, 2025-11-20 confirmed
- `https://hex.pm/packages/oban` — version `2.22.1`, 2026-04-30 confirmed
- `https://hex.pm/packages/tesla` — version `1.17.0`, 2026-04-18 confirmed
- `https://www.mux.com/docs/api-reference/video/assets/create-asset` — **Memo correction #1** verified: `playback_policies` (plural) is current; `playback_policy` (singular) is deprecated
- `https://hexdocs.pm/oban/Oban.Worker.html` — `timeout/1` returns positive integer ms; `{:snooze, _}`, `{:cancel, _}`/`{:discard, _}` semantics confirmed
- `https://github.com/oban-bg/oban/blob/main/lib/oban/job.ex` — Oban 2.x states `~w(suspended scheduled available executing retryable completed discarded cancelled)a` confirmed

### Secondary (MEDIUM confidence)
- `https://hexdocs.pm/oban/unique_jobs.html` — unique-job options (states list partially documented; verified via Oban.Job source instead)
- `https://hexdocs.pm/mux/Mux.Token.html` — `sign_playback_id/2` parameter docs (`:type` accepts `:video | :gif | :thumbnail | :storyboard`)
- `https://github.com/muxinc/mux-elixir/issues/42` — 429 `Retry-After` swallowed by `simplify_response/1`

### Tertiary (LOW confidence — flagged for validation)
- `https://hexdocs.pm/mux/Mux.Video.Assets.html` — SDK docstring example only includes `input:` key; doesn't enumerate `playback_policies`. Mitigated by direct API ref verification.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions live-verified on Hex.pm; SDK signatures verified against GitHub master.
- Architecture: HIGH — Phase 33 contract read in full; existing Rindle worker patterns (`process_variant.ex`, `cleanup_orphans.ex`) read in full; mirror points are concrete (line numbers).
- Pitfalls: HIGH — each pitfall traces to a verified source line + remediation.
- Memo correction #1 (D-04): HIGH — verified against authoritative Mux API reference cURL example.
- Validation Architecture: MEDIUM — concrete REQ→test map provided, but all test files are NEW; the planner will need to schedule Wave 0 to create scaffolding before implementation.

**Research date:** 2026-05-06
**Valid until:** 2026-06-06 (30 days; Mux SDK 3.2.x and Oban 2.21+ are stable)

## RESEARCH COMPLETE
