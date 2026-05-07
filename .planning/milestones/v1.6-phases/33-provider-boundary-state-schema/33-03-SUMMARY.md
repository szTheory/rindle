---
phase: 33-provider-boundary-state-schema
plan: "03"
subsystem: profile-dsl-and-delivery-dispatch
tags: [elixir, profile-dsl, nimble-options, dispatch, telemetry, repo-get-by]
requirements_completed: [STREAM-05, STREAM-06]
dependencies:
  requires:
    - "Plan 33-01 — Rindle.Streaming.Provider behaviour (signed_playback_url/3 callback)"
    - "Plan 33-02 — Rindle.Domain.MediaProviderAsset schema (Repo.get_by target with unique index from D-10)"
    - "Plan 33-04 — five new bare-atom error reason clauses (rendered when dispatch returns the atoms)"
  provides:
    - "Profile DSL :streaming key — NimbleOptions-validated, named-only, raw provider knobs forbidden (D-15..D-18)"
    - "Rindle.Delivery.streaming_url/3 D-19 dispatch tree — 8 branches + defensive Branch 5b"
    - "v1.4 telemetry contract preserved verbatim on Branches 1 and 6 (D-24); Branch 5 emits with kind: :hls"
    - ":strict opt flips Branch 6 to Branch 7 (D-20)"
  affects:
    - "Phase 34 Mux adapter — implements signed_playback_url/3; dispatch tree calls into it on Branch 5"
    - "Phase 34 MuxIngestVariant worker — populates the row whose state Branches 3/4/5 read"
    - "Phase 36 mix rindle.doctor — will surface streaming-config validation gaps that the validator catches at compile time"
tech-stack:
  added: []
  patterns:
    - "Pattern D — NimbleOptions schema + validate!/2 + rescue NimbleOptions.ValidationError → reraise ArgumentError; closed allowlist rejects raw provider knobs"
    - "Pattern H — Telemetry preservation on extended call sites; same measurement key (:system_time) and same metadata key set (:profile, :adapter, :mode, :kind, :mime); only :kind value changes (:progressive ↔ :hls)"
    - "do_progressive_streaming_url/3 — v1.4 body preserved verbatim as a private helper called from Branches 1 and 6"
key-files:
  created:
    - "test/rindle/delivery/streaming_dispatch_test.exs"
  modified:
    - "lib/rindle/profile/validator.ex"
    - "lib/rindle/delivery.ex"
    - "test/rindle/profile/validator_test.exs"
decisions:
  - "Reordered the validate!/1 pipeline so variants are validated before delivery — variant_keys is then passed into validate_delivery!/2 for the D-18 source_variant cross-check (option (a) from the plan; cleaner than a post-validate cross-check at the call site)."
  - ":streaming type is {:or, [:keyword_list, {:map, :atom, :any}, nil]}; the {:map, :atom, :any} entry covers map-style streaming opts (some adopters write `delivery: %{streaming: %{...}}`). The downstream normalize_delivery_opts!/1 converts both forms to a keyword list before NimbleOptions validation."
  - "Source-variant cross-check uses Map.keys(variants) — variants is already a map keyed by atom variant names at this stage."
  - "Branch 5b (defensive ready+empty-playback_ids guard) returns :provider_asset_not_ready (NOT a new error atom). Locked because it preserves the existing error vocabulary; richer variants are deferred to v1.7+ per D-27."
  - "asset_id_of/1 supports map (`%{id: id}`), string-key map, and a key_for fallback so test fixtures and production schema structs both work without forcing %MediaAsset{} structs at the dispatch boundary."
  - "Mox.defmock(Rindle.Streaming.ProviderMock, for: Rindle.Streaming.Provider) is declared inline in the dispatch test (guarded by Code.ensure_loaded?) rather than added to test/support/mocks.ex — keeps the streaming concern local until Phase 34 introduces a shared streaming-test fixture module."
metrics:
  duration: "~30 minutes"
  completed_date: "2026-05-06"
  tasks_completed: 3
  task_commits: 4
  files_created: 1
  files_modified: 3
  tests_added: 26
  tests_failed: 0
