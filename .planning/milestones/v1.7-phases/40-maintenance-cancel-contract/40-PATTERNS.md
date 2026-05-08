# Phase 40: Maintenance + Cancel Contract - Pattern Map

**Mapped:** 2026-05-07 19:56:47 EDT
**Files analyzed:** 12
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality | Recommended Plan |
|---|---|---|---|---|---|
| `lib/rindle/ops/upload_maintenance.ex` | service | batch | `lib/rindle/ops/upload_maintenance.ex` + `lib/rindle/upload/broker.ex` resumable cancel/compensation path | exact + partial | Plan 1 |
| `lib/rindle/workers/abort_incomplete_uploads.ex` | worker | batch | `lib/rindle/workers/abort_incomplete_uploads.ex` | exact | Plan 1 |
| `lib/mix/tasks/rindle.abort_incomplete_uploads.ex` | task | batch | `lib/mix/tasks/rindle.abort_incomplete_uploads.ex` | exact | Plan 1 |
| `test/rindle/ops/upload_maintenance_test.exs` | test | batch | `test/rindle/ops/upload_maintenance_test.exs` | exact | Plan 1 |
| `lib/rindle/ops/upload_maintenance.ex` | service | batch | `lib/rindle/ops/upload_maintenance.ex` cleanup lane | exact | Plan 2 |
| `lib/rindle/workers/cleanup_orphans.ex` | worker | batch | `lib/rindle/workers/cleanup_orphans.ex` | exact | Plan 2 |
| `test/rindle/workers/maintenance_workers_test.exs` | test | batch | `test/rindle/workers/maintenance_workers_test.exs` | exact | Plan 2 |
| `lib/rindle/ops/runtime_status.ex` | service | batch | `lib/rindle/ops/runtime_status.ex` | exact | Plan 3 |
| `lib/mix/tasks/rindle.runtime_status.ex` | task | transform | `lib/mix/tasks/rindle.runtime_status.ex` | exact | Plan 3 |
| `test/rindle/ops/runtime_status_test.exs` | test | batch | `test/rindle/ops/runtime_status_test.exs` | exact | Plan 3 |
| `test/rindle/runtime_status_task_test.exs` | test | transform | `test/rindle/runtime_status_task_test.exs` | exact | Plan 3 |
| `test/rindle/upload/broker_test.exs` | test | request-response | `test/rindle/upload/broker_test.exs` live resumable proof | exact | Plan 3 |

## Recommended Plan Ownership

### Plan 1: Abort lane resumable cancel contract

**Own these files**
- `lib/rindle/ops/upload_maintenance.ex`
- `lib/rindle/workers/abort_incomplete_uploads.ex`
- `lib/mix/tasks/rindle.abort_incomplete_uploads.ex`
- `test/rindle/ops/upload_maintenance_test.exs`

**Why**
- This is the only place allowed to perform remote resumable cancel.
- The existing ownership seam already keeps remote side effects in the service and telemetry/reporting in the worker/task.
- Touching cleanup or runtime-status here would widen blast radius unnecessarily.

### Plan 2: Cleanup eligibility guardrails

**Own these files**
- `lib/rindle/ops/upload_maintenance.ex`
- `lib/rindle/workers/cleanup_orphans.ex`
- `test/rindle/ops/upload_maintenance_test.exs`
- `test/rindle/workers/maintenance_workers_test.exs`

**Why**
- Cleanup eligibility is a second slice inside the same service module, but it is behaviorally distinct from abort-time cancel.
- Worker-level telemetry/reporting changes are isolated here.
- This plan should not modify runtime-status or live GCS proof code.

### Plan 3: Operator visibility and proof coverage

**Own these files**
- `lib/rindle/ops/runtime_status.ex`
- `lib/mix/tasks/rindle.runtime_status.ex`
- `test/rindle/ops/runtime_status_test.exs`
- `test/rindle/runtime_status_task_test.exs`
- `test/rindle/upload/broker_test.exs`

**Why**
- `runtime_status` is a separate operator-facing contract with its own formatter and task tests.
- The live proof seam for resumable lifecycle already lives in `broker_test.exs`; extending it there is lower risk than inventing a new integration harness.
- Keeping proof changes out of the maintenance-worker plans reduces regression risk on cron behavior.

