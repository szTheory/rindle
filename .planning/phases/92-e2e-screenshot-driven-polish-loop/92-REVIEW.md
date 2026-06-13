---
phase: 92-e2e-screenshot-driven-polish-loop
reviewed: 2026-06-13T03:29:05Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - .github/workflows/ci.yml
  - brandbook/src/admin-css-build.mjs
  - brandbook/tokens/rindle-admin.css
  - examples/adoption_demo/README.md
  - examples/adoption_demo/docs/adoption-proof-matrix.md
  - examples/adoption_demo/e2e/admin-actions.spec.js
  - examples/adoption_demo/e2e/admin-console.spec.js
  - examples/adoption_demo/e2e/admin-screenshots.spec.js
  - examples/adoption_demo/e2e/admin-theme.spec.js
  - examples/adoption_demo/e2e/support/admin.js
  - examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex
  - examples/adoption_demo/lib/adoption_demo_web/router.ex
  - lib/mix/tasks/rindle.runtime_status.ex
  - lib/rindle/admin/components.ex
  - lib/rindle/admin/live/actions_live.ex
  - lib/rindle/admin/live/assets_live.ex
  - lib/rindle/admin/live/upload_sessions_live.ex
  - lib/rindle/admin/queries.ex
  - mix.exs
  - priv/static/rindle_admin/rindle-admin.css
  - scripts/maintainer/check_adoption_proof_matrix.sh
  - test/rindle/admin/live/actions_live_test.exs
  - test/rindle/admin/live/home_assets_upload_test.exs
findings:
  critical: 1
  warning: 4
  info: 0
  total: 5
status: issues_found
---

# Phase 92: Code Review Report

**Reviewed:** 2026-06-13T03:29:05Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

Reviewed the Phase 92 admin console E2E, screenshot polish, proof-matrix, CSS, CI, and LiveView changes at standard depth. The primary issue is in the admin Actions LiveView: user-controlled owner type strings are converted into atoms on preview/execute paths, which violates the nested Phoenix app guidance and creates an atom-table exhaustion risk. Several robustness and proof-honesty gaps also remain around malformed admin action inputs, tampered LiveView event values, drift-gate false positives, and stale local admin documentation.

## Critical Issues

### CR-01: BLOCKER - Admin Owner Inputs Can Create Unbounded Atoms

**File:** `lib/rindle/admin/live/actions_live.ex:68`

**Issue:** `preview_owner_erasure/3`, `execute_owner_erasure/3`, and `parse_batch_owners/1` build owner structs with `String.to_atom(type)` from browser-controlled form fields. The adoption-demo Phoenix guide explicitly forbids `String.to_atom/1` on user input because atoms are not garbage-collected. The admin console is mounted in the demo with `allow_unauthenticated?: true`, so repeated requests with unique owner type strings can exhaust the BEAM atom table and crash the VM. This also allows arbitrary loaded module atoms to be used as owner struct names.

**Fix:**

```elixir
@allowed_owner_types %{
  "AdoptionDemo.Accounts.Member" => AdoptionDemo.Accounts.Member
}

defp parse_owner(type, id) when is_binary(type) and is_binary(id) do
  case Map.fetch(@allowed_owner_types, type) do
    {:ok, module} -> {:ok, %{__struct__: module, id: id}}
    :error -> {:error, :unsupported_owner_type}
  end
end

def handle_event("preview_owner_erasure", %{"owner_type" => type, "owner_id" => id}, socket) do
  with {:ok, owner} <- parse_owner(type, id),
       {:ok, report} <- Rindle.preview_owner_erasure(owner) do
    {:noreply, assign(socket, action_state: :preview, action_error: nil, action_data: %{type: type, id: id, report: report})}
  else
    _ -> {:noreply, assign(socket, action_error: "Unsupported owner type.")}
  end
end
```

Apply the same parser in `execute_owner_erasure/3` and batch parsing instead of calling `String.to_atom/1`.

## Warnings

### WR-01: WARNING - Malformed Batch Owner Input Crashes the LiveView

**File:** `lib/rindle/admin/live/actions_live.ex:299`

**Issue:** `parse_batch_owners/1` assumes every textarea line contains `type:id` and pattern matches `[type, id]`. A line without `:` raises `MatchError`; empty-but-whitespace input can produce a zero-owner confirmation flow; and malformed input reaches preview before any user-facing validation. This is browser-controlled input on a destructive-action surface, so invalid input should render a validation error instead of terminating the LiveView process.

