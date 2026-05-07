defmodule Rindle.Storage.GCSTest do
  use ExUnit.Case, async: false

  alias Rindle.Storage.GCS

  @gcs_credentials System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")
  @gcs_bucket System.get_env("RINDLE_GCS_BUCKET")
  @gcs_skip_reason (if Enum.any?([@gcs_credentials, @gcs_bucket], &is_nil/1) do
                      "Skipping GCS adapter test because GOOGLE_APPLICATION_CREDENTIALS_JSON or RINDLE_GCS_BUCKET environment variable is missing"
                    end)

  describe "always-on (no live bucket required)" do
    test "returns missing_bucket when no bucket is configured" do
      original = Application.get_env(:rindle, GCS)
      Application.delete_env(:rindle, GCS)

      try do
        assert {:error, :missing_bucket} = GCS.store("assets/a1.jpg", "/tmp/missing", [])
        assert {:error, :missing_bucket} = GCS.delete("assets/a1.jpg", [])
        assert {:error, :missing_bucket} = GCS.url("assets/a1.jpg", [])
        assert {:error, :missing_bucket} = GCS.download("assets/a1.jpg", "/tmp/out", [])
        assert {:error, :missing_bucket} = GCS.head("assets/a1.jpg", [])
      after
        if original, do: Application.put_env(:rindle, GCS, original)
      end
    end

    test "capabilities/0 returns exactly [:signed_url, :head] (GCS-02 / Capabilities drift detector)" do
      # GCS-02: Phase 37 ships ONLY :signed_url + :head. Phase 39 will rewrite
      # this assertion to include :resumable_upload + :resumable_upload_session.
      # The == form (not Enum.member?/2) is deliberate — list-membership asserts
      # would let resumable atoms slip in undetected.
      assert GCS.capabilities() == [:signed_url, :head]
    end

    test "capabilities/0 does NOT advertise resumable atoms in Phase 37 (defensive)" do
      caps = GCS.capabilities()
      refute :resumable_upload in caps
      refute :resumable_upload_session in caps
    end

    test "presigned_put/3 returns {:upload_unsupported, :presigned_put}" do
      assert {:error, {:upload_unsupported, :presigned_put}} =
               GCS.presigned_put("assets/foo.jpg", 60, [])
    end

    test "all four multipart callbacks return {:upload_unsupported, :multipart_upload}" do
      assert {:error, {:upload_unsupported, :multipart_upload}} =
               GCS.initiate_multipart_upload("k", 5_242_880, [])

      assert {:error, {:upload_unsupported, :multipart_upload}} =
               GCS.presigned_upload_part("k", "u", 1, 60, [])

      assert {:error, {:upload_unsupported, :multipart_upload}} =
               GCS.complete_multipart_upload("k", "u", [], [])

      assert {:error, {:upload_unsupported, :multipart_upload}} =
               GCS.abort_multipart_upload("k", "u", [])
    end
  end

  describe "live bucket round-trip (requires GOOGLE_APPLICATION_CREDENTIALS_JSON + RINDLE_GCS_BUCKET)" do
    @tag :gcs
    @tag skip: @gcs_skip_reason
    test "round-trips store, head (size + content_type parity), url, download, delete, head 404" do
      decoded = Jason.decode!(@gcs_credentials)
      goth_name = :"rindle_gcs_test_goth_#{System.unique_integer([:positive])}"
      finch_name = :"rindle_gcs_test_finch_#{System.unique_integer([:positive])}"

      {:ok, _} = Goth.start_link(name: goth_name, source: {:service_account, decoded})
      {:ok, _} = Finch.start_link(name: finch_name)

      original_env = Application.get_env(:rindle, GCS)

      Application.put_env(:rindle, GCS,
        bucket: @gcs_bucket,
        goth: goth_name,
        finch: finch_name,
        signing_key: decoded
      )

      key = "rindle-gcs-test/#{System.unique_integer([:positive])}.jpg"
      tmp_root = Path.join(System.tmp_dir!(), "rindle-gcs-#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp_root)
      source = Path.join(tmp_root, "source.bin")
      destination = Path.join(tmp_root, "downloaded.bin")
      # 20 bytes for the parity assertion mirroring test/rindle/storage/s3_test.exs:117
      body = "gcs-adapter-test-da" <> "1"
      File.write!(source, body)

      try do
        assert {:ok, %{key: ^key}} =
                 GCS.store(key, source,
                   content_type: "image/jpeg",
                   content_disposition: "inline; filename=\"foo.jpg\""
                 )

        # The S3-shape parity assertion (test/rindle/storage/s3_test.exs:117).
        # Proves RESEARCH §Section 2 size-as-string parse mirror is fixed AND
        # D-03 (content-type as object metadata) is wired end-to-end against a
        # real GCS bucket.
        assert {:ok, %{size: 20, content_type: "image/jpeg"}} = GCS.head(key, [])

        assert {:ok, signed_url} = GCS.url(key, [])
        assert is_binary(signed_url)
        assert String.contains?(signed_url, "X-Goog-Algorithm=GOOG4-RSA-SHA256")
        assert String.contains?(signed_url, "X-Goog-Signature=")

        assert {:ok, ^destination} = GCS.download(key, destination, [])
        assert File.read!(destination) == body

        assert {:ok, _} = GCS.delete(key, [])
        assert {:error, :not_found} = GCS.head(key, [])
      after
        _ = File.rm_rf(tmp_root)

        if original_env do
          Application.put_env(:rindle, GCS, original_env)
        else
          Application.delete_env(:rindle, GCS)
        end
      end
    end
  end
end
