defmodule Rindle.Storage.GCS.Signer do
  @moduledoc false

  # V4 signed URL generation for Rindle.Storage.GCS.
  #
  # Wraps gcs_signed_url ~> 0.6 in Client (private-key) auth mode only.
  # IAM SignBlob mode (OAuthConfig) is deferred to v1.7+ behind a config flag.
  #
  # The upstream library returns a bare URL, accepts decoded service-account maps
  # or raw PEM credentials, and does not load credential files on Rindle's behalf.

  ## Public API

  @spec url(bucket :: String.t(), key :: String.t(), opts :: keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def url(bucket, key, opts) do
    client = build_client(signing_key(opts))
    expires = ttl(opts)

    # gcs_signed_url client mode returns a bare String.t().
    # Wrap in {:ok, _} for parity with the Rindle.Storage.url/2 callback contract.
    # Content-Disposition and Content-Type live in GCS object
    # metadata at store/3, NEVER as URL response-* query parameters.
    signed_url = GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: expires)
    {:ok, signed_url}
  end

  ## Helpers

  # Credential dispatch:
  # - decoded JSON map → GcsSignedUrl.Client.load/1 (preferred)
  # - bare PEM string → manual %GcsSignedUrl.Client{} construction with
  #   :client_email sourced from app env
  # - file-path / anything else → raise ArgumentError (Q5 LOCKED)
  defp build_client(%{"private_key" => _, "client_email" => _} = json_map) do
    GcsSignedUrl.Client.load(json_map)
  end

  defp build_client(pem) when is_binary(pem) do
    if String.starts_with?(pem, "-----BEGIN ") do
      client_email = configured_client_email()

      if is_binary(client_email) and client_email != "" do
        %{__struct__: GcsSignedUrl.Client, private_key: pem, client_email: client_email}
      else
        raise ArgumentError,
              "Rindle.Storage.GCS :signing_key was given as a bare PEM string but " <>
                "`config :rindle, Rindle.Storage.GCS, client_email: \"...\"` is not set. " <>
                "Either pass the full decoded service-account JSON map (preferred) or " <>
                "configure :client_email separately."
      end
    else
      # Anything else that's a binary (file path, garbage) is rejected.
      # File-path loading is adopter responsibility per Q5 LOCKED — adopters
      # who want to load from a file decode at app boot via
      # `Jason.decode!(File.read!("path/to/key.json"))` and pass the map.
      raise ArgumentError,
            "Rindle.Storage.GCS :signing_key must be either a decoded service-account JSON " <>
              "map (preferred) or a bare PEM string (in which case `client_email:` must also " <>
              "be configured). File-path loading is not supported — decode your " <>
              "service-account JSON at boot via " <>
              "`Jason.decode!(File.read!(\"path/to/key.json\"))` and pass the resulting map. " <>
              "Got: #{inspect(pem)}"
    end
  end

  defp build_client(other) do
    raise ArgumentError,
          "Rindle.Storage.GCS :signing_key must be a decoded service-account JSON map " <>
            "(preferred) or a bare PEM string with :client_email configured separately. " <>
            "Got: #{inspect(other)}"
  end

  defp configured_client_email do
    Application.get_env(:rindle, Rindle.Storage.GCS, [])[:client_email]
  end

  defp signing_key(opts) do
    Keyword.get(opts, :signing_key) ||
      Application.get_env(:rindle, Rindle.Storage.GCS, [])[:signing_key] ||
      raise ArgumentError,
            "Rindle.Storage.GCS signing_key is not configured. Set " <>
              "`config :rindle, Rindle.Storage.GCS, signing_key: <decoded_json_map | pem_string>`."
  end

  # Match S3 precedence: call options override
  # Rindle.Config.signed_url_ttl_seconds/0 fallback.
  defp ttl(opts) do
    Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())
  end
end
