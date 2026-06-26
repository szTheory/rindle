defmodule Rindle.Storage.S3PublicEndpointTest do
  # async: false — these toggle the global `:rindle, Rindle.Storage.S3` app env.
  use ExUnit.Case, async: false

  alias Rindle.Storage.S3

  # Server-side (cluster-internal) endpoint the adapter signs/sends against by default.
  @aws_config [
    access_key_id: "minioadmin",
    secret_access_key: "minioadmin",
    scheme: "http://",
    host: "minio",
    port: 9000,
    region: "us-east-1"
  ]

  # Stub ExAws entrypoint that records the aws_config it was handed (the server-side path
  # passes `opts[:aws_config]` verbatim) and returns a HEAD-shaped success.
  defmodule CaptureRequest do
    def request(_operation, aws_config) do
      send(self(), {:captured_aws_config, aws_config})
      {:ok, %{headers: [{"Content-Length", "3"}, {"Content-Type", "image/png"}]}}
    end
  end

  setup do
    prior = Application.get_env(:rindle, Rindle.Storage.S3)

    on_exit(fn ->
      if prior do
        Application.put_env(:rindle, Rindle.Storage.S3, prior)
      else
        Application.delete_env(:rindle, Rindle.Storage.S3)
      end
    end)

    :ok
  end

  describe "presigned URLs without :public_endpoint (unchanged behaviour)" do
    test "GET is signed for the server-side host" do
      Application.put_env(:rindle, Rindle.Storage.S3, bucket: "rindle-test")

      assert {:ok, url} = S3.url("assets/a.png", bucket: "rindle-test", aws_config: @aws_config)
      assert url =~ "http://minio:9000/rindle-test/assets/a.png"
      assert url =~ "X-Amz-Signature="
    end
  end

  describe "presigned URLs with :public_endpoint configured" do
    setup do
      Application.put_env(:rindle, Rindle.Storage.S3,
        bucket: "rindle-test",
        public_endpoint: [scheme: "http://", host: "localhost", port: 9001]
      )

      :ok
    end

    test "GET is signed for the public endpoint, not the server-side host" do
      assert {:ok, url} = S3.url("assets/a.png", bucket: "rindle-test", aws_config: @aws_config)
      assert url =~ "http://localhost:9001/rindle-test/assets/a.png"
      refute url =~ "minio:9000"
      assert url =~ "X-Amz-Signature="
    end

    test "presigned PUT is also signed for the public endpoint" do
      assert {:ok, %{url: url, method: :put}} =
               S3.presigned_put("assets/a.png", 60,
                 bucket: "rindle-test",
                 aws_config: @aws_config
               )

      assert url =~ "http://localhost:9001/rindle-test/assets/a.png"
      refute url =~ "minio:9000"
    end

    test "presigned multipart upload-part URL is also signed for the public endpoint" do
      assert {:ok, %{url: url, part_number: 1}} =
               S3.presigned_upload_part("assets/a.png", "upload-123", 1, 60,
                 bucket: "rindle-test",
                 aws_config: @aws_config
               )

      assert url =~ "http://localhost:9001/rindle-test/assets/a.png"
      refute url =~ "minio:9000"
    end

    test "server-side ops still target the server-side host (public_endpoint is presign-only)" do
      Application.put_env(:rindle, Rindle.Storage.S3,
        bucket: "rindle-test",
        public_endpoint: [scheme: "http://", host: "localhost", port: 9001],
        request_module: CaptureRequest
      )

      assert {:ok, %{size: 3}} =
               S3.head("assets/a.png", bucket: "rindle-test", aws_config: @aws_config)

      assert_received {:captured_aws_config, captured}
      assert Keyword.get(captured, :host) == "minio"
      assert Keyword.get(captured, :port) == 9000
      refute Keyword.get(captured, :host) == "localhost"
    end
  end
end
