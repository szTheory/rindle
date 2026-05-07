---
phase: 33-provider-boundary-state-schema
reviewed: 2026-05-06T00:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - lib/rindle/capability.ex
  - lib/rindle/delivery.ex
  - lib/rindle/domain/media_provider_asset.ex
  - lib/rindle/domain/provider_asset_fsm.ex
  - lib/rindle/error.ex
  - lib/rindle/profile/validator.ex
  - lib/rindle/streaming/capabilities.ex
  - lib/rindle/streaming/provider.ex
  - priv/repo/migrations/20260506120000_create_media_provider_assets.exs
  - test/rindle/capability_test.exs
  - test/rindle/delivery/streaming_dispatch_test.exs
  - test/rindle/delivery_test.exs
  - test/rindle/domain/media_provider_asset_test.exs
  - test/rindle/domain/provider_asset_fsm_test.exs
  - test/rindle/error_streaming_freeze_test.exs
  - test/rindle/profile/validator_test.exs
  - test/rindle/streaming/capabilities_test.exs
  - test/rindle/streaming/provider_test.exs
findings:
  critical: 1
  warning: 4
  info: 5
  total: 10
status: issues_found
---

# Phase 33: Code Review Report

**Reviewed:** 2026-05-06T00:00:00Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Summary

Phase 33 ships a clean public seam for streaming providers: the `Rindle.Streaming.Provider` behaviour is locked at 6 required + 1 optional callbacks, the closed `Rindle.Streaming.Capabilities` vocabulary correctly filters unknown atoms and rescues raises, the `media_provider_assets` schema is additive (no `media_assets` / `media_variants` mutation), `Rindle.Domain.ProviderAssetFSM` enforces the D-13 transition allowlist with telemetry, and the `MediaProviderAsset` `Inspect` impl correctly redacts `provider_asset_id` and `raw_provider_metadata` (verified the `Inspect.Any.inspect/2` bypass pattern preserves the struct layer while skipping the override). `Rindle.Capability.report/0` returns booleans/module-names only and the leak test passes.

However, the 8-branch streaming dispatch in `Rindle.Delivery.streaming_url/3` introduces a **provider-side authorization bypass**: when a profile has both an `:authorizer` AND a `:streaming` provider configured AND the `media_provider_assets` row is in `:ready` state, Branch 5 (`dispatch_provider_signed_url`) mints a signed HLS URL without ever invoking the configured authorizer. Branches 1 and 6 (progressive paths) call `authorize_delivery/4` correctly; Branch 5 does not. This is a security regression vs. the v1.4 progressive contract which always authorizes. There is no test covering "streaming + authorizer + ready row," which is why the gap was missed.

Additional warnings cover: a non-exhaustive case clause in `dispatch_provider_signed_url` that will crash on a contract-violating provider response, NimbleOptions schema entries that include the literal `nil` (works, but fragile across versions), and a couple of doc/edge-case nits.

## Critical Issues

### CR-01: Authorization bypass on Branch 5 of `streaming_url/3`

**File:** `lib/rindle/delivery.ex:275-298`
**Issue:** `dispatch_provider_signed_url/4` mints a signed playback URL for a `:ready` `media_provider_assets` row by calling `streaming_config.provider.signed_playback_url(profile, playback_id, opts)` and emitting telemetry — but it never calls `authorize_delivery/4`. By contrast:

- `Rindle.Delivery.url/3` (line 129) authorizes
- `do_progressive_streaming_url/3` Branch 1 + Branch 6 (line 199) authorize

Effect: any profile that combines a `:streaming` provider with an `:authorizer` will leak signed HLS URLs to callers the authorizer was supposed to reject, as soon as the underlying `media_provider_assets.state` flips to `"ready"`. The bypass is not visible in the dispatch tests because `Rindle.Delivery.StreamingDispatchTest`'s `StreamingProfile` declares no authorizer, and `delivery_test.exs`'s `PrivateProfile` (which declares an authorizer) never goes through Branch 5 (it has no `:streaming` config, so it always lands on Branch 1 — progressive).

This contradicts the security/authorization model documented on `Rindle.Delivery` (private-by-default, "authorization (when configured) runs before any URL is issued").

**Fix:** Have Branch 5 authorize before calling the provider, mirroring the Branch 1/6 contract. Pass a streaming-shaped subject so authorizers can branch on `mode: :hls` if they want to.

