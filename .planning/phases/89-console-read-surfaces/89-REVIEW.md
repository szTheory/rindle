---
phase: 89-console-read-surfaces
reviewed: 2026-06-12T16:23:33Z
depth: standard
files_reviewed: 34
files_reviewed_list:
  - .github/workflows/ci.yml
  - RUNNING.md
  - lib/rindle/admin/components.ex
  - lib/rindle/admin/live/actions_live.ex
  - lib/rindle/admin/live/assets_live.ex
  - lib/rindle/admin/live/home_live.ex
  - lib/rindle/admin/live/runtime_doctor_live.ex
  - lib/rindle/admin/live/support.ex
  - lib/rindle/admin/live/upload_sessions_live.ex
  - lib/rindle/admin/live/variants_jobs_live.ex
  - lib/rindle/admin/queries.ex
  - lib/rindle/admin/router.ex
  - lib/rindle/upload/broker.ex
  - lib/rindle/upload/tus_plug.ex
  - mix.exs
  - priv/static/rindle_admin/favicon.svg
  - priv/static/rindle_admin/logo.svg
  - priv/static/rindle_admin/rindle-admin.css
  - priv/static/rindle_admin/rindle-admin.js
  - scripts/setup_branch_protection.sh
  - test/brandbook/admin_design_system_validation_test.exs
  - test/install_smoke/package_metadata_test.exs
  - test/rindle/admin/assets_test.exs
  - test/rindle/admin/live/home_assets_upload_test.exs
  - test/rindle/admin/live/variants_runtime_actions_test.exs
  - test/rindle/admin/live_update_test.exs
  - test/rindle/admin/optional_dependency_test.exs
  - test/rindle/admin/queries_test.exs
  - test/rindle/admin/router_test.exs
  - test/rindle/api_surface_boundary_test.exs
  - test/rindle/upload/broker_test.exs
  - test/rindle/upload/tus_plug_test.exs
  - test/support/rindle_admin_live_stub_support.ex
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 89: Code Review Report

**Reviewed:** 2026-06-12T16:23:33Z
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

Re-reviewed Phase 89 after `b1b98c0`. The three prior concerns are resolved: admin shell/page links now derive from the router session `base_path`, LiveViews subscribe through the configured `:pubsub_server` with a broad `"rindle:admin:lifecycle"` invalidation topic, and asset/upload-session cursor predicates now match `inserted_at DESC, id DESC` ordering.

Two remaining defects are still present in the reviewed code. Runtime/Doctor is wired to a synthetic test-like Oban config instead of the adopter runtime, and empty result pages render the generic error state even when no query failed.

## Critical Issues

### CR-01: Runtime/Doctor ignores the adopter's configured profiles and Oban runtime

**File:** `lib/rindle/admin/live/runtime_doctor_live.ex:112`
**Issue:** Runtime/Doctor passes `profiles: []` and `oban_config: [repo: Rindle.Repo, queues: []]` into `Queries.runtime_doctor/1`. Home/Status does the same at `lib/rindle/admin/live/home_live.ex:67`. `RuntimeChecks.run/2` already defaults to `Config.profile_modules()` and `Application.get_env(mix_app, Oban)`, and `check_oban_default_instance/1` compares the configured Oban repo with `Config.repo()`. In a host app that configures `config :rindle, :repo, MyApp.Repo`, this LiveView reports against `Rindle.Repo` and an empty queue list instead of the adopter's actual runtime. It also suppresses profile-specific checks by forcing an empty profile list. The admin console can therefore show false Runtime/Doctor failures or hide missing profile requirements.
**Fix:**
Let the query layer use its runtime defaults, or pass the adopter-derived values explicitly. Keep only the test probe override in tests, not production LiveView code.

```elixir
case Queries.runtime_doctor(
       runtime_opts: [limit: 25, provider_stuck: true],
       doctor_opts: []
     ) do
  {:ok, model} -> assign(socket, model: model, error?: false)
  {:error, reason} -> assign(socket, model: empty_model(), error?: true, error_reason: reason)
end
```

Apply the same correction in `HomeLive.refresh/1` so Home/Status and Runtime/Doctor reflect the same configured runtime.

## Warnings

### WR-01: Empty list states also render the generic error state

**File:** `lib/rindle/admin/live/assets_live.ex:106`
**Issue:** When the assets query succeeds with zero rows, the template renders both `<.empty_state />` and `<.error_state surface="Assets" />`. `VariantsJobsLive` has the same pattern at `lib/rindle/admin/live/variants_jobs_live.ex:71`. That tells users "Rindle Admin could not load this surface" even though the surface loaded successfully and no query error occurred. This is not just copy drift: it makes a normal filtered-empty result indistinguishable from a real load failure.
**Fix:** Render the error state only when `@error?` is true, and render only the empty state for successful empty results.

```heex
<%= if @error? do %>
  <.error_state surface="Assets" />
<% else %>
  <%= if Enum.empty?(@model.rows) do %>
    <.empty_state />
  <% else %>
    ...
  <% end %>
<% end %>
```

Update the existing empty-state tests so they assert absence of `data-rindle-admin-error-state` for successful empty queries, and add a separate forced-error test for the error affordance.

---

_Reviewed: 2026-06-12T16:23:33Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
