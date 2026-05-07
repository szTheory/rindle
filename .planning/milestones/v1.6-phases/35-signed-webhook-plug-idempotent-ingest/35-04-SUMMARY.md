---
phase: 35-signed-webhook-plug-idempotent-ingest
plan: 04
subsystem: ops
tags: [runtime-status, mix-task, ops, observability, provider-stuck, redaction, security-invariant-14, mux]

# Dependency graph
requires:
  - phase: 33-provider-boundary
    provides: MediaProviderAsset schema (states, redact_id/1)
  - phase: 34-mux-rest-adapter
    provides: Rindle.Streaming.Provider.Mux app-config namespace (provider_stuck_threshold_seconds default), Rindle.Workers.MuxSyncProviderAsset surface
  - phase: 35-signed-webhook-plug-idempotent-ingest
    plan: 02
    provides: Worker that leaves stuck rows in :uploading | :processing past max_attempts (drives the operator visibility need addressed here)
provides:
  - Rindle.runtime_status/1 :provider_stuck filter (D-39) + provider_assets report section (D-40)
  - mix rindle.runtime_status --provider-stuck flag (D-41)
  - Three-layer enforcement of security invariant 14 layer 3 (ops surface): full MediaAsset.id UUID + redacted last-4-char provider_asset_id tag in samples
  - Recommendation handler for :provider_stuck class (action: :resync, surface: Rindle.Workers.MuxSyncProviderAsset)