```elixir
defp dispatch_provider_signed_url(profile, streaming_config, playback_id, opts) do
  mime = Keyword.get(opts, :mime, "application/vnd.apple.mpegurl")
  mode = delivery_mode(profile)
  subject = %{profile: profile, playback_id: playback_id, mode: mode, kind: :hls}

  with :ok <- authorize_delivery(profile, :deliver, subject, opts),
       {:ok, %{url: _, kind: :hls, mime: returned_mime} = ok} <-
         streaming_config.provider.signed_playback_url(profile, playback_id, opts) do
    :telemetry.execute(
      [:rindle, :delivery, :streaming, :resolved],
      %{system_time: System.system_time()},
      %{
        profile: profile,
        adapter: profile.storage_adapter(),
        mode: mode,
        kind: :hls,
        mime: returned_mime || mime
      }
    )

    {:ok, ok}
  end
end
```

Then add a regression test under `streaming_dispatch_test.exs` that uses a profile with both `:streaming` and `:authorizer`, and asserts:
1. authorizer rejection on a `:ready` row returns `{:error, :forbidden}` and emits no `[:rindle, :delivery, :streaming, :resolved]` telemetry; and
2. authorizer approval still proceeds through the provider call.

## Warnings

### WR-01: Non-exhaustive `case` in `dispatch_provider_signed_url/4` will crash on contract-violating provider returns

**File:** `lib/rindle/delivery.ex:278-297`
**Issue:** The case only matches:

- `{:ok, %{url: _url, kind: :hls, mime: _}}`
- `{:error, _}`

Any other shape — including `{:ok, %{url: _, kind: :progressive, mime: _}}`, `{:ok, %{url: _}}` (missing `:kind`), or a bare `:ok` — raises `CaseClauseError` from inside core dispatch. The `Rindle.Streaming.Provider` behaviour `@callback signed_playback_url/3` is typed to require `kind: :hls`, but a buggy or unmaintained adapter that returns `kind: :progressive` will crash callers instead of producing a clean `{:error, _}` tuple. Crashes from inside `Rindle.Delivery` during request handling are particularly bad because they bypass the locked public-error vocabulary.

**Fix:** Add a defensive catch-all clause that converts unexpected `:ok` shapes into a typed error. Suggest a new error atom under the locked vocabulary, or reuse `:provider_sync_failed` since the adapter is misbehaving.

```elixir
case streaming_config.provider.signed_playback_url(profile, playback_id, opts) do
  {:ok, %{url: _url, kind: :hls, mime: returned_mime} = ok} ->
    # ... emit telemetry, return ok
  {:error, _} = err ->
    err
  other ->
    Logger.warning(
      "rindle.streaming.provider_returned_invalid_shape",
      provider: streaming_config.provider,
      returned: inspect(other, limit: 5)
    )
    {:error, :provider_sync_failed}
end
```

### WR-02: NimbleOptions schema entries use the bare literal `nil` as a type; relies on undocumented permissiveness

**File:** `lib/rindle/profile/validator.ex:18`, `:21`, `:42`, `:46`, `:49`, `:96`, `:88`
**Issue:** Several schemas use `{:or, [..., nil]}` (e.g. `{:or, [:pos_integer, nil]}`, `{:or, [:atom, nil]}`, `{:or, [:keyword_list, {:map, :atom, :any}, nil]}`). NimbleOptions does not officially document `nil` as a stand-alone type marker — its built-in `nil` handling is via `default: nil` plus an explicit `{:in, [...]}` allowlist. The current code happens to work on the project's pinned NimbleOptions version and is exercised by tests like `validator_test.exs:382-393` ("explicit `streaming: nil` → nil"), but it's a silent compatibility hazard the next time NimbleOptions is bumped. If NimbleOptions tightens its `:or` validator, every Phase 33 profile that opts out of streaming via `streaming: nil` (or omits `signed_url_ttl_seconds`, etc.) will fail to compile.

**Fix:** Either (a) keep the `nil` clauses but pin NimbleOptions to a compatible version range and add a `mix deps` lock comment, or (b) replace with the documented pattern: handle nil before NimbleOptions sees it (the validator already does this for `:streaming` at line 273 via `validate_streaming!(nil, _) -> nil`; extend the same pre-filter to the other `{:or, [..., nil]}` entries) and drop `nil` from the NimbleOptions type lists.

### WR-03: `do_progressive_streaming_url/3` raises `FunctionClauseError` for asset-shaped maps with no `:storage_key`

**File:** `lib/rindle/delivery.ex:228-231`
**Issue:** Branch 6 (no row, non-strict) and the asset-form Branch 1 path call:

```elixir
defp do_progressive_streaming_url(profile, asset, opts) when is_map(asset) do
  key = key_for(asset, :storage_key)
  do_progressive_streaming_url(profile, key, opts)
end
```

If `key_for(asset, :storage_key)` returns `nil` (e.g. caller passed `%{id: "..."}` without `:storage_key`), control falls into `do_progressive_streaming_url(profile, nil, opts)`. There is no clause matching `nil` (the binary clause has `is_binary(key)`, the map clause has `is_map(asset)`), so it raises `FunctionClauseError` from inside core. This is an internal crash for an externally-supplied bad map, where a typed `{:error, :provider_asset_not_ready}` (or a new `:invalid_asset` atom) would be friendlier and consistent with how the rest of the dispatch layer handles edge cases.