## Pattern Assignments

### `lib/rindle/ops/upload_maintenance.ex` (service, batch)

**Analogs:** [lib/rindle/ops/upload_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex:16), [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:367)

**Report shape pattern** ([upload_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex:16), lines 16-28):
```elixir
@type cleanup_report :: %{
        sessions_found: non_neg_integer(),
        sessions_deleted: non_neg_integer(),
        objects_deleted: non_neg_integer(),
        storage_errors: non_neg_integer(),
        storage_skipped: non_neg_integer()
      }

@type abort_report :: %{
        sessions_found: non_neg_integer(),
        sessions_aborted: non_neg_integer(),
        abort_errors: non_neg_integer()
      }
```

**Abort query gate pattern** ([upload_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex:128), lines 128-148):
```elixir
defp fetch_incomplete_timed_out_sessions do
  repo = Config.repo()
  now = DateTime.utc_now()

  query =
    from(s in MediaUploadSession,
      where:
        s.state in ["signed", "uploading"] or
          (s.state == "initialized" and s.upload_strategy == "multipart" and
             not is_nil(s.multipart_upload_id)),
      where: s.expires_at < ^now,
      select: s
    )
```

**Cleanup ordering pattern** ([upload_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex:185), lines 185-205):
```elixir
defp delete_session_and_object(session, acc, storage_mod) do
  # 1. Attempt storage deletion FIRST so the upload_key reference (only
  #    persisted on the session row) is preserved if storage fails.
  case attempt_storage_delete(session, storage_mod) do
    {:ok, object_increment} ->
      proceed_with_db_delete(session, acc, object_increment, _skipped_increment = 0)

    :storage_error ->
      Map.update!(acc, :storage_errors, &(&1 + 1))
  end
end
```

**Remote side effect outside DB transaction** ([upload_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex:233), lines 233-258):
```elixir
# Remote storage cleanup stays outside DB transactions so multipart abort
# retries do not hold database locks or hide network I/O in persistence work.
defp attempt_storage_delete(
       %MediaUploadSession{
         upload_strategy: "multipart",
         multipart_upload_id: multipart_upload_id
       } = session,
       storage_mod
     )
```

**Resumable cancel idempotency pattern to copy** ([broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:615), lines 615-635):
```elixir
defp compensate_failed_resumable_persist(adapter, storage_key, session_uri, opts) do
  case adapter.cancel_resumable_upload(storage_key, session_uri, opts) do
    {:ok, _} ->
      :ok

    {:error, :session_uri_unknown} ->
      :ok

    {:error, :session_uri_expired} ->
      :ok

    {:error, reason} ->
      Logger.warning("rindle.upload.broker.resumable_persist_compensation_failed",
        upload_key: storage_key,
        reason: inspect(reason)
      )
  end
end
```

**Direct adapter cancel pattern to avoid broadening** ([broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:372), lines 372-389):
```elixir
with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
     :ok <- ensure_resumable_session(session),
     asset <- repo.preload(session, :asset).asset,
     {:ok, profile_module} <- profile_name_to_module(asset.profile),
     adapter <- profile_module.storage_adapter(),
     :ok <- Capabilities.require_upload(adapter, :resumable_upload_session),
     {:ok, _result} <- adapter.cancel_resumable_upload(session.upload_key, session.session_uri, opts),
     :ok <- UploadSessionFSM.transition(session.state, "aborted", %{session_id: session.id}),
     {:ok, updated_session} <- update_session(repo, session, %{state: "aborted"}) do
  {:ok, %{session: updated_session}}
end
```

**Copy for Phase 40**
- Extend the abort report in place; do not introduce a second maintenance report type.
- Keep remote resumable cancel in `UploadMaintenance`, not in workers and not in `cleanup_orphans/1`.
- Mirror broker idempotency for `:session_uri_unknown` and `:session_uri_expired`, but keep Phase 40's narrower operator-only failure taxonomy on the row.
- Preserve the existing pattern that a transient remote failure increments error counters and leaves retryable DB state behind.

