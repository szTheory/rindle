---
phase: 33-provider-boundary-state-schema
plan: 01
subsystem: streaming
tags: [elixir, behaviour, capabilities, contract, provider]

# Dependency graph
requires:
  - phase: 26
    provides: "Reserved 2-callback Rindle.Streaming.Provider shim (streaming_url/3 + capabilities/0); replaced wholesale here per D-08."
provides:
  - "Rindle.Streaming.Capabilities — closed 5-atom vocabulary module (mirror of Rindle.Storage.Capabilities, sans require_*/2)"
  - "Rindle.Streaming.Provider — promoted runtime behaviour with locked 6 required + 1 optional callback contract"
  - "Public types: provider_asset_id, playback_id, provider_state, provider_event, capability"
  - "D-05 lock: streaming_url/3 is NOT a callback on the behaviour (Rindle.Delivery owns dispatch)"
affects:
  - "33-02 (media_provider_assets schema/migration — uses provider_state and provider_asset_id types)"
  - "33-03 (Profile DSL :streaming + Delivery dispatch — consumes Capabilities + behaviour)"
  - "33-04 (Capability.report/0 + locked error atoms — references Capabilities and behaviour shape)"
  - "Phase 34 (Mux adapter — implements the locked 7 callbacks verbatim)"
  - "Phase 37 / MUX-22 (Capabilities.require_streaming/2 lands here — intentionally absent in Phase 33 per D-03)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Closed-vocabulary capabilities module (Storage.Capabilities analog, stop-at-supports?/2)"
    - "Promoted runtime behaviour with @optional_callbacks list — Phase 34 implements verbatim"
    - "Behaviour contract enforces normalized event maps at trust boundary (no provider structs leak; D-07)"

key-files:
  created:
    - "lib/rindle/streaming/capabilities.ex"
    - "test/rindle/streaming/capabilities_test.exs"
    - "test/rindle/streaming/provider_test.exs"
    - ".planning/phases/33-provider-boundary-state-schema/deferred-items.md"
  modified:
    - "lib/rindle/streaming/provider.ex (rewrite — v1.4 2-callback shim → Phase 33 6+1 callback contract)"
    - "test/rindle/delivery_test.exs (Rule 1 auto-fix: flip v1.4 reservation guard to match D-05)"

key-decisions:
  - "Mirror Rindle.Storage.Capabilities verbatim for known/0, safe/1, supports?/2; stop the mirror at supports?/2 — Phase 33 does NOT ship require_streaming/2 (D-03 routes that to Phase 37 / MUX-22)."
  - "Locked 5-atom vocabulary in D-02 order: :signed_playback, :public_playback, :webhook_ingest, :server_push_ingest, :direct_creator_upload."
  - "Locked 6 required callbacks (D-04): capabilities/0, create_asset/3, get_asset/1, delete_asset/1, signed_playback_url/3, verify_webhook/3."
  - "Locked 1 optional callback (D-04): create_direct_upload/2 — declared via @optional_callbacks list."
  - "streaming_url/3 is removed from the behaviour (D-05) — that dispatch surface lives only on Rindle.Delivery; the v1.4 reservation guard at delivery_test.exs:253 was flipped (Rule 1 auto-fix) to refute its presence on the behaviour and explicitly cite D-05 + D-08 in the test name."
  - "verify_webhook/3 returns a normalized provider_event map (D-07) — Mux structs MUST NOT cross the behaviour boundary; future Phase 34 Mux adapter normalizes inside verify_webhook/3."
  - "Replacement of the v1.4 2-callback shape is non-breaking (D-08) — the v1.4 shim was a reserved namespace with zero shipped implementations, so removing :streaming_url and adding the locked contract requires no semver bump."
  - "Security invariant 14 documented in @moduledoc: provider_asset_id MUST NOT leak into adopter-facing URLs/telemetry/logs/inspect. Enforced at the schema layer in Plan 02."

patterns-established:
  - "Pattern A — Capability vocabulary: @typedoc + @type + @known list + known/0 + safe/1 (with case-list-fallthrough + rescue) + supports?/2."
  - "Pattern B — Promoted behaviour: @typedoc'd public types upfront, every @callback returns :ok-tuple or :error-tuple (no raises on happy path), single @optional_callbacks list at module bottom listing reserved-for-future callbacks."

requirements-completed: [STREAM-01, STREAM-02]

