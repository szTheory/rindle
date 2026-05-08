# Phase 38: Resumable Persistence + FSM - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 12
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `priv/repo/migrations/<timestamp>_extend_media_upload_sessions_for_resumable.exs` | migration | CRUD | `priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs` | exact |
| `lib/rindle/domain/media_upload_session.ex` | model | CRUD | `lib/rindle/domain/media_upload_session.ex` + `lib/rindle/domain/media_provider_asset.ex` | exact + partial |
| `lib/rindle/domain/upload_session_fsm.ex` | model | event-driven | `lib/rindle/domain/upload_session_fsm.ex` | exact |
| `lib/rindle/ops/runtime_checks.ex` | service | batch | `lib/rindle/ops/runtime_checks.ex` | exact |
| `test/rindle/domain/media_upload_session_test.exs` | test | CRUD | `test/rindle/domain/media_provider_asset_test.exs` | role-match |
| `test/rindle/domain/lifecycle_fsm_test.exs` | test | event-driven | `test/rindle/domain/lifecycle_fsm_test.exs` | exact |
| `test/rindle/domain/migration_test.exs` | test | CRUD | `test/rindle/domain/migration_test.exs` | exact |
| `lib/rindle/upload/resumable_telemetry.ex` | service | event-driven | `lib/rindle/upload/broker.ex` + `test/rindle/streaming/provider/mux/telemetry_test.exs` | role-match |
| `guides/storage_gcs.md` | docs | human-facing | `guides/troubleshooting.md` + `guides/getting_started.md` | role-match |
| `test/rindle/upload/resumable_telemetry_test.exs` | test | event-driven | `test/rindle/streaming/provider/mux/telemetry_test.exs` | exact |
| `test/rindle/contracts/telemetry_contract_test.exs` | test | event-driven | `test/rindle/contracts/telemetry_contract_test.exs` | exact |
| `test/rindle/ops/runtime_checks_test.exs` and/or `test/rindle/doctor_test.exs` | test | batch | `test/rindle/ops/runtime_checks_test.exs` + `test/rindle/doctor_test.exs` | exact |

## Pattern Assignments

### `priv/repo/migrations/<timestamp>_extend_media_upload_sessions_for_resumable.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs`

**Migration shape** ([priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs](/Users/jon/projects/rindle/priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs:1), lines 1-10):
```elixir
defmodule Rindle.Repo.Migrations.ExtendMediaUploadSessionsForMultipart do
  use Ecto.Migration

  def change do
    alter table(:media_upload_sessions) do
      add :upload_strategy, :string, null: false, default: "presigned_put"
      add :multipart_upload_id, :string
      add :multipart_parts, :map, null: false, default: %{}
    end
  end
end
```

**Base table/index posture** ([priv/repo/migrations/20260425090200_create_media_upload_sessions.exs](/Users/jon/projects/rindle/priv/repo/migrations/20260425090200_create_media_upload_sessions.exs:4), lines 4-17):
```elixir
def change do
  create table(:media_upload_sessions) do
    add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
    add :state, :string, null: false, default: "initialized"
    add :upload_key, :string, null: false
    add :expires_at, :utc_datetime_usec, null: false
    add :verified_at, :utc_datetime_usec
    add :failure_reason, :text

    timestamps()
  end

  create index(:media_upload_sessions, [:state])
  create index(:media_upload_sessions, [:expires_at])
end
```

**What to copy**
- Keep the migration as a small additive `alter table(:media_upload_sessions)` change.
- Follow the existing packaged-migration naming/module convention under `Rindle.Repo.Migrations.*`.
- Add the partial resumable expiry index in the same migration file after the `alter table` block.

---

### `lib/rindle/domain/media_upload_session.ex` (model, CRUD)

**Analogs:** `lib/rindle/domain/media_upload_session.ex`, inspect/redaction from `lib/rindle/domain/media_provider_asset.ex`

**Schema + state vocabulary pattern** ([lib/rindle/domain/media_upload_session.ex](/Users/jon/projects/rindle/lib/rindle/domain/media_upload_session.ex:27), lines 27-60):
```elixir
use Ecto.Schema
import Ecto.Changeset

@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id

@states [
  "initialized",
  "signed",
  "uploading",
  "uploaded",
  "verifying",
  "completed",
  "aborted",
  "expired",
  "failed"
]

schema "media_upload_sessions" do
  field :state, :string, default: "initialized"
  field :upload_key, :string
  field :upload_strategy, :string, default: "presigned_put"
  field :multipart_upload_id, :string
  field :multipart_parts, :map, default: %{}
  field :expires_at, :utc_datetime_usec
  field :verified_at, :utc_datetime_usec
  field :failure_reason, :string

  belongs_to :asset, Rindle.Domain.MediaAsset

  timestamps()
end
```

