defmodule Rindle.Storage.GCS.SignerTest do
  use ExUnit.Case, async: true

  alias Rindle.Storage.GCS.Signer
  alias Rindle.Storage.GCS.SigningKeyFixture

  @bucket "my-bucket"
  @key "assets/foo.jpg"

  describe "url/3 — V4 canonical query params" do
    test "returns {:ok, url} containing X-Goog-Algorithm=GOOG4-RSA-SHA256 and X-Goog-Signature" do
      opts = [signing_key: SigningKeyFixture.fixture_json(), expires_in: 600]
      assert {:ok, url} = Signer.url(@bucket, @key, opts)
      assert is_binary(url)
      assert String.contains?(url, "X-Goog-Algorithm=GOOG4-RSA-SHA256")
      assert url =~ ~r/X-Goog-Signature=[A-Fa-f0-9]+/
      assert String.contains?(url, "X-Goog-Expires=600")
    end

    test "URL never contains response-content-disposition or response-content-type query params (D-03)" do
      opts = [signing_key: SigningKeyFixture.fixture_json(), expires_in: 600]
      assert {:ok, url} = Signer.url(@bucket, @key, opts)
      refute String.contains?(url, "response-content-disposition")
      refute String.contains?(url, "response-content-type")
    end
  end

  describe "url/3 — TTL fallback (D-04)" do
    test "falls back to Rindle.Config.signed_url_ttl_seconds/0 when :expires_in is absent (default 900)" do
      opts = [signing_key: SigningKeyFixture.fixture_json()]
      assert {:ok, url} = Signer.url(@bucket, @key, opts)
      assert String.contains?(url, "X-Goog-Expires=900")
    end

    test "explicit :expires_in opt takes precedence over the config fallback" do
      original = Application.get_env(:rindle, :signed_url_ttl_seconds)
      Application.put_env(:rindle, :signed_url_ttl_seconds, 1234)

      try do
        opts = [signing_key: SigningKeyFixture.fixture_json(), expires_in: 600]
        assert {:ok, url} = Signer.url(@bucket, @key, opts)
        assert String.contains?(url, "X-Goog-Expires=600")
      after
        if original,
          do: Application.put_env(:rindle, :signed_url_ttl_seconds, original),
          else: Application.delete_env(:rindle, :signed_url_ttl_seconds)
      end
    end

    test "uses the configured TTL when :expires_in is absent" do
      original = Application.get_env(:rindle, :signed_url_ttl_seconds)
      Application.put_env(:rindle, :signed_url_ttl_seconds, 1234)

      try do
        opts = [signing_key: SigningKeyFixture.fixture_json()]
        assert {:ok, url} = Signer.url(@bucket, @key, opts)
        assert String.contains?(url, "X-Goog-Expires=1234")
      after
        if original,
          do: Application.put_env(:rindle, :signed_url_ttl_seconds, original),
          else: Application.delete_env(:rindle, :signed_url_ttl_seconds)
      end
    end
  end

  describe "url/3 — signing-key dispatch (RESEARCH Q5 LOCKED)" do
    test "accepts a decoded JSON map (preferred path)" do
      opts = [signing_key: SigningKeyFixture.fixture_json(), expires_in: 600]
      assert {:ok, _url} = Signer.url(@bucket, @key, opts)
    end

    test "accepts a bare PEM string when :client_email is configured" do
      # Q5 LOCKED accepts map + bare PEM. For bare PEM the signer needs
      # client_email separately — sourced from app env.
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        client_email: SigningKeyFixture.fixture_client_email()
      )

      try do
        opts = [signing_key: SigningKeyFixture.fixture_pem(), expires_in: 600]
        assert {:ok, url} = Signer.url(@bucket, @key, opts)
        assert is_binary(url)
        assert String.contains?(url, "X-Goog-Algorithm=GOOG4-RSA-SHA256")
      after
        if original,
          do: Application.put_env(:rindle, Rindle.Storage.GCS, original),
          else: Application.delete_env(:rindle, Rindle.Storage.GCS)
      end
    end

    test "raises ArgumentError when signing_key: looks like a file path (Q5 LOCKED — file-path loading is adopter responsibility)" do
      # Anything that doesn't look like a PEM and isn't a map is rejected.
      # An adopter who wants to load from a file decodes at app boot via
      # Jason.decode!(File.read!("path/to/key.json")) and passes the map.
      assert_raise ArgumentError, fn ->
        Signer.url(@bucket, @key, signing_key: "/path/to/service-account.json", expires_in: 600)
      end

      assert_raise ArgumentError, fn ->
        Signer.url(@bucket, @key, signing_key: "./relative/key.json", expires_in: 600)
      end
    end

    test "raises ArgumentError on bare PEM when :client_email is NOT configured (sad path)" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)
      # Ensure no :client_email is configured.
      Application.put_env(:rindle, Rindle.Storage.GCS, [])

      try do
        assert_raise ArgumentError, fn ->
          Signer.url(@bucket, @key,
            signing_key: SigningKeyFixture.fixture_pem(),
            expires_in: 600
          )
        end
      after
        if original,
          do: Application.put_env(:rindle, Rindle.Storage.GCS, original),
          else: Application.delete_env(:rindle, Rindle.Storage.GCS)
      end
    end
  end
end