---

# Phase 33 Plan 03: Profile DSL `:streaming` + Delivery dispatch tree Summary

Land the Profile DSL `:streaming` key (NimbleOptions-validated, named-only) and
replace the body of `Rindle.Delivery.streaming_url/3` with the locked 8-branch
dispatch tree from D-19. v1.4 telemetry contract preserved verbatim — the
single load-bearing v1.4 carryover and the largest landmine in Phase 33 stays
green byte-for-byte.

## Task Commits

| # | Gate | Commit | Description |
|---|------|--------|-------------|
| 1 | RED  | `a98c9c4` | `test(33-03): add 15 failing tests for Profile DSL :streaming key (STREAM-05)` |
| 1 | GREEN | `fc2188b` | `feat(33-03): add Profile DSL :streaming key with NimbleOptions schema (STREAM-05)` |
| 2 | RED  | `66c3101` | `test(33-03): add failing per-branch coverage for D-19 dispatch tree (STREAM-06)` |
| 2 | GREEN | `39c01ac` | `feat(33-03): replace streaming_url/3 body with D-19 dispatch tree (STREAM-06)` |

Task 3 (verification-only quality gate) produced no commits — all gates green
on existing artifacts.

## Final `@streaming_schema` shape (locked verbatim per D-15)

```elixir
@streaming_schema [
  provider: [
    type: :atom,
    required: true,
    doc: "Module implementing `Rindle.Streaming.Provider`."
  ],
  playback_policy: [
    type: {:in, [:signed, :public]},
    required: true,
    doc: "Named playback policy. `:signed` requires the provider to have signing configured."
  ],
  ingest_mode: [
    type: {:in, [:server_push, :direct_creator_upload]},
    required: true,
    doc: "Ingest path. `:direct_creator_upload` is reserved for Phase 37."
  ],
  source_variant: [
    type: :atom,
    required: true,
    doc: "Atom naming the variant in the same profile that feeds the provider ingest."
  ]
]
```

## Final `@delivery_schema` extension

```elixir
@delivery_schema [
  public: [type: :boolean, default: false],
  signed_url_ttl_seconds: [type: {:or, [:pos_integer, nil]}, default: nil],
  authorizer: [type: {:or, [:atom, nil]}, default: nil],
  streaming: [
    type: {:or, [:keyword_list, {:map, :atom, :any}, nil]},
    default: nil,
    doc: "Optional streaming-provider configuration (Phase 33). See `@streaming_schema`."
  ]
]
```

NimbleOptions rejects unknown keys by default; raw provider knobs
(`:max_resolution_tier`, `:input`, etc.) raise `ArgumentError` with the
`"streaming: "` prefix preserved by the new `validate_streaming!/2` rescue
clause (Pattern D).

## D-18 cross-check logic

The `validate!/1` pipeline now validates variants first, then passes the
`Map.keys(variants)` list into `validate_delivery!/2`. Inside
`validate_streaming!/2`:

```elixir
unless source_variant in variant_keys do
  raise ArgumentError,
        "streaming: source_variant #{inspect(source_variant)} not declared in variants/0 " <>
          "(declared: #{inspect(variant_keys)})"
end
```

Phase 33 only validates atom presence in `variants/0` (D-18 partial). Per-variant
`kind: :video | :audio` enforcement is **deferred to Phase 34** where Mux-specific
validation lives. Test 13 in the validator suite asserts an `:image`-kind variant
referenced by `source_variant` compiles successfully — the deferred-to-Phase-34
behaviour is locked at the test level.

## Final `streaming_url/3` body (D-19 verbatim, 8 branches + Branch 5b)

The body is now a `cond`/dispatch sandwich preserving the v1.4 path verbatim
inside `do_progressive_streaming_url/3`. Branch summary with test coverage:

