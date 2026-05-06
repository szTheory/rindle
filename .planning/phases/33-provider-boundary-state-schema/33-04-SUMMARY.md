---
phase: 33-provider-boundary-state-schema
plan: "04"
subsystem: error-vocabulary-and-capability-report
tags: [elixir, error-vocab, parity-freeze, capability-report, security-invariant-14]
requirements_completed: [STREAM-07, STREAM-08, STREAM-09]
dependencies:
  requires: []
  provides:
    - "5 new bare-atom Rindle.Error reason clauses (STREAM-07): :provider_asset_not_ready, :provider_webhook_invalid, :provider_sync_failed, :provider_quota_exceeded, :streaming_provider_requires_asset_struct"
    - "AV-06-05 freeze pattern parity gate locking the message wording at v1.6 ship (STREAM-09)"
    - "Rindle.Capability.report/0 aggregator with locked top-level shape per D-30 (STREAM-08)"
  affects:
    - "Plan 03 dispatch tree can return the 5 new atoms and Rindle.Error.message/1 renders correct human text"
    - "Phase 36 mix rindle.doctor (MUX-16) consumes Rindle.Capability.report/0 with a frozen shape"
tech-stack:
  added: []
  patterns:
    - "Pattern F: error-message clauses via def message(%{reason: <atom>}) do \"...\" |> String.trim() end (bare-atom only in Phase 33)"
    - "Pattern G: parity-freeze test via @public_*_reasons list + expected_messages map + exact/1 = String.trim_trailing/1 heredoc helper"
key-files:
  created:
    - "lib/rindle/capability.ex"
    - "test/rindle/error_streaming_freeze_test.exs"
    - "test/rindle/capability_test.exs"
    - ".planning/phases/33-provider-boundary-state-schema/deferred-items.md"
  modified:
    - "lib/rindle/error.ex"
decisions:
  - "exact/1 in error_streaming_freeze_test.exs is defined verbatim as defp exact(text), do: String.trim_trailing(text) — matching the existing AV freeze test analog at test/rindle/error_test.exs:318 (D-28)"
  - "signed_playback_configured? uses Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, []) (D-30) — does NOT call Code.ensure_loaded?/1 on :mux; returns [] when nothing is configured"
  - "Rindle.Capability is a read-only aggregator (no Repo, no I/O) and never echoes signing_key_id or signing_private_key values (security invariant 14 secondary enforcement)"
metrics:
  duration: "12m14s"
  completed_date: "2026-05-06"
  tasks_completed: 3
  commits: 5
  files_changed: 4
---

# Phase 33 Plan 04: Error Vocabulary + Capability Report Summary

Land the five new bare-atom `Rindle.Error` reason clauses for the streaming
provider boundary, the AV-06-05 freeze-pattern parity gate that locks the
wording at ship, and the new `Rindle.Capability.report/0` aggregator —
without touching `mix.exs`, without adding any Mux dependency, and without
modifying the existing v1.4 `:streaming_not_configured` clause.

## Tasks Completed

| # | Task | Commits | Files |
|---|------|---------|-------|
| 1 | Add 5 new error message clauses + freeze test (STREAM-07 + STREAM-09) | `8967768`, `40ffa01` | `test/rindle/error_streaming_freeze_test.exs`, `lib/rindle/error.ex` |
| 2 | Create `Rindle.Capability.report/0` aggregator (STREAM-08) | `8127f61`, `790c066` | `test/rindle/capability_test.exs`, `lib/rindle/capability.ex` |
| 3 | Quality gate (focused suite green; pre-existing baseline issues logged out-of-scope) | `ca81c5f` | `.planning/phases/33-provider-boundary-state-schema/deferred-items.md`, `lib/rindle/capability.ex` (mix format) |

## Frozen Wording: Five New `Rindle.Error.message/1` Clauses

The exact heredoc text below is the freeze point — locked across v1.6 by the
parity test in `test/rindle/error_streaming_freeze_test.exs`. Future PRs
cannot drift the wording without explicitly editing the freeze test. The
production code uses `|> String.trim()` (Pattern F); the test's expected
strings use `String.trim_trailing/1` (Pattern G — see decision below). With
heredocs that have no leading blank line, both pipelines produce the same
byte-for-byte string.

### `:provider_asset_not_ready`

```
The provider asset is not yet ready for playback.

Check `mix rindle.runtime_status --provider-stuck` to see whether ingest is in flight or stuck. If the row is in :uploading or :processing, wait for the provider webhook to confirm readiness. If the row stays in :processing past the configured threshold, inspect Oban for the `MuxIngestVariant` job (Phase 34) and consider re-ingest via `Rindle.regenerate_variants/2`.
```

