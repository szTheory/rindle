defmodule Rindle.Profile.Presets.MuxDirectUploadWebTest do
  use ExUnit.Case, async: true

  alias Rindle.Profile.Presets.MuxDirectUploadWeb
  alias Rindle.Profile.Presets.MuxWeb

  defmodule DirectUploadProfile do
    @moduledoc false

    use MuxDirectUploadWeb,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4", "video/webm"],
      max_bytes: 524_288_000
  end

  defmodule ExistingMuxWebProfile do
    @moduledoc false

    use MuxWeb,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4", "video/webm"],
      max_bytes: 524_288_000
  end

  test "locks ingest_mode: :direct_creator_upload while preserving the Mux baseline" do
    assert DirectUploadProfile.delivery_policy().streaming == %{
             provider: Rindle.Streaming.Provider.Mux,
             playback_policy: :signed,
             ingest_mode: :direct_creator_upload,
             source_variant: :web_720p
           }
  end

  test "preserves the existing MuxWeb ingest mode unchanged" do
    assert ExistingMuxWebProfile.delivery_policy().streaming.ingest_mode == :server_push
  end
end
