defmodule Rindle.Profile.PresetsWebTest do
  use ExUnit.Case, async: true

  alias Rindle.Adopter.CanonicalApp.VideoProfile, as: CanonicalVideoProfile
  alias Rindle.Profile.Presets.Web

  defmodule PresetProfile do
    @moduledoc false

    use Web,
      storage: Rindle.Storage.Local,
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  defmodule PresetProfileWithStrip do
    @moduledoc false

    use Web,
      storage: Rindle.Storage.Local,
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      scrub_strip: true
  end

  describe "variants/1" do
    test "teaches the explicit web_720p plus poster onboarding story" do
      assert Web.variants() == [
               web_720p: [kind: :video, preset: :web_720p],
               poster: [kind: :image, preset: :video_poster_scene]
             ]
    end

    test "keeps scrub strips explicit and opt-in" do
      assert Web.variants(scrub_strip: true) == [
               web_720p: [kind: :video, preset: :web_720p],
               poster: [kind: :image, preset: :video_poster_scene],
               scrub_strip: [kind: :image, preset: :video_thumbnail_strip]
             ]
    end
  end

  describe "profile consumption" do
    test "compiles into a real profile without inventing raw FFmpeg policy" do
      assert PresetProfile.variants() == [
               poster: %{preset: :video_poster_scene},
               web_720p: %{kind: :video, preset: :web_720p, faststart: true}
             ]
    end

    test "adds the scrub strip only when requested" do
      assert PresetProfileWithStrip.variants() == [
               poster: %{preset: :video_poster_scene},
               scrub_strip: %{preset: :video_thumbnail_strip},
               web_720p: %{kind: :video, preset: :web_720p, faststart: true}
             ]
    end

    test "keeps the canonical adopter profile on the exact stock onboarding surface" do
      assert CanonicalVideoProfile.variants() == PresetProfile.variants()

      assert CanonicalVideoProfile.upload_policy().allow_mime == [
               "video/mp4",
               "video/quicktime",
               "video/webm"
             ]

      assert PresetProfile.upload_policy().allow_mime ==
               CanonicalVideoProfile.upload_policy().allow_mime
    end
  end
end
