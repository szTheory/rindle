---
phase: 05-ci-1-0-readiness
plan: 02
subsystem: ci-contract-lane
tags: [ci, telemetry, contract-test, github-actions]

# Dependency graph
requires:
  - phase: 05-ci-1-0-readiness
    plan: 01
    provides: Real :telemetry.execute/3 emissions at all six locked event-family sites (asset/variant state_change, upload start/stop, delivery signed, cleanup run × 2 workers); without these, the contract assertions would have nothing to observe
  - phase: 03-delivery-observability
    provides: Locked TEL-01..08 public event-family contract that this lane asserts against
provides:
  - ExUnit :contract lane that locks the public telemetry surface against drift
  - Test_helper exclusion for :contract and :adopter tags so default `mix test` stays fast
  - GitHub Actions Contract job that runs `mix test --only contract` after the matrixed quality job
  - Mutation-tested ratchet: renaming any locked event name fails the lane
affects:
  - 05-03 (quality job extension) — quality matrix preserved as Blocker 4 invariant for contract job's needs declaration
  - 05-04 (adopter lane) — `:adopter` tag exclusion already wired in test_helper for the future adopter test fixture
  - Future phases adding new emission sites — must update @public_events allowlist or the no-extras probe test catches them

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ExUnit @moduletag :contract with default-exclude in test_helper.exs"
    - ":telemetry_test.attach_event_handlers/2 + on_exit detach for handler-leak prevention"
    - "assert_received (no timeout) for synchronous in-process telemetry emissions"
    - "Probe-handler superset for catching out-of-allowlist event names"
    - "GitHub Actions matrix-needs interaction for downstream-job gating"

key-files:
  created:
    - test/rindle/contracts/telemetry_contract_test.exs
  modified:
    - test/test_helper.exs
    - .github/workflows/ci.yml

key-decisions:
  - "Make LocalContractProfile public (delivery: [public: true]) so the local adapter resolves a URL without :signed_url capability — the [:rindle, :delivery, :signed] event still fires for both modes (mode is metadata, not a separate event)"
  - "Lift drain_probe_observations/1 to module-level: defp inside a describe block is invalid Elixir (Rule 3 — auto-fix blocking syntactic issue in plan snippet)"
  - "Probe-handler approach: cannot truly wildcard in :telemetry, so attach to a superset that includes plausible-but-not-public names ([:rindle, :upload, :began] etc.) — if those fire, the assertion catches them"
  - "Contract job uses Elixir 1.17/OTP 27 only (no matrix on contract lane) — contract assertions are not version-sensitive and matrixing would double the runtime"
  - "`needs: quality` is documented inline in YAML to make the matrix-needs interaction (Blocker 4) explicit for future readers"

patterns-established:
  - "Contract test module shell: use ExUnit.Case async: false + @moduletag :contract + setup attach + on_exit detach"
  - "Acceptance ratchet: a mutation test (rename emission event name; confirm lane fails; revert) belongs in the same plan that introduces the contract lane"
  - "Inline test profile module pattern (LocalContractProfile inside the test module body, like LocalProfile in lifecycle_integration_test.exs)"

requirements-completed:
  - CI-06

# Metrics
duration: 5min
completed: 2026-04-26
---

# Phase 05 Plan 02: Telemetry Contract Lane (CI-06) Summary

**Wired the `:contract` ExUnit lane plus a new GitHub Actions `Contract` job that runs `mix test --only contract` after the matrixed `quality` job; the lane fails the moment any locked telemetry event name is renamed or any required `:profile`/`:adapter` metadata key is dropped (Phase 5 success criterion 5.2).**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-26T21:54:41Z
- **Completed:** 2026-04-26T21:59:43Z
- **Tasks:** 3 / 3 complete
- **Files touched:** 1 created, 2 modified
- **Commits:** 3

## Accomplishments

- New `:contract` ExUnit lane locks the six locked public events as an exact allowlist (length + shape + atom-only structure + first-element `:rindle` + each-three-segment).
- Three concrete emission contract tests (AssetFSM / VariantFSM / Delivery.url) prove that `:profile` + `:adapter` metadata keys are present and all measurement values are numeric.
- A "no event outside allowlist fires" probe test attaches a superset of plausible-but-not-public event names (`:upload :began`, `:asset :transitioned`, etc.) and fails the lane if any of them fire.
- `test_helper.exs` excludes `:contract` and `:adopter` tags by default so `mix test` (no flags) stays fast and only the gated lanes run when opted in via `--only`.
- New `Contract` GitHub Actions job runs `mix test --only contract` on Elixir 1.17 / OTP 27 after the matrixed `quality` job succeeds; runs in parallel with the existing `Integration` job.
- Mutation acceptance proven locally: renaming `[:rindle, :asset, :state_change]` to `[:rindle, :asset, :transitioned]` in `asset_fsm.ex` failed the lane in two distinct assertions (the AssetFSM emission test and the no-extras probe test); reverted before commit.

