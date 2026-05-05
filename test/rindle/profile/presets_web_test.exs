defmodule Rindle.Profile.PresetsWebTest do
  use ExUnit.Case, async: true

  alias Rindle.Profile.Presets.Web

  defmodule PresetProfile do
    @moduledoc false

    @variants Web.variants()

    use Rindle.Profile,
      storage: Rindle.Storage.Local,
      variants: @variants,
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  defmodule PresetProfileWithStrip do
    @moduledoc false

    @variants Web.variants(scrub_strip: true)

    use Rindle.Profile,
      storage: Rindle.Storage.Local,
      variants: @variants,
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
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
               poster: %{kind: :image, preset: :video_poster_scene},
               web_720p: %{kind: :video, preset: :web_720p}
             ]
    end

    test "adds the scrub strip only when requested" do
      assert PresetProfileWithStrip.variants() == [
               poster: %{kind: :image, preset: :video_poster_scene},
               scrub_strip: %{kind: :image, preset: :video_thumbnail_strip},
               web_720p: %{kind: :video, preset: :web_720p}
             ]
    end
  end
end
