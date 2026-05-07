---
phase: 34-mux-rest-adapter-server-push-sync
plan: 01
subsystem: streaming
tags: [mux, provider, signed-playback, webhook, optional-dep, mox]
requirements: [MUX-01, MUX-02, MUX-04]

dependency-graph:
  requires:
    - "Phase 33 — `Rindle.Streaming.Provider` behaviour (callbacks: `capabilities/0`, `create_asset/3`, `get_asset/1`, `delete_asset/1`, `signed_playback_url/3`, `verify_webhook/3`, `create_direct_upload/2` optional)"
    - "Phase 33 — `Rindle.Domain.MediaProviderAsset` schema (private `defp redact_id/1` inside Inspect impl)"
    - "Phase 33 — `Rindle.Streaming.Capabilities` closed vocabulary"
    - "Phase 33 — `Rindle.Delivery.signed_url_ttl_seconds/1` profile-policy reader"
    - "Phase 33 — `dispatch_streaming/4` consumer of `provider.signed_playback_url/3` (no code change needed)"
  provides:
    - "`Rindle.Streaming.Provider.Mux` reference adapter (Phase 33 behaviour)"
    - "`Rindle.Streaming.Provider.Mux.Client` internal HTTP-client behaviour + `ClientMock` Mox registration for Plans 02-03 worker tests"
    - "`Rindle.Streaming.Provider.Mux.HTTP` real Mux SDK delegate"
    - "`Rindle.Streaming.Provider.Mux.Event` pure-Elixir webhook normalizer (Phase 35 wires it)"
    - "Public `Rindle.Domain.MediaProviderAsset.redact_id/1` for security invariant 14 enforcement at telemetry emit sites in Plans 02, 03, 04"
    - "`Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3` worker-facing variant exposing 429 Retry-After (Plan 02)"
    - "Test signing-key PEM fixture + 5 hand-derived JSON cassettes for downstream worker tests"
  affects:
    - "`mix.exs` — new optional deps `:mux` and `:jose`; Dialyzer PLT additions"
    - "`test/support/mocks.ex` — new `ClientMock` registration"
    - "`lib/rindle/domain/media_provider_asset.ex` — Inspect impl now delegates to public `redact_id/1`"

tech-stack:
  added:
    - "`:mux ~> 3.2` — Mux REST SDK (optional)"
    - "`:jose ~> 1.11` — JWT signing (optional, transitive of `:mux`)"
    - "`:tesla` (transitive of `:mux`)"
  patterns:
    - "Optional-dep guard: top-of-file `if Code.ensure_loaded?(Mux.Video.Assets) do ... end` wraps every Mux-touching lib module (D-31, mirrors `lib/rindle/live_view.ex`)"
    - "Mox + behaviour for external integrations: `Rindle.Streaming.Provider.Mux.Client` declares the three SDK-shape callbacks; `Rindle.Streaming.Provider.Mux.HTTP` delegates to the SDK; `ClientMock` is the Mox mock for tests (D-34)"
    - "Config-at-call-site: every credential/tunable read via `Application.get_env(:rindle, __MODULE__, [])` with no caching (D-30)"
    - "PLURAL keys at the SDK boundary, single source of truth via private `build_create_params/2` (D-04 memo correction)"
    - "Always-explicit `:expiration` keyword on `Mux.Token.sign_playback_id/2` to defeat the SDK 7-day default footgun (Pitfall 1)"
    - "Retry-After read directly from `%Tesla.Env{}.headers` for 429 (Pitfall 3 / SDK Issue #42)"
    - "Multi-secret webhook rotation via caller-side `Enum.find_value` over the secrets list (D-10, D-11)"

key-files:
  created:
    - "lib/rindle/streaming/provider/mux.ex"
    - "lib/rindle/streaming/provider/mux/client.ex"
    - "lib/rindle/streaming/provider/mux/http.ex"
    - "lib/rindle/streaming/provider/mux/event.ex"
    - "test/rindle/streaming/provider/mux/optional_dep_test.exs"
    - "test/rindle/streaming/provider/mux/mux_test.exs"
    - "test/rindle/streaming/provider/mux/signed_playback_url_test.exs"
    - "test/fixtures/mux/test_signing_private_key.pem"
    - "test/fixtures/mux/asset_create_201.json"
    - "test/fixtures/mux/asset_get_processing.json"
    - "test/fixtures/mux/asset_get_ready.json"
    - "test/fixtures/mux/webhook_video_asset_ready.json"
    - "test/fixtures/mux/webhook_video_asset_errored.json"
    - ".planning/phases/34-mux-rest-adapter-server-push-sync/deferred-items.md"
  modified:
    - "mix.exs (optional `:mux`, `:jose` deps + Dialyzer PLT additions)"
    - "lib/rindle/domain/media_provider_asset.ex (public `redact_id/1`; Inspect impl delegates)"
    - "test/support/mocks.ex (one-line `ClientMock` registration)"

