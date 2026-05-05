defmodule Rindle.ErrorTest do
  use ExUnit.Case, async: true

  @locked_messages %{
    processor_capability_missing:
      "could not deliver: processor capability missing. Check the variant kind and confirm the FFmpeg runtime supports it.",
    ffmpeg_not_found:
      "could not deliver: FFmpeg was not found. Install FFmpeg 6.0 or newer on this runtime and try again.",
    capability_drift:
      "could not deliver: generated media did not match the declared variant contract. Rebuild the variant recipe or verify the FFmpeg runtime.",
    variant_source_not_found:
      "could not deliver: source media for this variant is no longer available. Re-upload the asset or regenerate the variant.",
    unsupported_codec:
      "could not deliver: the source media uses an unsupported codec for this variant. Transcode the source to a supported codec or change the preset.",
    streaming_not_configured:
      "could not deliver: streaming delivery is not configured for this asset. Configure a local playback route or signed streaming delivery.",
    variant_processing_cancelled:
      "could not deliver: variant processing was cancelled before completion. Retry the job if playback is still needed.",
    range_unparseable:
      "could not deliver: the playback range header could not be parsed. Retry without a Range header or send one valid byte range."
  }

  test "renders the locked AV reason vocabulary byte-for-byte" do
    for {reason, expected_message} <- @locked_messages do
      error = struct!(Rindle.Error, action: :deliver, reason: reason)

      assert Rindle.Error.message(error) == expected_message
    end
  end
end
