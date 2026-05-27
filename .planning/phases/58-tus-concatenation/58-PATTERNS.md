# Phase 58: Tus Concatenation - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/storage.ex` | behaviour | request-response | `lib/rindle/storage.ex` | exact |
| `lib/rindle/storage/local.ex` | adapter | file I/O | `lib/rindle/storage/local.ex` | exact |
| `lib/rindle/storage/s3.ex` | adapter | request-response | `lib/rindle/storage/s3.ex` | exact |
| `lib/rindle/storage/gcs.ex` | adapter | request-response | `lib/rindle/storage/gcs.ex` | exact |
| `lib/rindle/upload/tus_plug.ex` | plug | request-response | `lib/rindle/upload/tus_plug.ex` | exact |
| `lib/rindle/domain/media_upload_session.ex` | schema | CRUD | `lib/rindle/domain/media_upload_session.ex` | exact |

## Pattern Assignments

### `lib/rindle/storage.ex` (behaviour, request-response)

**Analog:** `lib/rindle/storage.ex`

**Pattern** (lines 353-375):
```elixir
  @doc """
  Finalizes a tus upload after the last PATCH, converging into the trusted
  verify/promote lane.
  ...
  """
  @callback complete_part_stream(
              key :: String.t(),
              temp_path :: String.t() | nil,
              state :: tus_part_state(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
```

*Note: Add the new `@callback concatenate(final_key :: String.t(), source_keys :: [String.t()], opts :: keyword()) :: {:ok, map()} | {:error, term()}` following this documentation and type spec style.*

---

### `lib/rindle/storage/local.ex` (adapter, file I/O)

**Analog:** `lib/rindle/storage/local.ex`

**Pattern** (lines 87-111, `upload_part_stream` chunked reading):
```elixir
  @impl true
  def upload_part_stream(_key, temp_path, base_offset, _state, opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    result =
      temp_path
      |> File.stream!([], @part_copy_chunk)
      |> Enum.reduce_while({:ok, 0}, fn chunk, {:ok, written} ->
        case tus_append(session_id, chunk, opts) do
          :ok -> {:cont, {:ok, written + byte_size(chunk)}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
```
*Note: For `concatenate/3`, iterate `source_keys`, resolve their paths via `path_for(key, opts)`, stream their contents into `final_key`, and then `File.rm/1` the sources.*

---

### `lib/rindle/storage/s3.ex` (adapter, request-response)

**Analog:** `lib/rindle/storage/s3.ex`

**Pattern** (lines 188-214, `complete_part_stream`):
```elixir
  @impl true
  def complete_part_stream(key, _temp_path, state, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, upload_id} <- require_upload_id(Map.get(state, :upload_id)),
         {:ok, parts} <-
           flush_final_tail(...),
         {:ok, %{body: body}} <-
           request(
             S3.complete_multipart_upload(bucket, key, upload_id, normalize_parts(parts)),
             opts
           ) do
      File.rm(tail_path(key, opts))

      {:ok, Map.merge(%{upload_id: upload_id, upload_key: key, bucket: bucket}, body)}
    else
      {:error, reason} -> {:error, reason}
    end
  end
```
*Note: `concatenate/3` should mimic this `with` block style: resolve bucket, initiate new multipart upload for `final_key`, do `UploadPartCopy` for each key in `source_keys`, complete multipart upload, then delete the `source_keys` via `request(S3.delete_object(...))`.*

---

### `lib/rindle/storage/gcs.ex` (adapter, request-response)

**Analog:** `lib/rindle/storage/gcs.ex`

**Pattern** (lines 105-111, `verify_resumable_completion`):
```elixir
  @impl true
  def verify_resumable_completion(key, session_uri, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.verify_resumable_completion(bucket, key, session_uri, inject_credentials(opts))
    end
  end
```
*Note: The actual logic delegates to `Rindle.Storage.GCS.Client`. For `concatenate/3`, we will need a `Client.compose` wrapper calling the Google Cloud Storage compose API, followed by deleting the sources.*

---

### `lib/rindle/upload/tus_plug.ex` (plug, request-response)

**Analog:** `lib/rindle/upload/tus_plug.ex`

**Extensions Pattern** (lines 60-61):
```elixir
  @tus_version "1.0.0"
  @tus_extensions "creation,expiration,termination,checksum,creation-defer-length"
```
*Note: Must append `concatenation` to the `@tus_extensions` constant.*

**Header parsing Pattern** (lines 202-214):
```elixir
    with {:ok, length} <- parse_upload_length(conn),
         :ok <- check_max_size(length, opts[:max_size]),
         {:ok, %{session: session, upload_url: location}} <-
           create_upload_for_path(location_base(conn), opts[:profile], ...
```
*Note: Inside `handle_post/2`, add a `parse_upload_concat/1` helper similar to `parse_upload_length/1` to intercept the `Upload-Concat` header. Branch logic for `partial` vs `final`.*

---

### `lib/rindle/domain/media_upload_session.ex` (schema, CRUD)

**Analog:** `lib/rindle/domain/media_upload_session.ex`

**Pattern** (lines 43-45):
```elixir
    field :multipart_upload_id, :string
    field :multipart_parts, :map, default: %{}
    field :session_uri, :string
```
*Note: The CONTEXT.md says "store `is_partial: true` inside the existing JSON metadata column". However, `MediaUploadSession` does NOT have a `metadata` column. It has `multipart_parts: :map` (or `MediaAsset` has `metadata`). The planner must decide whether to use `multipart_parts`, add a `metadata: :map` field via migration, or store it in `MediaAsset.metadata`.*

## Shared Patterns

### Validation / Error Handling
**Source:** `lib/rindle/upload/tus_plug.ex`
**Apply to:** All plug changes
```elixir
  defp status_for(:invalid_concat), do: 400
  defp status_for(:concat_mismatch), do: 400
  # ...
  defp tus_error(conn, status, body) do
    conn
    |> put_tus_resumable()
    |> send_resp(status, body)
    |> halt()
  end
```

## Metadata

**Analog search scope:** `lib/rindle/storage/`, `lib/rindle/upload/`, `lib/rindle/domain/`
**Files scanned:** 6
**Pattern extraction date:** 2026-05-27