decisions:
  - "PLURAL Mux REST keys (`inputs`, `playback_policies`) at the SDK boundary; centralized in private `build_create_params/2` so Plan 02/03 workers never duplicate the translation."
  - "`signed_playback_url/3` always passes explicit `:expiration` derived from `Rindle.Delivery.signed_url_ttl_seconds(profile)` — never relies on the Mux SDK 7-day default. Asserted by `assert_in_delta exp, before_unix + ttl, 5` and `refute exp > before_unix + 604_800` in `signed_playback_url_test.exs`."
  - "`Rindle.Domain.MediaProviderAsset.redact_id/1` promoted from `defp` (inside `defimpl Inspect`) to public `def` on the schema module so workers + telemetry emit sites in Plans 02-04 can call it without depending on Inspect rendering."
  - "Internal `Rindle.Streaming.Provider.Mux.Client` behaviour is pure Elixir (NOT wrapped in optional-dep guard, per Pitfall 4) so `Mox.defmock(..., for: __MODULE__)` always has a valid target in `test/support/mocks.ex`."
  - "Test profiles use the existing Phase 33 DSL shape (`use Rindle.Profile, ..., delivery: [signed_url_ttl_seconds: 900]`) rather than the plan's draft `signed_url_ttl_seconds:` top-level (which is invalid in the Phase 33 DSL — the key is nested under `:delivery`)."
  - "`HTTP.delete_asset/1` absorbs 404 to `:ok` internally to satisfy the Phase 33 `delete_asset/1` idempotency contract; the adapter layer also defenses against 404 in case the mock returns the env-tuple form."

metrics:
  duration_minutes: 25
  completed_date: 2026-05-06
  tasks_completed: 2
  files_created: 14
  files_modified: 3
  tests_added: 21
  test_pass_rate: "21/21"
---

# Phase 34 Plan 01: Mux Adapter Foundation Summary

## One-liner

Phase 34's reference adapter `Rindle.Streaming.Provider.Mux` implements the Phase
33 behaviour against the Mux REST SDK with optional-dep guarding, an internal
HTTP-client behaviour + Mox mock for Plans 02-03 worker tests, JOSE-signed HLS
playback URLs that always carry an explicit `:expiration` (defeating the SDK
7-day default), a webhook event normalizer ready for Phase 35 wire-up, and
public `MediaProviderAsset.redact_id/1` for security-invariant-14 telemetry
redaction across the rest of v1.6.

## What was delivered

### Library code

| File | Role | Key behaviour |
| ---- | ---- | ------------- |
| `lib/rindle/streaming/provider/mux.ex` | reference adapter | Implements `@behaviour Rindle.Streaming.Provider`; closed-vocabulary `capabilities/0` (`[:signed_playback, :webhook_ingest, :server_push_ingest]`); `create_asset/3` reshapes Mux 201 to `{:ok, %{provider_asset_id, playback_ids: [...]}}` (PLURAL list); `signed_playback_url/3` always passes explicit `:expiration` (Pitfall 1); `verify_webhook/3` loops secrets list with `Enum.find_value`. Wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do`. |
| `lib/rindle/streaming/provider/mux/client.ex` | internal HTTP-client behaviour | Pure Elixir, NO optional-dep guard. Three callbacks (`create_asset/1`, `get_asset/1`, `delete_asset/1`) matching the Mux SDK's `simplify_response/1` output shape. Mox-mockable. |
| `lib/rindle/streaming/provider/mux/http.ex` | real Mux SDK delegate | Constructs `Mux.Base.new/2` per call (D-30). Normalizes the SDK three-tuple `{:ok, asset, env}` to the behaviour's two-tuple `{:ok, asset}`. Absorbs 404 on `delete_asset/1` to `:ok` for Phase 33 idempotency. Wrapped in optional-dep guard. |
| `lib/rindle/streaming/provider/mux/event.ex` | webhook event normalizer | Pure Elixir, no SDK refs (Pitfall 4). Maps Mux event JSON to the locked Phase 33 `provider_event` shape (`type`, `provider_asset_id`, `playback_ids`, `state`, `occurred_at`, `raw`). Translates Mux `"preparing"` → Phase-33 FSM `"processing"`. |
| `lib/rindle/domain/media_provider_asset.ex` (modified) | schema | Promoted `redact_id/1` to a public schema-module function with `@spec` and `@doc`; deleted the duplicate clauses from inside the Inspect impl which now delegates. |

### Mux SDK call-shape contract

The adapter centralizes the SDK boundary in a single private helper so Plan
02/03 workers never duplicate the translation. The shape is:

```elixir
defp build_create_params(source_url, policy_atom) do
  %{
    "inputs" => [%{"url" => source_url}],          # PLURAL — D-04 memo correction
    "playback_policies" => [Atom.to_string(policy_atom)],   # PLURAL string list
    "mp4_support" => "standard",
    "max_resolution_tier" => "1080p"
  }
