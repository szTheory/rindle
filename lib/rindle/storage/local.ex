defmodule Rindle.Storage.Local do
  @moduledoc """
  Local filesystem storage adapter.
  """

  @behaviour Rindle.Storage

  @impl true
  def store(key, source_path, opts) do
    destination_path = path_for(key, opts)

    with :ok <- File.mkdir_p(Path.dirname(destination_path)),
         :ok <- File.cp(source_path, destination_path) do
      {:ok, %{key: key, path: destination_path}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def download(key, destination_path, opts) do
    source_path = path_for(key, opts)

    with :ok <- File.mkdir_p(Path.dirname(destination_path)),
         :ok <- File.cp(source_path, destination_path) do
      {:ok, destination_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key, opts) do
    case File.rm(path_for(key, opts)) do
      :ok -> {:ok, %{key: key}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(key, opts) do
    {:ok, "file://" <> path_for(key, opts)}
  end

  @impl true
  def presigned_put(key, _expires_in, opts) do
    # Simulated presigned PUT for local development parity
    {:ok, %{url: "file://" <> path_for(key, opts), method: "PUT", headers: []}}
  end

  @impl true
  def initiate_multipart_upload(_key, _part_size, _opts) do
    {:error, {:upload_unsupported, :multipart_upload}}
  end

  @impl true
  def presigned_upload_part(_key, _upload_id, _part_number, _expires_in, _opts) do
    {:error, {:upload_unsupported, :multipart_upload}}
  end

  @impl true
  def complete_multipart_upload(_key, _upload_id, _parts, _opts) do
    {:error, {:upload_unsupported, :multipart_upload}}
  end

  @impl true
  def abort_multipart_upload(_key, _upload_id, _opts) do
    {:error, {:upload_unsupported, :multipart_upload}}
  end

  @impl true
  def head(key, opts) do
    path = path_for(key, opts)

    if File.exists?(path) do
      {:ok, %{size: File.stat!(path).size}}
    else
      {:error, :not_found}
    end
  end

  # Read size when streaming the per-PATCH temp file onto the part buffer. Keeps
  # the body off the heap — bytes flow temp_file -> part_file in bounded chunks,
  # never accumulated in a single binary (T-43-09).
  @part_copy_chunk 1024 * 1024

  @impl true
  def upload_part_stream(_key, temp_path, base_offset, _state, opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    # Stream the per-PATCH temp file onto the per-session .part file in bounded
    # chunks via the Phase-42 tus_append helper. Local has no part-number
    # semantics (it is a single growing file), so `part_number`/`:upload_id`/
    # `:parts` are meaningless here — the return is `%{offset: n}` with NO
    # `:upload_id`/`:parts` keys (Pitfall 5; the optional-map @type accommodates
    # this). The whole upload is never buffered in memory.
    result =
      temp_path
      |> File.stream!([], @part_copy_chunk)
      |> Enum.reduce_while({:ok, 0}, fn chunk, {:ok, written} ->
        case tus_append(session_id, chunk, opts) do
          :ok -> {:cont, {:ok, written + byte_size(chunk)}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
      {:ok, bytes_written} -> {:ok, %{offset: base_offset + bytes_written}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def complete_part_stream(key, _temp_path, _state, opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    # Atomic same-filesystem rename of the per-session .part file onto the final
    # key (wraps the Phase-42 tus_complete helper). The companion completion
    # callback to `upload_part_stream/5`: the edge calls it once, polymorphically,
    # with no `if adapter == Local` branch. `temp_path` is unused for Local —
    # the final PATCH bytes were already appended during the matching
    # `upload_part_stream/5` call.
    case tus_complete(session_id, key, opts) do
      {:ok, _path} -> {:ok, %{upload_key: key}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def capabilities, do: [:local, :presigned_put, :tus_upload]

  @doc """
  Returns the expanded local storage root for the given opts.
  """
  @spec root(keyword()) :: String.t()
  def root(opts) do
    opts
    |> Keyword.get(:root)
    |> case do
      nil ->
        Application.get_env(:rindle, __MODULE__, [])[:root] ||
          Path.join(System.tmp_dir!(), "rindle-storage")

      configured_root ->
        configured_root
    end
    |> Path.expand()
  end

  @doc """
  Resolves a storage key to an expanded filesystem path under the configured root.
  """
  @spec path_for(String.t(), keyword()) :: String.t()
  def path_for(key, opts) when is_binary(key) do
    Path.expand(key, root(opts))
  end

  @doc """
  Resolves the tus tmp part path for `session_id` under the configured root.

  The part file lives at `<root>/tus/<session_id>.part`. `session_id` is always
  a server-issued identifier (UUID), so the path is structurally
  traversal-proof. Kept under `root/1` so the completion `File.rename/2` is an
  atomic same-filesystem rename (see `tus_complete/3`).
  """
  @spec tus_part_path(String.t(), keyword()) :: String.t()
  def tus_part_path(session_id, opts) when is_binary(session_id) do
    Path.join([root(opts), "tus", session_id <> ".part"])
  end

  @doc """
  Appends `chunk` to the tus tmp part file for `session_id`.

  Opens the part path in `[:append, :binary]` mode (creating the `tus` tmp
  directory if needed) and binary-writes the chunk. Returns `:ok` or a tagged
  error. Never buffers the whole upload — callers append per PATCH chunk.
  """
  @spec tus_append(String.t(), iodata(), keyword()) :: :ok | {:error, term()}
  def tus_append(session_id, chunk, opts) when is_binary(session_id) do
    part_path = tus_part_path(session_id, opts)

    with :ok <- File.mkdir_p(Path.dirname(part_path)),
         {:ok, file} <- File.open(part_path, [:append, :binary]) do
      try do
        IO.binwrite(file, chunk)
      after
        File.close(file)
      end
    end
  end

  @doc """
  Atomically finalizes the tus upload by renaming the tmp part into `key`.

  Moves `<root>/tus/<session_id>.part` to the final storage path for `key`.
  Because both paths live under `root/1` (same filesystem), `File.rename/2` is
  atomic. A cross-device error (`:exdev`) is a misconfiguration (tmp dir and
  storage root on different filesystems) and is surfaced as an error — never a
  silent copy+delete fallback (Pitfall 5).
  """
  @spec tus_complete(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def tus_complete(session_id, key, opts) when is_binary(session_id) and is_binary(key) do
    part_path = tus_part_path(session_id, opts)
    destination_path = path_for(key, opts)

    with :ok <- File.mkdir_p(Path.dirname(destination_path)),
         :ok <- File.rename(part_path, destination_path) do
      {:ok, destination_path}
    end
  end
end
