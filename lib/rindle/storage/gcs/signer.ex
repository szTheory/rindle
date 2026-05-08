defmodule Rindle.Storage.GCS.Signer do
  @moduledoc false

  # V4 signed URL generation for Rindle.Storage.GCS.
  #
  # Wraps gcs_signed_url ~> 0.4.6 in Client (private-key) auth mode only.
  # IAM SignBlob mode (OAuthConfig) is deferred to v1.7+ behind a config flag.
  #
  # See:
  # - .planning/phases/37-gcs-adapter-foundation/37-CONTEXT.md (D-01, D-03, D-04, D-08)
  # - .planning/phases/37-gcs-adapter-foundation/37-RESEARCH.md
  #   (Q3 — Client mode returns BARE String, NOT {:ok, _};
  #    Q5 LOCKED — accepts map (preferred) + bare PEM; file paths MUST raise;
  #    RESEARCH §Section 3 — Client.load JSON-map dispatch)

  ## Public API

  @spec url(bucket :: String.t(), key :: String.t(), opts :: keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def url(bucket, key, opts) do
    client = build_client(signing_key(opts))
    expires = ttl(opts)

    # gcs_signed_url Client mode returns a BARE String.t() (RESEARCH Q3).
    # Wrap in {:ok, _} for parity with the Rindle.Storage.url/2 callback contract.
    # NOTE: D-03 lock — Content-Disposition and Content-Type live in GCS object
    # metadata at store/3, NEVER as URL response-* query parameters.
    signed_url = GcsSignedUrl.generate_v4(client, bucket, key, verb: "GET", expires: expires)
    {:ok, signed_url}
  end

  ## Helpers

  # RESEARCH Q5 LOCKED dispatch:
  # - decoded JSON map → GcsSignedUrl.Client.load/1 (preferred)
  # - bare PEM string → manual %GcsSignedUrl.Client{} construction with
  #   :client_email sourced from app env
  # - file-path / anything else → raise ArgumentError (Q5 LOCKED)
  defp build_client(%{"private_key" => _, "client_email" => _} = json_map) do
    GcsSignedUrl.Client.load(json_map)
  end

  defp build_client(pem) when is_binary(pem) do
    cond do
      String.starts_with?(pem, "-----BEGIN ") ->
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

      true ->
        # Anything else that's a binary (file path, garbage) is rejected.
        # File-path loading is adopter responsibility per Q5 LOCKED — adopters
        # who want to load from a file decode at app boot via
        # `Jason.decode!(File.read!("path/to/key.json"))` and pass the map.
        raise ArgumentError,
              "Rindle.Storage.GCS :signing_key must be either a decoded service-account JSON " <>
                "map (preferred) or a bare PEM string (in which case `client_email:` must also " <>
                "be configured). File-path loading is not supported in Phase 37 — decode your " <>
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

  # D-04 mirror of `lib/rindle/storage/s3.ex:55-61` — opts precedence over
  # Rindle.Config.signed_url_ttl_seconds/0 fallback.
  defp ttl(opts) do
    Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())
  end
end