**Changeset pattern** ([lib/rindle/domain/media_upload_session.ex](/Users/jon/projects/rindle/lib/rindle/domain/media_upload_session.ex:62), lines 62-87):
```elixir
def changeset(upload_session, attrs) do
  upload_session
  |> cast(attrs, [
    :asset_id,
    :state,
    :upload_key,
    :upload_strategy,
    :multipart_upload_id,
    :multipart_parts,
    :expires_at,
    :verified_at,
    :failure_reason
  ])
  |> validate_required([:asset_id, :state, :upload_key, :upload_strategy, :expires_at])
  |> validate_inclusion(:state, @states)
  |> foreign_key_constraint(:asset_id)
end
```

**Inspect redaction helper + impl pattern** ([lib/rindle/domain/media_provider_asset.ex](/Users/jon/projects/rindle/lib/rindle/domain/media_provider_asset.ex:78), lines 78-95 and 119-128):
```elixir
@spec redact_id(nil | String.t()) :: nil | String.t()
def redact_id(nil), do: nil

def redact_id(id) when is_binary(id) and byte_size(id) >= 4 do
  "..." <> String.slice(id, -4, 4)
end

def redact_id(_), do: "...redacted"
```

```elixir
defimpl Inspect, for: Rindle.Domain.MediaProviderAsset do
  def inspect(asset, opts) do
    redacted = %{
      asset
      | provider_asset_id: Rindle.Domain.MediaProviderAsset.redact_id(asset.provider_asset_id),
        raw_provider_metadata: %{redacted: true}
    }

    Inspect.Any.inspect(redacted, opts)
  end
end
```

**What to copy**
- Extend `@states` and `schema` in place instead of introducing a second schema module.
- Add the four resumable fields to the existing `cast/3` list and keep `validate_required/2` narrow.
- Add a module-level redaction helper plus `defimpl Inspect` so inspect output and any future telemetry/log helpers share one rule.

---

### `lib/rindle/domain/upload_session_fsm.ex` (model, event-driven)

**Analog:** `lib/rindle/domain/upload_session_fsm.ex`

**Allowed-transition map** ([lib/rindle/domain/upload_session_fsm.ex](/Users/jon/projects/rindle/lib/rindle/domain/upload_session_fsm.ex:6), lines 6-16):
```elixir
@allowed_transitions %{
  "initialized" => ["signed", "aborted", "expired", "failed"],
  "signed" => ["uploading", "uploaded", "verifying", "aborted", "expired", "failed"],
  "uploading" => ["uploaded", "verifying", "aborted", "expired", "failed"],
  "uploaded" => ["verifying"],
  "verifying" => ["completed", "failed"],
  "completed" => [],
  "aborted" => [],
  "expired" => [],
  "failed" => []
}
```

**Transition/error logging pattern** ([lib/rindle/domain/upload_session_fsm.ex](/Users/jon/projects/rindle/lib/rindle/domain/upload_session_fsm.ex:21), lines 21-29 and 41-50):
```elixir
@spec transition(state(), state(), map()) :: :ok | transition_error()
def transition(current_state, target_state, context \\ %{}) do
  if target_state in Map.get(@allowed_transitions, current_state, []) do
    :ok
  else
    log_transition_failure(current_state, target_state, context)
    {:error, {:invalid_transition, current_state, target_state}}
  end
end
```

```elixir
defp log_transition_failure(current_state, target_state, context) do
  Logger.warning("rindle.upload_session.transition_failed",
    session_id: Map.get(context, :session_id),
    from_state: current_state,
    to_state: target_state,
    reason: %{
      type: :invalid_transition,
      detail: Map.get(context, :reason, :invalid_transition)
    }
  )
end
```

**What to copy**
- Keep FSM changes as a single `@allowed_transitions` edit.
- Preserve the current invalid-transition return shape and structured log metadata.
- Add `"resuming"` narrowly in the locked lane instead of broadening unrelated edges.

---

