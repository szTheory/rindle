# Plan 05-01 Deferred Items

## Pre-existing format issues (out of scope)

The following files have pre-existing `mix format --check-formatted` violations
that were not introduced by Plan 05-01. They should be addressed in a separate
chore commit (likely as part of Plan 05-02 — the CI quality lane will catch
these once the format job is wired):

- `test/rindle/upload/broker_test.exs` — trailing whitespace + long `expect`
  lines in EXISTING tests (lines 26, 28, 54, 56-58, 81, 85, 93, 105, 109).
  My added telemetry describe block (lines 115+) IS formatted.

- `test/rindle/delivery_test.exs` — long `expect` lines in EXISTING tests
  (lines 36, 56, 72, 83, 99, 107, 122). My added telemetry describe block
  (lines 140+) IS formatted.

- `test/rindle/upload/proxied_test.exs` — trailing whitespace (lines 23, 27).
  Not touched by Plan 05-01.

These are documented per the executor scope-boundary rule (do not auto-fix
issues outside the current task's changes).

## Pre-existing flaky test (out of scope)

`test/rindle/workers/maintenance_workers_test.exs` line 167-168:

```elixir
test "AbortIncompleteUploads implements Oban.Worker" do
  assert function_exported?(AbortIncompleteUploads, :perform, 1)
end
```

This test is flaky depending on module-load timing. It fails on seeds 200/400
and passes on seeds 100/300/500. The same flake exists on the base commit
`47675510dcff8f8b27d568b0554490fad7175aa4` — it is NOT introduced by Plan 05-01.
Likely fix: add `Code.ensure_loaded(AbortIncompleteUploads)` before
`function_exported?/3`. Defer to a chore commit.

## Pre-existing storage_adapter_test :minio failure (out of scope)

`test/rindle/storage/storage_adapter_test.exs:100` — the
`@tag :minio` test "s3 adapter integration hook stores and deletes against
MinIO when configured" fails with a `String.replace/4` `FunctionClauseError`
inside the ExAws / sweet_xml stack when called against a real MinIO with the
inline `aws_config:` opts that pass `scheme: :http` (atom) instead of
`scheme: "http://"` (string).

This failure exists on the Plan 05-04 base commit `a275a2dd...` independent
of any Plan 04 changes — confirmed by `git stash && mix test --include minio`
on the unmodified base. It is NOT caused by the S3.store/3 return-shape
fix introduced in Plan 04 (Task 2 deviation Rule-1 fix).

Likely fix: change `String.to_atom()` to a pass-through string in
`storage_adapter_test.exs:93`, or fix the underlying ExAws scheme-coercion
expectation. Defer to a chore commit; the existing CI integration job's
`mix test test/rindle/storage/storage_adapter_test.exs --include minio`
step will already be red on `main` when the Phase 5 CI lanes are applied —
this is independent debt that Plan 04 surfaces but does not own.

Plan 04's adopter lane (`mix test --only adopter`) DOES pass end-to-end
against MinIO; the adopter test passes `scheme: "http://"` correctly through
global `Application.put_env/3` which is the production-correct shape.