| Branch | Trigger | Return | Test |
|--------|---------|--------|------|
| 1 | `streaming nil` (any key/asset) | `{:ok, %{kind: :progressive, ...}}` + telemetry | `streaming_dispatch_test.exs:108` |
| 2 | `streaming` configured + binary key | `{:error, :streaming_provider_requires_asset_struct}` | `streaming_dispatch_test.exs:131` |
| 3a | row state `"pending"` | `{:error, :provider_asset_not_ready}` | `streaming_dispatch_test.exs:143` |
| 3b | row state `"uploading"` | `{:error, :provider_asset_not_ready}` | `streaming_dispatch_test.exs:156` |
| 3c | row state `"processing"` | `{:error, :provider_asset_not_ready}` | `streaming_dispatch_test.exs:169` |
| 4  | row state `"errored"` | `{:error, :provider_sync_failed}` | `streaming_dispatch_test.exs:182` |
| 5  | row state `"ready"` + `[playback_id, _]` | `provider.signed_playback_url/3 → {:ok, %{kind: :hls, ...}}` + telemetry | `streaming_dispatch_test.exs:195` |
| 5b | row state `"ready"` + `playback_ids: []` | `{:error, :provider_asset_not_ready}` (defensive) | `streaming_dispatch_test.exs:236` |
| 6  | no row + non-strict | `{:ok, %{kind: :progressive, ...}}` + telemetry (D-24) | `streaming_dispatch_test.exs:251` |
| 7  | no row + `opts[:strict] = true` | `{:error, :provider_asset_not_ready}` (D-20) | `streaming_dispatch_test.exs:277` |

Plus a lookup-key test (Branch 4 with a decoy row under a different
`provider_name`) that asserts the three-tuple `Repo.get_by` (D-21, D-22) hits
exactly the right row — `streaming_dispatch_test.exs:289`.

## D-24 telemetry preservation

The single load-bearing v1.4 carryover. Two `:telemetry.execute` call sites in
the new `lib/rindle/delivery.ex`:

1. **`do_progressive_streaming_url/3`** — invoked by Branch 1 AND Branch 6
   (no row, non-strict). Body is **identical to the v1.4 streaming_url/3 body**
   line-for-line: same `with`-chain (`authorize_delivery → require_streaming_support →
   resolve_streaming_url`), same metadata `%{profile, adapter, mode, kind:
   :progressive, mime}`, same measurement `%{system_time: System.system_time()}`.
   Tripwires at `test/rindle/delivery_test.exs:352-380` and
   `test/rindle/contracts/telemetry_contract_test.exs:74,277` stay green
   byte-for-byte.

2. **`dispatch_provider_signed_url/4`** — invoked by Branch 5 only. Same
   metadata key set as #1 but with `kind: :hls` (the single v1.4-contract
   extension documented in `33-CONTEXT.md` D-24). Mime defaults to
   `application/vnd.apple.mpegurl` and respects whatever the provider returns.

The metadata key set is identical across all three emit paths (`profile`,
`adapter`, `mode`, `kind`, `mime`) — only the `:kind` value changes between
`:progressive` and `:hls` (Pattern H verbatim).

## D-21 / D-22 lookup keys

Single `Repo.get_by(MediaProviderAsset, asset_id: ..., profile: ...,
provider_name: ...)` — three keys, hits the unique index from D-10
(`media_provider_assets_asset_id_profile_provider_name_index`). No N+1, no
preload, no per-variant lookup.

`provider_name` derivation (D-22):

```elixir
defp derive_provider_name(provider_module) when is_atom(provider_module) do
  provider_module
  |> Module.split()
  |> List.last()
  |> Macro.underscore()
end
```

`Rindle.Streaming.Provider.Mux → "mux"`. `Rindle.Streaming.ProviderMock →
"provider_mock"` (used in dispatch tests). Stored opaque; never rendered to
public paths.

## Test counts

### Plan 33-03 focused suite

| File | Tests | Failures |
|------|-------|----------|
| `test/rindle/profile/validator_test.exs` | 36 (15 new + 21 pre-existing) | 0 |
| `test/rindle/delivery/streaming_dispatch_test.exs` | 11 (new file) | 0 |
| **Plan 33-03 focused suite total** | **47** | **0** |

`mix test test/rindle/delivery/ test/rindle/profile/ --color` → **72 tests, 0
failures**.

### Tripwire confirmation