### `lib/rindle/ops/runtime_checks.ex` (service, batch)

**Analog:** `lib/rindle/ops/runtime_checks.ex`

**Check registration pattern** ([lib/rindle/ops/runtime_checks.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_checks.ex:72), lines 72-116):
```elixir
def run(args, opts \\ []) do
  env = Keyword.get(opts, :env, System.get_env())
  probe = Keyword.get(opts, :probe, fn -> Rindle.AV.Probe.check_ffmpeg!() end)
  mix_app = Keyword.get(opts, :mix_app, :rindle)
  resolved = resolve_profiles(args, Keyword.get(opts, :profiles, Config.profile_modules()))
  profiles = resolved.profiles
  oban_config = Keyword.get(opts, :oban_config, Application.get_env(mix_app, Oban))
  local_playback_route = Keyword.get(opts, :local_playback_route, Config.local_playback_route())

  migration_statuses =
    Keyword.get_lazy(opts, :migration_statuses, fn -> migration_statuses(opts) end)

  checks =
    ([
       fn -> check_delivery_support(profiles) end,
       fn -> check_ffmpeg_runtime(probe) end,
       fn -> check_local_playback(profiles, local_playback_route) end,
       fn -> check_migration_pending(migration_statuses) end,
       fn -> check_migration_unresolved(migration_statuses) end,
       fn -> check_oban_default_instance(oban_config) end,
       fn -> check_oban_required_queues(profiles, oban_config) end,
       fn -> check_profile_runtime_fit(resolved, env) end,
       fn -> check_streaming_credentials(profiles, env) end,
       fn -> check_streaming_signing_key(profiles, env) end,
       fn -> check_streaming_webhook_secrets(profiles, env) end,
       fn -> check_streaming_smoke_ping(profiles, env, opts) end
     ] ++ gcs_extra)
    |> Enum.map(&run_check/1)
    |> Enum.sort_by(& &1.id)
end
```

**Per-check telemetry pattern** ([lib/rindle/ops/runtime_checks.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_checks.ex:128), lines 128-136):
```elixir
defp run_check(fun) do
  started_at = System.monotonic_time()
  result = fun.()

  :telemetry.execute(
    [:rindle, :runtime, :check, :stop],
    %{duration_us: elapsed_us(started_at)},
    %{check: result.id, status: result.status, component: result.component}
  )

  result
end
```

**Migration drift check style** ([lib/rindle/ops/runtime_checks.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_checks.ex:313), lines 313-360):
```elixir
defp check_migration_pending(statuses) do
  pending =
    statuses
    |> Enum.filter(fn
      {:down, _version, _name} -> true
      _other -> false
    end)
    |> Enum.map(&migration_version/1)

  if pending == [] do
    ok_result(
      "doctor.migrations.pending",
      :migrations,
      "No pending Rindle migrations were found.",
      "Keep Rindle migrations applied before running the runtime pipeline."
    )
  else
    error_result(
      "doctor.migrations.pending",
      :migrations,
      "Pending Rindle migrations: #{Enum.join(pending, ", ")}.",
      "Run `mix ecto.migrate` for the repo configured at `config :rindle, :repo` before retrying."
    )
  end
end
```

**What to copy**
- Append one new narrow `check_*` function and include it in the existing `checks` list.
- Return the same `%{id, status, component, summary, fix}` shape through `ok_result/4` or `error_result/4`.
- Keep this check schema-only and DB-introspection-based; do not hook in runtime-status or capability checks here.

---

### `test/rindle/domain/media_upload_session_test.exs` (test, CRUD)

**Analog:** `test/rindle/domain/media_provider_asset_test.exs`

**Migration smoke pattern** ([test/rindle/domain/media_provider_asset_test.exs](/Users/jon/projects/rindle/test/rindle/domain/media_provider_asset_test.exs:8), lines 8-40):
```elixir
describe "migration smoke" do
  test "media_provider_assets table exists with expected columns" do
    {:ok, %{rows: rows}} =
      Rindle.Repo.query(
        "SELECT column_name FROM information_schema.columns " <>
          "WHERE table_name = 'media_provider_assets' ORDER BY column_name",
        []
      )

    column_names = rows |> List.flatten() |> MapSet.new()
    ...
  end

  test "partial-where unique index exists on (provider_name, provider_asset_id)" do
    {:ok, %{rows: rows}} =
      Rindle.Repo.query(
        "SELECT indexdef FROM pg_indexes " <>
          "WHERE tablename = 'media_provider_assets' " <>
          "AND indexname = 'media_provider_assets_provider_name_provider_asset_id_index'",
        []
      )
    ...
  end
end
```