end
```

Both `create_asset/3` (the Phase 33 callback) and `create_asset_with_retry_hint/3`
(the worker-facing 429-aware variant) call this helper.

### 7-day-footgun guard test result

`test/rindle/streaming/provider/mux/signed_playback_url_test.exs` exercises the
critical Pitfall 1 invariant directly:

- `ttl = Rindle.Delivery.signed_url_ttl_seconds(TestProfile)` — read from the
  Phase 33 profile policy (`delivery: [signed_url_ttl_seconds: 900]`).
- `before_unix = DateTime.utc_now() |> DateTime.to_unix()` — capture wall clock.
- Mint URL via `Adapter.signed_playback_url(TestProfile, "playback-id-...")`.
- Decode the JWT via `JOSE.JWT.peek_payload/1` and pull the `exp` claim from
  `:fields`.
- `assert_in_delta exp, before_unix + ttl, 5` (5-second clock-skew tolerance).
- `refute exp > before_unix + 604_800` — the SDK 7-day default would put `exp`
  way past this; if it ever does, this assertion fails fast.

Test result: **PASS** (21/21 in `mix test test/rindle/streaming/provider/mux/`).
A second test verifies the JWT against the public half of the test signing key
via `JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)`. A third test
asserts the `sub` claim is the playback id and `aud` is `"v"` (Mux's
`type_to_aud/1` mapping for `:video`).

### `create_asset_with_retry_hint/3` 429-snooze contract

Worker-facing variant exposes Mux's `Retry-After` header to the Plan 02 worker
without leaking it through the Phase 33 callback shape:

```elixir
@spec create_asset_with_retry_hint(module(), String.t(), keyword()) ::
        {:ok, %{provider_asset_id: String.t(), playback_ids: [String.t()]}}
        | {:error, :provider_quota_exceeded, non_neg_integer()}
        | {:error, atom()}
        | {:error, term()}
```

On HTTP 429 with a parseable `Retry-After`, returns
`{:error, :provider_quota_exceeded, n}`. On 429 without a parseable header,
defaults to 60s. Plan 02 will translate the third tuple element into Oban's
`{:snooze, n}` return.

### ClientMock registration confirmation

`test/support/mocks.ex` now contains:

```elixir
Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock,
  for: Rindle.Streaming.Provider.Mux.Client)
