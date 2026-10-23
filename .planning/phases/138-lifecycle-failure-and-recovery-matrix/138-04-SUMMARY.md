---
phase: 138-lifecycle-failure-and-recovery-matrix
plan: 04
subsystem: streaming
tags: [mux, plug, ecto, concurrency, oban, telemetry]
requires: [138-03]
provides: [Serialized provider convergence, Postcommit success effects, Packaged signed Mux ingress proof]
affects: [138-05, 138-06]
actuals: {tasks: 2, commits: 2}
tech-stack:
  added: []
  patterns: [Locked provider decisions, Full polling snapshot comparison, Local HTTP SDK fixture]
key-files:
  created: []
  modified: [lib/rindle/workers/ingest_provider_webhook.ex, lib/rindle/workers/mux_sync_provider_asset.ex, lib/rindle/workers/mux_ingest_variant.ex, lib/rindle/domain/provider_asset_fsm.ex, test/rindle/workers/ingest_provider_webhook_test.exs, test/rindle/workers/mux_sync_provider_asset_test.exs, test/rindle/workers/mux_ingest_variant_test.exs, scripts/maintainer/twin_receipt.py, test/install_smoke/twin_receipt_test.exs, scripts/maintainer/built_package_twin.py, test/twin/host/mix.exs, test/twin/host/config/config.exs, test/twin/host/lib/twin/web.ex, test/twin/host/lib/twin/tracer.ex]
key-decisions:
  - Strictly older known timestamps and exact accepted-ID replay are effect-free; distinct equal/undated events follow the serialized existing FSM without lowering the watermark.
  - Polling compares full row identity and accepted event fields rather than second-precision updated_at alone.
  - Initial SDK linkage preserves a newer webhook for the same provider without an additional outbound create.
requirements-completed: []
requirements-covered: [RECOV-04]
coverage:
  - id: PROVIDER-CONCURRENCY
    description: Independent PostgreSQL writers prove locking, stale snapshots, initial-linkage races, rollback and committed effects.
    requirement: RECOV-04
    verification:
      - kind: unit
        ref: test/rindle/workers/ingest_provider_webhook_test.exs
        status: pass
    human_judgment: false
  - id: PROVIDER-PACKAGE
    description: Actual Mux SDK and signed raw-body Plug converge with exact create/job/effect counts and no canary export.
    requirement: RECOV-04
    verification:
      - kind: e2e
        ref: /private/tmp/rindle-138-provider-verified/receipt.json
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
independent_pilot_credit: false
---

# Phase 138 Plan 04: Provider convergence through supported boundaries

Provider writes now serialize against current committed rows, while a fresh packaged consumer proves actual SDK HTTP and signed webhook behavior.

## Task Commits

1. `97d2ea74` — serialized webhook, polling and initial-linkage decisions; postcommit effects; focused regressions and closed provider receipt.
2. `00e6e7b6` — local HTTP Mux fixture, activated already-locked SDK, raw-body signed ingress and normal queue trace.

## Evidence

- Named pre-fix regression: `newer ready followed by older errored cannot regress accepted provider state`. Preserved output `/private/tmp/rindle-138-provider-red.txt` shows the intended stale-state assertion failure, without setup failure.
- Final task command: 56 tests, zero failures, including receipt mutation controls. The three-worker suite independently ran twice: 49 tests, zero failures each. Exact independent Postgrex inventories after both showed zero new committed fixtures and preserved all 18 pre-existing rows.
- Concurrency controls use separate committed connections and PostgreSQL blocking-pid observations. Coverage includes equal/missing/invalid times, second/microsecond boundaries, legitimate newer errors, same-state event watermarks, stale polling ready/error/404/no-change/stuck decisions, initial linkage, rollback and independent postcommit reads.
- Public surface snapshot: four tests, zero failures. Docker-free twin suite: 24 tests, zero failures; diff/format checks clean.
- Real `run --case provider-events --verify --cleanup`: exit zero, `/private/tmp/rindle-138-provider-verified`. Subsequent independent `verify --inputs ... --receipt ...`: exit zero.
- Actual SDK 3.2.2 loaded from `/twin/_build/prod/lib/mux/ebin/Elixir.Mux.Video.Assets.beam`. One outbound create, seven distinct completed attempt-one jobs, one pending ready job for two deliveries, and one later replay job.
- HTTP statuses: 202, 202, 202, 202, 202, 400. The ready event, completed replay, older created and older errored snapshots retain identical provider identity, ready state, playback IDs, accepted ID and microsecond watermark.
- Effects advance once from two to three FSM transitions, zero to one processed webhook, and zero to two topic messages. Subsequent deliveries add no success effects. Invalid signatures: one; canary leaks: zero.

## Deviations and Follow-up

Test fixture cleanup initially captured a UUID passed through a changeset that does not cast ID. Fixtures now set the struct ID and assert exactly one deletion; only proven owned diagnostic rows were removed. Independent existing rows were preserved.

The quality gate found two new production complexity findings while implementing the fix; small private helpers removed both without expanding the baseline. Its remaining finding is nesting in the Plan 03 host storage download wrapper, which Plan 06 already owns and will repair before the required final quality gate. The AV repair host assertions were simplified with equivalent pattern matches in this plan's existing tracer owner.

No public export, schema, root lock, dependency tree, cloud parity, readiness or independent-adoption change. All RECOV requirements remain pending the complete six-case matrix and its pre-disposal audit.
