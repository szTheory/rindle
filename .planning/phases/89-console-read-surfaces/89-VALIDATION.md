---
phase: 89
slug: console-read-surfaces
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-12
updated: 2026-06-12
audited: 2026-06-12
---

# Phase 89 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution and retroactive Nyquist audit.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mix, Phoenix.LiveViewTest, ExCoveralls; Node brandbook checks for generated admin CSS |
| **Config file** | `test/test_helper.exs`; project config in `mix.exs`; CI lane in `.github/workflows/ci.yml` |
| **Quick run command** | `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/admin/assets_test.exs test/rindle/admin/queries_test.exs test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/live/variants_runtime_actions_test.exs test/rindle/admin/live_update_test.exs test/rindle/admin/optional_dependency_test.exs test/rindle/api_surface_boundary_test.exs` |
| **Full suite command** | `mix coveralls`; if local Postgres is saturated, rerun as `mix coveralls --max-cases 1` |
| **Optional-deps proof** | `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` |
| **Estimated runtime** | ~120 seconds focused; full-suite latency accepted only at phase gates |

---

## Sampling Rate

- **After every task commit:** Run the focused command for the touched admin router, query, LiveView, static-asset, or optional-dependency tests.
- **After every plan wave:** Run `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` plus all Phase 89 focused tests.
- **Before `$gsd-verify-work`:** `mix coveralls` must be green.
- **Max feedback latency:** 180 seconds for focused checks; full-suite latency is accepted only at wave and phase gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 89-01-T1 | 01 | 1 | ADMIN-01, ADMIN-06 | T-89-01..05 | Router tests define production-safe host auth, dev/test escape hatch limits, route expansion, static route, and public API boundary. | router/API | `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/api_surface_boundary_test.exs` | yes | green |
| 89-01-T2 | 01 | 1 | ADMIN-01, ADMIN-06 | T-89-01..05 | `Rindle.Admin.Router.rindle_admin/2` is guarded behind optional deps and rejects unsafe production mounts. | router/compile | `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/api_surface_boundary_test.exs`; `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` | yes | green |
| 89-02-T1 | 02 | 2 | ADMIN-02 | T-89-06, T-89-09, T-89-10 | Generated CSS, JS, logo, and favicon are package-owned, self-contained, and free of host UI toolchain dependencies. | asset/source | `node brandbook/src/admin-css-build.mjs`; `node brandbook/src/admin-contrast.mjs`; `cmp brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` | yes | green |
| 89-02-T2 | 02 | 2 | ADMIN-02 | T-89-07, T-89-08 | Static serving exposes only allowlisted admin assets and Hex package metadata includes all required files. | package/integration | `MIX_ENV=test mix test test/rindle/admin/assets_test.exs test/install_smoke/package_metadata_test.exs test/brandbook/admin_design_system_validation_test.exs` | yes | green |
| 89-03-T1 | 03 | 2 | ADMIN-03, ADMIN-05 | T-89-11..15 | Query tests cover read models, filter allowlists, redaction, action metadata, and facade isolation. | query/API | `MIX_ENV=test mix test test/rindle/admin/queries_test.exs test/rindle/api_surface_boundary_test.exs` | yes | green |
| 89-03-T2 | 03 | 2 | ADMIN-03, ADMIN-05 | T-89-11..15 | `Rindle.Admin.Queries` reads through the configured repo/runtime APIs and returns redacted, read-only UI models. | query/runtime | `MIX_ENV=test mix test test/rindle/admin/queries_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/api_surface_boundary_test.exs` | yes | green |
| 89-04-T1 | 04 | 3 | ADMIN-03, ADMIN-05 | T-89-16..20 | Shell, Home/Status, Assets, and Upload Sessions tests assert stable selectors, filters, redaction, and payload-agnostic refresh. | LiveView | `MIX_ENV=test mix test test/rindle/admin/live/home_assets_upload_test.exs` | yes | green |
| 89-04-T2 | 04 | 3 | ADMIN-03, ADMIN-05 | T-89-16..20 | Shared components and first three LiveViews render query-backed read-only data through guarded Phoenix modules. | LiveView/compile | `MIX_ENV=test mix test test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/queries_test.exs`; `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` | yes | green |
| 89-05-T1 | 05 | 4 | ADMIN-03, ADMIN-05 | T-89-21..25 | Remaining-surface tests cover Variants/Jobs, Runtime/Doctor, read-only Actions, diagnostics, and no destructive controls. | LiveView | `MIX_ENV=test mix test test/rindle/admin/live/variants_runtime_actions_test.exs` | yes | green |
| 89-05-T2 | 05 | 4 | ADMIN-03, ADMIN-05 | T-89-21..25 | Variants/Jobs, Runtime/Doctor, and Actions render through `Rindle.Admin.Queries` without mutation handlers. | LiveView/compile | `MIX_ENV=test mix test test/rindle/admin/live/variants_runtime_actions_test.exs test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/queries_test.exs`; `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` | yes | green |
| 89-06-T1 | 06 | 5 | ADMIN-05 | T-89-26..29 | Upload-session broadcast and console invalidation tests assert existing topics, forged-payload rejection, and `session_uri` omission. | PubSub/LiveView | `MIX_ENV=test mix test test/rindle/upload/broker_test.exs test/rindle/upload/tus_plug_test.exs test/rindle/admin/live_update_test.exs` | yes | green |
| 89-06-T2 | 06 | 5 | ADMIN-05 | T-89-26..29 | Broker and TusPlug broadcast only redaction-safe lifecycle payloads on existing `Rindle.PubSub` topics. | PubSub/integration | `MIX_ENV=test mix test test/rindle/upload/broker_test.exs test/rindle/upload/tus_plug_test.exs test/rindle/admin/live_update_test.exs test/rindle/workers/process_variant_test.exs test/rindle/workers/ingest_provider_webhook_test.exs` | yes | green |
| 89-07-T1 | 07 | 6 | ADMIN-06 | T-89-30, T-89-31, T-89-33 | With optional deps present, router, components, and all six LiveViews load; `phoenix_live_view` remains optional. | optional-deps | `MIX_ENV=test mix test test/rindle/admin/optional_dependency_test.exs`; `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` | yes | green |
| 89-07-T2 | 07 | 6 | ADMIN-06 | T-89-30..33 | CI contains a named ADMIN-06 no-optional-deps proof and branch-protection truth is updated. | CI/compile | `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors`; `bash scripts/setup_branch_protection.sh --print-expected` | yes | green |

