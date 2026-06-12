# Phase 89: Console Read Surfaces - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-12T02:03:35Z
**Phase:** 89-console-read-surfaces
**Mode:** assumptions
**Areas analyzed:** Mount And Auth Boundary, Optional LiveView Boundary, Assets And Package Serving, Read Surfaces And Query Boundary, Live Updates, Cohort Boundary

## Assumptions Presented

### Mount And Auth Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Implement `Rindle.Admin.Router.rindle_admin/2` as the only new public console surface, mounted inside a host-authenticated scope with host-supplied `:on_mount`; refuse unsafe unauthenticated production mounts by default. | Likely | `guides/admin_console_architecture.md`; `.planning/phases/86-research-architecture-lock/86-CONTEXT.md`; `mix.exs`; `lib/rindle/live_view.ex` |

### Optional LiveView Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Guard every Phoenix/LiveView-specific admin module with the existing `Code.ensure_loaded?/1` pattern and add a no-LiveView compile/package proof for ADMIN-06. | Confident | `mix.exs`; `lib/rindle/live_view.ex`; `.planning/REQUIREMENTS.md`; `guides/admin_console_architecture.md` |

### Assets And Package Serving

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Move/copy the generated Phase 88 admin assets into `priv/static/rindle_admin`, serve them from the `:rindle` app with `Plug.Static`, and add a package-file assertion so Hex includes them. | Confident | `guides/admin_design_system.md`; `mix.exs`; `brandbook/src/admin-css-build.mjs`; `brandbook/tokens/rindle-admin.css` |

### Read Surfaces And Query Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Build the six read surfaces from `Rindle.Admin.Queries`, composing existing domain schemas plus `Rindle.Ops.RuntimeStatus` / `Rindle.Ops.RuntimeChecks`; do not add admin convenience reads to `lib/rindle.ex`. | Confident | `guides/admin_console_ia.md`; `guides/admin_console_architecture.md`; `lib/rindle/domain/media_asset.ex`; `lib/rindle/domain/media_variant.ex`; `lib/rindle/domain/media_upload_session.ex`; `lib/rindle/ops/runtime_status.ex`; `lib/rindle/ops/runtime_checks.ex` |

### Live Updates

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Reuse `Rindle.PubSub` and the existing topic grammar for `:asset`, `:variant`, and `:upload_session`; add or normalize missing upload-session broadcasts where lifecycle changes occur rather than inventing a second realtime channel. | Likely | `lib/rindle/application.ex`; `lib/rindle/live_view.ex`; `lib/rindle/workers/process_variant.ex`; `lib/rindle/workers/ingest_provider_webhook.ex`; source search found upload-session topics but no upload-session broadcaster |

### Cohort Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Use Phase 89 tests/minimal host support to prove the mount contract, but leave Cohort rebrand, expanded seeds, walkthrough, and full demo mounting to Phase 91 unless a small hook is strictly necessary. | Likely | `.planning/REQUIREMENTS.md`; `.planning/ROADMAP.md`; `examples/adoption_demo/lib/adoption_demo_web/router.ex` |

## Corrections Made

No corrections - all assumptions confirmed.

## External Research

No new external research was performed. Phase 86 already captured LiveDashboard,
Oban Web, Phoenix LiveView router, Plug.Static, and CSP prior art; Phase 89
assumptions were resolved from local repo truth and prior planning artifacts.