# Metrics
duration: ~30 min
completed: 2026-05-06
---

# Phase 33 Plan 01: Provider Boundary Contract Surface Summary

**Locked the 5-atom streaming capability vocabulary and promoted `Rindle.Streaming.Provider` from a v1.4 2-callback reservation into the Phase 33 6 required + 1 optional callback runtime behaviour Phase 34's Mux adapter implements verbatim.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-05-06T16:50:00Z (approx — first edit timestamp)
- **Completed:** 2026-05-06T17:21:00Z
- **Tasks:** 3 (Task 1: Capabilities + tests; Task 2: Provider rewrite + tests; Task 3: full quality gate)
- **Files modified:** 6 (4 plan-targeted + 1 Rule 1 auto-fix + 1 deferred-items log)

## Accomplishments

- Created `Rindle.Streaming.Capabilities` with the locked 5-atom vocabulary (D-02) and the storage-analog `known/0` / `safe/1` / `supports?/2` shape — but stopping at `supports?/2` per D-03 (no `require_streaming/2` in Phase 33).
- Promoted `Rindle.Streaming.Provider` into a runtime behaviour with the **exact** 7 callbacks the Phase 34 Mux adapter will implement: 6 required (capabilities/0, create_asset/3, get_asset/1, delete_asset/1, signed_playback_url/3, verify_webhook/3) + 1 optional (create_direct_upload/2).
- Declared the public types Phase 33 + 34 share: `provider_asset_id`, `playback_id`, `provider_state` (the 6-state FSM vocabulary), `provider_event` (normalized webhook surface), and `capability`.
- Locked D-05: `streaming_url/3` is **NOT** a callback on the behaviour — the dispatch lives on `Rindle.Delivery` only. Tripwire enforced via `behaviour_info/1` introspection in two places (`provider_test.exs` and the rewritten `delivery_test.exs:253` reservation guard).
- Locked D-07: `verify_webhook/3`'s spec returns `{:ok, provider_event()}` — provider-specific structs (e.g. Mux structs) are forbidden from crossing the trust boundary.
- Documented security invariant 14 in `@moduledoc`: provider-internal asset identifiers MUST NOT leak into adopter-facing surfaces. Plan 02 will enforce this at the schema layer.
- Verified D-08: `git diff --name-only mix.exs` is empty — Phase 33 added zero new external dependencies.

## Task Commits

1. **Task 1 (RED): Failing test for Rindle.Streaming.Capabilities** — `5a1e809` (test)
2. **Task 1 (GREEN): Implement Rindle.Streaming.Capabilities** — `a02a628` (feat)
3. **Task 2 (RED): Failing test for Rindle.Streaming.Provider behaviour** — `29d7566` (test)
4. **Task 2 (GREEN): Promote Rindle.Streaming.Provider to runtime behaviour** — `a8769d4` (feat)
5. **Task 3 (Rule 1 auto-fix + deferred-items log): align v1.4 reservation tripwire with promoted behaviour (D-05)** — `dc0f722` (fix)

_Note: Tasks 1 + 2 were executed TDD-style with separate RED-test and GREEN-impl commits. Task 3 was a verification-only task that surfaced a single Rule 1 auto-fix (the v1.4 reservation test in `delivery_test.exs`) and a `deferred-items.md` log of pre-existing baseline issues._

The orchestrator owns the plan-metadata commit (SUMMARY.md + STATE.md + ROADMAP.md) — this executor does not write STATE.md or ROADMAP.md per the parallel-execution contract.

## Files Created/Modified

