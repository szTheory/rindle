defmodule Rindle.Upload.TusStream do
  @moduledoc false

  alias Rindle.Domain.MediaUploadSession

  @read_length 1_048_576

  @doc false
  @spec append(
          Plug.Conn.t(),
          MediaUploadSession.t(),
          map(),
          integer(),
          String.t() | nil,
          binary() | nil,
          keyword()
        ) ::
          {:ok, map()} | {:error, term()}
  def append(conn, session, payload, effective_len, checksum_alg, expected_hash, opts) do
    temp_path = Path.join([tmp_dir(opts), session.id <> ".patch"])
    File.mkdir_p!(Path.dirname(temp_path))

    hash_ctx =
      case checksum_alg do
        "sha1" -> :crypto.hash_init(:sha)
        "sha256" -> :crypto.hash_init(:sha256)
        _ -> nil
      end

    drain_result =
      case File.open(temp_path, [:write, :binary]) do
        {:ok, file} ->
          try do
            drain(
              conn,
              file,
              session.last_known_offset,
              0,
              opts[:max_size],
              effective_len,
              hash_ctx
            )
          after
            File.close(file)
          end

        {:error, reason} ->
          {:error, reason}
      end

    try do
      drain_result
      |> verify_checksum(expected_hash)
      |> dispatch_part(temp_path, session, payload, opts)
    after
      File.rm(temp_path)
    end
  end

  @doc false
  @spec persistence_attrs(MediaUploadSession.t(), map()) :: map()
  def persistence_attrs(session, part_state) do
    new_parts = encode_parts(Map.get(part_state, :parts))

    merged_parts =
      if new_parts do
        Map.merge(session.multipart_parts || %{}, new_parts)
      else
        session.multipart_parts
      end

    %{
      last_known_offset: part_state.offset,
      multipart_upload_id: Map.get(part_state, :upload_id),
      multipart_parts: merged_parts
    }
  end

  @doc false
  @spec completion(MediaUploadSession.t(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def completion(session, payload, opts) do
    opts[:adapter].complete_part_stream(
      session.upload_key,
      nil,
      prior_state(session),
      call_opts(session, payload["content_type"], opts)
    )
  end

  defp verify_checksum({:ok, new_offset, final_hash_ctx}, hash) when not is_nil(hash) do
    if :crypto.hash_final(final_hash_ctx) == hash,
      do: {:ok, new_offset},
      else: {:error, :checksum_mismatch}
  end

  defp verify_checksum({:ok, new_offset, _}, _), do: {:ok, new_offset}
  defp verify_checksum({:error, reason}, _), do: {:error, reason}

  defp dispatch_part({:ok, _new_offset}, temp_path, session, payload, opts) do
    opts[:adapter].upload_part_stream(
      session.upload_key,
      temp_path,
      session.last_known_offset,
      prior_state(session),
      call_opts(session, payload["content_type"], opts)
    )
  end

  defp dispatch_part({:error, reason}, _temp_path, _session, _payload, _opts),
    do: {:error, reason}

  defp prior_state(session) do
    %{
      offset: session.last_known_offset,
      upload_id: session.multipart_upload_id,
      parts: decode_parts(session.multipart_parts)
    }
  end

  defp decode_parts(%{"parts" => parts}) when is_list(parts), do: parts
  defp decode_parts(_), do: []

  defp drain(conn, file, base_offset, written, ceiling, upload_length, hash_ctx) do
    case Plug.Conn.read_body(conn, length: @read_length, read_length: @read_length) do
      {:ok, chunk, _conn} ->
        write_chunk(file, chunk, base_offset, written, ceiling, upload_length, hash_ctx, :done)

      {:more, chunk, conn} ->
        case write_chunk(
               file,
               chunk,
               base_offset,
               written,
               ceiling,
               upload_length,
               hash_ctx,
               :more
             ) do
          {:cont, new_written, new_hash_ctx} ->
            drain(conn, file, base_offset, new_written, ceiling, upload_length, new_hash_ctx)

          other ->
            other
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_chunk(file, chunk, base_offset, written, ceiling, upload_length, hash_ctx, mode) do
    new_written = written + byte_size(chunk)

    cond do
      new_written > ceiling ->
        {:error, :too_large}

      is_integer(upload_length) and base_offset + new_written > upload_length ->
        {:error, :too_large}

      true ->
        IO.binwrite(file, chunk)
        new_hash_ctx = if hash_ctx, do: :crypto.hash_update(hash_ctx, chunk), else: nil

        if mode == :done,
          do: {:ok, base_offset + new_written, new_hash_ctx},
          else: {:cont, new_written, new_hash_ctx}
    end
  end

  defp encode_parts(parts) when is_list(parts) and parts != [], do: %{"parts" => parts}
  defp encode_parts(_), do: %{}

  defp tmp_dir(opts), do: opts[:root] || Rindle.AV.TempRunDir.root_dir()

  defp call_opts(session_or_id, content_type, opts) do
    session_id = if is_map(session_or_id), do: session_or_id.id, else: session_or_id

    [session_id: session_id, root: opts[:root]]
    |> maybe_put_opt(:content_type, content_type)
  end

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, _key, ""), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)
end