**Fix:** Guard the recursive call:

```elixir
defp do_progressive_streaming_url(profile, asset, opts) when is_map(asset) do
  case key_for(asset, :storage_key) do
    key when is_binary(key) -> do_progressive_streaming_url(profile, key, opts)
    _ -> {:error, :provider_asset_not_ready}
  end
end
```

### WR-04: `dispatch_streaming` discards the `playback_policy` from the row in favour of the live `streaming_config`

**File:** `lib/rindle/delivery.ex:233-273`
**Issue:** `dispatch_streaming/4` reads only `state` and `playback_ids` off the `MediaProviderAsset` row; the row's `playback_policy` (and `ingest_mode`) fields are never consulted in the dispatch tree, even though they are persisted by `MediaProviderAsset.changeset/2`. If the persisted row's `playback_policy` is `"public"` but the live profile config later flips to `:signed`, dispatch will mint a signed URL anyway (via the provider), and vice versa for the inverse case. Because Phase 33 doesn't ship a Mux adapter this is currently a no-op divergence, but it is a latent invariant gap that will bite Phase 34. The code comments / dispatch table in `streaming_url/3`'s `@doc` (line 156-167) treat `state` as the single source of truth.

**Fix:** Either delete `playback_policy` and `ingest_mode` from the schema (and drop the columns from the migration), or assert they match `streaming_config` before Branch 5 fires:

```elixir
%MediaProviderAsset{state: "ready", playback_policy: row_policy, playback_ids: [playback_id | _]}
when row_policy == nil or
       row_policy == Atom.to_string(streaming_config.playback_policy) ->
  dispatch_provider_signed_url(...)

%MediaProviderAsset{state: "ready"} ->
  {:error, :provider_sync_failed}  # config drift between row and profile
```

Phase 34 should not be the first phase to discover this invariant.

## Info

### IN-01: `streaming_url/3` docstring claims "8-branch dispatch tree" but only enumerates Branches 1-7

**File:** `lib/rindle/delivery.ex:149`, `:156-168`
**Issue:** The doc says "8-branch dispatch tree (per CONTEXT D-19)" and then numbers branches 1 through 7. Branch 5b (the defensive `state == "ready", playback_ids: []` path) is the 8th. A casual reader counting branches in the docstring will be off by one.
**Fix:** Either explicitly call out Branch 5b in the numbered list, or update the leading sentence to "deterministic 7-branch dispatch tree (with Branch 5b defensive guard)".

### IN-02: `MediaProviderAsset` schema retains fields that no caller reads in Phase 33

**File:** `lib/rindle/domain/media_provider_asset.ex:50-55`
**Issue:** `playback_policy`, `ingest_mode`, `last_event_id`, `last_event_at` are persisted and writable, but no Phase 33 code path reads them. They are reserved for Phase 34. Carrying unused columns is fine (additive migration), but worth a TODO so Phase 34 doesn't mistake them for "already implemented."
**Fix:** Add a `@deprecated` (no, not appropriate) — instead, add a single comment near the schema block: `# Phase 33 reserves these for Phase 34 (Mux adapter); no Phase 33 dispatch reads them.`

### IN-03: `Capability.report/0` `processor_report/2` builds reports under `profile` key when no processor is declared

**File:** `lib/rindle/capability.ex:60-68`
**Issue:** When `safely_call_zero(profile, :processor)` returns `nil`, the entry is keyed by `profile` (a profile module) with caps `[]`. Mixing profile and processor modules in the keys of `processor_report` makes `report().processor` a heterogeneous map. The locked report shape `%{processor: %{module() => [atom()]}}` allows it, but downstream consumers (Phase 36 doctor) will need to discriminate.
**Fix:** Either skip `nil`-processor profiles entirely, or document the heterogeneous-key invariant on the `@type report` docstring.

### IN-04: `Inspect.Any.inspect/2` direct-call pattern is undocumented Elixir API

**File:** `lib/rindle/domain/media_provider_asset.ex:108`
**Issue:** Calling `Inspect.Any.inspect(redacted, opts)` works (verified manually with a struct that overrides Inspect — output `%Foo{a: "REDACTED", b: 1, c: 2}` is correct), but `Inspect.Any` is not part of Elixir's documented public API. The standard pattern when you want default struct rendering after redacting fields is to either `@derive Inspect, only: [...]` or to build the algebra document directly with `Inspect.Algebra.container_doc/4`. If a future Elixir release reorganizes `Inspect.Any`, the redaction layer breaks silently — not loudly — because the override would still be invoked and the test asserts on absence of secrets, not on the exact rendering shape.
**Fix:** Migrate to `@derive {Inspect, except: [:provider_asset_id, :raw_provider_metadata]}` and override only those two fields with hand-built algebra in the override; or pin Elixir's stdlib version range. Either is preferable to relying on `Inspect.Any.inspect/2` long-term.

