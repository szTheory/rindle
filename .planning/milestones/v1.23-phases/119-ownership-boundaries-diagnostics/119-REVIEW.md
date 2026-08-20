---
phase: 119-ownership-boundaries-diagnostics
reviewed: 2026-08-10T02:11:42Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/rindle/schema.ex
  - lib/rindle/ops/ownership_snapshot.ex
  - lib/rindle/ops/runtime_checks.ex
  - lib/rindle/ops/runtime_status.ex
  - lib/mix/tasks/rindle.doctor.ex
  - lib/mix/tasks/rindle.runtime_status.ex
  - lib/rindle/admin/queries.ex
  - lib/rindle/admin/live/runtime_doctor_live.ex
  - examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex
  - examples/adoption_demo/e2e/ops-surfaces.spec.js
  - test/rindle/ops/ownership_snapshot_test.exs
  - test/rindle/ops/runtime_checks_test.exs
  - test/rindle/ops/runtime_status_test.exs
  - test/rindle/doctor_test.exs
  - test/rindle/runtime_status_task_test.exs
  - test/rindle/admin/queries_test.exs
  - examples/adoption_demo/test/adoption_demo_web/live/ops_live_test.exs
findings:
  critical: 3
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 119: Code Review Report

**Reviewed:** 2026-08-10T02:11:42Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

The new ownership snapshot uses parameterized catalog reads and validates the dynamic Rindle identifier before interpolating it. However, the refusal path is not safe end-to-end: the admin LiveView crashes whenever the bounded runtime diagnostic is used, the shared refusal formatter still serializes untrusted prefix values, and the doctor data subsequently rendered by the admin surface includes raw database exception text.

## Critical Issues

### CR-01: Runtime/Doctor refusal page crashes instead of rendering the bounded diagnostic

**File:** `lib/rindle/admin/live/runtime_doctor_live.ex:104-108,190-195`

**Issue:** `Queries.runtime_doctor/1` deliberately returns `runtime_status: nil` for every runtime refusal (see `lib/rindle/admin/queries.ex:233-241`). The template always evaluates `runtime_findings(@model)`, but `runtime_findings/1` dereferences `runtime_status.variants`, `upload_sessions`, and the other report fields. A refusal therefore raises while rendering, so an operator whose schema/binding needs diagnostics sees a 500/live-render failure rather than the safe remediation shown at lines 53-58.

**Fix:** Make the findings section conditional on a present report, or make the helper return an empty list for `runtime_status: nil`.

```elixir
defp runtime_findings(%{runtime_status: nil}), do: []

defp runtime_findings(%{runtime_status: runtime_status}) do
  runtime_status.variants.findings ++
    runtime_status.upload_sessions.findings ++
    runtime_status.provider_assets.findings ++
    runtime_status.runtime_checks.findings
end
```

Add a LiveView render test that injects a refusal and asserts the bounded diagnostic is rendered successfully.

### CR-02: Bounded refusal formatter leaks arbitrary values carried as prefixes

**File:** `lib/mix/tasks/rindle.runtime_status.ex:79-84,126-135`

**Issue:** The two supposedly bounded refusal branches interpolate `details.expected_prefix` and `details.observed_prefix` into text and copy them directly into JSON. `RuntimeStatus` accepts a configurable `:ownership_snapshot` at `lib/rindle/ops/runtime_status.ex:83-95`; it does not validate injected snapshot fields before `bounded_refusal/3` copies them at lines 159-166. Thus a malformed/instrumented snapshot with a database error or credential sentinel in either field is emitted by both `mix rindle.runtime_status` and the adoption/admin formatters. This violates the phase's raw-error redaction boundary despite the unknown-error fallback.

**Fix:** Serialize a prefix only when it satisfies the strict safe schema-name contract (and, for Rindle, the supported-prefix set); otherwise use a constant such as `"unknown"` or omit the field. Apply the same projection before both text and JSON formatting, and add sentinel tests specifically inside a `:rindle_prefix_mismatch` and an `:oban_binding_drift` details map.

### CR-03: Admin Runtime/Doctor renders raw migration/database exception messages

**File:** `lib/rindle/ops/runtime_checks.ex:667-675` 

**Issue:** When migration inspection cannot connect or query, `migration_statuses/1` embeds `Exception.message(reason)` directly into a check name. That name is then made the check summary at `lib/rindle/ops/runtime_checks.ex:416`, returned by `Queries.runtime_doctor/1` on the refusal path at `lib/rindle/admin/queries.ex:233-241`, and rendered verbatim at `lib/rindle/admin/live/runtime_doctor_live.ex:83,98`. Postgrex/repository exception text can expose SQL, connection metadata, or credentials to every authorized admin viewer; it also defeats Phase 119's requirement that the adjacent presentation contain only bounded diagnostics.

**Fix:** Replace the caught exception message with fixed text (for example, `"migration inspection failed"`) and retain only a stable classification internally for logs/telemetry. Add a refusal-path admin render test whose migration inspection returns a SQL/credential sentinel and assert it is absent from both assigns and HTML.

---

_Reviewed: 2026-08-10T02:11:42Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