**State-validation loop pattern** ([test/rindle/domain/media_provider_asset_test.exs](/Users/jon/projects/rindle/test/rindle/domain/media_provider_asset_test.exs:61), lines 61-83):
```elixir
describe "changeset state validation" do
  setup do
    {:ok, asset: insert_media_asset!()}
  end

  for state <- ~w(pending uploading processing ready errored deleted) do
    test "accepts state=#{state}", %{asset: asset} do
      changeset =
        MediaProviderAsset.changeset(%MediaProviderAsset{}, base_attrs(asset, unquote(state)))

      assert changeset.valid?
    end
  end
end
```

**Inspect redaction assertions** ([test/rindle/domain/media_provider_asset_test.exs](/Users/jon/projects/rindle/test/rindle/domain/media_provider_asset_test.exs:194), lines 194-240):
```elixir
describe "Inspect redaction (security invariant 14, D-14)" do
  test "redacts provider_asset_id to last 4 chars when length >= 4" do
    record = %MediaProviderAsset{provider_asset_id: "abc-123-XYZ-9999"}
    output = inspect(record)

    assert output =~ "...9999"
    refute output =~ "abc-123"
    refute output =~ "XYZ"
  end

  test "redacts raw_provider_metadata to %{redacted: true}" do
    record = %MediaProviderAsset{
      raw_provider_metadata: %{secret: "supersecret-token-XYZ"}
    }

    output = inspect(record)

    assert output =~ "redacted: true"
    refute output =~ "supersecret-token-XYZ"
  end
end
```

**What to copy**
- Put new `MediaUploadSession` schema tests in their own dedicated test file rather than overloading `migration_test.exs`.
- Mirror the table/column/index smoke style, plus changeset accept/reject loops for the widened state and strategy vocabulary.
- Add inspect-specific assertions that raw `session_uri` never appears and `"[REDACTED]"` does.

---

### `test/rindle/domain/lifecycle_fsm_test.exs` (test, event-driven)

**Analog:** `test/rindle/domain/lifecycle_fsm_test.exs`

**Upload-session matrix pattern** ([test/rindle/domain/lifecycle_fsm_test.exs](/Users/jon/projects/rindle/test/rindle/domain/lifecycle_fsm_test.exs:176), lines 176-203):
```elixir
describe "upload session transition matrix" do
  test "accepts initialized through completed path" do
    assert :ok == UploadSessionFSM.transition("initialized", "signed")
    assert :ok == UploadSessionFSM.transition("signed", "uploading")
    assert :ok == UploadSessionFSM.transition("uploading", "uploaded")
    assert :ok == UploadSessionFSM.transition("uploaded", "verifying")
    assert :ok == UploadSessionFSM.transition("verifying", "completed")
  end

  test "accepts upload session terminal branches" do
    assert :ok == UploadSessionFSM.transition("initialized", "expired")
    assert :ok == UploadSessionFSM.transition("signed", "failed")
    assert :ok == UploadSessionFSM.transition("uploading", "aborted")
    assert :ok == UploadSessionFSM.transition("verifying", "failed")
  end

  test "rejects invalid upload session transitions" do
    assert {:error, {:invalid_transition, "initialized", "completed"}} =
             UploadSessionFSM.transition("initialized", "completed")
  end
end
```

**What to copy**
- Extend the existing upload-session section instead of creating a second FSM test module.
- Add positive assertions for `signed -> resuming` and `resuming -> uploading`, and negative assertions proving status-like probes do not need a new durable edge.

---

### `test/rindle/domain/migration_test.exs` (test, CRUD)

**Analog:** `test/rindle/domain/migration_test.exs`

**Column-introspection pattern** ([test/rindle/domain/migration_test.exs](/Users/jon/projects/rindle/test/rindle/domain/migration_test.exs:7), lines 7-19):
```elixir
{:ok, %{rows: rows}} =
  Repo.query("""
  SELECT column_name FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'media_assets'
  """)

column_names = Enum.map(rows, fn [name] -> name end) |> MapSet.new()
```