### IN-05: `derive_provider_name/1` silently accepts any atom; bad config crashes inside `Module.split/1`

**File:** `lib/rindle/delivery.ex:301-306`
**Issue:** `derive_provider_name(provider_module) when is_atom(provider_module)` admits all atoms. If a profile's compile-time validator regresses (or a config value is hot-reloaded with a non-module atom like `:mux`), `Module.split(:mux)` raises `ArgumentError` from inside dispatch. The validator currently rejects this at compile time, but the dispatch layer should fail closed regardless.
**Fix:** Pattern-match more strictly or rescue:

```elixir
defp derive_provider_name(provider_module) when is_atom(provider_module) do
  provider_module |> Module.split() |> List.last() |> Macro.underscore()
rescue
  ArgumentError -> Atom.to_string(provider_module)
end
```

---

## Fixes Applied

Applied 2026-05-06 by gsd-code-fixer (scope: critical + warning only; Info findings deferred).

| Finding | Severity | Commit | Description |
| --- | --- | --- | --- |
| CR-01 | Critical | `d16cd02` | Added `authorize_delivery/4` call in `dispatch_provider_signed_url/4` (streaming-shaped subject `%{profile, playback_id, mode, kind: :hls}`) before the provider call. Added two regression tests in `streaming_dispatch_test.exs`: rejection short-circuits before the provider and emits no `[:rindle, :delivery, :streaming, :resolved]` telemetry; approval still proceeds. |
| WR-01 | Warning | `a344614` | Added defensive catch-all clause to the `case` in `dispatch_provider_signed_url/4`. Logs an invalid-shape warning via `Logger.warning/1` and returns `{:error, :provider_sync_failed}` for any `:ok` shape that does not match `%{url, kind: :hls, mime}`. Added `require Logger` to the module. |
| WR-02 | Warning | `730b668` | Dropped bare `nil` from every `{:or, [..., nil]}` schema entry across `@profile_schema`, `@delivery_schema`, and `@image_variant_schema` (option (b)). Removed `default: nil` from those fields (NimbleOptions 1.1+ validates declared defaults against the type, which would reject `default: nil` once `nil` is removed from the type list). Added `drop_nil_values/1` pre-filter applied at every `NimbleOptions.validate!/2` entry point, and switched downstream `Keyword.fetch!` callsites to `Keyword.get(.., nil)` so absent → nil semantics are preserved. The `{:in, [1, 2, nil]}` allowlist on `@audio_variant_schema` was left unchanged because that's the documented allowlist pattern, not the bare-`nil` pitfall in `:or`. |
| WR-03 | Warning | `3a7609b` | Replaced the unconditional recursive call in `do_progressive_streaming_url(profile, asset, opts) when is_map(asset)` with a `case key_for(asset, :storage_key)` that returns `{:error, :provider_asset_not_ready}` when the resolved key is not a binary, instead of crashing with `FunctionClauseError`. |
| WR-04 | Warning | `0d35cff` | Added `streaming_config_drift/2`: cross-checks the persisted `playback_policy` and `ingest_mode` on `:ready` rows against the live `streaming_config` (after `Atom.to_string` normalization). When they disagree, refuses to mint and emits a `[:rindle, :delivery, :streaming, :config_drift]` warning telemetry event with `field`, `row_value`, `expected`, `profile`, `provider` metadata; returns `{:error, :provider_sync_failed}`. nil row fields are treated as "not yet recorded" and skipped (no drift) for backward-compatibility. Added three regression tests covering policy drift, mode drift, and aligned rows. |

**Regression suite:** `mix test test/rindle/streaming/ test/rindle/domain/ test/rindle/error_streaming_freeze_test.exs test/rindle/capability_test.exs test/rindle/error_test.exs test/rindle/delivery_test.exs test/rindle/delivery/ test/rindle/profile/validator_test.exs test/rindle/contracts/telemetry_contract_test.exs` — **235 tests, 0 failures (14 excluded by tag)**.

**v1.4 telemetry tripwires:** `delivery_test.exs:352-391` (the renumbered counterparts) and `telemetry_contract_test.exs:74,277` remain byte-for-byte unchanged; the `[:rindle, :delivery, :streaming, :resolved]` event still fires on Branches 1 and 6 with `kind: :progressive` and on Branch 5 (when authorized + no drift) with `kind: :hls`. The new `[:rindle, :delivery, :streaming, :config_drift]` event is additive.

**Info findings deferred:** IN-01 through IN-05 are out of scope for this fix pass and remain open for future cleanup.

---

_Reviewed: 2026-05-06T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
