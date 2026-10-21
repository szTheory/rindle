defmodule Twin.StorageFault do
  @behaviour Rindle.Storage
  @impl true
  defdelegate capabilities(), to: Rindle.Storage.S3
  @impl true
  defdelegate store(key, source, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate download(key, destination, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate url(key, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate head(key, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate presigned_put(key, expires, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate initiate_multipart_upload(key, size, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate presigned_upload_part(key, upload, part, expires, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate complete_multipart_upload(key, upload, parts, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate abort_multipart_upload(key, upload, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate upload_part_stream(key, path, offset, state, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate complete_part_stream(key, path, state, opts), to: Rindle.Storage.S3
  @impl true
  defdelegate concatenate(key, sources, opts), to: Rindle.Storage.S3

  @impl true
  def delete(key, opts) do
    # Atomic claim commits before network I/O; absent/foreign/variant keys delegate.
    %{num_rows: claimed} =
      Twin.Repo.query!(
        "UPDATE twin_fault_counters SET claims = claims + 1 WHERE run_id = $1 AND operation = 'delete' AND source_key = $2 AND claims = 0 RETURNING claims",
        [System.fetch_env!("TWIN_RUN_ID"), key]
      )

    if claimed == 1,
      do: {:error, :twin_source_delete_once},
      else: Rindle.Storage.S3.delete(key, opts)
  end
end

defmodule Twin.Profile do
  use Rindle.Profile,
    storage: Twin.StorageFault,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/png"],
    max_bytes: 1_048_576
end