**Default-value check pattern** ([test/rindle/domain/migration_test.exs](/Users/jon/projects/rindle/test/rindle/domain/migration_test.exs:37), lines 37-56):
```elixir
{:ok, %{rows: [[default]]}} =
  Repo.query("""
  SELECT column_default FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'media_assets'
    AND column_name = 'kind'
  """)

assert default =~ "image"
```

**Index-presence pattern** ([test/rindle/domain/migration_test.exs](/Users/jon/projects/rindle/test/rindle/domain/migration_test.exs:59), lines 59-68):
```elixir
{:ok, %{rows: rows}} =
  Repo.query("""
  SELECT indexname FROM pg_indexes
  WHERE schemaname = 'public' AND tablename = 'media_assets'
  """)

indexes = Enum.map(rows, fn [name] -> name end)
assert Enum.any?(indexes, &String.contains?(&1, "kind"))
```

**What to copy**
- Keep this file focused on direct catalog introspection.
- Add assertions for the four resumable columns, the `last_known_offset` default/`NOT NULL` guard, and either the exact partial-index name or its effective predicate.

---

### `test/rindle/contracts/telemetry_contract_test.exs` (test, event-driven)

**Analog:** `test/rindle/contracts/telemetry_contract_test.exs`

**Public-event allowlist pattern** ([test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:68), lines 68-85):
```elixir
@public_events [
  [:rindle, :upload, :start],
  [:rindle, :upload, :stop],
  [:rindle, :asset, :state_change],
  [:rindle, :variant, :state_change],
  [:rindle, :delivery, :signed],
  [:rindle, :delivery, :streaming, :resolved],
  [:rindle, :delivery, :range_request],
  [:rindle, :cleanup, :run],
  [:rindle, :repair, :start],
  [:rindle, :repair, :stop],
  [:rindle, :repair, :exception],
  [:rindle, :runtime, :refusal],
  [:rindle, :runtime, :check, :stop],
  [:rindle, :media, :transcode, :start],
  [:rindle, :media, :transcode, :stop],
  [:rindle, :media, :transcode, :exception]
]
```

**Runtime-check contract assertions** ([test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:178), lines 178-200):
```elixir
test "doctor check runner emits runtime check stop telemetry", %{ref: ref} do
  _report =
    RuntimeChecks.run([],
      probe: fn -> :ok end,
      env: %{},
      profiles: [],
      oban_config: [...],
      migration_statuses: []
    )

  assert_received {[:rindle, :runtime, :check, :stop], ^ref, measurements, metadata}
  assert_numeric_measurements(measurements)
  assert is_binary(metadata.check)
  assert metadata.status in [:ok, :error]
  assert is_atom(metadata.component)
end
```

**Broad allowlist probe helper** ([test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:442), lines 442-510):
```elixir
probe_events =
  @public_events ++
    [
      [:rindle, :upload, :began],
      [:rindle, :upload, :ended],
      [:rindle, :asset, :transitioned],
      ...
    ]

:telemetry.attach_many(
  handler_id,
  probe_events,
  fn name, measurements, metadata, _config ->
    send(parent, {:probe_observed, name, measurements, metadata})
  end,
  nil
)
```

**What to copy**
- Add the two resumable public events directly to `@public_events`.
- Reuse `assert_required_metadata_keys/1` and `assert_numeric_measurements/1` expectations for required `:profile` and `:adapter` metadata plus numeric measurements.
- If Phase 38 adds any in-process emit site, extend the broad probe list to catch accidental event-name drift.

---

### `test/rindle/ops/runtime_checks_test.exs` and/or `test/rindle/doctor_test.exs` (test, batch)

**Analogs:** `test/rindle/ops/runtime_checks_test.exs`, `test/rindle/doctor_test.exs`

**Stable check-order pattern** ([test/rindle/ops/runtime_checks_test.exs](/Users/jon/projects/rindle/test/rindle/ops/runtime_checks_test.exs:33), lines 33-71):
```elixir
test "returns deterministic stable check ids" do
  report =
    RuntimeChecks.run([],
      probe: fn -> :ok end,
      env: %{},
      profiles: [ImageProfile, VideoProfile],
      oban_config: [...],
      migration_statuses: [],
      local_playback_route: [base_url: "http://example.test/rindle/local", secret_key_base: "secret"]
    )

  assert Enum.map(report.checks, & &1.id) == [
           "doctor.delivery_support",
           "doctor.ffmpeg_runtime",
           "doctor.local_playback",
           "doctor.migrations.pending",
           "doctor.migrations.unresolved",
           ...
         ]
end
```