**Fix:** Return `{:ok, owners}` or `{:error, message}` from parsing, validate that at least one owner is present, and show `action_error` on failure.

```elixir
defp parse_batch_owners(text) do
  text
  |> String.split("\n", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
  |> Enum.reduce_while({:ok, []}, fn line, {:ok, owners} ->
    case String.split(line, ":", parts: 2) do
      [type, id] when type != "" and id != "" ->
        case parse_owner(type, id) do
          {:ok, owner} -> {:cont, {:ok, [owner | owners]}}
          {:error, _} -> {:halt, {:error, "Unsupported owner type: #{type}"}}
        end

      _ ->
        {:halt, {:error, "Owners must be formatted as Module:id, one per line."}}
    end
  end)
  |> case do
    {:ok, []} -> {:error, "Enter at least one owner."}
    {:ok, owners} -> {:ok, Enum.reverse(owners)}
    error -> error
  end
end
```

### WR-02: WARNING - Tampered Action Events Can Crash the Actions LiveView

**File:** `lib/rindle/admin/live/actions_live.ex:31`

**Issue:** `select_action` calls `String.to_existing_atom(id_str)` without validating that the requested id is one of the configured actions. A tampered LiveView event with an unknown id raises `ArgumentError`. Similarly, `execute_lifecycle_repair` has a two-branch `case action do` with no fallback, so any value other than `"reprobe"` or `"requeue"` raises `CaseClauseError`. These are avoidable LiveView crashes from browser-controlled event payloads.

**Fix:** Validate IDs against the action directory and return a visible error for unsupported lifecycle actions.

```elixir
def handle_event("select_action", %{"id" => id_str}, socket) do
  allowed = MapSet.new(socket.assigns.model.actions, &Atom.to_string(&1.id))

  if MapSet.member?(allowed, id_str) do
    {:noreply, assign(socket, active_action_id: String.to_existing_atom(id_str), action_state: :input, action_error: nil, action_data: %{})}
  else
    {:noreply, assign(socket, action_error: "Unknown admin action.")}
  end
end

def handle_event("execute_lifecycle_repair", %{"asset_id" => _id, "repair_action" => action}, socket)
    when action not in ["reprobe", "requeue"] do
  {:noreply, assign(socket, action_error: "Unsupported lifecycle repair action.")}
end
```

### WR-03: WARNING - Proof Matrix Drift Gate Can Pass When Referenced Specs Do Not Exist

**File:** `scripts/maintainer/check_adoption_proof_matrix.sh:22`

**Issue:** The drift gate only checks that `adoption-proof-matrix.md` contains literal substrings such as `e2e/admin-console.spec.js` and `e2e/admin-screenshots.spec.js`. If a spec is deleted, renamed, or excluded from the Playwright suite but the stale filename remains in the markdown, this merge-blocking proof gate still passes. That creates a CI/proof false positive for the new admin behavior and screenshot claims.

**Fix:** Keep the substring checks if desired, but also assert that each referenced spec path exists and that Playwright can list it.

```bash
require_file() {
  local rel="$1"
  local path="${repo_root}/examples/adoption_demo/${rel}"
  if [[ ! -f "${path}" ]]; then
    echo "check_adoption_proof_matrix: missing referenced file ${rel}" >&2
    exit 1
  fi
}

for spec in \
  e2e/admin-console.spec.js \
  e2e/admin-theme.spec.js \
  e2e/admin-actions.spec.js \
  e2e/admin-screenshots.spec.js
do
  require_substring "${spec}" "${spec}"
  require_file "${spec}"
done
```

### WR-04: WARNING - README Points Developers at the Wrong Admin Console URL

**File:** `examples/adoption_demo/README.md:86`

**Issue:** The Admin Console Walkthrough says to visit `http://localhost:4000/admin`, but the current demo quick-start runs on port `4102` and the router mounts the console at `/admin/rindle`. This stale URL sends developers to a non-existent route and contradicts the proof matrix and Playwright helper route contract.

**Fix:** Update the walkthrough URL and keep it aligned with the configurable port language.

```markdown
After seeding the database (`mix run priv/repo/seeds.exs`) and starting the server,
developers can visit `http://localhost:4102/admin/rindle`
or `http://localhost:${ADOPTION_DEMO_BROWSER_PORT}/admin/rindle` when overriding the port.
```

---

_Reviewed: 2026-06-13T03:29:05Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
