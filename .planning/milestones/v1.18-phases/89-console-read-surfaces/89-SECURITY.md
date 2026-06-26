---
phase: 89
slug: console-read-surfaces
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-12
updated: 2026-06-12
register_authored_at_plan_time: true
security_enforcement: true
---

# Phase 89 - Security

Per-phase security contract for `89-console-read-surfaces`: threat register,
accepted risks, mitigation evidence, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| host router -> Rindle macro | Host-owned Phoenix scope invokes `Rindle.Admin.Router.rindle_admin/2`. | Host auth acknowledgement, route path, LiveView session config |
| host auth -> LiveView on_mount | Host app owns auth pipeline and LiveView `:on_mount`; Rindle only propagates explicit hooks. | Auth boundary acknowledgement and hook modules |
| host request -> static assets | Host routes serve library-owned admin static files. | Asset file names and content types |
| browser params -> LiveView | Route params and filter params enter admin LiveViews. | Asset IDs, upload-session IDs, filter strings |
| LiveView -> admin queries | LiveViews request read models from `Rindle.Admin.Queries`. | Normalized filters and IDs |
| admin queries -> database | Query module reads domain schemas through adopter-configured repo. | Asset, upload-session, variant, provider, runtime rows |
| domain rows -> browser | Sensitive internals must be redacted before render. | Session URI and provider identifiers |
| PubSub -> LiveView | Lifecycle events invalidate visible rows. | Event atom plus allowlisted payload |
| upload session row -> PubSub payload | Upload lifecycle writers broadcast redaction-safe events. | Session ID, asset ID, state, strategy, protocol, offset |
| optional deps -> default install | Console modules must compile away when Phoenix/LiveView deps are absent. | Optional dependency graph and compile-time guards |
| CI matrix -> release confidence | ADMIN-06 no-optional-deps proof is visible in CI and branch protection. | Required check names and workflow gates |

## Summary Threat Flags Review

