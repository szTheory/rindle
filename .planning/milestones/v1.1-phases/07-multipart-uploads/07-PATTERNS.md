# Phase 07: multipart-uploads - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 18
**Analogs found:** 17 / 18

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle.ex` | service | request-response | `lib/rindle.ex` | exact |
| `lib/rindle/upload/broker.ex` | service | request-response | `lib/rindle/upload/broker.ex` | exact |
| `lib/rindle/storage.ex` | config | request-response | `lib/rindle/storage.ex` | exact |
| `lib/rindle/storage/s3.ex` | service | request-response | `lib/rindle/storage/s3.ex` | exact |
| `lib/rindle/storage/local.ex` | service | request-response | `lib/rindle/storage/local.ex` | exact |
| `lib/rindle/domain/media_upload_session.ex` | model | CRUD | `lib/rindle/domain/media_upload_session.ex` | exact |
| `lib/rindle/domain/upload_session_fsm.ex` | utility | event-driven | `lib/rindle/domain/upload_session_fsm.ex` | exact |
| `lib/rindle/ops/upload_maintenance.ex` | service | batch | `lib/rindle/ops/upload_maintenance.ex` | exact |
| `lib/rindle/workers/abort_incomplete_uploads.ex` | service | event-driven | `lib/rindle/workers/abort_incomplete_uploads.ex` | exact |
| `priv/repo/migrations/*_extend_media_upload_sessions_for_multipart.exs` | migration | CRUD | `priv/repo/migrations/20260425090200_create_media_upload_sessions.exs` | role-match |
| `test/rindle/upload/broker_test.exs` | test | request-response | `test/rindle/upload/broker_test.exs` | exact |
| `test/rindle/upload/lifecycle_integration_test.exs` | test | file-I/O | `test/rindle/upload/lifecycle_integration_test.exs` | exact |
| `test/adopter/canonical_app/lifecycle_test.exs` | test | file-I/O | `test/adopter/canonical_app/lifecycle_test.exs` | exact |
| `test/rindle/storage/storage_adapter_test.exs` | test | request-response | `test/rindle/storage/storage_adapter_test.exs` | exact |
| `test/rindle/storage/s3_test.exs` | test | file-I/O | `test/rindle/storage/s3_test.exs` | exact |
| `test/rindle/ops/upload_maintenance_test.exs` | test | batch | `test/rindle/ops/upload_maintenance_test.exs` | exact |
| `test/rindle/workers/maintenance_workers_test.exs` | test | event-driven | `test/rindle/workers/maintenance_workers_test.exs` | exact |
| `lib/rindle/domain/media_upload_part.ex` or equivalent multipart-manifest store | model | CRUD | none in repo | no-analog |

## Pattern Assignments

### `lib/rindle/upload/broker.ex` (service, request-response)

**Analog:** `lib/rindle/upload/broker.ex`

**Imports + repo seam** (`lib/rindle/upload/broker.ex:6-11`):
```elixir
alias Rindle.Domain.AssetFSM
alias Rindle.Config
alias Rindle.Domain.{MediaAsset, MediaUploadSession}
alias Rindle.Domain.UploadSessionFSM
alias Rindle.Security.StorageKey
alias Rindle.Workers.PromoteAsset
```

**Session-init transaction pattern** (`lib/rindle/upload/broker.ex:28-81`):
```elixir
def initiate_session(profile_module, opts \\ []) do
  repo = Config.repo()
  profile_name = profile_module_to_name(profile_module)
  filename = Keyword.get(opts, :filename, "unknown")
  extension = Path.extname(filename)

  asset_id = Ecto.UUID.generate()
  storage_key = StorageKey.generate(profile_name, asset_id, extension)

  expires_in_seconds = Keyword.get(opts, :expires_in, 3600)
  expires_at = DateTime.add(DateTime.utc_now(), expires_in_seconds, :second)

  case repo.transaction(fn ->
         {:ok, asset} =
           %MediaAsset{id: asset_id}
           |> MediaAsset.changeset(%{
             state: "staged",
             profile: profile_name,
             storage_key: storage_key,
             filename: filename
           })
           |> repo.insert()

         {:ok, session} =
           %MediaUploadSession{}
           |> MediaUploadSession.changeset(%{
             asset_id: asset.id,
              state: "initialized",
              upload_key: storage_key,
              expires_at: expires_at
            })
           |> repo.insert()

         session
       end) do
    {:ok, session} -> {:ok, session}
    {:error, reason} -> {:error, reason}
  end
end
```

**Capability/storage call shape for broker entrypoints** (`lib/rindle/upload/broker.ex:101-123`):
```elixir
def sign_url(session_id, opts \\ []) do
  repo = Config.repo()

  with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
       :ok <- UploadSessionFSM.transition(session.state, "signed", %{session_id: session.id}),
       asset <- repo.preload(session, :asset).asset,
       {:ok, profile_module} <- profile_name_to_module(asset.profile),
       adapter <- profile_module.storage_adapter(),
       expires_in <- Keyword.get(opts, :expires_in, 3600),
       {:ok, presigned} <- adapter.presigned_put(session.upload_key, expires_in, opts) do
    repo.transaction(fn ->
      {:ok, updated_session} =
        session
        |> MediaUploadSession.changeset(%{state: "signed"})
        |> repo.update()

      %{session: updated_session, presigned: presigned}
    end)
  else
    nil -> {:error, :not_found}
    {:error, reason} -> {:error, reason}
  end
end
```

**Trusted verification/promotion lane** (`lib/rindle/upload/broker.ex:143-207`):
```elixir
def verify_completion(session_id, opts \\ []) do
  repo = Config.repo()

  with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
       asset <- repo.preload(session, :asset).asset,
       {:ok, profile_module} <- profile_name_to_module(asset.profile),
       adapter <- profile_module.storage_adapter(),
       {:ok, metadata} <- adapter.head(session.upload_key, opts),
       :ok <- UploadSessionFSM.transition(session.state, "verifying", %{session_id: session.id}),
       :ok <- AssetFSM.transition(asset.state, "validating", %{asset_id: asset.id}) do
    execute_verify_completion(repo, session, asset, profile_module, metadata)
  else
    nil -> {:error, :not_found}
    {:error, :not_found} -> {:error, :storage_object_missing}
    {:error, reason} -> {:error, reason}
  end
end
```

**Multi + enqueue pattern** (`lib/rindle/upload/broker.ex:162-207`):
```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(
  :verifying_session,
  MediaUploadSession.changeset(session, %{state: "verifying"})
)
|> Ecto.Multi.run(:verify_fsm_complete, fn _repo, %{verifying_session: vs} ->
  do_fsm_transition(vs)
end)
|> Ecto.Multi.update(
  :session,
  fn %{verifying_session: vs} ->
    MediaUploadSession.changeset(vs, %{
      state: "completed",
      verified_at: DateTime.utc_now()
    })
  end
)
|> Ecto.Multi.update(
  :asset,
  MediaAsset.changeset(asset, %{
    state: "validating",
    byte_size: Map.get(metadata, :size),
    content_type: Map.get(metadata, :content_type)
  })
)
|> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset.id}))
|> repo.transaction()
```

Use this file as the primary analog for multipart initiation, per-part signing, manifest persistence, completion, and post-complete verification. Keep `Config.repo()` at the top of each broker entrypoint.

---

### `lib/rindle/storage.ex` (config, request-response)

**Analog:** `lib/rindle/storage.ex`

**Behaviour contract pattern** (`lib/rindle/storage.ex:1-28`):
```elixir
defmodule Rindle.Storage do
  @moduledoc """
  Behaviour contract for all storage adapters used by Rindle.

  Storage I/O must never happen inside database transactions. Callers should
  persist domain state first, then execute storage side effects in separate
  steps.
  """

  @callback presigned_put(key :: String.t(), expires_in :: pos_integer(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback head(key :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback capabilities() :: [atom()]
end
```

Multipart callbacks should extend this behaviour in the same tagged-tuple style. Keep capability advertising additive via `capabilities/0`.

---

### `lib/rindle/storage/s3.ex` (service, request-response)

**Analog:** `lib/rindle/storage/s3.ex`

**Imports + behaviour pattern** (`lib/rindle/storage/s3.ex:6-8`):
```elixir
@behaviour Rindle.Storage

alias ExAws.S3
```

**Tagged storage wrapper pattern** (`lib/rindle/storage/s3.ex:11-24`):
```elixir
def store(key, source_path, opts) do
  with {:ok, bucket} <- bucket(opts),
       {:ok, body} <- File.read(source_path),
       {:ok, response} <-
         request(S3.put_object(bucket, key, body, object_opts(opts)), opts) do
    {:ok, %{key: key, bucket: bucket, response: response}}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

**Presign pattern** (`lib/rindle/storage/s3.ex:63-70`):
```elixir
def presigned_put(key, expires_in, opts) do
  with {:ok, bucket} <- bucket(opts),
       {:ok, url} <-
         S3.presigned_url(s3_config(opts), :put, bucket, key, expires_in: expires_in) do
    {:ok, %{url: url, method: :put, headers: %{}}}
  end
end
```

**Read/normalize remote metadata pattern** (`lib/rindle/storage/s3.ex:72-91`):
```elixir
def head(key, opts) do
  with {:ok, bucket} <- bucket(opts) do
    handle_head_response(request(S3.head_object(bucket, key), opts))
  end
end

defp handle_head_response({:ok, %{headers: headers}}) do
  normalized = Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end)

  {:ok,
   %{
     size: parse_size(Map.get(normalized, "content-length")),
     content_type: Map.get(normalized, "content-type")
   }}
end

defp handle_head_response({:error, %{status_code: 404}}), do: {:error, :not_found}
defp handle_head_response({:error, reason}), do: {:error, reason}
```

**Capability list** (`lib/rindle/storage/s3.ex:93-94`):
```elixir
def capabilities, do: [:presigned_put, :head, :signed_url]
```

**Shared request/config helpers** (`lib/rindle/storage/s3.ex:107-122`):
```elixir
defp bucket(opts) do
  case Keyword.get(opts, :bucket) || Application.get_env(:rindle, __MODULE__, [])[:bucket] do
    nil -> {:error, :missing_bucket}
    bucket -> {:ok, bucket}
  end
end

defp request(operation, opts) do
  ExAws.request(operation, Keyword.get(opts, :aws_config, []))
rescue
  exception -> {:error, exception}
end

defp s3_config(opts) do
  ExAws.Config.new(:s3, Keyword.get(opts, :aws_config, []))
end
```

Add multipart wrappers here, not in the broker. Follow the existing `with` + `{:ok, ...} | {:error, ...}` shape and extend `capabilities/0` with a multipart capability atom.

---

### `lib/rindle/storage/local.ex` (service, request-response)

**Analog:** `lib/rindle/storage/local.ex`

**Unsupported/local-development baseline** (`lib/rindle/storage/local.ex:45-63`):
```elixir
@impl true
def presigned_put(key, _expires_in, opts) do
  {:ok, %{url: "file://" <> storage_path(key, opts), method: "PUT", headers: []}}
end

@impl true
def head(key, opts) do
  path = storage_path(key, opts)

  if File.exists?(path) do
    {:ok, %{size: File.stat!(path).size}}
  else
    {:error, :not_found}
  end
end

@impl true
def capabilities, do: [:local, :presigned_put]
```

For multipart support, use this file as the explicit unsupported-adapter analog: do not pretend multipart exists here, and do not add capability atoms unless the implementation is real.

---

### `lib/rindle.ex` (service, request-response)

**Analog:** `lib/rindle.ex`

**Public facade delegation pattern** (`lib/rindle.ex:38-75`):
```elixir
@spec initiate_upload(module(), keyword()) :: {:ok, map()} | {:error, term()}
def initiate_upload(profile, opts \\ []) do
  Broker.initiate_session(profile, opts)
end

@spec verify_upload(binary(), keyword()) :: {:ok, map()} | {:error, term()}
def verify_upload(session_id, opts \\ []) do
  Broker.verify_completion(session_id, opts)
end
```

**Storage facade delegation pattern** (`lib/rindle.ex:385-404`):
```elixir
@spec head(module(), String.t(), keyword()) :: storage_result()
def head(profile, key, opts \\ []) do
  invoke_storage(profile, :head, [key, opts])
end

@spec presigned_put(module(), String.t(), pos_integer(), keyword()) :: storage_result()
def presigned_put(profile, key, expires_in, opts \\ []) do
  invoke_storage(profile, :presigned_put, [key, expires_in, opts])
end
```

Expose any adopter-facing multipart API here by delegating to `Broker` or the storage facade, matching the current public tagged-tuple style and arity patterns.

---

### `lib/rindle/domain/media_upload_session.ex` (model, CRUD)

**Analog:** `lib/rindle/domain/media_upload_session.ex`

**Schema + allowed-field pattern** (`lib/rindle/domain/media_upload_session.ex:47-66`):
```elixir
schema "media_upload_sessions" do
  field :state, :string, default: "initialized"
  field :upload_key, :string
  field :expires_at, :utc_datetime_usec
  field :verified_at, :utc_datetime_usec
  field :failure_reason, :string

  belongs_to :asset, Rindle.Domain.MediaAsset

  timestamps()
end

def changeset(upload_session, attrs) do
  upload_session
  |> cast(attrs, [:asset_id, :state, :upload_key, :expires_at, :verified_at, :failure_reason])
  |> validate_required([:asset_id, :state, :upload_key, :expires_at])
  |> validate_inclusion(:state, @states)
  |> foreign_key_constraint(:asset_id)
end
```

If multipart metadata stays on the session row, follow this file’s field/cast/validate pattern. If it moves to a separate manifest table, keep this session schema as the lifecycle authority and only add the minimum linking fields needed.

---

### `lib/rindle/domain/upload_session_fsm.ex` (utility, event-driven)

**Analog:** `lib/rindle/domain/upload_session_fsm.ex`

**Transition map pattern** (`lib/rindle/domain/upload_session_fsm.ex:8-18`):
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

**Failure logging pattern** (`lib/rindle/domain/upload_session_fsm.ex:23-53`):
```elixir
def transition(current_state, target_state, context \\ %{}) do
  if target_state in Map.get(@allowed_transitions, current_state, []) do
    :ok
  else
    log_transition_failure(current_state, target_state, context)
    {:error, {:invalid_transition, current_state, target_state}}
  end
end

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

If multipart needs any new states, extend this map and keep invalid-transition logging intact. If no new states are needed, preserve the current FSM and only reuse existing transitions.

---

### `lib/rindle/ops/upload_maintenance.ex` (service, batch)

**Analog:** `lib/rindle/ops/upload_maintenance.ex`

**Imports and current repo seam** (`lib/rindle/ops/upload_maintenance.ex:21-28`):
```elixir
require Logger

import Ecto.Query

alias Rindle.Domain.MediaUploadSession
alias Rindle.Domain.UploadSessionFSM
alias Rindle.Repo
```

Phase 7 should copy this structure but replace hard-coded `Rindle.Repo` usage with the Phase 6 `Rindle.Config.repo/0` seam.

**Public batch API pattern** (`lib/rindle/ops/upload_maintenance.ex:68-85`, `102-116`):
```elixir
@spec cleanup_orphans(keyword()) :: {:ok, cleanup_report()} | {:error, term()}
def cleanup_orphans(opts \\ []) do
  dry_run? = Keyword.get(opts, :dry_run, true)
  storage_mod = Keyword.get(opts, :storage, nil)

  case fetch_expired_sessions() do
    {:ok, sessions} ->
      report = process_cleanup(sessions, dry_run?, storage_mod)
      {:ok, report}

    {:error, reason} ->
      Logger.error("rindle.upload_maintenance.cleanup_query_failed",
        reason: inspect(reason)
      )

      {:error, reason}
  end
end

@spec abort_incomplete_uploads(keyword()) :: {:ok, abort_report()} | {:error, term()}
def abort_incomplete_uploads(opts \\ []) when is_list(opts) do
  case fetch_incomplete_timed_out_sessions() do
    {:ok, sessions} ->
      report = process_abort(sessions)
      {:ok, report}

    {:error, reason} ->
      Logger.error("rindle.upload_maintenance.abort_query_failed",
        reason: inspect(reason)
      )

      {:error, reason}
  end
end
```

**Cleanup query and delete-order invariant** (`lib/rindle/ops/upload_maintenance.ex:122-140`, `201-265`):
```elixir
query =
  from(s in MediaUploadSession,
    where: s.state == "expired",
    select: s
  )

case attempt_storage_delete(session, storage_mod) do
  {:ok, object_increment} ->
    proceed_with_db_delete(session, acc, object_increment, _skipped_increment = 0)

  {:skipped, skipped_increment} ->
    proceed_with_db_delete(session, acc, _object_increment = 0, skipped_increment)

  :storage_error ->
    Map.update!(acc, :storage_errors, &(&1 + 1))
end
```

**Abort/expire pattern** (`lib/rindle/ops/upload_maintenance.ex:267-317`):
```elixir
defp process_abort(sessions) do
  base_report = %{
    sessions_found: length(sessions),
    sessions_aborted: 0,
    abort_errors: 0
  }

  Enum.reduce(sessions, base_report, fn session, acc ->
    expire_session(session, acc)
  end)
end

defp expire_session(session, acc) do
  case UploadSessionFSM.transition(session.state, "expired", %{session_id: session.id}) do
    :ok ->
      do_expire_session(session, acc)

    {:error, {:invalid_transition, from, to}} ->
      Logger.warning("rindle.upload_maintenance.session_expiry_invalid_transition",
        session_id: session.id,
        from_state: from,
        to_state: to
      )

      Map.update!(acc, :abort_errors, &(&1 + 1))
  end
end
```

Multipart abort/cleanup belongs here. Preserve the existing two-step lifecycle: mark terminal first, perform remote storage abort outside any DB transaction, and keep the row when cleanup needs retry.

---

### `lib/rindle/workers/abort_incomplete_uploads.ex` (service, event-driven)

**Analog:** `lib/rindle/workers/abort_incomplete_uploads.ex`

**Worker contract** (`lib/rindle/workers/abort_incomplete_uploads.ex:65-99`):
```elixir
use Oban.Worker, queue: :rindle_maintenance, max_attempts: 3

require Logger

alias Rindle.Ops.UploadMaintenance

@impl Oban.Worker
def perform(%Oban.Job{}) do
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
        %{
          profile: :unknown,
          adapter: :unknown,
          worker: __MODULE__
        }
      )

      :ok

    {:error, reason} ->
      Logger.error("rindle.workers.abort_incomplete_uploads.failed",
        reason: inspect(reason)
      )

      {:error, reason}
  end
end
```

If Phase 7 adds a dedicated multipart-abort worker, copy this shape exactly: thin worker, all logic in `UploadMaintenance`, structured logs, telemetry at the worker boundary only.

---

### `priv/repo/migrations/*_extend_media_upload_sessions_for_multipart.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260425090200_create_media_upload_sessions.exs`

**Migration shape** (`priv/repo/migrations/20260425090200_create_media_upload_sessions.exs:1-18`):
```elixir
defmodule Rindle.Repo.Migrations.CreateMediaUploadSessions do
  use Ecto.Migration

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
end
```

If multipart state lives on `media_upload_sessions`, extend this table with the same straightforward `add` + `index` style. If the planner chooses a separate part-manifest table, there is no close repo analog for that new schema and migration.

---

### Tests: broker, storage, maintenance, worker, and MinIO integration

**Broker repo-seam/unit pattern** (`test/rindle/upload/broker_test.exs:13-50`, `93-176`):
```elixir
defmodule TestRepoProbe do
  def transaction(fun) when is_function(fun, 0) do
    notify(:transaction)
    Rindle.Adopter.CanonicalApp.Repo.transaction(fun)
  end

  def insert(changeset) do
    notify({:insert, changeset.data.__struct__})
    Rindle.Adopter.CanonicalApp.Repo.insert(changeset)
  end
end

test "transitions session to signed and returns presigned URL" do
  {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")

  expect(Rindle.StorageMock, :presigned_put, fn key, _expires_in, _opts ->
    assert key == session.upload_key
    {:ok, %{url: "https://example.com/upload", method: :put, headers: %{}}}
  end)

  {:ok, %{session: updated_session, presigned: presigned}} = Broker.sign_url(session.id)
  assert updated_session.state == "signed"
  assert presigned.url == "https://example.com/upload"
end
```

Use this for multipart broker unit tests, especially repo seam proof and adapter mock expectations.

**Storage behaviour truthfulness pattern** (`test/rindle/storage/storage_adapter_test.exs:32-47`):
```elixir
test "both adapters implement the storage behaviour callbacks" do
  callbacks = Rindle.Storage.behaviour_info(:callbacks)

  for {name, arity} <- callbacks do
    assert function_exported?(Local, name, arity)
    assert function_exported?(S3, name, arity)
  end
end

test "capability lists are truthful for local and s3 adapters" do
  assert [:local, :presigned_put] == Local.capabilities()
  assert [:presigned_put, :head, :signed_url] == S3.capabilities()
end
```

Use this for multipart callback coverage and capability honesty assertions.

**MinIO S3 adapter integration pattern** (`test/rindle/storage/s3_test.exs:26-66`):
```elixir
@tag :minio
@tag skip: @minio_skip_reason
test "round-trips store, head, download, url, delete, and not_found against MinIO" do
  opts = [
    bucket: @minio_bucket,
    content_type: "image/jpeg",
    aws_config: [
      access_key_id: @minio_access_key,
      secret_access_key: @minio_secret_key,
      scheme: "http://",
      host: uri.host,
      port: uri.port,
      region: @minio_region
    ]
  ]

  assert {:ok, %{key: ^key}} = S3.store(key, source, opts)
  assert {:ok, %{size: 20, content_type: "image/jpeg"}} = S3.head(key, opts)
  assert {:ok, %{url: put_url, method: :put, headers: %{}}} = S3.presigned_put(key, 60, opts)
  assert {:ok, _result} = S3.delete(key, opts)
end
```

Use this as the direct analog for MinIO-backed multipart adapter proof.

**Broker integration with real file writes** (`test/rindle/upload/lifecycle_integration_test.exs:58-80`):
```elixir
test "direct upload completes through broker and queues promotion", %{root: root} do
  source = write_fixture(root, "direct-source.png")

  {:ok, session} = Broker.initiate_session(LocalProfile, filename: "direct.png")
  {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)

  upload_path = storage_path_from_url(presigned.url)
  File.mkdir_p!(Path.dirname(upload_path))
  File.cp!(source, upload_path)

  {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)

  assert Rindle.Repo.get!(MediaUploadSession, session.id).state == "completed"
  assert_enqueued worker: PromoteAsset, args: %{"asset_id" => asset.id}
end
```

Use this for local/integration multipart lifecycle proof when not using MinIO.

**Canonical adopter MinIO proof** (`test/adopter/canonical_app/lifecycle_test.exs:37-99`, `101-125`, `192-220`):
```elixir
setup do
  minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
  bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")
  access_key = System.get_env("RINDLE_MINIO_ACCESS_KEY", "minioadmin")
  secret_key = System.get_env("RINDLE_MINIO_SECRET_KEY", "minioadmin")
  region = System.get_env("RINDLE_MINIO_REGION", "us-east-1")

  Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)
  Application.put_env(:rindle, Rindle.Storage.S3, bucket: bucket)
end

test "direct upload through MinIO promotes asset, generates ready variant, and serves signed URL" do
  {:ok, session} = Broker.initiate_session(AdopterProfile, filename: "adopter.png")
  {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
  :ok = put_to_presigned_url(presigned.url, @png_1x1)
  {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
end
```

Use this as the highest-confidence analog for the required real S3-compatible multipart proof.

**Maintenance correctness tests** (`test/rindle/ops/upload_maintenance_test.exs:91-177`, `204-266`):
```elixir
test "preserves DB row when storage delete fails so a future run can retry" do
  expect(Rindle.StorageMock, :delete, fn _key, _opts ->
    {:error, :storage_unavailable}
  end)

  {:ok, report} =
    UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

  assert report.storage_errors >= 1
  assert report.sessions_deleted == 0
end

test "transitions timed-out uploading sessions to expired" do
  {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])
  assert report.sessions_aborted >= 1
end
```

Use this file for multipart abort/retry invariants.

**Worker delegation/telemetry pattern** (`test/rindle/workers/maintenance_workers_test.exs:122-155`, `245-264`):
```elixir
test "delegates to UploadMaintenance.abort_incomplete_uploads/1 and returns :ok" do
  assert :ok = perform_job(AbortIncompleteUploads, %{})
end

test "AbortIncompleteUploads emits [:rindle, :cleanup, :run] on success", %{ref: ref} do
  assert :ok = perform_job(AbortIncompleteUploads, %{})

  assert_received {[:rindle, :cleanup, :run], ^ref, measurements, metadata}
  assert is_integer(measurements.sessions_aborted)
  assert metadata.worker == AbortIncompleteUploads
end
```

Use this for any multipart cleanup worker tests.

---

### Capability gate pattern for unsupported adapters

**Analog:** `lib/rindle/delivery.ex` and `test/rindle/delivery_test.exs`

**Capability-check helper** (`lib/rindle/delivery.ex:183-210`):
```elixir
defp ensure_signed_delivery_support(_adapter, :public), do: :ok

defp ensure_signed_delivery_support(adapter, :private) do
  capabilities = safe_capabilities(adapter)

  if :signed_url in capabilities do
    :ok
  else
    {:error, {:delivery_unsupported, :signed_url}}
  end
end

defp safe_capabilities(adapter) do
  case adapter.capabilities() do
    caps when is_list(caps) -> caps
    _ -> []
  end
rescue
  _ -> []
end
```

**Unsupported-capability assertion** (`test/rindle/delivery_test.exs:81-96`):
```elixir
test "private delivery without signed capability is rejected" do
  key = "assets/asset-1/original.jpg"

  assert {:error, {:delivery_unsupported, :signed_url}} =
           Rindle.Delivery.url(UnsupportedProfile, key)
end
```

Use this exact pattern for multipart capability gating: safe capability lookup first, explicit tagged unsupported error before any adapter-specific call.

## Shared Patterns

### Runtime repo seam
**Sources:** `lib/rindle/upload/broker.ex:28-29`, `lib/rindle/upload/broker.ex:101-102`, `lib/rindle/upload/broker.ex:143-145`, `test/rindle/upload/broker_test.exs:72-88`
**Apply to:** `Broker`, `UploadMaintenance`, multipart tests, any new worker that touches persistence.
```elixir
repo = Config.repo()
```

```elixir
Application.put_env(:rindle, :repo, TestRepoProbe)
Application.put_env(:rindle, :repo_probe_owner, self())
```

### Capability honesty
**Sources:** `lib/rindle/delivery.ex:185-210`, `test/rindle/storage/storage_adapter_test.exs:44-47`
**Apply to:** multipart initiation, multipart part signing, multipart completion.
```elixir
capabilities = safe_capabilities(adapter)

if :signed_url in capabilities do
  :ok
else
  {:error, {:delivery_unsupported, :signed_url}}
end
```

### Storage side effects outside transactions
**Sources:** `lib/rindle/storage.ex:3-8`, `lib/rindle/ops/upload_maintenance.ex:201-220`
**Apply to:** remote multipart initiate/complete/abort flows.
```elixir
Storage I/O must never happen inside database transactions. Callers should
persist domain state first, then execute storage side effects in separate
steps.
```

```elixir
case attempt_storage_delete(session, storage_mod) do
  {:ok, object_increment} -> proceed_with_db_delete(session, acc, object_increment, _skipped_increment = 0)
  :storage_error -> Map.update!(acc, :storage_errors, &(&1 + 1))
end
```

### Verification remains the trust boundary
**Sources:** `lib/rindle/upload/broker.ex:146-154`, `lib/rindle/upload/broker.ex:162-189`
**Apply to:** multipart completion API and tests.
```elixir
{:ok, metadata} <- adapter.head(session.upload_key, opts),
:ok <- UploadSessionFSM.transition(session.state, "verifying", %{session_id: session.id}),
:ok <- AssetFSM.transition(asset.state, "validating", %{asset_id: asset.id}) do
  execute_verify_completion(repo, session, asset, profile_module, metadata)
end
```

### Worker boundary for telemetry
**Sources:** `lib/rindle/workers/abort_incomplete_uploads.ex:72-99`, `test/rindle/ops/upload_maintenance_test.exs:269-297`
**Apply to:** any new multipart cleanup worker.
```elixir
:telemetry.execute(
  [:rindle, :cleanup, :run],
  %{sessions_aborted: report.sessions_aborted},
  %{profile: :unknown, adapter: :unknown, worker: __MODULE__}
)
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/rindle/domain/media_upload_part.ex` or equivalent multipart-manifest persistence module | model | CRUD | Repo has no existing child-table schema for upload-part manifests; planner should use `MediaUploadSession` lifecycle ownership plus `07-RESEARCH.md` guidance for authoritative `{part_number, etag}` persistence. |

## Metadata

**Analog search scope:** `lib/rindle/`, `priv/repo/migrations/`, `test/rindle/`, `test/adopter/`, `.planning/phases/07-multipart-uploads/`
**Files scanned:** 17 code/test files + 2 phase input files + 1 migration
**Pattern extraction date:** 2026-04-28
