---
phase: 42-tus-protocol-edge-bare-plug
plan: 04
subsystem: streaming
tags: [mux, code-review, telemetry, oban, fsm, security-invariant-14, polish]

# Dependency graph
requires:
  - phase: 34-mux-rest-adapter-server-push-sync
    provides: Mux REST adapter, sync coordinator/worker, ingest worker, webhook event normalizer (the POLISH-01 advisory surface)
provides:
  - "8 Phase-34 advisory fixes (WR-01/02/04/05/06/08/09, IN-02) with regression coverage where they assert behavior"
  - "3 documented waivers (WR-07, IN-01, IN-03) with one-line inline rationales + SUMMARY traceability"
  - "WR-03 telemetry-contract semantics documented in the MuxSyncProviderAsset moduledoc (age_ms across :resolved/:stuck)"
affects: [44-auth-hardening-dx-docs-telemetry-ci, 45-browser-mux-direct-creator-upload, POLISH-02]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "fetch_required/2 config resolution — return {:error, {:missing_config, key}} instead of Keyword.fetch! mid-request (retry-safe)"
    - "RFC 7230 case-insensitive header lookup — downcase the whole header map once, then Map.fetch/2"
    - "Invalid-FSM-transition resolves to :cancel/reconcile_to_errored instead of burning Oban retries"
    - "safe_reason/1 telemetry redaction — atoms pass; everything else inspect |> String.slice(0, 200) (invariant-14-adjacent)"
    - "WAIVED (POLISH-01/D-13) inline-comment convention for deliberately-not-fixed advisories"

key-files:
  created:
    - .planning/phases/42-tus-protocol-edge-bare-plug/42-04-SUMMARY.md
  modified:
    - lib/rindle/streaming/provider/mux.ex
    - lib/rindle/streaming/provider/mux/http.ex
    - lib/rindle/streaming/provider/mux/event.ex
    - lib/rindle/workers/mux_sync_provider_asset.ex
    - lib/rindle/workers/mux_sync_coordinator.ex
    - lib/rindle/workers/mux_ingest_variant.ex
    - test/rindle/streaming/provider/mux/mux_test.exs
    - test/rindle/workers/mux_sync_coordinator_test.exs
    - test/rindle/workers/mux_sync_provider_asset_test.exs
    - test/rindle/workers/mux_ingest_variant_test.exs

key-decisions:
  - "WR-03 resolved by DOCUMENTING the telemetry contract (option (a), smaller diff) per D-13 discretion — no behavior change"
  - "POLISH-01 kept strictly Mux-isolated: zero tus files touched (D-13 scope fence)"
  - "Pre-existing credo refactoring findings on mux.ex (complexity 10, nesting depth 4) logged to deferred-items.md as out-of-scope (SCOPE BOUNDARY) — present on HEAD before any 42-04 edit"

patterns-established:
  - "D-13 selective triage: fix real correctness/observability findings at natural file locality; waive defensive-only / deliberate-deferral findings with a one-line rationale rather than a blanket --fix"

requirements-completed: [POLISH-01]

# Metrics
duration: continuation (resumed after dropped connection)
completed: 2026-05-22
---

# Phase 42 Plan 04: POLISH-01 Phase-34 Advisory Backlog Summary

**Closed the Phase-34 Mux code-review backlog via D-13 selective triage: 8 advisories fixed with regression coverage, 3 waived with inline rationale, WR-03 telemetry contract documented — all Mux-isolated, zero tus overlap.**

## Performance

- **Duration:** Continuation (a prior executor dropped mid-plan; this run assessed committed work, finished the waivers, and closed the plan)
- **Completed:** 2026-05-22
- **Tasks:** 3 (Mux adapter fixes + WR-03 doc; Mux worker fixes + IN-02; 3 waivers)
- **Files modified:** 10 (6 source + 4 test)

## Accomplishments