## Task Commits

1. **Task 1 — scaffold telemetry contract test lane** — `6d893a8` (test)
2. **Task 2 — assert allowlist + metadata + numeric measurements contract** — `af1296b` (test)
3. **Task 3 — add Contract job to CI workflow** — `3cac365` (ci)

No `feat`/`refactor` commits were needed. Plan 01 already wired the underlying emission code; this plan's job was to lock the surface in tests + CI.

## Files Created/Modified

### Tests

- `test/rindle/contracts/telemetry_contract_test.exs` (NEW, 192 lines) — `Rindle.Contracts.TelemetryContractTest` with `@moduletag :contract`, `async: false`, `setup` attaches handlers via `:telemetry_test.attach_event_handlers/2`, `on_exit` detaches the ref. Inline `LocalContractProfile` (storage: Local, delivery: [public: true]) drives `Delivery.url/3`. Five tests across three describe blocks: allowlist shape (1), metadata + measurement contract (3), no event outside allowlist fires (1).

### Test infrastructure

- `test/test_helper.exs` — replaced `ExUnit.start()` with `ExUnit.start(exclude: [:integration, :minio, :contract, :adopter])` so default `mix test` ignores all four gated lanes.

### CI

- `.github/workflows/ci.yml` — appended a new `contract` job after `integration`. Job declares `needs: quality` (waits for both 1.15/26 and 1.17/27 matrix variants per Blocker 4); runs Elixir 1.17/OTP 27 with deps + build cache; final step `mix test --only contract`.

## Decisions Made

