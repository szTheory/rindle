# Phase 57: Tus Checksum & Defer-Length - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/upload/tus_plug.ex` | middleware | streaming/request-response | `lib/rindle/upload/tus_plug.ex` | exact |
| `lib/rindle/domain/media_upload_session.ex` | model | CRUD | `lib/rindle/domain/media_upload_session.ex` | exact |
| `priv/repo/migrations/*_add_upload_length.exs` | migration | CRUD | `priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs` | exact |
| `test/rindle/upload/tus_plug_test.exs` | test | request-response | `test/rindle/upload/tus_plug_test.exs` | exact |

## Pattern Assignments

### `lib/rindle/upload/tus_plug.ex` (middleware, streaming/request-response)

**Analog:** `lib/rindle/upload/tus_plug.ex`

**Hashing core pattern** (lines 333-338):
```elixir
    hash_ctx =
      case checksum_alg do
        "sha1" -> :crypto.hash_init(:sha)
        "sha256" -> :crypto.hash_init(:sha256)
        _ -> nil
      end
```

**Stream append hashing validation** (lines 340-362):
```elixir
    drain_result =
      case File.open(temp_path, [:write, :binary]) do
        # ...
      end

    drain_result =
      case {drain_result, expected_hash} do
        {{:ok, new_offset, final_hash_ctx}, hash} when not is_nil(hash) ->
          if :crypto.hash_final(final_hash_ctx) == hash do
            {:ok, new_offset}
          else
            {:error, :checksum_mismatch}
          end

        {{:ok, new_offset, _}, _} ->
          {:ok, new_offset}

        {{:error, reason}, _} ->
          {:error, reason}
      end
```

**Defer-Length header parsing pattern** (lines 620-632):
```elixir
  defp parse_upload_length(conn) do
    case {get_req_header(conn, "upload-length"), get_req_header(conn, "upload-defer-length")} do
      {[value], _} ->
        case Integer.parse(value) do
          {length, ""} when length >= 0 -> {:ok, length}
          _ -> {:error, :invalid_length}
        end

      {[], ["1"]} ->
        {:ok, "deferred"}

      _ ->
        {:error, :invalid_length}
    end
  end
```

**Checksum parsing validation** (lines 566-583):
```elixir
  defp parse_upload_checksum(conn) do
    case get_req_header(conn, "upload-checksum") do
      [value] ->
        case String.split(value, " ", parts: 2) do
          [alg, hash] when alg in ["sha1", "sha256"] ->
            case Base.decode64(hash) do
              {:ok, decoded} -> {:ok, alg, decoded}
              :error -> {:error, :invalid_checksum}
            end

          _ ->
            {:error, :invalid_checksum}
        end

      _ ->
        {:ok, nil, nil}
    end
  end
```

### `lib/rindle/domain/media_upload_session.ex` (model, CRUD)

**Analog:** `lib/rindle/domain/media_upload_session.ex`

**Field addition pattern** (lines 40-45):
```elixir
  schema "media_upload_sessions" do
    field :state, :string, default: "initialized"
    field :upload_key, :string
    field :upload_strategy, :string, default: "presigned_put"
    field :upload_length, :integer
```

**Changeset addition pattern** (lines 61-71):
```elixir
    |> cast(attrs, [
      :asset_id,
      :state,
      :upload_key,
      :upload_strategy,
      :upload_length,
      # ...
```

### `priv/repo/migrations/*_add_upload_length.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs`

**Alter table pattern** (lines 4-8):
```elixir
  def change do
    alter table(:media_upload_sessions) do
      add :upload_length, :integer, null: true
    end
  end
```

### `test/rindle/upload/tus_plug_test.exs` (test, request-response)

**Analog:** `test/rindle/upload/tus_plug_test.exs`

**Defer-Length test pattern** (lines 859-873):
```elixir
    test "POST with Upload-Defer-Length: 1 creates a session without length" do
      conn =
        conn(:post, "/uploads/tus")
        |> put_req_header("upload-defer-length", "1")
        |> put_req_header("upload-metadata", "filename Y2xpcC5qcGc=")
        |> route()

      assert conn.status == 201
      [location] = get_resp_header(conn, "location")
      token = location |> String.split("/") |> List.last()

      {:ok, payload} = Plug.Crypto.verify(@secret_key_base, @tus_url_salt, token)
      assert payload["length"] == "deferred"

      session = AdopterRepo.get!(MediaUploadSession, payload["session_id"])
      assert session.upload_length == nil
    end
```

**Checksum test pattern** (lines 913-926):
```elixir
    test "PATCH verifies valid sha256 checksum", %{root: root} do
      opts = opts_for(root)
      {token, _sid} = create(opts, 10)

      body = "0123456789"
      hash = :crypto.hash(:sha256, body) |> Base.encode64()

      p1 =
        conn(:patch, "/uploads/tus/" <> token, body)
        |> put_req_header("content-type", "application/offset+octet-stream")
        |> put_req_header("upload-offset", "0")
        |> put_req_header("upload-checksum", "sha256 #{hash}")
        |> TusPlug.call(opts)

      assert p1.status == 204
      assert get_resp_header(p1, "upload-offset") == ["10"]
    end
```

## Shared Patterns

### Error Handling
**Source:** `lib/rindle/upload/tus_plug.ex`
**Apply to:** `lib/rindle/upload/tus_plug.ex`
```elixir
  defp status_for(:invalid_length), do: 400
  defp status_for(:invalid_checksum), do: 400
  defp status_for(:checksum_mismatch), do: 460
```

## Metadata

**Analog search scope:** `lib/**/*.ex`, `test/**/*.exs`, `priv/repo/migrations/*.exs`
**Files scanned:** 4
**Pattern extraction date:** 2026-05-27