- **8 advisories fixed** with regression coverage where they assert behavior:
  - **WR-01** (`mux/http.ex`, `mux.ex`): `fetch_required/2` returns `{:error, {:missing_config, key}}` for missing token/signing config instead of raising `KeyError` mid-request and burning Oban retries.
  - **WR-02** (`mux.ex`): `fetch_sig_header/1` downcases the whole header map once then `Map.fetch("mux-signature")` (RFC 7230 case-insensitive) — a mixed-case `Mux-Signature` now resolves. Spoofing mitigation (T-42-SIGHDR).
  - **WR-04** (`mux_sync_provider_asset.ex`): `{:error, {:invalid_transition, from, to}}` from `apply_state_transition/4` resolves to `reconcile_to_errored/4` instead of retrying the same structurally-impossible transition. Self-inflicted-DoS mitigation (T-42-RETRY).
  - **WR-05** (`mux.ex` + `event.ex`): `normalize_state/1` allowlists `preparing|ready|errored|deleted`; unknown statuses log `rindle.mux.unknown_status` warning and return `nil` (treated downstream as "ignore"), so they no longer flow into the FSM and burn retries.
  - **WR-06** (`mux_sync_provider_asset.ex`): adapter `{:error, reason}` persists `last_sync_error` (inspect-truncated to 4096) before propagating, giving operators a breadcrumb.
  - **WR-08** (`mux_sync_coordinator.ex`): `Oban.insert` outcomes distinguished into fresh / dedup (`conflict?: true`) / failed; failures logged via `rindle.workers.mux_sync_coordinator.enqueue_errors`.
  - **WR-09** (`mux_ingest_variant.ex`): `:exception` telemetry routes the reason through `safe_reason/1` (atoms pass; else `inspect |> String.slice(0, 200)`). Information-disclosure mitigation (T-42-LEAK-MUX, invariant-14-adjacent).
  - **IN-02** (`mux_sync_coordinator_test.exs`): test env setup uses `Keyword.merge(prev, ...)` at all four sites (test hygiene).
- **WR-03 documented** in the `MuxSyncProviderAsset` moduledoc: the `age_ms` metric carries two semantics across `:resolved` (with `no_change`) and `:stuck`; dashboards MUST gate on `no_change` (or use `:stuck`) before treating a large `age_ms` as a liveness problem. Option (a), the smaller diff — no behavior change.
- **3 advisories waived** with one-line inline `WAIVED (POLISH-01/D-13)` rationale comments (see Waiver Register below).
- **Mux-isolated:** the entire diff touches only `lib/rindle/streaming/provider/mux*` and `lib/rindle/workers/mux_*` (+ their tests). Zero tus code paths modified (verified via `git diff --name-only`).

## Task Commits

1. **Tasks 1+2 source fixes (WR-02 + WR-03 doc + worker fixes)** — `72b2fc6` (fix): WR-02 case-insensitive sig header + WR-03 telemetry-contract moduledoc note (`mux.ex`, `mux_sync_provider_asset.ex`).
2. **Tasks 1+2 regression coverage** — `591c4ff` (test): regression coverage for WR-04/06/08/09 + IN-02 across the Mux worker test files and `mux_test.exs`.
3. **Task 3 waivers** — `8556265` (docs): WR-07 / IN-01 / IN-03 inline waiver rationales (`mux_sync_coordinator.ex`, `event.ex`, `mux.ex`) + pre-existing credo findings logged to `deferred-items.md`.

_Note: WR-01, WR-09, and the WR-07 `limit`/`order_by` cap were carried into the tree by the v1.7 polish commit `2a6119d` ("feat(v1.7): ... address Phase 34/35 polish") and were verified present + correct against their acceptance criteria during this plan; the WR-07 waiver documents that the cap is already in place and no further behavior change is required._

**Plan metadata:** committed with this SUMMARY + STATE.md + ROADMAP.md + REQUIREMENTS.md (docs: complete plan).

## Waiver Register (POLISH-01 / D-13 traceability)

| ID | File | Rationale (one-line) |
|----|------|----------------------|
| WR-07 | `lib/rindle/workers/mux_sync_coordinator.ex` | Documented v1.7 deferral (unbounded scan; add LIMIT only on a >1k-stuck-rows adopter signal). The `limit`/`order_by` cap is already in place; no further behavior change required. |
| IN-01 | `lib/rindle/streaming/provider/mux/event.ex` | Defensive-only Unix-string `created_at` parse; no live caller feeds Mux REST `created_at` into Event normalization (webhooks use ISO8601). Belt-and-suspenders; no behavior change. |
| IN-03 | `lib/rindle/streaming/provider/mux.ex` | `playback_id` is a documented URL-safe alphanumeric (Mux contract); the `URI.encode_www_form/1` here is belt-and-suspenders only. No behavior change. |

## Files Created/Modified