- **`lib/rindle/streaming/capabilities.ex`** (new — 44 lines) — Closed 5-atom streaming-capability vocabulary. Mirrors `Rindle.Storage.Capabilities` (`known/0`, `safe/1` with case + rescue, `supports?/2`); intentionally OMITS `require_streaming/2` (D-03 — Phase 37 / MUX-22).
- **`lib/rindle/streaming/provider.ex`** (rewrite — 14 → 110 lines) — Promoted behaviour. Replaces the v1.4 reserved 2-callback shim (`streaming_url/3`, `capabilities/0`) with the Phase 33 6 required + 1 optional callback contract. Adds public typespecs and `@optional_callbacks [create_direct_upload: 2]`.
- **`test/rindle/streaming/capabilities_test.exs`** (new — 68 lines, 7 tests, `async: true`) — Covers `known/0` ordering, `safe/1` unknown-filtering / rescue / non-list fallthrough, `supports?/2` happy + sad paths, and the **D-03 tripwire** that asserts `require_streaming/2` is NOT exported.
- **`test/rindle/streaming/provider_test.exs`** (new — 57 lines, 6 tests, `async: true`) — Locks the behaviour shape via `behaviour_info(:callbacks)` + `behaviour_info(:optional_callbacks)`. Includes the **D-05 tripwire** asserting `{:streaming_url, 3}` is absent from `behaviour_info(:callbacks)`.
- **`test/rindle/delivery_test.exs`** (modified — 1 test rewritten) — Rule 1 auto-fix: the v1.4 reservation guard at line 253 asserted `streaming_url/3` IS a callback on the behaviour, contradicting D-05 + D-08. Flipped the assertion to `refute`, renamed the test to "Rindle.Streaming.Provider is callback-only and does not declare streaming_url/3 (Phase 33 D-05)", and added an inline comment citing D-05 + D-08 rationale. The two **explicit** VALIDATION.md tripwires (lines 352-380 streaming-resolved telemetry; lines 382-391 no-emit-on-failure) are unaffected and stay green — they test `Rindle.Delivery.streaming_url/3` (the dispatch function), which lives on `Rindle.Delivery`, not on the behaviour.
- **`.planning/phases/33-provider-boundary-state-schema/deferred-items.md`** (new) — Logs pre-existing baseline failures NOT caused by Plan 33-01: 2 `Rindle.ApplicationTest` failures (canonical-app profile bleeding into runtime guard), 5–7 AV/ffmpeg `:epipe` parallelism flakes (each affected test passes in isolation), 47 pre-existing `mix credo --strict` issues (zero in plan files), and 11 pre-existing `mix dialyzer` warnings (zero in plan files). All verified pre-existing on base commit `c6aeead`.

## Decisions Made

- **Mirror-and-stop pattern (Claude's Discretion within D-03 lock):** included `supports?/2` in the new module because it is part of the storage analog and adds zero risk; stopped the mirror there, deferring `require_streaming/2` to Phase 37 / MUX-22 per D-03.
- **TDD per task (plan-level discipline):** even though the plan frontmatter is `type: execute`, both implementation tasks have `tdd="true"`, so each was executed RED-first → GREEN. Resulted in 4 atomic commits (2 test + 2 feat) for the implementation work, plus 1 fix commit for Task 3.
- **Rule 1 auto-fix on `delivery_test.exs:253`:** the v1.4 reservation test at that line asserted a callback (`streaming_url/3`) the plan explicitly removes per D-05 + D-08. Per the executor's deviation rules this is Rule 1 (test asserts an invariant the plan-locked contract directly contradicts) — fixed inline. The test was kept (not deleted) and renamed to lock the **inverse** assertion (D-05 enforcement). The two explicit VALIDATION.md tripwires (lines 352-380, 382-391) on the same file are unaffected.
- **Out-of-scope test failures logged, not fixed:** AV `:epipe` parallelism flakes, `Rindle.ApplicationTest` profile bleed-through, pre-existing credo + dialyzer baseline issues — all confirmed pre-existing on base by isolation runs. Logged to `deferred-items.md`; not fixed (per executor scope-boundary rules).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `test/rindle/delivery_test.exs:253` reservation guard contradicted Phase 33 D-05**
- **Found during:** Task 3 (full-suite quality gate)
- **Issue:** The v1.4 reservation test asserted `assert {:streaming_url, 3} in Rindle.Streaming.Provider.behaviour_info(:callbacks)`. Phase 33 D-05 explicitly removes `streaming_url/3` from the behaviour (it dispatches only on `Rindle.Delivery`). D-08 calls the v1.4 → Phase 33 callback shape change non-breaking because no implementations existed.
- **Fix:** Flipped the assertion to `refute`; renamed the test to "Rindle.Streaming.Provider is callback-only and does not declare streaming_url/3 (Phase 33 D-05)"; added an inline comment citing D-05 + D-08; preserved the surrounding `behaviours == []` and `function_exported?(..., :behaviour_info, 1)` assertions.
- **Files modified:** `test/rindle/delivery_test.exs`
- **Verification:** `mix test test/rindle/delivery_test.exs --color` → 20/20 green (including the explicit VALIDATION.md tripwires at lines 352-380 and 382-391).
- **Committed in:** `dc0f722`

**2. [Rule 3 - Blocking] `mix deps.get` was required before tests could run**
- **Found during:** First `mix test` invocation in Task 1
- **Issue:** The fresh worktree had no `deps/` directory — `mix test` failed with "the dependency is not available, run mix deps.get" for every Hex package.
- **Fix:** Ran `mix deps.get` once, then proceeded with the standard task flow. No changes to `mix.exs` or `mix.lock` (deps are exactly the v1.5-baseline lockfile).
- **Files modified:** none (only `_build/` and `deps/` populated)
- **Verification:** Subsequent `mix test test/rindle/streaming/capabilities_test.exs` ran successfully against the populated deps.
- **Committed in:** N/A (environment setup; not a code change)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking).
**Impact on plan:** Both auto-fixes were necessary for plan correctness. The Rule 1 fix is the **only** change outside the plan's `files_modified` list — it was unavoidable because the plan-locked decisions D-05 + D-08 directly invalidate the assertion the v1.4 reservation test was making, and that test would have failed on every subsequent CI run otherwise. No scope creep.

