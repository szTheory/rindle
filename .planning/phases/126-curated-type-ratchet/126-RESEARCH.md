# Phase 126 — Curated Type Ratchet Research

## Objective and Authority

TYPE-01 requires the supported **Elixir 1.17 / OTP 27** home cell to pass Dialyzer after every retained ignore is justified or removed. TYPE-02 requires a curated gate that rejects new actionable findings and closes issue #76 with evidence. SAFE-01 remains the preservation contract for every source-bearing slice.

The sole acceptance authority is `.github/workflows/nightly.yml` `dialyzer` (single 1.17/27 cell, `MIX_ENV=test`, PostgreSQL, `mix dialyzer --format github`). It is non-advisory, flows into `Nightly Summary`, and its PLT key hashes `mix.exs`, `mix.lock`, and `.dialyzer_ignore.exs`. Local output on any other BEAM version is diagnostic only: it must not add, remove, or justify an ignore entry.

## Current Gate

- `mix.exs` owns Dialyxir configuration: committed `priv/plts/dialyzer.plt`, explicit added apps, and `.dialyzer_ignore.exs`.
- `test/install_smoke/ci_lane_split_test.exs` locks that the nightly job runs Dialyzer with no `continue-on-error`.
- `test/install_smoke/ci_cache_hygiene_test.exs` locks the exact PLT cache inputs.
- Do not modify topology, cache shape, job name, schedule, summary dependencies, dependency versions, or PR required-check policy.

## Inventory

`.dialyzer_ignore.exs` is the entire curated baseline: **45 entries across 18 files**—8 legacy atom-class filters from Phase 34 and 37 description-specific filters from the v0.4.1 strict baseline. No entry may be widened to a file-only or regex-wide suppression.

| Category | Owners | Disposition rule |
|---|---|---|
| Historical PLT noise | `rindle.ex`, `upload/broker`, `html`, `ops/runtime_status`, `workers/process_variant`, `workers/promote_asset` | Retain only if the exact 1.17/27 warning still reproduces and a behavior-preserving type boundary cannot correct it. Remove obsolete Phase-34 entries when unused. |
| Migration API/support | `migration.ex`, `migration/v1.ex`, `test/support/host_rindle_migration.ex` | Actionable when specs/return unions/raising paths can be made truthful without migration behavior changes. |
| Runtime/task/Admin | `batch_owner_erasure`, `runtime_checks`, `admin/live/actions_live` | Fix only with focused owner behavior tests; never weaken Admin or task result terms for Dialyzer. |
| Storage streams | `storage/gcs/client`, `storage/local`, `storage/s3` | Treat stream/opaque warnings as analyzer noise only after supported-cell confirmation and local/S3/GCS behavior coverage. |
| TUS crypto | `upload/tus_plug` | Prefer opaque-safe helper/spec boundary; preserve protocol/error semantics. |
| Mux workers | `mux_ingest_variant`, `mux_sync_provider_asset` | Correct response/error pattern types only with Mux behavior coverage. |

## Actionability Decision Rule

For each exact `{path, description}` pair: reproduce on supported CI; identify the owning public/behavior boundary; make the smallest truthful code/spec/pattern correction; run focused behavior tests and SAFE-01; remove exactly that pair; then inspect the supported Nightly result. Through Plan 126-06, the current slice passes only when its owned warning set is absent or explicitly retained with supported rationale, no new or unowned warning appears, and exact annotation identity/count proves the emitted set is only the previously recorded later-owned E38-E40 Tus warnings; Dialyzer must honestly conclude `failure` and Nightly Summary must record that failure. Plan 126-07 owns TUS/Mux and restores the global green requirement, which remains mandatory for Plans 126-08 and 126-09. A finding is retained only when it is version/dependency analyzer noise or fixing it would require an unsupported contract/schema/telemetry/error change. Record the exact rationale next to the entry. Never suppress a new warning merely to make the gate green.

## Validation Architecture

1. Add a focused baseline-policy ExUnit test for valid tuple shape, duplicate rejection, no file-wide ignores, and removal of a stale entry.
2. Keep the two existing workflow/cache structural tests as topology regressions.
3. Per owner slice: focused behavioral tests plus `bash scripts/maintainer/refactor_contract.sh` (SAFE-01).
4. Final: supported Nightly `mix dialyzer --format github` succeeds on exact head; inspect `Nightly Summary`; post the sanitized baseline/result link to #76 and close it only when every obsolete or actionable ignore is gone and every retained analyzer-noise filter has an explicit supported-cell justification.

## Recommended Bounded Slices

1. Baseline-policy test and inventory normalization (no source changes).
2. Migration/support and runtime/task warnings.
3. Storage stream adapters.
4. TUS and Mux workers; retire historical unused entries.
5. Exact-head supported Nightly authority and issue #76 disposition.

## Boundaries and Risks

Out of scope: public API, schemas/migrations, telemetry, error vocabulary, Admin behavior, dependencies, release topology, cache redesign, and local toolchain promotion. Major risks are opaque crypto/stream false positives and Ecto migration callback inference; treat both as retainable only with explicit supported-cell evidence. Issue #76 stays open until the final supported Nightly run is green and the temporary strict baseline is retired; a small curated analyzer-noise remainder is acceptable only when each retained filter has an explicit supported-cell justification.

## Resolved Open Questions

- **Which toolchain decides acceptance?** The literal nightly 1.17/OTP27 home cell, not the developer machine.
- **Can the current strict baseline be kept indefinitely?** No; it is a temporary description-specific ratchet and must be retired owner-by-owner.
- **Should Dialyzer move to PR CI?** No; current Nightly gating and PR ExUnit behavior coverage are a locked scope boundary.
