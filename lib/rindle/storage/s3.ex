defmodule Rindle.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter powered by ExAws.

  ## tus single-node constraint

  The S3 tus backing (`upload_part_stream/5`) buffers each PATCH's sub-5-MiB
  tail remainder on **node-local disk** under `Rindle.tmp/tus/`, while the
  authoritative cross-PATCH bookkeeping (offset, `upload_id`, committed `parts`)
  lives in the **shared DB**. Because the tail buffer is node-local, the S3 tus
  backing REQUIRES single-node or sticky-session routing: a resumed PATCH must
  reach the same node that holds the in-progress tail buffer.

  A cross-node resume — where the DB shows a mid-multipart upload (a non-empty
  `upload_id` plus at least one committed part) but the expected tail file is
  absent on this node — is detected and fails loudly with
  `{:error, :tus_tail_missing}` rather than silently re-slicing from a fresh
  empty tail (which would corrupt the assembled object). Multi-node operators
  MUST pin tus PATCHes to a single node (sticky sessions) or accept this loud
  failure on misrouted resumes.
  """

  @behaviour Rindle.Storage

  alias ExAws.S3

  # S3 minimum non-final multipart part size (5 MiB). Every part except the LAST
  # must be >= this size, so a tus PATCH carrying fewer bytes (especially a
  # resumed tail) is buffered on disk until a full 5 MiB part accumulates.
  @s3_min_part_size 5 * 1024 * 1024

  # Read size when streaming the per-PATCH temp file onto the tail buffer. Keeps
  # the body off the heap — bytes flow temp_file -> tail_file in bounded chunks,
  # never accumulated in a binary (T-43-03 / RESEARCH anti-pattern line 282).
  @tail_copy_chunk 1024 * 1024

  @impl true
  def store(key, source_path, opts) do
    # Return shape mirrors Rindle.Storage.Local.store/3 — `%{key: key, ...}` —
    # so consumers of the Storage behaviour (e.g. Rindle.Workers.ProcessVariant)
    # can read `storage_meta.key` uniformly across adapters. Surfaced by the
    # adopter lifecycle test in Plan 05-04 (CI-08).
    with {:ok, bucket} <- bucket(opts),
         {:ok, body} <- File.read(source_path),
         {:ok, response} <-
           request(S3.put_object(bucket, key, body, object_opts(opts)), opts) do
      {:ok, %{key: key, bucket: bucket, response: response}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def download(key, destination_path, opts) do
    # ExAws.S3.download_file returns an ExAws.S3.Download struct; ExAws.request
    # on a Download struct returns {:ok, :done} on success, NOT bare :ok.
    # Surfaced by the adopter lifecycle test in Plan 05-04 (CI-08); this was
    # a latent Rule-1 bug (Local adapter is used everywhere upstream so no
    # downstream test exercised this S3-specific path until now).
    with {:ok, bucket} <- bucket(opts),
         :ok <- File.mkdir_p(Path.dirname(destination_path)),
         {:ok, _result} <-
           S3.download_file(bucket, key, destination_path)
           |> request(opts) do
      {:ok, destination_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, result} <- request(S3.delete_object(bucket, key), opts) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(key, opts) do
    with {:ok, bucket} <- bucket(opts) do
      S3.presigned_url(s3_config(opts), :get, bucket, key,
        expires_in: Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())
      )
    end
  end

  @impl true
  def presigned_put(key, expires_in, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, url} <-
           S3.presigned_url(s3_config(opts), :put, bucket, key, expires_in: expires_in) do
      {:ok, %{url: url, method: :put, headers: %{}}}
    end
  end

  @impl true
  def initiate_multipart_upload(key, part_size, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, %{body: %{upload_id: upload_id}}} <-
           request(S3.initiate_multipart_upload(bucket, key, object_opts(opts)), opts) do
      {:ok, %{upload_id: upload_id, upload_key: key, bucket: bucket, part_size: part_size}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def presigned_upload_part(key, upload_id, part_number, expires_in, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, url} <-
           S3.presigned_url(s3_config(opts), :put, bucket, key,
             expires_in: expires_in,
             query_params: [
               {"partNumber", Integer.to_string(part_number)},
               {"uploadId", upload_id}
             ]
           ) do
      {:ok,
       %{
         url: url,
         method: :put,
         headers: %{},
         part_number: part_number,
         upload_id: upload_id
       }}
    end
  end

  @impl true
  def complete_multipart_upload(key, upload_id, parts, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, %{body: body}} <-
           request(
             S3.complete_multipart_upload(bucket, key, upload_id, normalize_parts(parts)),
             opts
           ) do
      {:ok, Map.merge(%{upload_id: upload_id, upload_key: key, bucket: bucket}, body)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def abort_multipart_upload(key, upload_id, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, response} <- request(S3.abort_multipart_upload(bucket, key, upload_id), opts) do
      {:ok, %{response: response, upload_id: upload_id, upload_key: key, bucket: bucket}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def upload_part_stream(key, temp_path, base_offset, state, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- guard_local_tail_present(tail_path(key, opts), state),
         {:ok, upload_id} <- ensure_upload_id(bucket, key, state, opts),
         {:ok, bytes_written} <- append_to_tail(tail_path(key, opts), temp_path),
         {:ok, parts, next_number} <-
           drain_tail_parts(
             bucket,
             key,
             upload_id,
             tail_path(key, opts),
             Map.get(state, :parts, []),
             next_part_number(state),
             opts
           ) do
      {:ok,
       state
       |> Map.put(:offset, base_offset + bytes_written)
       |> Map.put(:upload_id, upload_id)
       |> Map.put(:parts, parts)
       |> Map.put(:next_part_number, next_number)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def complete_part_stream(key, _temp_path, state, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, upload_id} <- require_upload_id(Map.get(state, :upload_id)),
         {:ok, parts} <-
           flush_final_tail(
             bucket,
             key,
             upload_id,
             tail_path(key, opts),
             Map.get(state, :parts, []),
             next_part_number(state),
             opts
           ),
         {:ok, %{body: body}} <-
           request(
             S3.complete_multipart_upload(bucket, key, upload_id, normalize_parts(parts)),
             opts
           ) do
      # Best-effort tail cleanup; the Rindle.tmp/ reaper sweeps any residue.
      File.rm(tail_path(key, opts))

      {:ok, Map.merge(%{upload_id: upload_id, upload_key: key, bucket: bucket}, body)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def head(key, opts) do
    with {:ok, bucket} <- bucket(opts) do
      handle_head_response(request(S3.head_object(bucket, key), opts))
    end
  end

  defp handle_head_response({:ok, %{headers: headers}}) do
    # Normalize headers to lowercase to handle varying S3 provider implementations
    normalized = Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end)

    {:ok,
     %{
       size: parse_size(Map.get(normalized, "content-length")),
       content_type: Map.get(normalized, "content-type")
     }}
  end

  defp handle_head_response({:error, %{status_code: 404}}), do: {:error, :not_found}
  defp handle_head_response({:error, {:http_error, 404, _response}}), do: {:error, :not_found}
  defp handle_head_response({:error, reason}), do: {:error, reason}

  @impl true
  def capabilities, do: [:presigned_put, :head, :signed_url, :multipart_upload, :tus_upload]

  @doc """
  Canonical reaper-facing path of the on-disk tail buffer for a tus session.

  Returns the EXACT file `upload_part_stream/5` writes its sub-5-MiB tail
  remainder to for `session_id`, so cleanup code (the orphan reaper /
  `Rindle.Ops.UploadMaintenance`) can delete the real file rather than guessing
  at the encoding. The adapter owns the one canonical tail-path computation
  here: the path is `Base.url_encode64(session_id, padding: false) <> ".tail"`
  under the sweepable `Rindle.tmp/tus/` root — never the raw id (CR-02).

  Pass `:root` to override the base dir (used by tests for per-test isolation).
  Delegates to the private `tail_path/2`, threading `session_id` as both the
  key and the `:session_id` opt so the encoding is identical regardless of how
  the original PATCH was keyed. There is exactly one `Base.url_encode64` site
  (`tail_filename/1`); this helper does not re-encode.
  """
  @spec tus_tail_path(binary(), keyword()) :: Path.t()
  def tus_tail_path(session_id, opts \\ []) when is_binary(session_id) do
    tail_path(session_id, Keyword.put_new(opts, :session_id, session_id))
  end

  # --- tus tail-buffer internals (TUS-06) ---------------------------------

  # Lazily initiate the S3 multipart upload on the first PATCH; subsequent
  # PATCHes thread the same UploadId back through `state`.
  defp ensure_upload_id(_bucket, _key, %{upload_id: id}, _opts) when is_binary(id) and id != "",
    do: {:ok, id}

  defp ensure_upload_id(bucket, key, _state, opts) do
    case request(S3.initiate_multipart_upload(bucket, key, object_opts(opts)), opts) do
      {:ok, %{body: %{upload_id: upload_id}}} -> {:ok, upload_id}
      {:error, reason} -> {:error, reason}
    end
  end

  defp require_upload_id(id) when is_binary(id) and id != "", do: {:ok, id}
  defp require_upload_id(_), do: {:error, :missing_upload_id}

  # Cross-node resume guard (CR-04, threat T-43-06-01). The sub-5-MiB tail
  # remainder is node-local disk state, while offset/upload_id/parts live in the
  # shared DB. A mid-multipart resume is identified by BOTH a non-empty upload_id
  # AND at least one already-committed part — meaning a prior node sliced and
  # persisted a tail boundary. If that node's tail file is absent here, this
  # PATCH was routed to a different node; re-slicing from a fresh empty tail
  # would silently corrupt the assembled object, so fail loudly instead.
  #
  # A FIRST PATCH legitimately has no committed parts (and usually a nil
  # upload_id), so the `parts != []` signal prevents a false positive on the
  # happy first-write path — a brand-new multipart has no tail yet by design.
  #
  # The error surface is the bare `:tus_tail_missing` atom only: the absolute
  # tail path and session_uri are NOT included (threat T-43-06-02 — no
  # internal-path disclosure across the adapter boundary).
  defp guard_local_tail_present(tail_path, state) do
    upload_id = Map.get(state, :upload_id)
    parts = Map.get(state, :parts, [])
    mid_multipart? = is_binary(upload_id) and upload_id != "" and is_list(parts) and parts != []

    if mid_multipart? and not File.exists?(tail_path) do
      {:error, :tus_tail_missing}
    else
      :ok
    end
  end

  # Stream the per-PATCH temp file onto the tail buffer in bounded chunks.
  # Returns the number of bytes appended (== this PATCH's payload size). The
  # body never lands in a single binary on the heap (T-43-03).
  defp append_to_tail(tail_path, temp_path) do
    with :ok <- File.mkdir_p(Path.dirname(tail_path)),
         {:ok, dest} <- File.open(tail_path, [:append, :binary]) do
      try do
        written =
          temp_path
          |> File.stream!([], @tail_copy_chunk)
          |> Enum.reduce(0, fn chunk, acc ->
            IO.binwrite(dest, chunk)
            acc + byte_size(chunk)
          end)

        {:ok, written}
      after
        File.close(dest)
      end
    end
  end

  # While the tail buffer holds a full non-final part, slice off exactly one
  # @s3_min_part_size part, UploadPart it, capture the server-issued ETag, and
  # rewrite the tail to the leftover. part_number is 1-based, strictly
  # increasing, and persisted (S3 reassembles by part_number, never arrival).
  defp drain_tail_parts(bucket, key, upload_id, tail_path, parts, part_number, opts) do
    case File.stat(tail_path) do
      {:ok, %{size: size}} when size >= @s3_min_part_size ->
        with {:ok, body} <- read_leading_part(tail_path),
             {:ok, part} <-
               upload_one_part(bucket, key, upload_id, part_number, body, opts),
             :ok <- truncate_tail_head(tail_path, @s3_min_part_size) do
          drain_tail_parts(
            bucket,
            key,
            upload_id,
            tail_path,
            parts ++ [part],
            part_number + 1,
            opts
          )
        end

      {:ok, _stat} ->
        {:ok, parts, part_number}

      {:error, :enoent} ->
        {:ok, parts, part_number}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # On completion, flush any remaining tail (any size — the LAST part has no
  # 5 MiB floor) as the final part, then return the full ordered parts list.
  defp flush_final_tail(bucket, key, upload_id, tail_path, parts, part_number, opts) do
    case File.stat(tail_path) do
      {:ok, %{size: size}} when size > 0 ->
        with {:ok, body} <- File.read(tail_path),
             {:ok, part} <-
               upload_one_part(bucket, key, upload_id, part_number, body, opts) do
          {:ok, parts ++ [part]}
        end

      {:ok, _stat} ->
        {:ok, parts}

      {:error, :enoent} ->
        {:ok, parts}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Read exactly one @s3_min_part_size slice from the front of the tail file.
  defp read_leading_part(tail_path) do
    case File.open(tail_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          case IO.binread(file, @s3_min_part_size) do
            data when is_binary(data) -> {:ok, data}
            :eof -> {:ok, ""}
            {:error, reason} -> {:error, reason}
          end
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Drop the first `drop` bytes from the tail file, rewriting it to the leftover.
  # The leftover is streamed (bounded chunks) into a sibling temp file and then
  # renamed over the tail — the residual is always < 5 MiB so this stays cheap
  # and never accumulates the whole upload in memory.
  defp truncate_tail_head(tail_path, drop) do
    rest_path = tail_path <> ".rest"

    with {:ok, src} <- File.open(tail_path, [:read, :binary]),
         {:ok, dst} <- open_rest(rest_path, src) do
      try do
        _ = IO.binread(src, drop)
        copy_rest(src, dst)
      after
        File.close(src)
        File.close(dst)
      end

      File.rename(rest_path, tail_path)
    end
  end

  defp open_rest(rest_path, src) do
    case File.open(rest_path, [:write, :binary]) do
      {:ok, dst} ->
        {:ok, dst}

      {:error, reason} ->
        File.close(src)
        {:error, reason}
    end
  end

  defp copy_rest(src, dst) do
    case IO.binread(src, @tail_copy_chunk) do
      data when is_binary(data) and byte_size(data) > 0 ->
        IO.binwrite(dst, data)
        copy_rest(src, dst)

      _ ->
        :ok
    end
  end

  # Issue one UploadPart and read the ETag from the response HEADERS (Pitfall 2:
  # upload_part has NO body parser; the ETag lives only in the headers).
  defp upload_one_part(bucket, key, upload_id, part_number, body, opts) do
    with {:ok, response} <-
           request(S3.upload_part(bucket, key, upload_id, part_number, body), opts),
         etag when is_binary(etag) <- etag_from_headers(response) do
      {:ok, %{part_number: part_number, etag: etag}}
    else
      nil -> {:error, :missing_etag}
      {:error, reason} -> {:error, reason}
    end
  end

  defp etag_from_headers(%{headers: headers}) do
    headers
    |> Enum.into(%{}, fn {k, v} -> {String.downcase(k), v} end)
    |> Map.get("etag")
  end

  defp etag_from_headers(_), do: nil

  # Next 1-based part number: prefer the persisted counter, else derive from the
  # accumulated parts (count + 1), else start at 1.
  defp next_part_number(%{next_part_number: n}) when is_integer(n) and n >= 1, do: n
  defp next_part_number(%{parts: parts}) when is_list(parts), do: length(parts) + 1
  defp next_part_number(_), do: 1

  # Tail-buffer path under the sweepable Rindle.tmp/ root (invariant 13). Keyed
  # on the server-issued session_id when present (traversal-proof), else a
  # filesystem-safe encoding of the upload key. An explicit `:root` opt overrides
  # the base dir (used by the unit tests for per-test isolation).
  defp tail_path(key, opts) do
    base = Keyword.get(opts, :root) || Rindle.AV.TempRunDir.root_dir()
    id = Keyword.get(opts, :session_id) || key
    Path.join([base, "tus", tail_filename(id)])
  end

  defp tail_filename(id) do
    Base.url_encode64(id, padding: false) <> ".tail"
  end

  defp parse_size(nil), do: 0

  defp parse_size(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      _ -> 0
    end
  end

  defp parse_size(val) when is_integer(val), do: val

  defp normalize_parts(parts) do
    Enum.map(parts, fn
      %{part_number: part_number, etag: etag} -> {part_number, etag}
      %{"part_number" => part_number, "etag" => etag} -> {part_number, etag}
      {part_number, etag} -> {part_number, etag}
    end)
  end

  defp bucket(opts) do
    case Keyword.get(opts, :bucket) || Application.get_env(:rindle, __MODULE__, [])[:bucket] do
      nil -> {:error, :missing_bucket}
      bucket -> {:ok, bucket}
    end
  end

  defp request(operation, opts) do
    request_module().request(operation, Keyword.get(opts, :aws_config, []))
  rescue
    exception -> {:error, exception}
  end

  # The ExAws request entrypoint, resolved through application env so the
  # offline unit suite can substitute a deterministic stub (the "fake request"
  # sanctioned in 43-VALIDATION) while production and the MinIO lane use the real
  # `ExAws.request/2`. No network mock is wired by default.
  defp request_module do
    Application.get_env(:rindle, __MODULE__, [])[:request_module] || ExAws
  end

  defp s3_config(opts) do
    ExAws.Config.new(:s3, Keyword.get(opts, :aws_config, []))
  end

  defp object_opts(opts) do
    case Keyword.get(opts, :content_type) do
      nil -> []
      content_type -> [content_type: content_type]
    end
  end
end