## Issues Encountered

- **Worktree base-recovery during baseline-comparison spike:** while attempting to verify that AV `:epipe` failures were pre-existing on base, I ran `git checkout c6aeead -- .` which overwrote my unstaged `delivery_test.exs` edit and the freshly-rewritten `lib/rindle/streaming/provider.ex` working-tree state. Recovered by stashing → `git checkout HEAD -- lib/rindle/streaming/provider.ex` → `git stash pop` to restore the pending edit. All four committed plan files were unaffected (commits a02a628, 29d7566, a8769d4 already existed in the branch ref). Lesson logged: prefer per-file `git checkout c6aeead -- <single-file>` over blanket `... -- .` when comparing against base.

## Self-Check

Verifying all acceptance criteria from `33-01-PLAN.md`:

### Files exist
- `lib/rindle/streaming/capabilities.ex` → FOUND
- `lib/rindle/streaming/provider.ex` → FOUND (rewritten)
- `test/rindle/streaming/capabilities_test.exs` → FOUND
- `test/rindle/streaming/provider_test.exs` → FOUND
- `.planning/phases/33-provider-boundary-state-schema/33-01-SUMMARY.md` → FOUND (this file)

### Commits exist
- `5a1e809` (test: failing capabilities) → FOUND
- `a02a628` (feat: capabilities impl) → FOUND
- `29d7566` (test: failing provider behaviour) → FOUND
- `a8769d4` (feat: provider behaviour) → FOUND
- `dc0f722` (fix: D-05 tripwire alignment + deferred-items log) → FOUND

### Plan acceptance criteria
- `grep -c '^  @known' lib/rindle/streaming/capabilities.ex` → 1 ✓
- `grep -c ':signed_playback' lib/rindle/streaming/capabilities.ex` → 2 ✓ (typespec + @known)
- `grep -c ':direct_creator_upload' lib/rindle/streaming/capabilities.ex` → 3 ✓ (typespec + @known + @typedoc)
- `grep -c 'def require_' lib/rindle/streaming/capabilities.ex` → 0 ✓ (D-03)
- `grep -c 'rescue' lib/rindle/streaming/capabilities.ex` → 1 ✓
- `grep -c "^  @callback" lib/rindle/streaming/provider.ex` → 7 ✓
- `grep -c "@optional_callbacks" lib/rindle/streaming/provider.ex` → 1 ✓
- `grep -c "create_direct_upload: 2" lib/rindle/streaming/provider.ex` → 1+ ✓
- `grep -c "@callback streaming_url" lib/rindle/streaming/provider.ex` → 0 ✓ (D-05)
- `grep -c "@callback verify_webhook" lib/rindle/streaming/provider.ex` → 1 ✓
- `grep -c "@callback create_asset" lib/rindle/streaming/provider.ex` → 1 ✓
- `grep -c "@callback get_asset" lib/rindle/streaming/provider.ex` → 1 ✓
- `grep -c "@callback delete_asset" lib/rindle/streaming/provider.ex` → 1 ✓
- `grep -c "@callback signed_playback_url" lib/rindle/streaming/provider.ex` → 1 ✓
- `grep -c "@callback capabilities" lib/rindle/streaming/provider.ex` → 1 ✓
- `grep -c "@type provider_state" lib/rindle/streaming/provider.ex` → 1 ✓
- `grep -c "@type provider_event" lib/rindle/streaming/provider.ex` → 1 ✓
- `mix test test/rindle/streaming/ --color` → 13/13 green (7 capabilities + 6 provider) ✓
- `mix format --check-formatted` → exit 0 ✓
- `mix compile --warnings-as-errors` → exit 0 ✓
- `git diff --name-only mix.exs` → empty ✓ (no new external deps)
- VALIDATION.md tripwires:
  - `test/rindle/delivery_test.exs` → 20/20 green ✓
  - `test/rindle/error_test.exs` → 12/12 green ✓
  - `test/rindle/profile/validator_test.exs` → 21/21 green ✓