### `lib/rindle/workers/abort_incomplete_uploads.ex` (worker, batch)

**Analog:** [lib/rindle/workers/abort_incomplete_uploads.ex](/Users/jon/projects/rindle/lib/rindle/workers/abort_incomplete_uploads.ex:73)

**Delegation + telemetry boundary** (lines 73-90):
```elixir
case UploadMaintenance.abort_incomplete_uploads([]) do
  {:ok, report} ->
    Logger.info("rindle.workers.abort_incomplete_uploads.completed",
      sessions_found: report.sessions_found,
      sessions_aborted: report.sessions_aborted,
      abort_errors: report.abort_errors
    )

    :telemetry.execute(
      [:rindle, :cleanup, :run],
      %{sessions_aborted: report.sessions_aborted},
      %{profile: :unknown, adapter: :unknown, worker: __MODULE__}
    )
```

**Copy for Phase 40**
- Add resumable metrics here, not inside the service.
- Keep the service free of `[:rindle, :cleanup, :run]` telemetry.

### `lib/mix/tasks/rindle.abort_incomplete_uploads.ex` (task, batch)

**Analog:** [lib/mix/tasks/rindle.abort_incomplete_uploads.ex](/Users/jon/projects/rindle/lib/mix/tasks/rindle.abort_incomplete_uploads.ex:47)

**Task delegation/reporting pattern** (lines 47-79):
```elixir
Mix.shell().info("Aborting incomplete uploads past their TTL...")

case UploadMaintenance.abort_incomplete_uploads([]) do
  {:ok, report} ->
    print_abort_report(report)
    maybe_exit_nonzero(report.abort_errors)

  {:error, reason} ->
    Mix.shell().error("Abort task failed: #{inspect(reason)}")
    exit({:shutdown, 1})
end
```

**Copy for Phase 40**
- Keep the task as a thin presentation layer.
- If resumable counters are added to the report, print them here rather than changing task semantics.

### `test/rindle/ops/upload_maintenance_test.exs` (test, batch)

**Analog:** [test/rindle/ops/upload_maintenance_test.exs](/Users/jon/projects/rindle/test/rindle/ops/upload_maintenance_test.exs:14)

**Repo probe seam** (lines 14-36):
```elixir
defmodule TestRepoProbe do
  def all(queryable) do
    notify(:all)
    AdopterRepo.all(queryable)
  end

  def delete(struct) do
    notify({:delete, struct.__struct__})
    AdopterRepo.delete(struct)
  end

  def update(changeset) do
    notify({:update, changeset.data.__struct__})
    AdopterRepo.update(changeset)
  end
end
```

**Retryability invariant pattern** ([upload_maintenance_test.exs](/Users/jon/projects/rindle/test/rindle/ops/upload_maintenance_test.exs:242), lines 242-259):
```elixir
expect(Rindle.StorageMock, :delete, fn _key, _opts ->
  {:error, :storage_unavailable}
end)

{:ok, report} =
  UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

assert report.storage_errors >= 1
assert report.sessions_deleted == 0
assert AdopterRepo.get(MediaUploadSession, session.id) != nil
```

**Idempotent remote-not-found pattern** ([upload_maintenance_test.exs](/Users/jon/projects/rindle/test/rindle/ops/upload_maintenance_test.exs:345), lines 345-359):
```elixir
expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _upload_id, _opts ->
  {:error, :not_found}
end)

{:ok, report} =
  UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

assert report.storage_errors == 0
assert report.sessions_deleted == 1
```

**Service-telemetry anti-regression pattern** ([upload_maintenance_test.exs](/Users/jon/projects/rindle/test/rindle/ops/upload_maintenance_test.exs:482), lines 482-510):
```elixir
ref =
  :telemetry_test.attach_event_handlers(self(), [
    [:rindle, :cleanup, :run]
  ])

assert {:ok, _report} = UploadMaintenance.abort_incomplete_uploads([])
refute_received {[:rindle, :cleanup, :run], ^ref, _, _}
```