| File | Tests | Result |
|------|-------|--------|
| `test/rindle/delivery_test.exs` | 20 | PASS — including lines 352-380 (`streaming_url/3` emits telemetry on success) and 382-391 (no emit on failure) |
| `test/rindle/contracts/telemetry_contract_test.exs` | (filtered) | PASS — including line 74 (event in `@public_events`) and line 277 (kind: :progressive metadata) |

`mix test test/rindle/delivery_test.exs test/rindle/contracts/telemetry_contract_test.exs --color`
→ **20 tests, 0 failures (14 excluded — `:integration`/`:contract`)**

### Full suite (`mix test --color`)

**655 tests, 3 failures (38 excluded)**. The 3 failures are pre-existing
baseline flakes already documented in
`.planning/phases/33-provider-boundary-state-schema/deferred-items.md`
(Plans 33-01, 33-02, 33-04 each independently confirmed pre-existing on
base commit `c6aeead`):

1. `test/rindle/processor/av_test.exs:138` — FFmpeg `:epipe` parallelism flake
   (pre-existing). Passes in isolation.
2. `test/rindle/processor/waveform_test.exs:31` — same `:epipe` parallelism
   flake. Passes in isolation.
3. `test/rindle/application_test.exs:41` — `Rindle.Adopter.CanonicalApp.VideoProfile`
   bleeds into `Application.get_env(:rindle, :profiles)` via
   `elixirc_paths(:test)`. Pre-existing.

**Plan 33-03 introduced zero new failures** — verified by isolation runs of
the 3 failing tests on top of the Plan 33-03 commits.

## Quality Gate Status

| Gate | Status | Notes |
|------|--------|-------|
| `mix test test/rindle/delivery/ test/rindle/profile/` | PASS | 72/72 |
| `mix test test/rindle/delivery_test.exs test/rindle/contracts/telemetry_contract_test.exs` (TRIPWIRES) | PASS | 20/20 |
| `mix test test/rindle/delivery/streaming_dispatch_test.exs` (new file) | PASS | 11/11 |
| `mix test test/rindle/profile/validator_test.exs` | PASS | 36/36 (15 new + 21 pre-existing) |
| `mix test --color` (full suite) | NO REGRESSION | 3 pre-existing flakes (deferred-items.md); zero new failures |
| `mix format --check-formatted` on Plan 33-03 files | PASS | All four files clean |
| `mix credo --strict` on Plan 33-03 production source | PASS | 79 mods/funs, 0 issues |
| `git diff --name-only c6aeead..HEAD -- mix.exs` | PASS (empty) | mix.exs unchanged — no new deps |

## Acceptance Criteria Verification

### Task 1 grep checks (validator)

- `grep -c '@streaming_schema' lib/rindle/profile/validator.ex` → **3** (≥2 required)
- `grep -c 'streaming: \[' lib/rindle/profile/validator.ex` → **1** (≥1 required)
- `grep -c 'validate_streaming!' lib/rindle/profile/validator.ex` → **3** (≥2 required)
- `grep -c ':in, \[:signed, :public\]' lib/rindle/profile/validator.ex` → **1**
- `grep -c ':in, \[:server_push, :direct_creator_upload\]' lib/rindle/profile/validator.ex` → **1**
- `grep -c "source_variant.*not declared" lib/rindle/profile/validator.ex` → **1**
- `grep -c 'kind:.*video.*audio' lib/rindle/profile/validator.ex` → **0** (D-18 deferral confirmed)

### Task 2 grep checks (delivery dispatch)