| Artifact | Threat Flags |
|----------|--------------|
| `89-01-SUMMARY.md` | No explicit `## Threat Flags` section; router issues were auto-fixed and covered by router/auth/static/optional-deps tests. |
| `89-02-SUMMARY.md` | None; static asset serving, package metadata, and admin DOM mutation surfaces were covered by the plan threat model. |
| `89-03-SUMMARY.md` | None. |
| `89-04-SUMMARY.md` | None; browser params, query rendering, and PubSub invalidation were covered by the plan threat model. |
| `89-05-SUMMARY.md` | None; diagnostics, PubSub invalidation, redaction, and read-only action surfaces were covered by the plan threat model. |
| `89-06-SUMMARY.md` | None; PubSub emission was covered by payload redaction, forged-payload invalidation, existing topic grammar, and persisted-transition broadcasts. |
| `89-07-SUMMARY.md` | No explicit `## Threat Flags` section; optional-deps issues were auto-fixed and covered by ADMIN-06 tests/CI evidence. |

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Evidence | Status |
|-----------|----------|-----------|-------------|---------------------|--------|
| T-89-01 | Elevation of Privilege | `Rindle.Admin.Router.rindle_admin/2` | mitigate | Production mounts reject `allow_unauthenticated?: true` and require non-empty `:on_mount` or `auth_guarded?: true` in `lib/rindle/admin/router.ex`; covered by `test/rindle/admin/router_test.exs`. | closed |
| T-89-02 | Spoofing | Host auth acknowledgement | mitigate | Router moduledoc and mount config keep auth ownership in the host; tests assert host `on_mount` and `auth_guarded?: true` acknowledgement paths. | closed |
| T-89-03 | Tampering | Static asset route | mitigate | Static assets are exact allowlisted files in `StaticAssetsPlug`; traversal, `tokens.json`, and unlisted asset names are denied by `test/rindle/admin/assets_test.exs`. | closed |
| T-89-04 | Information Disclosure | CSP/socket options | mitigate | Router stores host-provided `home_path`, socket, transport, and `csp_nonce_assign_key` in session config without generating Rindle-owned nonce/session data; covered by router tests. | closed |
| T-89-05 | Denial of Service | Optional LiveView dependency | mitigate | Admin router, components, and LiveViews are guarded by `Code.ensure_loaded?/1`; `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` passed. | closed |
| T-89-06 | Tampering | `priv/static/rindle_admin/rindle-admin.css` | mitigate | `cmp brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` passed. | closed |
| T-89-07 | Information Disclosure | Static asset route | mitigate | `test/rindle/admin/assets_test.exs` proves only four packaged files are served and traversal/unlisted paths return 404. | closed |
| T-89-08 | Tampering | Hex package metadata | mitigate | `test/install_smoke/package_metadata_test.exs` passed and asserts all four admin static assets ship in package metadata. | closed |
| T-89-09 | Spoofing | Theme JavaScript | mitigate | `priv/static/rindle_admin/rindle-admin.js` normalizes themes to `light`, `dark`, or `auto`, scopes binding to `[data-rindle-admin-root]`, and updates `aria-pressed`. | closed |
| T-89-10 | Denial of Service | Host asset pipeline | mitigate | Assets are served from `priv/static/rindle_admin`; package/static tests passed with no host Tailwind/esbuild dependency. | closed |
| T-89-11 | Information Disclosure | `Rindle.Admin.Queries.upload_sessions/1` | mitigate | Query rows replace raw `session_uri` with `Redacted by Rindle Admin`; tests assert raw URI absence and reject `session_uri` filters. | closed |
| T-89-12 | Information Disclosure | Provider asset summaries | mitigate | Provider asset rows replace raw provider IDs with `Provider identifier redacted`; tests assert raw provider IDs are absent. | closed |
| T-89-13 | Tampering | Query filters | mitigate | `Rindle.Admin.Queries` normalizes allowlisted filters and rejects unknown filter keys with tagged errors; tests cover unknown keys. | closed |
| T-89-14 | Elevation of Privilege | Public facade | mitigate | `test/rindle/api_surface_boundary_test.exs` keeps admin read helpers off the public `Rindle` facade and keeps `Rindle.Admin.Queries` hidden. | closed |
| T-89-15 | Repudiation | Actions directory | mitigate | `actions_directory/0` returns read-only Phase 90 metadata with `enabled?: false`, `read_only?: true`, and no callback/MFA fields; tests assert no executable callbacks. | closed |
| T-89-16 | Tampering | PubSub payload handling | mitigate | LiveViews handle `{:rindle_event, _event_type, _payload}` as invalidation only and re-query authoritative data; forged-payload tests passed. | closed |
| T-89-17 | Information Disclosure | Upload-session detail | mitigate | Upload-session LiveView renders redacted query output; list/detail tests assert raw session URI absence. | closed |
| T-89-18 | Spoofing | Active navigation/theme state | mitigate | Components render exact six-surface nav allowlist, `aria-current="page"`, and `data-theme` controls; LiveView tests assert shell/nav/theme state. | closed |
| T-89-19 | Denial of Service | LiveView subscriptions | mitigate | Detail/list LiveViews subscribe to visible `rindle:asset`, `rindle:variant`, `rindle:upload_session`, and admin lifecycle topics only; no wildcard or second channel is present. | closed |
| T-89-20 | Elevation of Privilege | Read surfaces | mitigate | First read surfaces link to inspection routes and render query models only; destructive source scan over `lib/rindle/admin` found no submit forms, mutation events, or repair/erase calls. | closed |
| T-89-21 | Elevation of Privilege | `ActionsLive` | mitigate | Actions surface renders read-only operation rows and the destructive-control source scan found no submit form, mutation event, or ops facade call. | closed |
| T-89-22 | Information Disclosure | `VariantsJobsLive` provider/job context | mitigate | Query/UI redaction uses `Provider identifier redacted`; tests assert raw provider IDs are not rendered before or after forged PubSub events. | closed |
| T-89-23 | Tampering | PubSub refresh | mitigate | Variants/Jobs treats PubSub events as invalidation and reloads through `Rindle.Admin.Queries.variants_jobs/1`; forged provider ID tests passed. | closed |
| T-89-24 | Repudiation | Runtime diagnostics | mitigate | Runtime/Doctor renders generated/runtime/doctor status and links to investigation surfaces; tests assert diagnostic rows and no action execution. | closed |
| T-89-25 | Denial of Service | LiveView optional deps | mitigate | All admin LiveViews are guarded by `Code.ensure_loaded?(Phoenix.LiveView)`; optional dependency test and no-optional compile passed. | closed |
| T-89-26 | Information Disclosure | Upload-session PubSub payload | mitigate | Broker and TusPlug broadcast payloads contain only session ID, asset ID, state, upload strategy, resumable protocol, and optional offset; upload tests refute `session_uri`, provider ID, authorization, and token fields. | closed |
| T-89-27 | Tampering | Forged PubSub payloads | mitigate | Console LiveView tests broadcast forged state, raw session URI, and provider IDs; rendered output reloads authoritative data and omits forged secrets. | closed |
| T-89-28 | Denial of Service | Over-broad subscriptions/channels | mitigate | Upload lifecycle code reuses `Rindle.PubSub` and existing `rindle:admin:lifecycle`, `rindle:upload_session:<id>`, and `rindle:asset:<id>` topics; no console-specific channel exists. | closed |
| T-89-29 | Repudiation | Lifecycle notifications | mitigate | Broadcast calls occur after successful signed/uploading/completed/cancelled transitions in broker/TusPlug paths; upload lifecycle tests passed. | closed |
| T-89-30 | Denial of Service | Default/non-console compile | mitigate | Local `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` passed. | closed |
| T-89-31 | Tampering | `mix.exs` dependency posture | mitigate | `test/rindle/admin/optional_dependency_test.exs` asserts `phoenix_live_view` remains `optional: true` and no new runtime UI framework dependency is added. | closed |
| T-89-32 | Repudiation | CI evidence | mitigate | `.github/workflows/ci.yml` contains the named `ADMIN-06 Optional Dependencies` matrix; `scripts/setup_branch_protection.sh --print-expected` lists both required ADMIN-06 checks. | closed |
| T-89-33 | Elevation of Privilege | Guarded module leakage | mitigate | Guarded modules compile away under no-optional-deps; with-deps smoke tests assert router, components, and six LiveViews load when deps are present. | closed |
| T-89-SC | Tampering | npm/pip/cargo installs | accept | Plan-time accepted risk repeated across plans: no npm, pip, or cargo install task was in scope; verification used existing Mix deps and repo assets only. | closed |

