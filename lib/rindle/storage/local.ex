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
end