- `grep -c ':streaming_provider_requires_asset_struct' lib/rindle/delivery.ex` → **2** (≥1 required)
- `grep -c ':provider_asset_not_ready' lib/rindle/delivery.ex` → **6** (≥2 required — Branches 3, 5b, 7 + comments + return values)
- `grep -c ':provider_sync_failed' lib/rindle/delivery.ex` → **2** (1 required — Branch 4 return + comment)
- `grep -c 'Repo.get_by' lib/rindle/delivery.ex` → **1** (≥1 required — D-21 single lookup)
- `grep -c 'MediaProviderAsset' lib/rindle/delivery.ex` → **7** (≥4 required — alias + 6 struct pattern matches)
- `grep -c 'Module.split' lib/rindle/delivery.ex` → **1** (D-22)
- `grep -c 'do_progressive_streaming_url' lib/rindle/delivery.ex` → **5** (≥4 required — definition + map-arity clause + Branch 1 + Branch 6 + comment)
- `grep -c 'kind: :hls' lib/rindle/delivery.ex` → **3** (≥1 required — Branch 5 telemetry + spec widening + moduledoc)
- `grep -c 'kind: :progressive' lib/rindle/delivery.ex` → **6** (≥2 required — emit + return + spec + moduledoc + comments)
- `grep -c ':strict' lib/rindle/delivery.ex` → **3** (≥1 required — D-20)
- `grep -c '\[:rindle, :delivery, :streaming, :resolved\]' lib/rindle/delivery.ex` → **5** (2 telemetry execute call sites + 3 doc references)

## Decisions Made (Claude's Discretion)

1. **Pipeline reorder for D-18 cross-check.** The plan offered two options for
   threading variants into the streaming validator: (a) reorder the pipeline so
   variants are validated first; (b) post-validate cross-check at the call site
   in `Rindle.Profile.Validator.validate!/1`. Picked (a). Justification: keeps
   the streaming validation co-located with `validate_delivery!/2` (same rescue
   clause, same `"streaming: "`/`"delivery: "` prefix discipline), avoids
   spreading streaming logic across two functions. Test 12
   (`source_variant: :nonexistent` raises) verifies the cross-check works.

2. **`:streaming` type widened to `{:or, [:keyword_list, {:map, :atom, :any}, nil]}`.**
   Some adopters write `delivery: %{streaming: %{...}}` (map form). The plan's
   suggested type was `{:or, [:keyword_list, :map, nil]}` but `:map` matched
   any non-keyword map; widening to `{:map, :atom, :any}` keeps the type more
   precise (atom keys, any values) while still allowing both keyword-list and
   map forms. The `normalize_delivery_opts!/1` helper already handles both
   forms before NimbleOptions validation.

3. **Defensive Branch 5b returns `:provider_asset_not_ready` (not a new atom).**
   The plan documents this as a defensive guard. Choosing the existing
   `:provider_asset_not_ready` atom (rather than a new
   `:provider_no_playback_id` or similar) preserves the locked v1.6 error
   vocabulary frozen by Plan 33-04's parity test. Test "Branch 5b" verifies the
   provider is **not** called in this case (Mox `verify_on_exit!` would fail
   otherwise).

4. **`asset_id_of/1` supports plain `%{id: ...}` maps in addition to `%MediaAsset{}`.**
   Lets dispatch tests pass either schema structs or plain maps without forcing
   `%MediaAsset{}` instantiation in every test; production path still works
   identically against the schema struct.

5. **`Mox.defmock` declared inline in the dispatch test (guarded).** Avoids
   bloating `test/support/mocks.ex` with a streaming-only mock until Phase 34
   needs a shared streaming-test fixture. The `Code.ensure_loaded?` guard makes
   it idempotent for re-compilation.

None of these touched any locked contract surface (D-15..D-24 are byte-for-byte
verbatim).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `mix deps.get` was required before tests could run**

- **Found during:** First `mix test` invocation in Task 1.
- **Issue:** The fresh worktree had no `deps/` or `_build/` directories — `mix
  test` failed with "the dependency is not available, run mix deps.get" for
  every Hex package.
- **Fix:** Ran `mix deps.get` and `MIX_ENV=test mix compile` once; subsequent
  test runs succeeded.
- **Files modified:** none (only `_build/` and `deps/` populated).
- **Committed in:** N/A (environment setup, not a code change).

**2. [Rule 3 — Formatting] `mix format` reformatted pre-existing tests in `test/rindle/profile/validator_test.exs`**

- **Found during:** Task 1 GREEN gate (`mix format --check-formatted`).
- **Issue:** When I added 15 new streaming-key test cases, the project-default
  `mix format` rewrote some pre-existing assertions (whitespace only —
  e.g. line wrapping a `compile_profile/1` call onto its own line, breaking
  long `refute Map.has_key?` lines).