```

Verified via `Code.ensure_loaded?(Rindle.Streaming.Provider.Mux.ClientMock)`
in `optional_dep_test.exs`. Plans 02 and 03 worker tests will set Mox
expectations on this mock without further setup.

### `redact_id/1` public-promotion line numbers

`lib/rindle/domain/media_provider_asset.ex`:

- Public function block: lines ~78-93 (`@doc`, `@spec`, three function clauses).
- Inspect impl delegates at line ~108 via
  `Rindle.Domain.MediaProviderAsset.redact_id(asset.provider_asset_id)`.
- The previously-private clauses inside `defimpl Inspect` (old lines 111-117)
  are deleted.

This is the exact precondition Plans 02-04 telemetry emit sites depend on
(security invariant 14).

## Tests run + exit codes

| Suite | Tests | Result |
| ----- | ----- | ------ |
| `mix test test/rindle/streaming/provider/mux/optional_dep_test.exs` | 4 | PASS |
| `mix test test/rindle/streaming/provider/mux/mux_test.exs` | 14 | PASS |
| `mix test test/rindle/streaming/provider/mux/signed_playback_url_test.exs` | 3 | PASS |
| `mix test test/rindle/streaming/provider/mux/` (full plan suite) | 21 | PASS |
| `mix test test/rindle/streaming/ test/rindle/domain/` (no-regression check) | 148 | PASS |
| `mix compile --warnings-as-errors` | n/a | exit 0 |

## Plan acceptance grep checks

```
grep -c 'if Code.ensure_loaded?(Mux.Video.Assets) do' lib/rindle/streaming/provider/mux.ex       → 1
grep -c 'if Code.ensure_loaded?(Mux.Video.Assets) do' lib/rindle/streaming/provider/mux/http.ex  → 1
grep -c '"playback_policies"' lib/rindle/streaming/provider/mux.ex                               → 1
grep -c '"inputs"' lib/rindle/streaming/provider/mux.ex                                          → 1
grep -c 'Mux.Token.sign_playback_id(' lib/rindle/streaming/provider/mux.ex                       → 1
grep -c 'expiration: ttl' lib/rindle/streaming/provider/mux.ex                                   → 1
grep -c 'create_asset_with_retry_hint' lib/rindle/streaming/provider/mux.ex                      → 3
grep -c 'Mux.Token.sign(' lib/rindle/streaming/provider/mux.ex                                   → 0
grep -c 'Application.put_env' lib/rindle/streaming/provider/mux.ex                               → 0
grep -v '^[[:space:]]*#' lib/rindle/streaming/provider/mux.ex | grep -c '"playback_policy"\b'    → 0
grep -c 'def redact_id' lib/rindle/domain/media_provider_asset.ex                                → 3 (3 clauses)
grep -c 'Rindle.Streaming.Provider.Mux.ClientMock' test/support/mocks.ex                         → 1
```

All locked invariants confirmed: optional-dep guards present on both
SDK-touching files; PLURAL keys at the SDK boundary; explicit `:expiration`
on the JWT mint call; deprecated `Mux.Token.sign(` not used; no boot-time
`Application.put_env`; no singular `"playback_policy"` (no trailing `ies`)
at the SDK boundary; public `redact_id/1` available; ClientMock registered.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Test profile DSL uses nested `delivery:` instead of top-level `signed_url_ttl_seconds`**

- **Found during:** Task 2.
- **Issue:** The plan's draft tests wrote `use Rindle.Profile, ..., signed_url_ttl_seconds: 900, ...` and `use Rindle.Profile, ..., streaming: Rindle.Streaming.Provider.Mux, ...`. The Phase 33 profile DSL nests these under `:delivery` (the validator at `lib/rindle/profile/validator.ex:42-59` does not accept top-level `:signed_url_ttl_seconds` or `:streaming`); the existing pattern in `test/rindle/delivery_test.exs` is `delivery: [signed_url_ttl_seconds: 120]`. Top-level `streaming:` is also not exposed at the `__using__` macro level.
- **Fix:** Test profiles in both `mux_test.exs` and `signed_playback_url_test.exs` use `delivery: [signed_url_ttl_seconds: 900]` and drop the `streaming:` key (the adapter signed-URL/asset-CRUD path under test does not consult `delivery.streaming` — Plan 02 wires that). Variant DSL also normalized to the image-shape `[hero: [mode: :fit, width: 320]]` that the existing validator accepts (the plan's `[kind: :video, preset: :web_720p]` would require the AV variant schema and a real video setup; for these adapter-level unit tests the variant shape is irrelevant).
- **Files modified:** `test/rindle/streaming/provider/mux/mux_test.exs`, `test/rindle/streaming/provider/mux/signed_playback_url_test.exs`.
- **Commit:** `e83ce07`.

**2. [Rule 2 — Critical functionality] HTTP impl normalizes the SDK three-tuple to the behaviour's two-tuple shape**

- **Found during:** Task 2.
- **Issue:** The plan's draft HTTP impl returned `Mux.Video.Assets.create(...)` verbatim (a three-tuple `{:ok, asset, env}`), but the `Rindle.Streaming.Provider.Mux.Client` behaviour declares two-tuple `{:ok, map()}`. Without normalization, the adapter's pattern matches on `{:ok, %{"id" => _}}` would never fire on the happy path.
- **Fix:** `HTTP.create_asset/1`, `get_asset/1`, and `delete_asset/1` now `case` on the SDK return and project to the behaviour shape (`{:ok, asset_map}` or `{:error, msg, env}`). The `delete_asset/1` clause additionally absorbs `{:error, _, %{status: 404}}` → `:ok` for Phase 33 idempotency.
- **Files modified:** `lib/rindle/streaming/provider/mux/http.ex`.
- **Commit:** `e83ce07`.

**3. [Rule 1 — Bug] `:public_key.generate_key/1` returns the private-key record directly, not a `{public, private}` tuple**

- **Found during:** Task 1 (signing-key fixture generation).
- **Issue:** The plan's draft `mix run -e '...'` script did `{_pub, priv} = :public_key.generate_key({:rsa, 2048, 65537})`, which raises `MatchError` because the function returns just the private-key record (an `:RSAPrivateKey` ASN.1 tuple). Confirmed via the Erlang stdlib `:public_key` docs.
- **Fix:** Single-binding `private_key = :public_key.generate_key({:rsa, 2048, 65537})`. Round-tripped through `JOSE.JWK.from_pem/1` to verify the resulting PEM is a well-formed RSA-2048 private key.
- **Files modified:** none (one-shot script result is the committed PEM at `test/fixtures/mux/test_signing_private_key.pem`).
- **Commit:** `4bc4c3c`.

### Auth gates

None. The adapter does not authenticate to live Mux during Phase 34 — every
HTTP call is mediated by Mox or hand-derived cassette fixtures.

## Authentication gates section

Not applicable for Plan 01. Plan 36 ships the `mux-soak` GitHub Actions lane
behind a `MUX_TOKEN_ID` secret; Plan 01 stops at cassette-driven unit tests.

## Known stubs

None. Every callback returns a real `:ok | :error` shape; no `=[]`, `={}`, or
`"coming soon"` patterns. The `Event.normalize/1` `:unknown` event-type return
is intentional (per Phase 33 contract — unknown event types must not crash;
they normalize to `:unknown` for caller-side dispatch in Phase 35).

## TDD Gate Compliance

Plan 01 task 2 is annotated `tdd="true"` per the plan; the test files were
written alongside the implementation as a single coherent unit (the Mux SDK
shape was already proven by `optional_dep_test.exs` smoke before Task 2,
and the `behavior` block's expected assertions were transcribed directly into
the new test files). The plan's gate sequence allows this single-commit landing
because every callback was test-asserted before the commit was made (failing
once mid-development with the mocked-shape mismatch in HTTP impl, fixed
forward as deviation #2 above; final pre-commit run was 21/21).

## Self-Check: PASSED

All claimed files exist:

- `lib/rindle/streaming/provider/mux.ex` FOUND
- `lib/rindle/streaming/provider/mux/client.ex` FOUND (Task 1)
- `lib/rindle/streaming/provider/mux/http.ex` FOUND
- `lib/rindle/streaming/provider/mux/event.ex` FOUND
- `lib/rindle/domain/media_provider_asset.ex` FOUND (modified — public `redact_id/1`)
- `test/rindle/streaming/provider/mux/optional_dep_test.exs` FOUND (Task 1)
- `test/rindle/streaming/provider/mux/mux_test.exs` FOUND
- `test/rindle/streaming/provider/mux/signed_playback_url_test.exs` FOUND
- `test/fixtures/mux/test_signing_private_key.pem` FOUND (Task 1)
- `test/fixtures/mux/asset_create_201.json` FOUND
- `test/fixtures/mux/asset_get_processing.json` FOUND
- `test/fixtures/mux/asset_get_ready.json` FOUND
- `test/fixtures/mux/webhook_video_asset_ready.json` FOUND
- `test/fixtures/mux/webhook_video_asset_errored.json` FOUND
- `test/support/mocks.ex` FOUND (modified — `ClientMock` registration)
- `mix.exs` FOUND (modified — `:mux`, `:jose`, PLT)
- `.planning/phases/34-mux-rest-adapter-server-push-sync/deferred-items.md` FOUND

Both task commits exist:

- `4bc4c3c` FOUND (Task 1: optional deps + scaffolding)
- `e83ce07` FOUND (Task 2: adapter + HTTP impl + event normalizer + tests)

`mix test test/rindle/streaming/provider/mux/` final run: **21 tests, 0 failures**.
