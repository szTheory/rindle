defmodule Rindle.Test.MuxWebhookFixtures do
  @moduledoc false

  # Test signing helper for Mux webhook fixtures.
  #
  # Mirrors `Mux.Webhooks.TestUtils.generate_signature/2` with one critical
  # addition: a `:timestamp` override. The SDK helper hardcodes
  # `System.system_time(:second)` — useless for replay-attack tests that
  # need to forge stale signatures (D-34).
  #
  # HMAC recipe (D-35, byte-accurate against SDK):
  # HMAC-SHA256 over signed_payload `"<ts>.<body>"`, hex-encoded lowercase.
  #
  # Header format: `"t=<unix_ts>,v1=<hex>"` (matches Mux's documented format
  # at https://www.mux.com/docs/core/verify-webhook-signatures).

  @doc """
  Build a Mux-Signature header value for the given payload and secret.

  ## Options

    * `:timestamp` — Unix timestamp (seconds). Defaults to
      `System.system_time(:second)`. Override for replay-attack tests
      (e.g., `timestamp: System.system_time(:second) - 600`).
  """
  @spec sign_header(payload :: binary(), secret :: binary(), opts :: keyword()) :: binary()
  def sign_header(payload, secret, opts \\ []) when is_binary(payload) and is_binary(secret) do
    timestamp = Keyword.get(opts, :timestamp, System.system_time(:second))
    signed_payload = "#{timestamp}.#{payload}"

    signature =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signature}"
  end
end