### Plan acceptance criteria NOT met (with justification)
- `mix credo --strict --color` exit 0 — **NOT met on base, NOT met on HEAD; identical issue counts (47).** Plan 33-01 added zero new credo issues; verified by side-by-side `mix credo --strict` runs on `c6aeead` and HEAD. Logged in `deferred-items.md` §3.
- `mix dialyzer` exit 0 — **NOT met on base, NOT met on HEAD; identical 11-warning count.** All warnings touch files NOT modified by Plan 33-01 (`lib/rindle/html.ex`, `lib/rindle/ops/runtime_status.ex`, `lib/rindle/workers/process_variant.ex`, `lib/rindle/workers/promote_asset.ex`). Logged in `deferred-items.md` §4.

## TDD Gate Compliance

Tasks 1 and 2 followed proper RED/GREEN ordering:

- **Task 1 RED gate:** `5a1e809` — `test(33-01): add failing test for Rindle.Streaming.Capabilities` (committed BEFORE the implementation file existed; tests verified to fail with `UndefinedFunctionError` for `Rindle.Streaming.Capabilities.known/0`).
- **Task 1 GREEN gate:** `a02a628` — `feat(33-01): implement Rindle.Streaming.Capabilities (closed vocabulary)` (made all 7 RED tests pass).
- **Task 2 RED gate:** `29d7566` — `test(33-01): add failing test for Rindle.Streaming.Provider behaviour` (committed against the v1.4 shim; behaviour-info introspection produced 5/6 RED failures, exactly as the plan locks expected).
- **Task 2 GREEN gate:** `a8769d4` — `feat(33-01): promote Rindle.Streaming.Provider to runtime behaviour` (made all 6 RED tests pass).

No REFACTOR commits were needed; both implementations were locked verbatim by the plan and the storage-capabilities analog.

## User Setup Required

None — no external service configuration required for Plan 33-01. The behaviour and capability vocabulary are pure-Elixir contract surface; no env vars, secrets, or dashboard configuration introduced.

## Next Phase Readiness

**Ready for Plan 33-02** (`media_provider_assets` Ecto schema + migration):
- `Rindle.Streaming.Provider.provider_state()` typespec available for the schema's state column FSM (D-13 matrix).
- `Rindle.Streaming.Provider.provider_asset_id()` typespec available for the schema's `provider_asset_id` column.
- Security invariant 14 (provider_asset_id redaction) is documented in `@moduledoc` — Plan 33-02 will enforce it at the schema layer via `Inspect` impl.

**Ready for Plan 33-03** (Profile DSL `:streaming` + Delivery dispatch):
- `Rindle.Streaming.Capabilities.known/0` available for capability validation in profile DSL.
- `Rindle.Streaming.Capabilities.safe/1` available for adapter-capability filtering at runtime.
- Behaviour callbacks locked — Plan 33-03 can call `Rindle.Streaming.Provider.signed_playback_url/3` against the contract without ambiguity.

**Ready for Phase 34** (Mux adapter):
- The 7-callback shape is frozen — Phase 34 can land `Rindle.Streaming.Provider.Mux` as a verbatim implementation with zero contract negotiation.

**Blockers for downstream plans:** none. The `deferred-items.md` entries are pre-existing baseline issues (credo + dialyzer + 2 ApplicationTest + AV parallelism) that exist independently of Phase 33; they do not block Plan 33-02, 33-03, or 33-04 from executing.

---
*Phase: 33-provider-boundary-state-schema*
*Plan: 01*
*Completed: 2026-05-06*