### `:provider_webhook_invalid`

```
A streaming-provider webhook payload failed signature verification or replay-window validation.

To fix:
  1. Confirm the webhook secret matches the value configured in the provider dashboard. If you recently rotated, the new secret should be the FIRST entry in `:webhook_secrets`.
  2. Check the request timestamp tolerance — Mux's default is 300s; signed payloads outside this window are rejected as replays.
  3. Inspect telemetry under `[:rindle, :provider, :webhook, :rejected]` to see whether the failure was a signature mismatch or a replay-window failure.

The 400 response is intentional and is identical for signature and replay failures (operators distinguish via telemetry metadata, not error variants).
```

### `:provider_sync_failed`

```
A `media_provider_assets` row is in `:errored` state. The provider asset cannot be served.

To fix:
  1. Inspect `last_sync_error` on the row to see the provider-side cause.
  2. If the original source is recoverable, re-ingest via `Rindle.regenerate_variants/2` (the FSM allows `:errored → :processing` re-entry).
  3. If the asset should be retired, delete it via the provider dashboard and then `Rindle.detach/1` the local row.

Run `mix rindle.runtime_status --provider-stuck` for a list of errored rows.
```

### `:provider_quota_exceeded`

```
The streaming provider rejected a request due to quota or rate-limit caps.

To fix:
  1. Check the provider dashboard for current quota usage and limits (Mux: storage, encoding minutes, delivery minutes).
  2. Back off automatic retries — Oban will requeue but the underlying limit will not clear until the quota window rolls.
  3. If you are scaling intentionally, contact the provider to raise limits before retrying.

This atom is the bare-atom v1.6 surface. Provider/retry-after detail can be inspected from telemetry metadata.
```

### `:streaming_provider_requires_asset_struct`

```
`Rindle.Delivery.streaming_url/3` was called with a binary storage key on a profile that has streaming configured.

To fix: pass the asset struct (`%Rindle.Domain.MediaAsset{}` or equivalent map with `:id`) instead of the storage key. Streaming dispatch needs the asset's binary_id to look up the matching `media_provider_assets` row.

For profiles that have NOT opted into streaming, the binary-key form continues to work and falls through to v1.4 progressive playback.
```

## Decision: `exact/1` is `String.trim_trailing/1`, not `String.trim/1`

Per Claude's Discretion (D-32) the implementation choice for the freeze
test's normalization helper was the executor's call. Locked rationale:

- Mirrors `test/rindle/error_test.exs:318` byte-for-byte — the existing
  AV-06-05 freeze test uses `defp exact(text), do: String.trim_trailing(text)`.
- Each heredoc value passed to `exact/1` is written with content on the line
  immediately after `"""` (no leading blank line). Heredocs always emit a
  trailing newline, so `String.trim_trailing/1` removes only that single
  trailing `\n`. Production code uses `|> String.trim()` after the same
  no-leading-blank-line heredoc, which also strips only the trailing
  newline. Both pipelines produce identical strings.
- Using `String.trim/1` on the test side would diverge from the AV analog
  and weaken the freeze (matching strings that have a leading blank line in
  production).

Verified by 25/0 deterministic passes across 3 consecutive
`mix test test/rindle/error_streaming_freeze_test.exs test/rindle/capability_test.exs test/rindle/error_test.exs`
runs.

## `Rindle.Capability.report/0` Locked Shape

```elixir
@type report :: %{
        storage: %{module() => [atom()]},
        processor: %{module() => [atom()]},
        streaming: %{
          providers: %{module() => [atom()]},
          signed_playback_configured?: boolean(),
          configured_profiles: [module()]
        }
      }
```

### Example output: empty config (no profiles, no Mux config)

Smoke verified via `mix run --no-start -e 'IO.inspect(Rindle.Capability.report())'`:

```elixir
%{
  processor: %{},
  storage: %{},
  streaming: %{
    providers: %{},
    signed_playback_configured?: false,
    configured_profiles: []
  }
}
```

### Example output: populated Mux signing config

Set in test via `Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
signing_key_id: "kid-abc", signing_private_key: "-----BEGIN PRIVATE KEY-----...")`:

```elixir
%{
  processor: %{},
  storage: %{},
  streaming: %{
    providers: %{},
    signed_playback_configured?: true,        # boolean ONLY
    configured_profiles: []
  }
}
```

The boolean flips to `true` once both keys are binaries; the literal config
values NEVER appear in the output. Test 11 (`inspect(report)` does not
contain the literal signing-key marker `"-----BEGIN PRIVATE KEY-----TEST-DO-NOT-LEAK-ABCD-1234"`)
covers the security invariant 14 secondary enforcement byte-for-byte.

