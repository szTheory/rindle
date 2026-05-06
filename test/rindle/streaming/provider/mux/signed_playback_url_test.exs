defmodule Rindle.Streaming.Provider.Mux.SignedPlaybackUrlTest do
  use Rindle.DataCase, async: false

  alias Rindle.Streaming.Provider.Mux, as: Adapter

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [hero: [mode: :fit, width: 320]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [signed_url_ttl_seconds: 900]
  end

  setup do
    prev = Application.get_env(:rindle, Adapter, [])

    Application.put_env(
      :rindle,
      Adapter,
      Keyword.merge(prev,
        signing_key_id: "test_kid",
        signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem")
      )
    )

    on_exit(fn -> Application.put_env(:rindle, Adapter, prev) end)

    :ok
  end

  test "JWT exp matches profile signed_url_ttl_seconds (NOT SDK 7-day default)" do
    ttl = Rindle.Delivery.signed_url_ttl_seconds(TestProfile)
    assert ttl == 900

    before_unix = DateTime.utc_now() |> DateTime.to_unix()

    assert {:ok, %{url: url, kind: :hls, mime: "application/vnd.apple.mpegurl"}} =
             Adapter.signed_playback_url(TestProfile, "playback-id-test-fixture-1234")

    assert url =~ ~r{^https://stream\.mux\.com/playback-id-test-fixture-1234\.m3u8\?token=}

    %URI{query: query} = URI.parse(url)
    %{"token" => jwt} = URI.decode_query(query)

    # JWT payload extraction via JOSE.JWT.peek_payload/1 returns a %JOSE.JWT{}
    # whose `:fields` map has the standard claims.
    fields = jwt |> JOSE.JWT.peek_payload() |> Map.fetch!(:fields)
    exp = fields["exp"]

    # exp must be approximately now + ttl (±5s clock skew tolerance).
    assert_in_delta exp, before_unix + ttl, 5

    # The 7-day-footgun guard: SDK default would mint exp at now + 604_800.
    # Refute that — if this assertion fails, `:expiration` is not being passed.
    refute exp > before_unix + 604_800,
           "JWT carries SDK-default 7-day exp — :expiration not passed correctly"
  end

  test "JWT verifies against the test signing-key fixture's public half" do
    {:ok, %{url: url}} = Adapter.signed_playback_url(TestProfile, "playback-id-1")

    %URI{query: query} = URI.parse(url)
    %{"token" => jwt} = URI.decode_query(query)

    public_jwk =
      "test/fixtures/mux/test_signing_private_key.pem"
      |> File.read!()
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_public()

    assert {true, _payload, _jws} = JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)
  end

  test "JWT carries the correct sub (playback_id) and aud (\"v\" for :video)" do
    {:ok, %{url: url}} = Adapter.signed_playback_url(TestProfile, "playback-id-aud-test")

    %URI{query: query} = URI.parse(url)
    %{"token" => jwt} = URI.decode_query(query)

    fields = jwt |> JOSE.JWT.peek_payload() |> Map.fetch!(:fields)
    assert fields["sub"] == "playback-id-aud-test"
    # Mux.Token translates :video → "v" (its `type_to_aud/1` mapping).
    assert fields["aud"] == "v"
  end
end