Status vocabulary: `closed` means mitigation evidence was found or the accepted risk is documented here. `open` would block phase advancement.

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-89-01 | T-89-SC | No package-manager install task was planned or executed in Phase 89; static assets came from existing repository files and Mix dependencies. | Plan-time threat register, verified by GSD secure-phase audit | 2026-06-12 |

Accepted risks do not resurface in future audit runs unless the phase scope changes.

## Security Audit 2026-06-12

| Metric | Count |
|--------|-------|
| Threats found | 34 |
| Closed | 34 |
| Open | 0 |

## Verification Evidence

| Check | Result |
|-------|--------|
| `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/admin/assets_test.exs test/rindle/admin/queries_test.exs test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/live/variants_runtime_actions_test.exs test/rindle/admin/live_update_test.exs test/rindle/admin/optional_dependency_test.exs test/rindle/api_surface_boundary_test.exs` | Passed, 57 tests, 0 failures. |
| `MIX_ENV=test mix test test/rindle/upload/broker_test.exs test/rindle/upload/tus_plug_test.exs test/rindle/workers/process_variant_test.exs test/rindle/workers/ingest_provider_webhook_test.exs` | Passed, 95 tests, 0 failures, 3 skipped. |
| `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs` | Passed, 15 tests, 0 failures. |
| `cmp brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` | Passed. |
| Destructive-control scan over `lib/rindle/admin` | Passed; no submit forms, mutation events, erase/repair/regenerate ops calls, or lifecycle repair modules found. |
| Broadcast-secret scan over `lib/rindle/upload/broker.ex` and `lib/rindle/upload/tus_plug.ex` | Passed; no forbidden secret fields appear in broadcast payload construction. |
| `bash scripts/setup_branch_protection.sh --print-expected` | Passed; output includes both `ADMIN-06 Optional Dependencies` matrix checks. |
| `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` | Passed. |
| `MIX_ENV=test mix deps.get` | Restored normal test dependency state; dependencies unchanged. |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-12 | 34 | 34 | 0 | Codex via `$gsd-secure-phase 89` |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

Approval: verified 2026-06-12
