defmodule Rindle.Storage.GCS do
  @moduledoc """
  Google Cloud Storage adapter using `goth ~> 1.4` (auth) + `finch ~> 0.21` (HTTP) +
  `gcs_signed_url ~> 0.4.6` (V4 signing).

  ## Setup

  Add `Goth` and `Finch` to your supervision tree (Rindle does not start them):

      children = [
        {Goth, name: MyApp.Goth, source: {:service_account, json_creds}},
        {Finch, name: MyApp.Finch}
      ]

  Configure the adapter:

      config :rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        goth: MyApp.Goth,
        finch: MyApp.Finch,
        signing_key: System.fetch_env!("GCS_SERVICE_ACCOUNT_JSON") |> Jason.decode!(),
        signed_url_ttl: 3600

  ## Capabilities

  This adapter advertises `[:signed_url, :head, :resumable_upload,
  :resumable_upload_session]`. `:resumable_upload` covers broker-owned
  initiation plus adapter-side completion verification; the session-scoped atom
  widens that to remote status and cancel operations.

  See `guides/storage_gcs.md` (forthcoming) for the full setup walk-through,
  including service-account JSON wiring, signed-URL lifecycle, and the
  Active-Storage-derived lesson that Content-Disposition / Content-Type live in
  GCS object metadata at upload time (NOT in V4 signed URL query params).
  """

  @behaviour Rindle.Storage

  alias Rindle.Storage.GCS.{Client, Signer}

  @impl true
  def store(key, source_path, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.store(bucket, key, source_path, inject_credentials(opts))
    end
  end

  @impl true
  def download(key, destination_path, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.download(bucket, key, destination_path, inject_credentials(opts))
    end
  end

  @impl true
  def delete(key, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.delete(bucket, key, inject_credentials(opts))
    end
  end

  @impl true
  def url(key, opts) do
    with {:ok, bucket} <- bucket(opts) do
      # V4 Client-mode signing is local — no Goth needed.
      Signer.url(bucket, key, inject_credentials(opts))
    end
  end

  @impl true
  def head(key, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.head(bucket, key, inject_credentials(opts))
    end
  end

  @impl true
  def initiate_resumable_upload(key, expected_size, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.initiate_resumable_upload(bucket, key, expected_size, inject_credentials(opts))
    end
  end

  @impl true
  def resumable_upload_status(key, session_uri, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.resumable_upload_status(bucket, key, session_uri, inject_credentials(opts))
    end
  end

  @impl true
  def cancel_resumable_upload(key, session_uri, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.cancel_resumable_upload(bucket, key, session_uri, inject_credentials(opts))
    end
  end

  @impl true
  def verify_resumable_completion(key, session_uri, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- ensure_goth_loaded() do
      Client.verify_resumable_completion(bucket, key, session_uri, inject_credentials(opts))
    end
  end

  ## Unsupported callbacks (multipart/presigned PUT)

  @impl true
  def presigned_put(_key, _expires_in, _opts) do
    {:error, {:upload_unsupported, :presigned_put}}
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
  def capabilities, do: [:signed_url, :head, :resumable_upload, :resumable_upload_session]

  ## Helpers

  # Mirrors lib/rindle/storage/s3.ex:173-178 — D-08 lock.
  defp bucket(opts) do
    case Keyword.get(opts, :bucket) || Application.get_env(:rindle, __MODULE__, [])[:bucket] do
      nil -> {:error, :missing_bucket}
      bucket -> {:ok, bucket}
    end
  end

  # D-09 — Code.ensure_loaded?(Goth) guard. Returns :ok when present;
  # {:error, :goth_unconfigured} when the optional dep was never installed.
  # NOTE: Plan 01's Client also guards via the same path inside fetch_token/1
  # (the rescue ArgumentError covers the "dep loaded but instance not started"
  # branch — RESEARCH Pitfall 6). This adapter-entry guard catches the "dep not
  # in the build at all" branch BEFORE the Client makes any HTTP plumbing
  # decisions.
  defp ensure_goth_loaded do
    if Code.ensure_loaded?(Goth), do: :ok, else: {:error, :goth_unconfigured}
  end

  # Threads adopter config (`finch:`, `goth:`, `signing_key:`, `base_url:`) into
  # opts so the Client and Signer pick them up via Keyword.get without forcing
  # the caller to pass them on every call. Per-call opts win over app env via
  # Keyword.put_new_lazy/3 — matches S3's `Keyword.get(opts, :bucket) ||
  # Application.get_env(...)` precedence.
  defp inject_credentials(opts) do
    app_env = Application.get_env(:rindle, __MODULE__, [])

    opts
    |> Keyword.put_new_lazy(:finch, fn -> app_env[:finch] end)
    |> Keyword.put_new_lazy(:goth, fn -> app_env[:goth] end)
    |> Keyword.put_new_lazy(:signing_key, fn -> app_env[:signing_key] end)
    |> Keyword.put_new_lazy(:base_url, fn -> app_env[:base_url] end)
  end
end