- `lib/rindle/streaming/provider/mux/http.ex` — WR-01 `fetch_required/2` config resolution.
- `lib/rindle/streaming/provider/mux.ex` — WR-02 case-insensitive sig header, WR-05 status allowlist, WR-01 signing-config resolution, IN-03 waiver comment.
- `lib/rindle/streaming/provider/mux/event.ex` — WR-05 status allowlist + unknown-status warning, IN-01 waiver comment.
- `lib/rindle/workers/mux_sync_provider_asset.ex` — WR-04 invalid-transition → reconcile, WR-06 `last_sync_error` breadcrumb, WR-03 telemetry-contract moduledoc.
- `lib/rindle/workers/mux_sync_coordinator.ex` — WR-08 distinguished insert outcomes + error logging, WR-07 waiver comment (cap already in place).
- `lib/rindle/workers/mux_ingest_variant.ex` — WR-09 `safe_reason/1` redaction in `:exception` telemetry.
- `test/rindle/streaming/provider/mux/mux_test.exs` — WR-02 mixed-case header + WR-05 unknown-status regression tests.
- `test/rindle/workers/mux_sync_coordinator_test.exs` — WR-08 insert-outcome tests + IN-02 `Keyword.merge` hygiene.
- `test/rindle/workers/mux_sync_provider_asset_test.exs` — WR-04 invalid-transition→cancel + WR-06 `last_sync_error` persisted regression tests.
- `test/rindle/workers/mux_ingest_variant_test.exs` — WR-09 `safe_reason/1` redaction regression tests.

## Decisions Made

- **WR-03 → document (not emit new metric):** per D-13 discretion, chose the moduledoc-documentation path (smaller diff, no behavior change) over emitting `no_change: true` + `last_synced_at_ms`. The `no_change` flag was already present in the emitted metadata, so the documentation precisely matches the shipped contract.
- **WR-05 allowlist includes `deleted`:** the review specified `~w(preparing ready errored)`; the implementation keeps the existing `deleted` mapping too, since `deleted` is a real Mux/FSM state and dropping it would be a behavior regression. Unknown-only statuses still log + return `nil`.

## Deviations from Plan

None affecting scope — plan executed as written. Two procedural notes:

1. **Carried-in fixes (not a deviation):** WR-01, WR-09, and the WR-07 cap were already in the tree from the v1.7 polish commit `2a6119d`. They were re-verified against their acceptance criteria rather than re-implemented (no duplication).
2. **Out-of-scope credo findings logged:** `mix credo lib/rindle/streaming/provider/mux.ex` reports 2 refactoring opportunities (cyclomatic complexity 10 in `create_asset_with_retry_hint/3`; nesting depth 4 in `verify_webhook/3`). Both were confirmed pre-existing on the committed HEAD (present before any 42-04 edit) and logged to `deferred-items.md` per the executor SCOPE BOUNDARY rule. Not fixed.

## Issues Encountered

- **Resumed from a dropped connection.** The prior executor had committed `72b2fc6` (WR-02 + WR-03 doc) and `591c4ff` (regression tests) but left the 3 waiver comments uncommitted and never wrote the SUMMARY / updated tracking. This run verified all 8 fixes present + correct, confirmed the waiver wording, committed the waivers (`8556265`), and closed the plan. No committed work was reverted or duplicated.

## Verification

- `mix compile --warnings-as-errors` — clean.
- Mux suites (`test/rindle/streaming/provider/mux/` + the three worker test files) — **70 tests, 0 failures**.
- `mix format --check-formatted` on all 6 changed source files — clean.
- `mix credo` on the 3 waiver files — `event.ex` and `mux_sync_coordinator.ex` clean; `mux.ex` shows only the 2 pre-existing/documented refactoring findings.
- `git diff --name-only` for this plan — only `mux*` files. Zero tus overlap (D-13 scope fence honored).

## Next Phase Readiness

- POLISH-01 closed; the Phase-34 advisory backlog is resolved (8 fixed, 3 waived, WR-03 documented).
- POLISH-02 (Phase 44) inherits the same `WAIVED (POLISH-01/D-13)` inline-comment convention and the deferred-items credo refactoring backlog for mux.ex.
- This plan ran fully parallel to the tus spine (Plans 01-03) with zero overlap; no impact on the tus edge work.

---
*Phase: 42-tus-protocol-edge-bare-plug*
*Completed: 2026-05-22*