**Copy for Phase 40**
- Add resumable cases beside the multipart cases instead of creating a new test module.
- Reuse the existing "row remains for retry" assertions for non-idempotent cancel failures.
- Add direct assertions that `session_uri` is cleared or preserved according to the proof marker decision, without exposing it in logs.

### `lib/rindle/workers/cleanup_orphans.ex` (worker, batch)

**Analog:** [lib/rindle/workers/cleanup_orphans.ex](/Users/jon/projects/rindle/lib/rindle/workers/cleanup_orphans.ex:67)

**Thin worker orchestration pattern** (lines 67-88):
```elixir
with {:ok, storage_mod} <- resolve_storage_adapter(args) do
  cleanup_opts = build_cleanup_opts(dry_run?, storage_mod)

  handle_cleanup_result(
    UploadMaintenance.cleanup_orphans(cleanup_opts),
    dry_run?,
    storage_mod
  )
else
  {:error, reason} ->
    Logger.error("rindle.workers.cleanup_orphans.failed",
      reason: inspect(reason),
      stage: :resolve_storage_adapter
    )
```

**Worker telemetry pattern** (lines 100-122):
```elixir
:telemetry.execute(
  [:rindle, :cleanup, :run],
  %{
    sessions_deleted: report.sessions_deleted,
    objects_deleted: report.objects_deleted
  },
  %{
    profile: :unknown,
    adapter: storage_mod || :unknown,
    dry_run: dry_run?,
    worker: __MODULE__
  }
)
```

**Copy for Phase 40**
- Keep cleanup worker changes limited to surfacing new report fields.
- Do not add any remote cancel call path here.

### `test/rindle/workers/maintenance_workers_test.exs` (test, batch)

**Analog:** [test/rindle/workers/maintenance_workers_test.exs](/Users/jon/projects/rindle/test/rindle/workers/maintenance_workers_test.exs:140)

**Worker delegation pattern** (cleanup lines 140-176, abort lines 268-307):
```elixir
assert :ok =
         perform_job(CleanupOrphans, %{
           "dry_run" => false,
           "storage" => to_string(Rindle.StorageMock)
         })

assert_received {:repo_probe, {:delete, MediaUploadSession}}
```

```elixir
assert :ok = perform_job(AbortIncompleteUploads, %{})

updated = AdopterRepo.get!(MediaUploadSession, session.id)
assert updated.state == "expired"
refute_received {:repo_probe, {:delete, MediaUploadSession}}
```

**Copy for Phase 40**
- Extend these tests only for worker-side counters/logging boundaries.
- Keep detailed cancel taxonomy coverage in `UploadMaintenanceTest`, not here.

### `lib/rindle/ops/runtime_status.ex` (service, batch)

**Analog:** [lib/rindle/ops/runtime_status.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_status.ex:36)

**Top-level report shape pattern** (lines 36-57):
```elixir
def runtime_status(opts \\ []) do
  with {:ok, filters} <- normalize_filters(opts) do
    now = DateTime.utc_now()
    cutoff = older_than_cutoff(now, filters.older_than)

    {:ok,
     %{
       generated_at: now,
       filters: filters,
       runtime_checks: runtime_checks_report(filters, cutoff, now),
       assets: asset_report(filters),
       variants: variant_report(filters, cutoff, now),
       upload_sessions: upload_session_report(filters, cutoff, now),
       provider_assets: provider_assets_report(filters, now),
       recommendations: recommendations(filters, cutoff, now)
     }}
```

**Upload-session section pattern** ([runtime_status.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_status.ex:113), lines 113-134):
```elixir
defp upload_session_report(filters, cutoff, now) do
  findings =
    upload_session_finding_rows_query(filters, cutoff)
    |> Config.repo().all()
    |> Enum.map(&upload_session_sample(&1, now))
    |> summarize_state_findings(filters.limit)

  counts =
    from(s in MediaUploadSession,
      join: a in MediaAsset,
      on: a.id == s.asset_id,
      select: {s.state, count(s.id)}
    )
```