### Crash safety when `:mux` dep absent (D-30)

`signed_playback_configured?/0` calls `Application.get_env(:rindle,
Rindle.Streaming.Provider.Mux, [])` which returns `[]` when nothing is
configured — never raises. There is no `Code.ensure_loaded?/1` call on the
`:mux` dep anywhere in `lib/rindle/capability.ex` (`grep -c
'Code.ensure_loaded' lib/rindle/capability.ex` returns 0). Test 7 verifies
the function does not crash under empty/missing Mux config.

## Test Counts

### Plan 04 focused suite

| File | Tests | Failures |
|------|-------|----------|
| `test/rindle/error_streaming_freeze_test.exs` | 2 | 0 |
| `test/rindle/capability_test.exs` | 11 | 0 |
| `test/rindle/error_test.exs` (TRIPWIRE — D-26) | 12 | 0 |
| **Plan 04 focused suite total** | **25** | **0** |

Verified deterministic across 3 consecutive runs.

### Tripwire: existing AV freeze tests stay green

`test/rindle/error_test.exs` continues to pass byte-for-byte with the
existing 8 AV public reason atoms (`:processor_capability_missing`,
`:ffmpeg_not_found`, `:capability_drift`, `:variant_source_not_found`,
`:unsupported_codec`, `:streaming_not_configured`,
`:variant_processing_cancelled`, `:range_unparseable`). D-26 invariant
honored: the existing `:streaming_not_configured` clause at
`lib/rindle/error.ex:214-221` is unchanged byte-for-byte (verified by `git
diff lib/rindle/error.ex | grep -E '^-.*streaming_not_configured'`
producing zero hits).

## Deviations from Plan

None of Rules 1–4 fired during execution. The plan was executed exactly as
written, with one exception requiring an executor judgment call:

### `[Rule 0 — Plan-prescribed acceptance-criterion enforcement]` Rewrote `@moduledoc` reference to `Code.ensure_loaded?/1`