*Status vocabulary: pending, green, red, flaky.*

---

## Requirement Coverage

| Requirement | Status | Automated Evidence |
|-------------|--------|--------------------|
| ADMIN-01 | COVERED | `test/rindle/admin/router_test.exs`, `test/rindle/api_surface_boundary_test.exs`, `lib/rindle/admin/router.ex` |
| ADMIN-02 | COVERED | `test/rindle/admin/assets_test.exs`, `test/install_smoke/package_metadata_test.exs`, `test/brandbook/admin_design_system_validation_test.exs`, packaged files under `priv/static/rindle_admin` |
| ADMIN-03 | COVERED | `test/rindle/admin/queries_test.exs`, `test/rindle/admin/live/home_assets_upload_test.exs`, `test/rindle/admin/live/variants_runtime_actions_test.exs`, all six `lib/rindle/admin/live/*.ex` surfaces |
| ADMIN-05 | COVERED | `test/rindle/admin/queries_test.exs`, `test/rindle/admin/live_update_test.exs`, `test/rindle/upload/broker_test.exs`, `test/rindle/upload/tus_plug_test.exs`, API boundary tests |
| ADMIN-06 | COVERED | `test/rindle/admin/optional_dependency_test.exs`, `.github/workflows/ci.yml`, `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` |

No Phase 89 requirement is missing automated verification.

---

## Wave 0 Requirements

Existing infrastructure covers all Phase 89 requirements. The original Wave 0 placeholders were resolved by Plans 01 through 07:

- [x] `test/rindle/admin/router_test.exs` covers ADMIN-01 safe mount, production auth refusal, route expansion, and static route behavior.
- [x] `test/rindle/admin/assets_test.exs`, `test/install_smoke/package_metadata_test.exs`, and `test/brandbook/admin_design_system_validation_test.exs` cover ADMIN-02 serving/package inclusion.
- [x] `test/rindle/admin/queries_test.exs` covers ADMIN-03 and ADMIN-05 read models, redaction, filter validation, and facade isolation.
- [x] `test/rindle/admin/live/home_assets_upload_test.exs`, `test/rindle/admin/live/variants_runtime_actions_test.exs`, and `test/rindle/admin/live_update_test.exs` cover six read surfaces, detail flows, stable selectors, read-only actions, and PubSub invalidation.
- [x] `test/rindle/admin/optional_dependency_test.exs`, local no-optional compile, and `.github/workflows/ci.yml` cover ADMIN-06.

---

## Manual-Only Verifications

All Phase 89 requirements have automated verification. Host demo click-around and screenshot-driven visual polish remain explicitly deferred to Phase 91/92 and are not Phase 89 blockers.

---

## Validation Audit 2026-06-12

| Metric | Count |
|--------|-------|
| Requirements audited | 5 |
| Task rows mapped | 14 |
| Gaps found | 0 |
| Resolved by new tests in this audit | 0 |
| Escalated/manual-only gaps | 0 |

Audit notes:

- State detected: A - existing `89-VALIDATION.md` was present.
- The existing file was a draft scaffold with Wave 0 placeholders; plans and summaries showed concrete automated coverage for all requirements.
- No new test files were generated because the completed phase already contained the required focused tests and CI proof.
- `89-VERIFICATION.md`, `89-REVIEW.md`, and `89-SECURITY.md` all report Phase 89 clean/verified with no open gaps or threats.

---

## Verification Evidence

| Check | Evidence |
|-------|----------|
| Focused Phase 89 behavior | Current audit run: `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/admin/assets_test.exs test/rindle/admin/queries_test.exs test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/live/variants_runtime_actions_test.exs test/rindle/admin/live_update_test.exs test/rindle/admin/optional_dependency_test.exs test/rindle/api_surface_boundary_test.exs` passed with 57 tests, 0 failures. |
| Optional dependency proof | Current audit run: `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` passed. |
| Security coverage | `89-SECURITY.md` records focused admin/API tests, upload PubSub tests, package metadata tests, destructive-control scans, broadcast-secret scans, branch-protection check output, and no-optional compile passing. |
| Code review | `89-REVIEW.md` records 34 reviewed files and 0 findings. |
| Full suite | Current audit run: `mix coveralls` hit local Postgres `too_many_connections`; serialized rerun `mix coveralls --max-cases 1` passed with 3 doctests and 1140 tests, 0 failures, 4 skipped, 56 excluded. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or resolved Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency target documented for focused and full-suite checks.
- [x] `nyquist_compliant: true` set in frontmatter after plans map concrete task IDs and Wave 0 coverage is complete.

**Approval:** approved 2026-06-12
