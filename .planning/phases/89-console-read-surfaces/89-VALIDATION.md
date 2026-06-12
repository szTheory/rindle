---
phase: 89
slug: console-read-surfaces
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-12
---

# Phase 89 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mix; coverage via ExCoveralls |
| **Config file** | `test/test_helper.exs`; project config in `mix.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/rindle/admin/queries_test.exs test/rindle/admin/router_test.exs` |
| **Full suite command** | `mix coveralls` |
| **Estimated runtime** | ~120 seconds focused, longer for full suite |

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
| 89-W0-01 | TBD | 0 | ADMIN-01 | T-89-auth | Host auth pipeline and `on_mount` are required for production-safe mounts; dev/test escape hatch cannot bypass production auth. | unit/integration | `MIX_ENV=test mix test test/rindle/admin/router_test.exs` | missing W0 | pending |
| 89-W0-02 | TBD | 0 | ADMIN-02 | T-89-assets | Static assets are served from `priv/static/rindle_admin` by `:rindle` and included in Hex package files. | unit/package | `MIX_ENV=test mix test test/install_smoke/package_metadata_test.exs test/rindle/admin/assets_test.exs` | partial W0 | pending |
| 89-W0-03 | TBD | 0 | ADMIN-03 | T-89-redaction | Six read surfaces render from `Rindle.Admin.Queries` without exposing raw upload session URIs or provider IDs. | query/LiveView | `MIX_ENV=test mix test test/rindle/admin/queries_test.exs test/rindle/admin/live` | missing W0 | pending |
| 89-W0-04 | TBD | 0 | ADMIN-05 | T-89-pubsub | LiveViews treat PubSub events as invalidation and refresh through `Rindle.Admin.Queries`; no admin reads are added to `lib/rindle.ex`. | unit/LiveView/boundary | `MIX_ENV=test mix test test/rindle/admin/live_update_test.exs test/rindle/api_surface_boundary_test.exs` | partial W0 | pending |
| 89-W0-05 | TBD | 0 | ADMIN-06 | T-89-optional-deps | No default install requires Phoenix LiveView; admin modules compile away when optional deps are absent. | compile/package | `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` | command exists | pending |

*Status: pending, green, red, flaky.*

---

## Wave 0 Requirements

- [ ] `test/rindle/admin/router_test.exs` - covers ADMIN-01 safe mount and option behavior.
- [ ] `test/rindle/admin/queries_test.exs` - covers ADMIN-03 and ADMIN-05 query read models and redaction.
- [ ] `test/rindle/admin/live/*_test.exs` - covers the six read surfaces and PubSub refresh behavior.
- [ ] `test/rindle/admin/assets_test.exs` or a package metadata extension - covers ADMIN-02 static file serving and package inclusion.
- [ ] CI or test wrapper for `mix compile --no-optional-deps --warnings-as-errors` - covers ADMIN-06.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Host visual inspection of the mounted console in a demo app | ADMIN-01, ADMIN-03 | Phase 89 is not the deterministic full-console E2E phase; visual click-around is deferred to Phase 91/92 unless a narrow mount proof is needed. | Mount through the example router only if the plan needs a host integration smoke check; verify routes load and no destructive actions execute. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency target documented for focused and full-suite checks.
- [ ] `nyquist_compliant: true` set in frontmatter after plans map concrete task IDs and Wave 0 coverage is complete.

**Approval:** pending
