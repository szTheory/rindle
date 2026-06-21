defmodule Rindle.Support.S3MultipartRequestStub do
  @moduledoc """
  Deterministic, offline `ExAws.request/2` substitute for the tus tail-buffer
  unit tests (`Rindle.Storage.S3TusTest`, TUS-06).

  `Rindle.Storage.S3.upload_part_stream/5` and `complete_part_stream/4` issue real
  S3 multipart operations (`initiate_multipart_upload`, `upload_part`,
  `complete_multipart_upload`). The slice/accumulate MATH that those unit specs
  pin is pure and on-disk, but exercising it still drives one `UploadPart` per
  >= 5 MiB part — which would otherwise require a live S3/MinIO endpoint. This
  stub returns synthetic, well-formed responses (server-issued ETag in the
  response HEADERS, mirroring real S3 — Pitfall 2) so the math is verifiable with
  zero network. 43-VALIDATION line 58 explicitly sanctions a "fake `request`".

  Delegation is keyed on the CALLER'S INTENT, not ambient env. A non-empty
  `aws_config` (an explicit endpoint + credentials passed by the caller) means
  "talk to a real S3/MinIO", so the operation is delegated to the genuine
  `ExAws.request/2`. The untagged tail-buffer specs pass NO `aws_config` (it
  resolves to `[]`), so their three multipart ops are fabricated and never touch
  the network.

  This intent-based check REPLACED an earlier ambient `RINDLE_MINIO_*`-env check,
  which wrongly delegated the empty-config offline specs to real AWS whenever the
  MinIO env happened to be set — they then resolved live credentials via EC2
  instance-metadata (IMDS) and raised `Instance Meta Error: HTTP 404` in any CI job
  that sets `RINDLE_MINIO_*` (Integration, Package Consumer), while the Quality job
  (no MinIO env) passed. Genuine MinIO multipart coverage is preserved: `@tag
  :minio` tests in `s3_test.exs` pass an explicit `aws_config:` (non-empty →
  delegated to real ExAws), and `tus_s3_integration_test.exs` replaces this module
  with real `ExAws` outright via `Application.put_env(:rindle, Rindle.Storage.S3,
  bucket: ...)` in its `setup`.

  Every non-multipart operation passes through to `ExAws` unchanged.

  Wired via `config :rindle, Rindle.Storage.S3, request_module: __MODULE__` in
  `config/test.exs`; production resolves `ExAws` (the default).
  """

  alias ExAws.Operation.S3, as: Op

  @doc """
  Stub entrypoint matching the `ExAws.request/2` arity used by
  `Rindle.Storage.S3`.
  """
  def request(%Op{} = op, config) do
    cond do
      # Explicit endpoint requested by the caller (non-empty aws_config) → run the
      # genuine ExAws round-trip, so `@tag :minio` tests keep exercising real MinIO.
      # The offline tail-buffer specs pass NO aws_config (config == []), so they
      # never reach here and stay fully offline (no network, no IMDS).
      config not in [nil, []] ->
        ExAws.request(op, config)

      initiate_multipart?(op) ->
        {:ok, %{body: %{upload_id: "stub-upload-#{System.unique_integer([:positive])}"}}}

      upload_part?(op) ->
        part_number = Map.get(op.params, "partNumber")

        {:ok,
         %{
           status_code: 200,
           headers: [{"ETag", "\"stub-etag-part-#{part_number}\""}],
           body: ""
         }}

      complete_multipart?(op) ->
        {:ok,
         %{
           body: %{
             location: "http://stub/#{op.bucket}/#{op.path}",
             bucket: op.bucket,
             key: op.path,
             etag: "\"stub-etag-complete\""
           }
         }}

      true ->
        ExAws.request(op, config)
    end
  end

  def request(op, config), do: ExAws.request(op, config)

  defp initiate_multipart?(%Op{http_method: :post, resource: "uploads"}), do: true
  defp initiate_multipart?(_), do: false

  defp upload_part?(%Op{http_method: :put, params: %{"partNumber" => _}}), do: true
  defp upload_part?(_), do: false

  defp complete_multipart?(%Op{http_method: :post, resource: resource, params: params})
       when resource != "uploads" do
    Map.has_key?(params, "uploadId")
  end

  defp complete_multipart?(_), do: false
end