**Bounded findings/query pattern** ([runtime_status.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_status.ex:291), lines 291-307):
```elixir
from(s in MediaUploadSession,
  join: a in MediaAsset,
  on: a.id == s.asset_id,
  where: s.state in ["expired", "failed"],
  select: %{
    session_id: s.id,
    asset_id: s.asset_id,
    state: s.state,
    failure_reason: s.failure_reason,
    expires_at: s.expires_at,
    updated_at: s.updated_at
  }
)
```

**Recommendation surface pattern** ([runtime_status.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_status.ex:544), lines 544-556):
```elixir
defp upload_recommendations(states) do
  if "expired" in states do
    [
      %{
        class: :expired_upload_sessions,
        action: :cleanup,
        surface: "mix rindle.abort_incomplete_uploads && mix rindle.cleanup_orphans",
        summary: "Expire timed-out sessions first, then clean up their staged upload residue."
      }
    ]
  else
    []
  end
end
```

**Copy for Phase 40**
- Keep resumable data nested under `upload_sessions`; do not create a top-level sibling report.
- Add bounded counters and findings through the existing count-query + summarize pipeline.
- Surface operator action through `recommendations`, not by dumping protocol internals.

### `lib/mix/tasks/rindle.runtime_status.ex` (task, transform)

**Analog:** [lib/mix/tasks/rindle.runtime_status.ex](/Users/jon/projects/rindle/lib/mix/tasks/rindle.runtime_status.ex:68)

**Formatter composition pattern** (lines 68-86):
```elixir
def format_text_report(report) do
  [
    "Rindle: runtime status report...",
    "  generated_at: #{DateTime.to_iso8601(report.generated_at)}",
    "  profile:      #{report.filters.profile || "all"}",
    "  older_than:   #{report.filters.older_than || "any"}",
    "  limit:        #{report.filters.limit}",
    "  format:       text"
  ] ++
    format_section("runtime_checks", report.runtime_checks.counts) ++
    format_section("assets", report.assets.counts) ++
    format_section("variants", report.variants.counts) ++
    format_findings(report.runtime_checks.findings) ++
    format_findings(report.variants.findings) ++
    format_upload_findings(report.upload_sessions.findings) ++
    format_section("upload_sessions", report.upload_sessions.counts) ++
    format_provider_findings(report.provider_assets.findings) ++
    format_recommendations(report.recommendations) ++ ["Done."]
end
```

**Upload-session text rendering pattern** (lines 117-129):
```elixir
defp format_upload_findings(findings) do
  ["Upload session findings:"] ++
    Enum.flat_map(findings, fn finding ->
      [
        "  #{finding.state}: #{finding.count} (oldest_age_seconds=#{finding.oldest_age_seconds})"
      ] ++
        Enum.map(finding.samples, fn sample ->
          "    - #{sample.session_id}: #{sample.failure_reason || "operator attention required"}"
        end)
    end)
end
```

**Copy for Phase 40**
- Extend the existing upload-session section; do not add a new resumable formatter family.
- Keep text and JSON output driven entirely by the report map.
- Never render `session_uri` or partial URI fragments in either format.

### `test/rindle/ops/runtime_status_test.exs` (test, batch)

**Analog:** [test/rindle/ops/runtime_status_test.exs](/Users/jon/projects/rindle/test/rindle/ops/runtime_status_test.exs:111)

**Bounded upload-session contract pattern** (lines 111-129):
```elixir
test "reports expired and failed upload sessions with cleanup recommendation" do
  _expired =
    insert_upload_session(asset, %{
      state: "expired",
      expires_at: DateTime.add(DateTime.utc_now(), -900, :second)
    })

  _failed = insert_upload_session(asset, %{state: "failed", failure_reason: "mime_mismatch"})

  assert {:ok, report} = RuntimeStatus.runtime_status(limit: 2)
  assert Enum.any?(report.recommendations, &(&1.action == :cleanup))
end
```

**Copy for Phase 40**
- Add resumable counter assertions here, including stale-session-uri counts.
- Assert bounded findings and recommendations, not low-level provider protocol details.
- Add a negative assertion that the serialized report does not contain `session_uri`.

### `test/rindle/runtime_status_task_test.exs` (test, transform)

**Analog:** [test/rindle/runtime_status_task_test.exs](/Users/jon/projects/rindle/test/rindle/runtime_status_task_test.exs:23)