The plan's Task 2 acceptance criterion is strict: `grep -c 'Code.ensure_loaded'
lib/rindle/capability.ex returns 0`. My initial `@moduledoc` mentioned
`Code.ensure_loaded?/1` only to describe what the module deliberately avoids.
The grep counts string matches in the entire file (including comments and
moduledocs), so the moduledoc reference was rewritten as: "uses
`Application.get_env/2`, which returns `[]` when nothing is configured" —
preserving the same semantic intent.

This is plan-acceptance-criterion compliance, not a Rule 1-4 deviation.
Documented here for traceability.

## Quality Gate Outcome

| Gate | Status | Notes |
|------|--------|-------|
| `mix test` (focused: freeze + capability + error_test) | PASS (25/0, deterministic across 3 runs) | All STREAM-07/08/09 tests + tripwire |
| `mix test` (full suite) | NO REGRESSION | Plan-04 introduces 0 new failures; pre-existing FFmpeg `:epipe` flakes (3-6 per run, varying tests) verified on baseline `c6aeead` |
| `mix format --check-formatted` | PASS (after auto-format) | |
| `mix.exs` unchanged | PASS | `git diff --name-only c6aeead..HEAD -- mix.exs` empty |
| `lib/rindle/error.ex` additive-only | PASS (D-26) | `git diff c6aeead..HEAD -- lib/rindle/error.ex \| grep -cE '^-([^-]\|$)'` returns 0 |
| `mix credo --strict` | NO REGRESSION | Plan-04 introduces 0 new findings on `lib/rindle/error.ex`, `lib/rindle/capability.ex`, or the new tests; baseline credo exit code 14 (152 files, all unrelated) is logged out-of-scope in `deferred-items.md` |
| `mix dialyzer` | NO REGRESSION | Plan-04 introduces 0 new dialyzer warnings; baseline exit code 2 (warnings in `lib/rindle/html.ex`, `lib/rindle/ops/runtime_status.ex`, `lib/rindle/workers/process_variant.ex`, `lib/rindle/workers/promote_asset.ex`) is logged out-of-scope in `deferred-items.md` |

## Deferred Issues

Pre-existing issues on baseline `c6aeead` that Plan 04 did NOT introduce —
logged in `.planning/phases/33-provider-boundary-state-schema/deferred-items.md`
for visibility, out-of-scope per executor scope boundary:

1. **`mix credo --strict` baseline exit code 14** — 152 source files, ~50
   findings spread across `lib/rindle/processor/ffmpeg.ex`,
   `lib/rindle/live_view.ex`, `lib/rindle/ops/runtime_status.ex`,
   `lib/rindle/av/capability.ex`, `lib/rindle/domain/media_asset.ex`,
   `lib/rindle/processor/av/video.ex`, `lib/rindle/workers/process_variant.ex`,
   `lib/rindle/ops/lifecycle_repair.ex`. None reference plan-04 files.
2. **`mix dialyzer` baseline exit code 2** — pattern_match/pattern_match_cov
   warnings in `lib/rindle/html.ex:266`, `lib/rindle/ops/runtime_status.ex:584-585`,
   `lib/rindle/workers/process_variant.ex:108,398`,
   `lib/rindle/workers/promote_asset.ex:255`. None reference plan-04 files.
3. **FFmpeg subprocess `:epipe` test flakes** in `waveform_test.exs`,
   `av_test.exs`, `ffprobe_test.exs`, `av_probe_test.exs`,
   `application_test.exs`. Failures shift between runs (3-6 per full-suite
   invocation). Verified pre-existing.

## Threat Surface Scan

The plan's `<threat_model>` enumerated three threats. Plan 04
mitigates all three by construction; no new threat surface was discovered
during execution.

| Threat ID | Disposition | Plan 04 enforcement |
|-----------|-------------|---------------------|
| T-33-05 (Information Disclosure: `Rindle.Capability.report/0` returning Mux signing keys) | mitigate | `signed_playback_configured?/0` returns a boolean built from `is_binary/1` on the two keys; the values are never returned, embedded in metadata, or echoed. Test 11 in `test/rindle/capability_test.exs` asserts `inspect(report, limit: :infinity, printable_limit: :infinity)` does NOT contain the literal `signing_private_key` value (the test uses a deliberate `"-----BEGIN PRIVATE KEY-----TEST-DO-NOT-LEAK-ABCD-1234"` marker) and does NOT contain the `signing_key_id` value. |
| T-33-06 (Denial of Service: `report/0` crashing when `:mux` dep absent) | mitigate | `Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])` returns `[]` when nothing is configured — never raises. Test 7 verifies `report/0` runs under `Application.delete_env/2`. `grep -c 'Code.ensure_loaded' lib/rindle/capability.ex` returns 0. |
| T-33-07 (Information Disclosure: error messages echoing internal state) | accept | The 5 new clauses use bare-atom variants only (D-27); none embed runtime values. Map-keyed variants that COULD echo input data are explicitly deferred to v1.7+. |

No new threat flags discovered.

## Self-Check: PASSED

Verified all SUMMARY claims:

- `lib/rindle/error.ex` exists with all 5 new clauses (`grep -c 'def message(%{reason: :provider_' lib/rindle/error.ex` returns 4; `grep -c ':streaming_provider_requires_asset_struct' lib/rindle/error.ex` returns 1).
- `lib/rindle/capability.ex` exists with `report/0`.
- `test/rindle/error_streaming_freeze_test.exs` exists with `@public_streaming_reasons` + `defp exact`.
- `test/rindle/capability_test.exs` exists with 11 tests across 3 describe blocks.
- All 5 commits exist in `git log --oneline c6aeead..HEAD`: `8967768`, `40ffa01`, `8127f61`, `790c066`, `ca81c5f`.
- `git diff --name-only c6aeead..HEAD -- mix.exs` is empty.
- `git diff c6aeead..HEAD -- lib/rindle/error.ex | grep -cE '^-([^-]|$)'` is 0.
- Plan-04 focused suite passes 25/0 deterministically across 3 runs.

## TDD Gate Compliance

| Plan-level gate | Commit | Verified |
|-----------------|--------|----------|
| RED (Task 1: freeze test failing) | `8967768 test(33-04): add failing freeze test for 5 new streaming reason atoms` | YES — initial run reported 1 failure (the message-text test) before the impl commit |
| GREEN (Task 1: 5 new clauses make freeze test pass) | `40ffa01 feat(33-04): add 5 streaming reason atom message clauses` | YES — `mix test test/rindle/error_streaming_freeze_test.exs test/rindle/error_test.exs` returned 14/0 immediately after this commit |
| RED (Task 2: capability test failing — module missing) | `8127f61 test(33-04): add failing tests for Rindle.Capability.report/0` | YES — initial run reported 11 failures (UndefinedFunctionError) |
| GREEN (Task 2: aggregator makes 11 tests pass) | `790c066 feat(33-04): add Rindle.Capability.report/0 aggregator` | YES — `mix test test/rindle/capability_test.exs` returned 11/0 immediately after this commit |
| REFACTOR | `ca81c5f chore(33-04): apply mix format + log pre-existing quality-gate items` | YES — purely formatting + docs; no behavior change; tests stay green |

All TDD gates honored.
