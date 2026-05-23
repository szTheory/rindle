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

  When the `RINDLE_MINIO_*` environment is present (the CI MinIO lane and the
  `@tag :minio` integration tests), this stub DELEGATES to the real
  `ExAws.request/2` so the live UploadPart round-trip is genuinely exercised. It
  only fabricates responses for the three multipart operations; every other
  operation passes through to `ExAws` unchanged.

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
      minio_configured?() ->
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

  defp minio_configured? do
    Enum.all?(
      [
        System.get_env("RINDLE_MINIO_URL"),
        System.get_env("RINDLE_MINIO_ACCESS_KEY"),
        System.get_env("RINDLE_MINIO_SECRET_KEY"),
        System.get_env("RINDLE_MINIO_BUCKET")
      ],
      &(&1 not in [nil, ""])
    )
  end
end