**Task-output contract pattern** (lines 23-46):
```elixir
RuntimeStatusTask.run(["--limit", "1"])

assert_received {:mix_shell, :info, ["Rindle: runtime status report..."]}
assert_received {:mix_shell, :info, ["Variants:"]}
assert_received {:mix_shell, :info, ["Findings:"]}
assert_received {:mix_shell, :info, ["Recommendations:"]}
assert_received {:mix_shell, :info, ["Done."]}
```

**Section-order contract pattern** (lines 90-103):
```elixir
provider_idx = Enum.find_index(lines, &(&1 == "Provider asset findings:"))
upload_idx = Enum.find_index(lines, &(&1 == "Upload session findings:"))
rec_idx = Enum.find_index(lines, &(&1 == "Recommendations:"))

assert upload_idx < provider_idx
assert provider_idx < rec_idx
```

**Copy for Phase 40**
- Add assertions for the new resumable counters in the existing upload-session output.
- Preserve deterministic ordering; do not insert a second resumable section.

### `test/rindle/upload/broker_test.exs` (test, request-response)

**Analog:** [test/rindle/upload/broker_test.exs](/Users/jon/projects/rindle/test/rindle/upload/broker_test.exs:528)

**Local idempotent-cancel precedent** (lines 528-561):
```elixir
test "initiate_resumable_session/2 cancels the remote session when persistence fails" do
  expect(Rindle.StorageMock, :cancel_resumable_upload, fn key, session_uri, _opts ->
    assert key =~ "testprofile"
    assert session_uri == "https://storage.googleapis.com/upload/session-rollback"
    {:ok, %{cancelled: true}}
  end)

  assert {:error, :session_insert_failed} =
           Broker.initiate_resumable_session(TestProfile, filename: "resumable.jpg")
end
```

**Live GCS proof seam** ([broker_test.exs](/Users/jon/projects/rindle/test/rindle/upload/broker_test.exs:740), lines 740-827):
```elixir
@tag :gcs
@tag skip: @gcs_skip_reason
test "streams a resumable upload through the broker lifecycle and converges via verify_completion/2" do
  {:ok, %{session: session, resumable: resumable}} =
    Broker.initiate_resumable_session(LiveGCSProfile, ...)

  assert {:ok, %{session: completed_session, asset: asset}} =
           Broker.verify_completion(session.id)

  assert inspect(completed_session) =~ "[REDACTED]"
  refute inspect(completed_session) =~ resumable.session_uri
end
```

**Copy for Phase 40**
- Extend the existing live resumable proof file for maintenance scenarios.
- Reuse the same secret-gated GCS setup and redaction assertions.
- Assert stepwise operator-visible state: initiate, abort/idempotent abort, runtime-status visibility, cleanup.

### `test/rindle/storage/gcs/client_test.exs` (test, request-response)

**Analog:** [test/rindle/storage/gcs/client_test.exs](/Users/jon/projects/rindle/test/rindle/storage/gcs/client_test.exs:266)

**Provider error mapping contract** (lines 266-289):
```elixir
test "cancel returns success and preserves 404/410 mappings" do
  assert {:ok, %{cancelled: true}} =
           Client.cancel_resumable_upload(@bucket, "assets/resumable.bin", "#{base_url}/session/upload-cancelled", opts)

  assert {:error, :session_uri_unknown} =
           Client.cancel_resumable_upload(@bucket, "assets/resumable.bin", "#{base_url}/session/upload-gone", opts)

  assert {:error, :session_uri_expired} =
           Client.cancel_resumable_upload(@bucket, "assets/resumable.bin", "#{base_url}/session/upload-expired", opts)
end
```

**Copy for Phase 40**
- Treat these tuples as locked inputs to maintenance logic.
- Do not redefine or wrap them in new public result families.

## Shared Patterns