- **Profile chose public delivery for the URL test.** The local storage adapter advertises `[:local, :presigned_put]` only — no `:signed_url`. Rather than introduce a fake adapter or stub, configure the inline `LocalContractProfile` with `delivery: [public: true]` so `Delivery.url/3` resolves without the private-mode capability gate. The `[:rindle, :delivery, :signed]` event fires for BOTH `:public` and `:private` modes (mode is metadata), so the contract still asserts profile + adapter + numeric measurements.
- **Lifted `drain_probe_observations/1` to module-level.** The plan snippet placed `defp` inside a `describe` block, which is invalid Elixir syntax — Rule 3 (auto-fix blocking issue caused directly by the task's own code).
- **Single Elixir/OTP combo on contract lane.** Contract assertions test event name + metadata shape, neither of which is version-sensitive. Matrix-testing would double runtime for no signal; explicitly chose 1.17/27 to align with the integration lane.
- **Inline comment block on `needs: quality`.** Made the matrix-needs interaction documented at the source for future readers (Blocker 4 invariant).

## Deviations from Plan

The plan was executed substantively as written. Two adjustments were required:

### Adaptation A (Task 2): Profile delivery mode

- **Plan said:** `LocalContractProfile` uses `storage: Rindle.Storage.Local` with default delivery; the `Delivery.url/3` test calls private-mode delivery.
- **Reality:** `Rindle.Storage.Local.capabilities/0` returns `[:local, :presigned_put]` — `:signed_url` is absent, so `Delivery.url/3` rejects with `{:error, {:delivery_unsupported, :signed_url}}` in private mode. Confirmed via test failure.
- **Action:** added `delivery: [public: true]` to `LocalContractProfile`. The locked telemetry event still fires (mode is metadata, not a separate event name), so all metadata + measurement assertions remain in scope.
- **Rule:** Rule 1 (auto-fix bug — plan's test snippet would fail at the URL resolution step before reaching the assertion).

### Adaptation B (Task 2): `defp` placement

- **Plan said:** `drain_probe_observations/1` is `defp`-defined inside the "no event outside allowlist fires" `describe` block.
- **Reality:** Elixir does not allow `defp` inside a `describe` block (`describe` is a macro that wraps `test` blocks; module-level definitions must be siblings of `describe`, not nested in it).
- **Action:** moved `drain_probe_observations/1` to the bottom of the test module, alongside the other private assertion helpers.
- **Rule:** Rule 3 (auto-fix blocking syntax issue).

Both adaptations preserve all acceptance criteria.

## Authentication Gates

None — purely test code + YAML changes; no external auth required.

## Verification Results

### Plan-level invariants

- `mix test test/rindle/contracts/telemetry_contract_test.exs` (no `--only`) → "0 tests, 0 failures (5 excluded)" — the file's tests are excluded by default. ✓
- `mix test --only contract` → "5 tests, 0 failures (165 excluded)" — lane runs ONLY the contract-tagged tests and passes. ✓
- Mutation: renamed `[:rindle, :asset, :state_change]` → `[:rindle, :asset, :transitioned]` in `lib/rindle/domain/asset_fsm.ex`; `mix test --only contract` failed with 2 assertions (AssetFSM emission test + no-extras probe test). Reverted; lane passes again. ✓
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` exits 0. ✓

### Acceptance grep checks

- `grep -c 'ExUnit.start(exclude:' test/test_helper.exs` → 1 ✓
- `grep ':contract' test/test_helper.exs` → 1 match ✓
- `grep ':adopter' test/test_helper.exs` → 1 match ✓
- `grep '@moduletag :contract' test/rindle/contracts/telemetry_contract_test.exs` → 1 ✓
- `grep ':telemetry_test.attach_event_handlers' test/rindle/contracts/telemetry_contract_test.exs` → 1 ✓
- `grep ':telemetry.detach' test/rindle/contracts/telemetry_contract_test.exs` → 1 ✓
- `grep 'Map.has_key?(metadata, :profile)' test/rindle/contracts/telemetry_contract_test.exs` → 1+ ✓
- `grep 'Map.has_key?(metadata, :adapter)' test/rindle/contracts/telemetry_contract_test.exs` → 1+ ✓
- `grep 'is_number' test/rindle/contracts/telemetry_contract_test.exs` → 1+ ✓
- `grep 'in @public_events' test/rindle/contracts/telemetry_contract_test.exs` → 1+ (the no-extras assertion) ✓
- `wc -l test/rindle/contracts/telemetry_contract_test.exs` → 192 (≥ 100) ✓
- YAML structural check via Python: contract job has `needs: quality`, `runs-on: ubuntu-latest`, `name: Contract`, and a `Run contract tests` step ✓
- Quality matrix preserved: `data['jobs']['quality']['strategy']['matrix']['include']` = `[{1.15/26}, {1.17/27}]` ✓
- All three job names present: Quality (1), Integration (1), Contract (1) ✓

## Deferred Issues

None introduced by this plan.

The pre-existing warning emitted during compile — `defp create_session/2 default values are never used` in `test/rindle/ops/upload_maintenance_test.exs:30` — is unrelated to this plan and was already present at the base commit. It is logged in `.planning/phases/05-ci-1-0-readiness/deferred-items.md` from Plan 01.

## Threat Flags

None. The threat surface introduced by this plan is captured by `<threat_model>` items T-05-02-01..02 in the plan; mitigations are enforced in implementation:

- T-05-02-01 (handler ID collision): `:telemetry_test.attach_event_handlers/2` auto-generates unique refs per Pitfall 2 in 05-RESEARCH.md; the test module is `async: false` to prevent inter-test handler races.
- T-05-02-02 (info disclosure via assertion error messages): test metadata uses only `"TestProfile"`, `__MODULE__`, `Rindle.Storage.Local`, and `LocalContractProfile` — no secrets, PII, or production identifiers.

No new attack surface (no network, no secrets, no new public API).

## TDD Gate Compliance

This plan is `type: execute`. Tasks 1 and 2 declare `tdd="true"`; Task 3 declares `tdd="false"`.

- Task 1's RED phase is the smoke test asserting the `@public_events` list shape — it passes immediately because the test fixture controls the list itself (Task 1 is scaffolding, not testing emission code). The fail-fast rule was considered: this is the documented behavior of structural fixture tests, not a "feature already exists" false-positive.
- Task 2's RED phase passes immediately on first run because Plan 01 already wired the underlying emission code that Task 2's assertions check. The mutation acceptance criterion (rename event name → lane fails) is the explicit RED proof: a hostile change to the locked surface fails 2 assertions in the lane. This is the ratchet that makes the lane meaningful.
- Task 3 is a CI configuration task and is appropriately marked `tdd="false"`.

Git log shows three commits for this plan: `6d893a8` (test), `af1296b` (test), `3cac365` (ci). No `feat`/`refactor` commits were needed because the lane locks already-wired emission sites; no new lib code was required.

## Self-Check: PASSED

- File: `test/rindle/contracts/telemetry_contract_test.exs` → FOUND
- File: `test/test_helper.exs` → FOUND (modified)
- File: `.github/workflows/ci.yml` → FOUND (modified)
- Commit `6d893a8` → FOUND in `git log`
- Commit `af1296b` → FOUND in `git log`
- Commit `3cac365` → FOUND in `git log`