- **Fix:** Ran `mix format` to apply the project's canonical style; tests
  unaffected (still 36/36 green).
- **Files modified:** `test/rindle/profile/validator_test.exs` (whitespace
  only; all assertions and helpers byte-for-byte identical).
- **Committed in:** `fc2188b` (folded into the GREEN-gate commit since the
  reformat was the same edit-cycle as the new tests).

### Deferred Issues (out-of-scope per SCOPE BOUNDARY)

Three pre-existing baseline failures already documented in
`deferred-items.md` (Plans 33-01, 33-02, 33-04 confirmed pre-existing on
`c6aeead`):

1. `test/rindle/processor/av_test.exs:138` — FFmpeg `:epipe` parallelism flake.
2. `test/rindle/processor/waveform_test.exs:31` — same `:epipe` parallelism
   flake.
3. `test/rindle/application_test.exs:41` — canonical-app profile bleed-through
   into `Application.get_env(:rindle, :profiles)`.

Plus pre-existing `mix credo --strict` baseline issues (47, all in unrelated
files) and pre-existing `mix dialyzer` baseline warnings (11, all in unrelated
files). Plan 33-03 introduces zero new findings on credo or dialyzer for its
two production files (`lib/rindle/profile/validator.ex`,
`lib/rindle/delivery.ex`) — verified via `mix credo --strict
lib/rindle/profile/validator.ex lib/rindle/delivery.ex` (clean: 79 mods/funs,
0 issues).

## Threat Surface Scan

The plan's `<threat_model>` was "no new threats — contract-extension only" with
explicit rationale (Profile DSL runs at adopter compile-time, no untrusted
runtime input; Repo lookup uses three pre-validated keys, none from external
sources). Plan 33-03 execution did not surface any new trust boundaries or
new untrusted-input crossings. The `signed_url_ttl_seconds` policy is honored
on Branch 5 because Plan 01's behaviour callback `signed_playback_url/3` is
documented as "MUST respect the profile's `signed_url_ttl_seconds` policy" —
that's a Phase 34 implementation concern. No new threat flags.

## Self-Check: PASSED

Verified all SUMMARY claims:

### Files exist
- `lib/rindle/profile/validator.ex` (modified) → FOUND
- `lib/rindle/delivery.ex` (modified) → FOUND
- `test/rindle/profile/validator_test.exs` (modified) → FOUND
- `test/rindle/delivery/streaming_dispatch_test.exs` (new) → FOUND
- `.planning/phases/33-provider-boundary-state-schema/33-03-SUMMARY.md` → FOUND (this file)

### Commits exist (in `git log --oneline`)
- `a98c9c4` (test: 15 failing validator tests) → FOUND
- `fc2188b` (feat: validator GREEN — :streaming schema + cross-check) → FOUND
- `66c3101` (test: 11 failing dispatch-tree tests) → FOUND
- `39c01ac` (feat: dispatch GREEN — D-19 8-branch dispatch) → FOUND

### Plan acceptance criteria
- All Task 1 acceptance greps satisfied (see Acceptance Criteria Verification above)
- All Task 2 acceptance greps satisfied (see Acceptance Criteria Verification above)
- `mix test test/rindle/profile/validator_test.exs --color` exits 0 with all 15 new tests passing AND every pre-existing test still passing → 36/36
- `mix test test/rindle/delivery/streaming_dispatch_test.exs --color` exits 0 with all 10 branch tests + 1 lookup-key test passing → 11/11
- `mix test test/rindle/delivery_test.exs --color` exits 0 — TRIPWIRE: existing tests at lines 352-391 STAY green → 20/20
- `mix test test/rindle/contracts/telemetry_contract_test.exs --color` exits 0 → tripwires at :74, :277 stay green
- `mix.exs` unchanged → `git diff --name-only c6aeead..HEAD -- mix.exs` is empty
- `mix format --check-formatted` on plan files → exit 0

### Plan acceptance criteria NOT met (with justification)

