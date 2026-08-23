Code.require_file("support.ex", __DIR__)

defmodule Rindle.InstallSmoke.DocsParity.OnboardingAndCapabilitiesTest do
  import Rindle.InstallSmoke.DocsParity.Support
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../../README.md", __DIR__)
  @guide_path Path.expand("../../../guides/getting_started.md", __DIR__)
  @expected_tus_extensions "creation,expiration,termination,checksum,creation-defer-length,concatenation"

  setup_all do
    {:ok, load_docs!(%{readme: @readme_path, guide: @guide_path})}
  end

  test "README and getting-started guide teach the facade-first lifecycle and handoff", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "Rindle.Profile"
      assert doc =~ "Rindle.initiate_upload"
      assert doc =~ "Rindle.verify_completion"
      assert doc =~ "Rindle.attach"
      assert doc =~ "Rindle.url"
    end

    assert readme =~ "getting_started.html"
    assert readme =~ "canonical deep adopter guide"
    assert guide =~ "[README](readme.html)"
  end

  test "README and getting-started guide teach convenience helpers and bangs", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      # Read helpers (API-09, API-10)
      assert doc =~ "Rindle.attachment_for"
      assert doc =~ "Rindle.ready_variants_for"

      # Bang variants (API-11)
      assert doc =~ "Rindle.attach!"
      assert doc =~ "Rindle.detach!"
      assert doc =~ "Rindle.upload!"
      assert doc =~ "Rindle.url!"
      assert doc =~ "Rindle.variant_url!"

      # Boundary contract surfaced via Rindle.Error
      assert doc =~ "Rindle.Error"
    end
  end

  test "introductory sections keep Rindle and Rindle.Profile as the first-tier concepts", %{
    readme: readme,
    guide: guide
  } do
    for {doc, name} <- [{readme, "README"}, {guide, "getting-started"}] do
      intro = introductory_section(doc)

      assert intro =~ "Rindle", "#{name} intro should mention Rindle"
      assert intro =~ "Rindle.Profile", "#{name} intro should mention Rindle.Profile"

      refute intro =~ "Rindle.Upload.Broker",
             "#{name} intro should not present Rindle.Upload.Broker as the default entrypoint"
    end
  end

  test "docs keep presigned PUT first-run and multipart advanced-only", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "presigned PUT"
      assert doc =~ "first-run path"
      assert doc =~ "Multipart upload is"
      assert doc =~ "advanced"

      refute Regex.match?(~r/first-run path is multipart/i, doc)
      refute Regex.match?(~r/default onboarding story is multipart/i, doc)
      refute Regex.match?(~r/multipart upload is the default/i, doc)
      refute Regex.match?(~r/Rindle\.Upload\.Broker.+default first-run entrypoint/is, doc)
      refute Regex.match?(~r/Broker\.(initiate_session|verify_completion).+first-run/is, doc)
    end
  end

  test "README and getting-started expose GCS only as an optional advanced pointer", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "Storage with GCS (optional)"
      assert doc =~ "mix rindle.doctor"
      assert doc =~ "storage_gcs.html"
      assert Regex.match?(~r/GCS resumable upload is ((a shipped|an) )?advanced path/i, doc)

      refute Regex.match?(~r/GCS resumable upload is the canonical first-run/i, doc)
      refute Regex.match?(~r/GCS resumable upload is the default onboarding/i, doc)
    end
  end

  test "README and getting-started guide teach the locked AV onboarding path", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "mix deps.get"
      assert doc =~ "mix rindle.doctor"
      assert doc =~ "libvips"
      assert doc =~ "Rindle.Profile.Presets.Web"
      assert doc =~ "kind: :video"
      assert doc =~ "preset: :web_720p"
      assert doc =~ "preset: :video_poster_scene"
      assert doc =~ "FFmpeg >= 6.0"
      assert doc =~ "running.html"
    end
  end

  test "README leads with original-only image attachment before AV setup", %{readme: readme} do
    image_first_index = string_index(readme, "## First Attachment in ~2 Minutes")

    assert image_first_index,
           "README must include the image-first first attachment section"

    assert_in_order!(readme, [
      "## First Attachment in ~2 Minutes",
      "## AV Quickstart"
    ])

    for snippet <- [
          "FFmpeg >= 6.0",
          "libvips",
          "kind: :video",
          "Rindle.Profile.Presets.Web",
          "web_720p",
          "poster"
        ] do
      index = string_index(readme, snippet)
      assert index, "expected #{inspect(snippet)} in README"

      assert index > image_first_index,
             "#{inspect(snippet)} must appear after image-first section"
    end

    for snippet <- [
          "variants: []",
          "allow_mime",
          "max_bytes",
          "Rindle.initiate_upload",
          "Rindle.Upload.Broker.sign_url",
          "Rindle.verify_completion",
          "Rindle.attach",
          "Rindle.url",
          "running.html"
        ] do
      assert readme =~ snippet
    end
  end

  test "README states the product-fit boundary", %{readme: readme} do
    assert readme =~ "## When Not to Use Rindle"

    for snippet <- [
          "Phoenix/Ecto library",
          "hosted media platform",
          "daemon",
          "CDN replacement",
          "DRM",
          "HLS/DASH",
          "AI/GPU",
          "PDF/Office"
        ] do
      assert readme =~ snippet
    end
  end

  test "TusPlug moduledoc matches shipped tus scope" do
    moduledoc =
      Rindle.Upload.TusPlug
      |> moduledoc!()
      |> normalize_whitespace()

    assert moduledoc =~ @expected_tus_extensions

    for token <- String.split(@expected_tus_extensions, ",") do
      assert moduledoc =~ token
    end

    assert moduledoc =~ "local"
    assert moduledoc =~ "S3"
    assert moduledoc =~ "PATCH"
    assert moduledoc =~ "DELETE"
    assert moduledoc =~ "implemented"
    assert moduledoc =~ "no Phoenix"
    assert moduledoc =~ "@behaviour Plug"
    assert moduledoc =~ "sticky"
    assert moduledoc =~ "node-affinity" or moduledoc =~ "node-local"
    assert moduledoc =~ ":tus_tail_missing"

    refute Regex.match?(~r/Local only/i, moduledoc)
    refute moduledoc =~ "Phase 42"
    refute Regex.match?(~r/PATCH\s*\|\s*Ã¢ÂÂ/, moduledoc)
    refute Regex.match?(~r/DELETE\s*\|\s*Ã¢ÂÂ/, moduledoc)
  end
end
