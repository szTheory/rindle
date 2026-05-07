defmodule Rindle.Profile.Presets.MuxWebTest do
  use ExUnit.Case, async: true

  alias Rindle.Profile.Presets.MuxWeb
  alias Rindle.Profile.Presets.Web

  defmodule MuxWebProfile do
    @moduledoc false

    use MuxWeb,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
      max_bytes: 524_288_000
  end

  defmodule MuxWebProfileWithStrip do
    @moduledoc false

    use MuxWeb,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4"],
      max_bytes: 100_000_000,
      scrub_strip: true
  end

  defmodule WebProfileForCompare do
    @moduledoc false

    use Web,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
      max_bytes: 524_288_000
  end

  defmodule AdopterDeliveryWins do
    @moduledoc false

    use MuxWeb,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4"],
      delivery: [public: false, signed_url_ttl_seconds: 3600]
  end

  describe "compile" do
    test "inherits Web's web_720p + poster variants verbatim (D-01, D-04)" do
      assert MuxWebProfile.variants() == WebProfileForCompare.variants()
    end

    test "writes the locked streaming block to delivery_policy/0 (D-02)" do
      assert MuxWebProfile.delivery_policy().streaming == %{
               provider: Rindle.Streaming.Provider.Mux,
               playback_policy: :signed,
               ingest_mode: :server_push,
               source_variant: :web_720p
             }
    end

    test "scrub_strip flag passes through to Web.variants/1 (D-01 passthrough)" do
      assert {:scrub_strip, _} =
               List.keyfind(MuxWebProfileWithStrip.variants(), :scrub_strip, 0)
    end

    test "adopter delivery keys other than :streaming survive merge (Keyword.merge last)" do
      # The locked streaming block always wins; adopter's other delivery
      # keys (public, signed_url_ttl_seconds, ...) are preserved.
      policy = AdopterDeliveryWins.delivery_policy()
      assert policy.streaming.provider == Rindle.Streaming.Provider.Mux
      assert policy.streaming.playback_policy == :signed
      assert policy.public == false
      assert policy.signed_url_ttl_seconds == 3600
    end
  end
end