### Service/worker telemetry split
**Sources:** [lib/rindle/ops/upload_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex:51), [test/rindle/ops/upload_maintenance_test.exs](/Users/jon/projects/rindle/test/rindle/ops/upload_maintenance_test.exs:482), [lib/rindle/workers/abort_incomplete_uploads.ex](/Users/jon/projects/rindle/lib/rindle/workers/abort_incomplete_uploads.ex:82), [lib/rindle/workers/cleanup_orphans.ex](/Users/jon/projects/rindle/lib/rindle/workers/cleanup_orphans.ex:110)
```elixir
# Service returns reports; workers emit [:rindle, :cleanup, :run]
assert {:ok, _report} = UploadMaintenance.cleanup_orphans(dry_run: true)
refute_received {[:rindle, :cleanup, :run], ^ref, _, _}
```

**Apply to**
- All maintenance service changes.
- New `:resumable_aborts` telemetry field belongs in workers, not service code.

### Remote side effects stay outside DB transactions
**Sources:** [lib/rindle/ops/upload_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/upload_maintenance.ex:185), [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:532)
```elixir
case attempt_storage_delete(session, storage_mod) do
  {:ok, object_increment} ->
    proceed_with_db_delete(session, acc, object_increment, _skipped_increment = 0)

  :storage_error ->
    Map.update!(acc, :storage_errors, &(&1 + 1))
end
```

**Apply to**
- Resumable cancel during abort lane.
- Cleanup proof-marker enforcement.

### Idempotent remote-not-found/expired handling
**Sources:** [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:615), [test/rindle/storage/gcs/client_test.exs](/Users/jon/projects/rindle/test/rindle/storage/gcs/client_test.exs:266)
```elixir
{:error, :session_uri_unknown} -> :ok
{:error, :session_uri_expired} -> :ok
```

**Apply to**
- Maintenance abort logic.
- Cleanup eligibility proof if based on clearing `session_uri`.

### Bounded operator surfaces
**Sources:** [lib/rindle/ops/runtime_status.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_status.ex:113), [lib/mix/tasks/rindle.runtime_status.ex](/Users/jon/projects/rindle/lib/mix/tasks/rindle.runtime_status.ex:117)
```elixir
%{
  counts: Map.put(counts, :total, Enum.sum(Map.values(counts))),
  findings: findings
}
```

**Apply to**
- New resumable counters under `upload_sessions`.
- Failure reasons as low-cardinality strings only.

## Anti-Patterns To Avoid

- Do not call remote resumable cancel from `cleanup_orphans/1` or `CleanupOrphans`; Phase 40 locks that ownership to the abort lane.
- Do not route maintenance through `Broker.cancel_resumable_session/2`; that path is user-facing and only persists `"aborted"` on direct success, while Phase 40 needs operator-only failure bookkeeping and idempotent 404/410 handling.
- Do not hide remote cancel inside `repo.transaction/1`, `Ecto.Multi`, or cleanup DB delete paths.
- Do not delete resumable `"expired"` rows solely because state is terminal; require local proof that remote cancel already succeeded or was idempotently resolved.
- Do not add a new top-level `resumable_sessions` section or a second formatter family to `runtime_status`.
- Do not expose `session_uri`, partial URIs, offsets, or provider headers in runtime-status findings, logs, telemetry, or task output.
- Do not emit `[:rindle, :cleanup, :run]` from `Rindle.Ops.UploadMaintenance`.
- Do not invent new public error tuples or durable FSM states such as `"cancel_failed"`.

## No Analog Found

None. The phase can extend existing maintenance, runtime-status, worker, task, and live resumable proof seams directly.

## Metadata

**Analog search scope:** `lib/rindle/ops`, `lib/rindle/workers`, `lib/mix/tasks`, `lib/rindle/upload`, `test/rindle/ops`, `test/rindle/workers`, `test/rindle/upload`, `test/rindle/storage`, `test/adopter/canonical_app`
**Key reusable seams:** existing two-step maintenance lane, worker-only cleanup telemetry, bounded `runtime_status` report pipeline, broker live resumable GCS proof
**Planner note:** The only intentional file overlap between plans is `lib/rindle/ops/upload_maintenance.ex` and `test/rindle/ops/upload_maintenance_test.exs`; split by function ownership (`abort_*` in Plan 1, `cleanup_*` in Plan 2) to keep merge risk low.