**Migration-drift assertion style** ([test/rindle/ops/runtime_checks_test.exs](/Users/jon/projects/rindle/test/rindle/ops/runtime_checks_test.exs:175), lines 175-206):
```elixir
test "distinguishes pending and unresolved migration drift" do
  report =
    RuntimeChecks.run([],
      probe: fn -> :ok end,
      env: %{},
      profiles: [],
      oban_config: [...],
      migration_statuses: [
        {:down, 20_260_502_120_000, "extend_media_for_av.exs"},
        {:up, 20_260_425_090_000, "** FILE NOT FOUND **"}
      ]
    )

  pending = fetch_check(report, "doctor.migrations.pending")
  unresolved = fetch_check(report, "doctor.migrations.unresolved")
  ...
end
```

**Doctor CLI output pattern** ([test/rindle/doctor_test.exs](/Users/jon/projects/rindle/test/rindle/doctor_test.exs:6), lines 6-34 and 71-97):
```elixir
output = capture_io(fn ->
  report =
    Mix.Tasks.Rindle.Doctor.run_checks([],
      exit_on_failure?: false,
      probe: fn -> :ok end,
      env: %{},
      profiles: [],
      oban_config: [...],
      migration_statuses: []
    )

  assert report.success?
end)

assert output =~ "Rindle: running environment checks"
assert output =~ "doctor.ffmpeg_runtime"
assert output =~ "doctor.oban_required_queues"
assert output =~ "Rindle: Environment checks passed"
```

**What to copy**
- Update the stable check-id list if a new `doctor.resumable_session_schema` row is added.
- Add focused assertions around the new check’s `status`, `summary`, and `fix`.
- If CLI output order changes, cover it in `DoctorTest` with the same `capture_io` style.

## Shared Patterns

### Secret Redaction
**Sources:** [lib/rindle/domain/media_provider_asset.ex](/Users/jon/projects/rindle/lib/rindle/domain/media_provider_asset.ex:78), [test/rindle/domain/media_provider_asset_test.exs](/Users/jon/projects/rindle/test/rindle/domain/media_provider_asset_test.exs:194)
**Apply to:** `lib/rindle/domain/media_upload_session.ex`, any resumable telemetry helpers, inspect tests
```elixir
def redact_id(nil), do: nil
def redact_id(id) when is_binary(id) and byte_size(id) >= 4 do
  "..." <> String.slice(id, -4, 4)
end
def redact_id(_), do: "...redacted"
```

```elixir
def inspect(asset, opts) do
  redacted = %{asset | ...}
  Inspect.Any.inspect(redacted, opts)
end
```

Use the same centralized helper idea, but for `session_uri` the phase decision is stricter: always replace populated values with `"[REDACTED]"`, not a last-4 tag.

### Public Telemetry Contract
**Sources:** [test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:68), [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:513), [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:325)
**Apply to:** resumable status/cancel event registration and any emit helper added in this phase or the next
```elixir
:telemetry.execute(
  [:rindle, :upload, :start],
  %{system_time: System.system_time()},
  %{
    profile: profile_name,
    adapter: adapter,
    session_id: session_id
  }
)
```

```elixir
:telemetry.execute(
  [:rindle, :upload, :stop],
  %{system_time: System.system_time()},
  %{
    profile: asset.profile,
    adapter: profile_module.storage_adapter(),
    session_id: updated_session.id,
    asset_id: updated_asset.id
  }
)
```

Keep metadata low-cardinality, require `:profile` and `:adapter`, and exclude `session_uri`, headers, storage keys, or raw provider/session identifiers.

### `lib/rindle/upload/resumable_telemetry.ex` (service, event-driven)
**Sources:** [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:325), [test/rindle/streaming/provider/mux/telemetry_test.exs](/Users/jon/projects/rindle/test/rindle/streaming/provider/mux/telemetry_test.exs:142)
**Apply to:** centralized resumable `:status` / `:cancel` emit helpers
```elixir
:telemetry.execute(event_name, measurements, metadata)
```

Use the broker's direct `:telemetry.execute/3` posture, but wrap it in a tiny internal helper that allowlists metadata keys before emission. Reuse the Mux parity-test expectation model: later tests should drive both event names, drain captured events, and assert `session_uri` is absent from every metadata value.

