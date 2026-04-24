defmodule Rindle.Storage.Local do
  @moduledoc """
  Local filesystem storage adapter.
  """

  @behaviour Rindle.Storage

  @impl true
  def store(key, source_path, opts) do
    destination_path = storage_path(key, opts)

    with :ok <- File.mkdir_p(Path.dirname(destination_path)),
         :ok <- File.cp(source_path, destination_path) do
      {:ok, %{key: key, path: destination_path}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key, opts) do
    case File.rm(storage_path(key, opts)) do
      :ok -> {:ok, %{key: key}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(key, opts) do
    {:ok, "file://" <> storage_path(key, opts)}
  end

  @impl true
  def presigned_put(_key, _expires_in, _opts) do
    {:error, :unsupported_operation}
  end

  @impl true
  def capabilities, do: [:local]

  defp storage_path(key, opts) do
    Path.join(local_root(opts), key)
  end

  defp local_root(opts) do
    Keyword.get(opts, :root) ||
      Application.get_env(:rindle, __MODULE__, [])[:root] ||
      Path.join(System.tmp_dir!(), "rindle-storage")
  end
end
