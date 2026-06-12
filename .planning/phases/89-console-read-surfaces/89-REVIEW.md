---
phase: 89-console-read-surfaces
reviewed: 2026-06-12T16:12:03Z
depth: standard
files_reviewed: 33
files_reviewed_list:
  - .github/workflows/ci.yml
  - RUNNING.md
  - lib/rindle/admin/components.ex
  - lib/rindle/admin/live/actions_live.ex
  - lib/rindle/admin/live/assets_live.ex
  - lib/rindle/admin/live/home_live.ex
  - lib/rindle/admin/live/runtime_doctor_live.ex
  - lib/rindle/admin/live/upload_sessions_live.ex
  - lib/rindle/admin/live/variants_jobs_live.ex
  - lib/rindle/admin/queries.ex
  - lib/rindle/admin/router.ex
  - lib/rindle/upload/broker.ex
  - lib/rindle/upload/tus_plug.ex
  - mix.exs
  - mix.lock
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
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 89: Code Review Report

**Reviewed:** 2026-06-12T16:12:03Z
**Depth:** standard
**Files Reviewed:** 33
**Status:** issues_found

## Summary

Reviewed the admin console read surfaces, optional dependency guards, admin queries, PubSub payloads, CI/package metadata changes, and upload broadcast changes. The implementation keeps sensitive upload session URIs out of query rows and PubSub payloads, but the mounted console is not actually mount-path safe, and LiveView invalidation is wired to a different PubSub contract than the upload broadcasters. Query cursor handling also does not match the declared sort order.

## Critical Issues

### CR-01: Admin LiveView links ignore the mount path

**File:** `lib/rindle/admin/components.ex:7`
**Issue:** `rindle_admin/2` is advertised and tested as mountable at arbitrary paths, and `Rindle.Admin.Router` accepts `home_path`, `live_socket_path`, `transport`, and route prefixes. The rendered shell and page links are still hard-coded to `/admin/rindle` in `@surfaces` and page templates. A host mounting `rindle_admin("/media")` under `/ops` gets correct routes from the macro, but every nav item and cross-page action sends users back to `/admin/rindle/...`, which may 404 or escape the host's authenticated admin scope.
**Fix:**
Read the mount data from the LiveView session in each `mount/3`, assign a base path, and build all admin links from that base path instead of hard-coded strings.

```elixir
# Router session should include the mounted path/prefix needed by the UI.
session = %{
  "rindle_admin" => %{
    "base_path" => path,
    "home_path" => config.home_path,
    "live_socket_path" => config.live_socket_path,
    "transport" => config.transport,
    "csp_nonce_assign_key" => config.csp_nonce_assign_key
  }
}

# In LiveViews:
def mount(_params, %{"rindle_admin" => %{"base_path" => base_path}}, socket) do
  {:ok, assign(socket, :admin_base_path, base_path)}
end

# In components/templates:
href={Path.join(@admin_base_path, "assets")}
href={Path.join(@admin_base_path, "assets/#{asset.id}")}
```

Also update `Components.shell/1` to accept a `:base_path` assign and derive its surface links from that value.

Affected hard-coded links include `lib/rindle/admin/components.ex:8-13`, `lib/rindle/admin/live/assets_live.ex:124`, `lib/rindle/admin/live/upload_sessions_live.ex:85`, `lib/rindle/admin/live/variants_jobs_live.ex:45`, and `lib/rindle/admin/live/runtime_doctor_live.ex:35`.

### CR-02: LiveViews subscribe to a hard-coded PubSub server and miss configured broadcasts

**File:** `lib/rindle/admin/live/assets_live.ex:188`
**Issue:** Upload broadcasters use `Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)` in both `Broker` and `TusPlug`, but admin LiveViews subscribe directly to `Rindle.PubSub`. Any adopter configuring `:pubsub_server` will broadcast lifecycle invalidations on one server while the admin console listens on another, so detail/list screens stop updating even though events are emitted. Home and Runtime/Doctor also define `handle_info/2` refreshes but do not subscribe to any lifecycle topic, so their "Waiting for lifecycle events" indicator cannot change from current broker/tus broadcasts.
**Fix:**
Centralize the PubSub server lookup for admin LiveViews and subscribe through the same configured server the broadcasters use. Add an admin-wide topic if Home/Status and Runtime/Doctor are expected to refresh from lifecycle events.

```elixir
defp pubsub_server do
  Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
end

defp subscribe(topic), do: PubSub.subscribe(pubsub_server(), topic)
```

For broad surfaces, have the upload broadcasters also publish a non-secret invalidation event:

```elixir
topics =
  ["rindle:admin:lifecycle", "rindle:upload_session:#{session.id}"]
  |> maybe_append_asset_topic(session.asset_id)
```

Then subscribe Home/Status and Runtime/Doctor to `"rindle:admin:lifecycle"` when `connected?(socket)`.

Affected hard-coded subscriptions are `lib/rindle/admin/live/assets_live.ex:188`, `lib/rindle/admin/live/upload_sessions_live.ex:159-160`, and `lib/rindle/admin/live/variants_jobs_live.ex:165`; the matching configurable broadcasters are `lib/rindle/upload/broker.ex:997-999` and `lib/rindle/upload/tus_plug.ex:1013-1015`.

## Warnings

### WR-01: Cursor filters do not match the query ordering

**File:** `lib/rindle/admin/queries.ex:57`
**Issue:** Asset and upload-session list queries order rows by `inserted_at DESC, id DESC`, but cursor filtering only applies `id < cursor`. UUID ordering is not correlated with `inserted_at`, so using `cursor` can skip rows or repeat rows whenever creation time and UUID lexical order differ. The cursor contract is exposed by `normalize_filters/2`, so callers can request incorrect pages even though the first page looks correct.
**Fix:** Use a composite cursor that includes both `inserted_at` and `id`, or simplify the ordering to match the cursor. For the existing sort order, filter on the tuple shape:

```elixir
defp maybe_cursor(query, nil), do: query

defp maybe_cursor(query, %{inserted_at: inserted_at, id: id}) do
  from a in query,
    where: a.inserted_at < ^inserted_at or (a.inserted_at == ^inserted_at and a.id < ^id)
end
```

Apply the same shape to upload sessions at `lib/rindle/admin/queries.ex:104-111` and `lib/rindle/admin/queries.ex:295-296`, and either encode/decode cursor tokens at the LiveView/query boundary or remove the cursor filter until a stable cursor format exists.

---

_Reviewed: 2026-06-12T16:12:03Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