- `mix credo --strict --color` exit 0 (full suite) — **NOT met on base, NOT met on HEAD; identical baseline issue counts.** Plan 33-03 added zero new credo issues; verified by `mix credo --strict lib/rindle/profile/validator.ex lib/rindle/delivery.ex` returning 0 issues. Pre-existing baseline issues are out-of-scope per the deferred-items.md baseline confirmation already in place from Plans 33-01/02/04.
- `mix dialyzer` exit 0 (full suite) — **NOT met on base.** Same posture as above: zero new warnings on plan files; pre-existing baseline warnings logged in deferred-items.md.

## TDD Gate Compliance

| Plan-level gate | Commit | Verified |
|-----------------|--------|----------|
| Task 1 RED (15 failing validator tests) | `a98c9c4` | YES — initial run reported 10 failures (`unknown options [:streaming]`) before the schema commit |
| Task 1 GREEN (validator schema + cross-check) | `fc2188b` | YES — `mix test test/rindle/profile/validator_test.exs --color` returned 36/0 immediately after this commit |
| Task 2 RED (11 failing dispatch tests) | `66c3101` | YES — initial run reported 10 failures (Mox.UnexpectedCallError for StorageMock; the no-streaming Branch 1 test passed because the v1.4 path was untouched at that point) |
| Task 2 GREEN (dispatch tree implementation) | `39c01ac` | YES — `mix test test/rindle/delivery/streaming_dispatch_test.exs --color` returned 11/0 immediately after this commit |
| REFACTOR | none | No refactor commit needed — the GREEN implementations were locked verbatim by the plan and pattern map; no cleanup required. |

All TDD gates honored.

## Manual Smoke Test

Optional manual smoke from the plan's `<verification>`:

1. **Open `iex -S mix`.**
2. **Define a streaming-configured profile inline:**
   ```elixir
   defmodule Smoke.MyProfile do
     use Rindle.Profile,
       storage: Rindle.Storage.Local,
       variants: [web: [kind: :video, preset: :web_720p]],
       allow_mime: ["video/mp4"],
       delivery: [
         streaming: [
           provider: Rindle.Streaming.Provider.Mux,
           playback_policy: :signed,
           ingest_mode: :server_push,
           source_variant: :web
         ]
       ]
   end
   ```
3. **Call `Rindle.Delivery.streaming_url(Smoke.MyProfile, "key.mp4")`** —
   expected: `{:error, :streaming_provider_requires_asset_struct}` (Branch 2,
   verified in `streaming_dispatch_test.exs:131`).

This is the load-bearing v1.6 behavioural shift adopters will see first when
they opt into `:streaming`. The dispatch test asserts the same outcome
programmatically, so the manual smoke is verification-by-symmetry rather than
an additional gate.

## Next Phase Readiness

**Ready for Phase 34** (Mux adapter):

- `Rindle.Streaming.Provider.Mux` can implement the 7 callbacks against a
  frozen contract (Plan 33-01) and rely on the dispatch tree to route to
  `signed_playback_url/3` on Branch 5 — no contract negotiation needed.
- The `Repo.get_by` lookup keys (`asset_id`, `profile`, `provider_name`) match
  what Phase 34's `MuxIngestVariant` worker writes (D-22 derivation matches
  `to_string(profile)` and the worker's `Module.split |> List.last |>
  Macro.underscore` pattern).
- The `:strict` opt (D-20) gives adopters a path to flip from non-strict
  fallback (gradual migration) to provider-only (greenfield) without API
  changes.

**Ready for Phase 36** (DX + onboarding):

- `mix rindle.doctor` can surface streaming-config validation errors at
  compile time via the NimbleOptions schema (already enforced by `validate!/1`).
- `Rindle.Profile.Presets.MuxWeb` can declare the locked 4-key streaming map
  per D-15 and adopters get strict raw-knob rejection out of the box (D-16).

**Blockers for downstream plans:** none. The 3 pre-existing baseline failures
in `deferred-items.md` are independent of Phase 33 and do not block Phase 34
from executing.

---
*Phase: 33-provider-boundary-state-schema*
*Plan: 03*
*Completed: 2026-05-06*