### `guides/storage_gcs.md` (docs, human-facing)
**Sources:** [guides/troubleshooting.md](/Users/jon/projects/rindle/guides/troubleshooting.md:1), [guides/getting_started.md](/Users/jon/projects/rindle/guides/getting_started.md:1)
**Apply to:** the narrow Phase 38 logger-filter note required by `RESUMABLE-03`
```md
# <Guide Title>

## <Scoped section>
```

Keep the guide intentionally small and explicit. Use grep-friendly strings such as `Logger.add_translator`, `:session_uri`, `bearer credential`, and `Phase 41`, and state that the broader GCS onboarding guide is still deferred.

### `test/rindle/upload/resumable_telemetry_test.exs` (test, event-driven)
**Source:** [test/rindle/streaming/provider/mux/telemetry_test.exs](/Users/jon/projects/rindle/test/rindle/streaming/provider/mux/telemetry_test.exs:41)
**Apply to:** attach/drain parity coverage for resumable telemetry helpers
```elixir
:telemetry.attach_many(handler_id, events, fn evt, measurements, metadata, _ ->
  send(test_pid, {:tele, evt, measurements, metadata})
end, nil)
```

```elixir
defp drain_telemetry(acc \\ []) do
  receive do
    {:tele, _, _, _} = msg -> drain_telemetry([msg | acc])
  after
    100 -> Enum.reverse(acc)
  end
end
```

Copy the attach/drain structure directly. Replace the Mux asset-id redaction assertions with resumable-specific checks that raw `session_uri` never appears in metadata and that metadata keys remain within the locked allowlist.

### Doctor Check Shape
**Sources:** [lib/rindle/ops/runtime_checks.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_checks.ex:72), [lib/rindle/ops/runtime_checks.ex](/Users/jon/projects/rindle/lib/rindle/ops/runtime_checks.ex:313), [test/rindle/ops/runtime_checks_test.exs](/Users/jon/projects/rindle/test/rindle/ops/runtime_checks_test.exs:33)
**Apply to:** `doctor.resumable_session_schema`
```elixir
checks =
  [
    fn -> check_delivery_support(profiles) end,
    ...
  ]
  |> Enum.map(&run_check/1)
  |> Enum.sort_by(& &1.id)
```

```elixir
ok_result("doctor.migrations.pending", :migrations, "...", "...")
error_result("doctor.migrations.pending", :migrations, "...", "...")
```

The new resumable schema check should be another narrow `check_*` function returning the same result shape and benefiting automatically from `run_check/1` telemetry.

### Catalog Introspection Tests
**Sources:** [test/rindle/domain/migration_test.exs](/Users/jon/projects/rindle/test/rindle/domain/migration_test.exs:7), [test/rindle/domain/media_provider_asset_test.exs](/Users/jon/projects/rindle/test/rindle/domain/media_provider_asset_test.exs:8)
**Apply to:** resumable migration smoke and doctor-check tests
```elixir
Repo.query("""
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = '...'
""")
```

```elixir
Repo.query(
  "SELECT indexdef FROM pg_indexes " <>
    "WHERE tablename = '...' AND indexname = '...'",
  []
)
```

Prefer direct `information_schema` and `pg_indexes` queries over new abstractions.

### Telemetry Redaction Parity Test
**Source:** [test/rindle/streaming/provider/mux/telemetry_test.exs](/Users/jon/projects/rindle/test/rindle/streaming/provider/mux/telemetry_test.exs:142)
**Apply to:** new resumable telemetry-parity coverage
```elixir
Enum.each(events, fn {:tele, event_name, _measurements, metadata} ->
  asset_id = metadata[:asset_id]

  assert asset_id == nil or asset_id =~ @redacted_id_regex

  if is_binary(asset_id) do
    refute asset_id =~ @raw_id_regex
  end
end)
```

Reuse the structure: attach handlers, drive every known emit site, drain events, then assert the secret never crosses the telemetry boundary. Adapt the matchers for `session_uri` by asserting absence rather than last-4 redaction.

## No Analog Found

None. Every scoped file has a usable in-repo analog.

## Metadata

**Analog search scope:** `priv/repo/migrations`, `lib/rindle/domain`, `lib/rindle/ops`, `lib/rindle/upload`, `test/rindle`
**Files scanned:** 17
**Pattern extraction date:** 2026-05-07
