defmodule Rindle.Storage.GCS.SigningKeyFixture do
  @moduledoc false

  # Throwaway RSA key + service-account JSON map for unit tests of
  # Rindle.Storage.GCS.Signer.
  #
  # The key is generated at module-load via :public_key.generate_key/1.
  # Each ExUnit run produces a fresh key; the key is NEVER from a real
  # GCP account and has no production trust.
  #
  # RESEARCH Q5 LOCKED: Phase 37 accepts decoded JSON map AND bare PEM
  # string only. File-path loading is adopter responsibility; this fixture
  # therefore exposes `fixture_json/0` (map) and `fixture_pem/0` (bare PEM)
  # but NO file-path helper.

  @client_email "rindle-test@rindle-fixture.iam.gserviceaccount.com"

  @doc """
  Returns a decoded service-account JSON map suitable for
  `GcsSignedUrl.Client.load/1`.
  """
  @spec fixture_json() :: %{required(String.t()) => String.t()}
  def fixture_json do
    %{
      "type" => "service_account",
      "project_id" => "rindle-test",
      "private_key_id" => "rindle-test-key-id",
      "private_key" => generate_pem(),
      "client_email" => @client_email,
      "client_id" => "0",
      "token_uri" => "https://oauth2.googleapis.com/token"
    }
  end

  @doc """
  Returns the bare PEM string (the value of `fixture_json()["private_key"]`).
  Used for the Q5 LOCKED bare-PEM dispatch path.
  """
  @spec fixture_pem() :: String.t()
  def fixture_pem, do: fixture_json()["private_key"]

  @doc """
  Returns the literal client_email used by `fixture_json/0`. Plan 02 Signer
  Test 7 sets `:client_email` config to this value when exercising the bare-PEM
  dispatch path.
  """
  @spec fixture_client_email() :: String.t()
  def fixture_client_email, do: @client_email

  defp generate_pem do
    # PRIMARY: simpler PKCS#1 PEM. `gcs_signed_url 0.4.6` parses both PKCS#1
    # and PKCS#8 PEMs via :public_key.pem_decode/1 + cert chain detection,
    # so PKCS#1 is the cleaner default. The [FALLBACK] PKCS#8 wrap below is
    # only needed if Client.load/1 raises MatchError on the PKCS#1 PEM
    # during integration testing.
    rsa_private_key = :public_key.generate_key({:rsa, 2048, 65_537})
    pem_entry = :public_key.pem_entry_encode(:RSAPrivateKey, rsa_private_key)
    :public_key.pem_encode([pem_entry])
  end

  # [FALLBACK] PKCS#8 wrap. Only swap `generate_pem/0` to call this version
  # if `GcsSignedUrl.Client.load/1` raises `MatchError` on the PKCS#1 PEM
  # produced by the primary path. The manual ASN.1 wrap below has been
  # known to be fragile across OTP versions, so the primary path is the
  # safer default.
  #
  # defp generate_pem_pkcs8 do
  #   rsa_private_key = :public_key.generate_key({:rsa, 2048, 65_537})
  #   der = :public_key.der_encode(:RSAPrivateKey, rsa_private_key)
  #   pkcs8 = wrap_in_pkcs8(der)
  #   pem_entry = {:PrivateKeyInfo, pkcs8, :not_encrypted}
  #   :public_key.pem_encode([pem_entry])
  # end
  #
  # defp wrap_in_pkcs8(rsa_der) do
  #   rsa_oid = <<0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00>>
  #   octet_string = <<0x04>> <> length_encode(byte_size(rsa_der)) <> rsa_der
  #   inner = <<0x02, 0x01, 0x00>> <> rsa_oid <> octet_string
  #   <<0x30>> <> length_encode(byte_size(inner)) <> inner
  # end
  #
  # defp length_encode(n) when n < 128, do: <<n>>
  # defp length_encode(n) when n < 256, do: <<0x81, n>>
  # defp length_encode(n) when n < 65_536, do: <<0x82, n::16>>
end