affects: [phase-36-onboarding-ci, runtime-status-extensions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "provider_assets_report/2 mirrors variant_report/3 byte-for-byte template structure"
    - "format_provider_findings/1 mirrors format_findings/1 style; placed AFTER upload_sessions and BEFORE format_recommendations in format_text_report/1"
    - "@doc false def for format helpers tested directly (matches existing format_text_report/1 surface)"
    - "Effective threshold resolution: operator filters.older_than wins; otherwise Application.get_env app-config; otherwise 7200s default constant"

key-files:
  created: []
  modified:
    - lib/rindle/ops/runtime_status.ex
    - lib/mix/tasks/rindle.runtime_status.ex
    - test/rindle/ops/runtime_status_test.exs
    - test/rindle/runtime_status_task_test.exs
    - .planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md

key-decisions:
  - "D-39 implemented via filters.older_than override + Application.get_env-resolved default in effective_provider_stuck_threshold/1"
  - "Threshold default constant @provider_stuck_default_threshold_seconds 7200 lives in runtime_status.ex (not duplicated into app config) — Mux app config overrides cleanly when present"
  - "provider_assets report ALWAYS returns the locked shape (counts + threshold_seconds + findings: []) — schema-stable when filter is off"
  - "format_provider_findings/1 exposed as @doc false def (not defp) to enable direct test calls — matches format_text_report/1 precedent"
  - "Counts query covers ALL MediaProviderAsset rows (group by state) regardless of filter; profile filter applies to counts when set"

patterns-established:
  - "Pattern 1: report-section function template — mirror variant_report/3 (counts | findings | section-specific extra keys like threshold_seconds)"
  - "Pattern 2: redaction at the ops boundary — pipe row.provider_asset_id through MediaProviderAsset.redact_id/1 in the sample builder, never log/return raw"

requirements-completed: [MUX-14]

# Metrics
duration: 13min
completed: 2026-05-07
---

# Phase 35 Plan 04: mix rindle.runtime_status --provider-stuck Summary

**`Rindle.runtime_status/1` and `mix rindle.runtime_status` extended with a `:provider_stuck` filter and `provider_assets` report section that surfaces `MediaProviderAsset` rows stuck in `:uploading | :processing` past a configurable threshold, with REDACTED `provider_asset_id` (last-4 tag via `MediaProviderAsset.redact_id/1`) and the full `MediaAsset.id` UUID in every sample (security invariant 14, layer 3).**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-05-07T22:43:00Z
- **Completed:** 2026-05-07T22:56:00Z
- **Tasks:** 2 (both TDD: RED -> GREEN)
- **Files modified:** 4 source/test + 1 deferred-items doc

## Accomplishments

- New `:provider_stuck` boolean filter on `Rindle.runtime_status/1`, fully wired through `normalize_filters/1` (positive validation, key-string fallback, allowlist).
- New `provider_assets` report section (always-present, schema-stable) with `counts` (state -> integer + `:total`), `threshold_seconds` (effective), and `findings` (only populated when filter is `true` AND rows match).
- Effective threshold resolution per D-39: operator's `--older-than-sec` overrides; otherwise `Application.get_env(:rindle, Rindle.Streaming.Provider.Mux)[:provider_stuck_threshold_seconds]`; otherwise default 7200s.
- Sample shape per D-40: full `MediaAsset.id` UUID + REDACTED `provider_asset_id` (`...abcd`) via `MediaProviderAsset.redact_id/1` — three-layer security invariant 14 enforcement is now complete (Layer 1: Phase 33 schema Inspect impl; Layer 2: Plan 02 worker telemetry; Layer 3: this plan's ops samples).
- New `recommendation_for_class(:provider_stuck)` handler returning `%{action: :resync, surface: "Rindle.Workers.MuxSyncProviderAsset", ...}` and wired into `recommendations/3` via a new `provider_classes` extraction.
- `mix rindle.runtime_status --provider-stuck` flag in `OptionParser` strict opts, threaded through `maybe_put/3` into the filter map.
- `format_provider_findings/1` text helper mirroring `format_findings/1` style; inserted in `format_text_report/1` AFTER `upload_sessions` and BEFORE `format_recommendations` (D-41 locked position).
- 15 new test cases (9 ops-layer + 6 Mix-task layer); all pass alongside the 10 pre-existing tests in those files.

## Task Commits

Each task was committed atomically following the TDD RED -> GREEN cycle:

1. **Task 1 RED: failing tests for provider_assets report** — `17716c7` (test)
2. **Task 1 GREEN: implement provider_assets_report/2 + filter** — `717a89c` (feat)
3. **Task 2 RED: failing tests for --provider-stuck Mix flag** — `83f3213` (test)
4. **Task 2 GREEN: implement Mix flag + format_provider_findings/1** — `80f813c` (feat)
5. **Deferred items log** — `0f80461` (docs)

_TDD gate sequence: RED commits precede GREEN for both tasks; full git log linearizes test -> feat -> test -> feat -> docs._

## Files Created/Modified

- `lib/rindle/ops/runtime_status.ex` — `MediaProviderAsset` alias added; `@allowed_filter_keys` extended with `:provider_stuck`; `@type filters` and `@type report` extended; `provider_assets_report/2` + `effective_provider_stuck_threshold/1` + `provider_assets_finding_rows_query/3` + `maybe_filter_provider_assets_profile/2` + `provider_asset_sample/2` added; `recommendation_for_class(:provider_stuck)` clause added before catch-all; `recommendations/3` extended with `provider_classes`; `normalize_filters/1` and `normalize_filter_keys/1` extended; `normalize_provider_stuck/1` validator added.
- `lib/mix/tasks/rindle.runtime_status.ex` — OptionParser strict opts gain `provider_stuck: :boolean`; `filters` map building adds `maybe_put(:provider_stuck, ...)`; `format_text_report/1` inserts the provider section in the locked position; `format_provider_findings/1` added as `@doc false def`; `@moduledoc` Options list documents the flag including the redaction note.
- `test/rindle/ops/runtime_status_test.exs` — `MediaProviderAsset` alias added; new `describe "provider_assets report (MUX-14)"` block with 9 cases covering schema-stable report shape, filter behavior, threshold default + override, sample redaction, recommendation surface, profile narrowing, counts; new `insert_provider_asset/2` helper.
- `test/rindle/runtime_status_task_test.exs` — new `describe "--provider-stuck (MUX-14)"` block with 6 cases covering flag parsing, `format_provider_findings/1` empty + non-empty, `format_text_report/1` inclusion + ordering, redaction surfacing in rendered output; helpers `build_provider_finding/0` and `build_report_with_provider_findings/1`.
- `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` — appended a Plan 35-04 section documenting (a) 3 pre-existing test failures verified on the worktree base before any 35-04 changes, (b) the plan's reference to a non-existent test path resolved via Rule 3.

## Decisions Made

- **Test file resolution (Rule 3 fix):** `35-04-PLAN.md` referenced `test/mix/tasks/rindle.runtime_status_test.exs`, which does not exist. The actual Mix-task test file lives at `test/rindle/runtime_status_task_test.exs` (verified pre-existing on the base). Extended the real file rather than creating a parallel.
- **Threshold default constant:** Introduced `@provider_stuck_default_threshold_seconds 7200` rather than hardcoding `7200` inline in `effective_provider_stuck_threshold/1`. Improves readability and centralizes the magic number that is duplicated in plan documentation.
- **Counts query is unconditional:** `counts` are populated from all `MediaProviderAsset` rows (grouped by state) regardless of the `:provider_stuck` filter, with optional profile narrowing. This keeps the report shape schema-stable and gives operators useful at-a-glance state distribution even with the filter off.
- **Filter-pure findings:** When `filters.provider_stuck` is `false`, no rows are queried for findings (returns `[]` immediately). The query, redaction, and sample-building happens only when the filter is true. Saves one Repo round-trip on the common path.
- **`format_provider_findings/1` as `@doc false def`:** Mirrors the existing `format_text_report/1` surface (also `@doc false def`) to permit direct test calls without exposing it on the public Mix-task API.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test file path correction**
- **Found during:** Task 2 setup
- **Issue:** The plan's `<files>` list references `test/mix/tasks/rindle.runtime_status_test.exs`. The file does not exist; the real Mix-task test lives at `test/rindle/runtime_status_task_test.exs`. Creating the planned path would orphan the existing test suite (`Rindle.RuntimeStatusTaskTest`) and split the same module across two files.
- **Fix:** Extended the existing `test/rindle/runtime_status_task_test.exs` with the new `describe "--provider-stuck (MUX-14)"` block, preserving the existing 3 tests.
- **Files modified:** `test/rindle/runtime_status_task_test.exs`
- **Verification:** All 9 tests in the file pass (3 pre-existing + 6 new).
- **Committed in:** `83f3213` (Task 2 RED)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep. The plan's intent — "extend the Mix-task test suite with the new flag's behavior" — is met by the corrected path.

## Issues Encountered

- **Pre-existing full-suite failures (out of scope):** `mix test` (full suite) reports 3 failures on the worktree base that REPRODUCE before any 35-04 code is touched (`git stash` + re-run on bare base confirms): `application_test.exs:41`, `application_test.exs:58`, `av_probe_test.exs:58`. The first two are caused by an adopter `Rindle.Adopter.CanonicalApp.VideoProfile` configured at app config that pollutes assertions on `affected_profiles`. The third is order-sensitive (passes in isolation). All three are documented in `deferred-items.md` and tracked for v1.7 polish or `/gsd-code-review`.
- **Mix-task smoke in `MIX_ENV=dev`:** `mix rindle.runtime_status` (with or without `--provider-stuck`) crashes with "could not lookup Ecto repo Rindle.Repo because it was not started or it does not exist". Confirmed pre-existing — the bare task without my flag hits the same error. The task is normally exercised via `Rindle.DataCase` in tests; the dev/prod runtime expects an adopter app to start the Repo. The unit test "the --provider-stuck flag is parsed and surfaces in filters" exercises the equivalent code path through `RuntimeStatusTask.run/1` from inside `DataCase` and passes.

## User Setup Required

None - no external service configuration required. The new flag is wholly additive; existing operators see no change unless they pass `--provider-stuck`. Adopters configuring `:provider_stuck_threshold_seconds` under `Rindle.Streaming.Provider.Mux` is OPTIONAL — the 7200s default takes over when absent.

## Next Phase Readiness

- ROADMAP success criterion #5 met: `mix rindle.runtime_status --provider-stuck` lists stuck/uploading rows older than the configured threshold; rows include the redacted `provider_asset_id` (last-4 tag) and the full `MediaAsset.id` UUID + `last_sync_error`.
- Three-layer security invariant 14 enforcement is complete:
  - Layer 1 (Phase 33): `MediaProviderAsset` Inspect impl redacts on iex/log inspection.
  - Layer 2 (Plan 02): worker telemetry + PubSub redact.
  - Layer 3 (Plan 04): `provider_stuck` sample's `provider_asset_id` is the redacted last-4 tag.
- All locked decisions D-39, D-40, D-41 (and D-42's threshold default reuse) are implemented with traceable code.
- Phase 36 (`MuxWeb` preset, `mix rindle.doctor` streaming smoke, `guides/streaming_providers.md`, package-consumer `mux-enabled` lane) can document the new operator surface in `guides/streaming_providers.md` Day-2 ops section.

## TDD Gate Compliance

Both tasks followed the RED -> GREEN cycle with separate commits:

- Task 1: `17716c7` (test, RED) -> `717a89c` (feat, GREEN). 9 ops tests RED before impl, all green after.
- Task 2: `83f3213` (test, RED) -> `80f813c` (feat, GREEN). 6 Mix-task tests RED before impl, all green after.

No REFACTOR commits needed; first GREEN implementation already matched the plan's mirrored `variant_report/3` / `format_findings/1` shape and `mix format` left structure intact.

## Self-Check: PASSED

- `lib/rindle/ops/runtime_status.ex` — FOUND
- `lib/mix/tasks/rindle.runtime_status.ex` — FOUND
- `test/rindle/ops/runtime_status_test.exs` — FOUND
- `test/rindle/runtime_status_task_test.exs` — FOUND
- `.planning/phases/35-signed-webhook-plug-idempotent-ingest/deferred-items.md` — FOUND
- Commit `17716c7` — FOUND
- Commit `717a89c` — FOUND
- Commit `83f3213` — FOUND
- Commit `80f813c` — FOUND
- Commit `0f80461` — FOUND
- Acceptance grep counts: provider_stuck in @allowed_filter_keys (1), provider_assets_report defined (1), MediaProviderAsset.redact_id call (1), recommendation_for_class(:provider_stuck) (1), normalize_provider_stuck (5 occurrences), provider_assets in runtime_status return (1), provider_stuck :boolean in OptionParser (1), maybe_put(:provider_stuck (1), format_provider_findings def (2 clauses), redacted dddd assertion in tests (3+).
- `mix compile --warnings-as-errors --force` — exit 0
- `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs` — 25 tests, 0 failures
- `mix format --check-formatted` on touched files — exit 0

---
*Phase: 35-signed-webhook-plug-idempotent-ingest*
*Completed: 2026-05-07*
