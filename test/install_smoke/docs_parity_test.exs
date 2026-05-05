defmodule Rindle.InstallSmoke.DocsParityTest do
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../README.md", __DIR__)
  @guide_path Path.expand("../../guides/getting_started.md", __DIR__)
  @troubleshooting_path Path.expand("../../guides/troubleshooting.md", __DIR__)
  @running_path Path.expand("../../RUNNING.md", __DIR__)

  setup_all do
    {:ok,
       %{
       readme: File.read!(@readme_path),
       guide: File.read!(@guide_path),
       troubleshooting: File.read!(@troubleshooting_path),
       running: File.read!(@running_path)
     }}
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

    assert readme =~ "guides/getting_started.md"
    assert readme =~ "canonical deep adopter guide"
    assert guide =~ "[`README.md`](../README.md)"
  end

  test "README and getting-started guide teach Phase 19 convenience helpers and bangs", %{
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

      # Boundary contract surfaced (Phase 17 D-01 allowlist)
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

  test "docs call out adopter-owned Repo, default Oban ownership, and explicit migrations", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "adopter-owned Repo"
      assert doc =~ "default Oban"
      assert doc =~ ~s(config :rindle, :repo, MyApp.Repo)
      assert doc =~ ~s(config :my_app, Oban)
      assert doc =~ "Application.app_dir(:rindle, \"priv/repo/migrations\")"
      assert doc =~ "docs snippet"
      assert doc =~ "mix rindle.*"
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

  test "README and getting-started guide teach the locked AV onboarding path", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "mix deps.get"
      assert doc =~ "mix rindle.doctor"
      assert doc =~ "Rindle.Profile.Presets.Web"
      assert doc =~ "kind: :video"
      assert doc =~ "preset: :web_720p"
      assert doc =~ "preset: :video_poster_scene"
      assert doc =~ "FFmpeg >= 6.0"
      assert doc =~ "RUNNING.md"
    end
  end

  test "running guide publishes the durable FFmpeg install matrix", %{running: running} do
    for snippet <- [
          "FFmpeg >= 6.0",
          "brew install ffmpeg",
          "apt-get install -y ffmpeg",
          "apk add --no-cache ffmpeg",
          "FedericoCarboni/setup-ffmpeg",
          "Fly.io Dockerfile",
          "Heroku Aptfile",
          "Render Dockerfile",
          "mix rindle.doctor"
        ] do
      assert running =~ snippet
    end
  end

  test "troubleshooting guide is part of the public AV docs surface", %{
    troubleshooting: troubleshooting
  } do
    assert troubleshooting =~ "mix rindle.doctor"
    assert troubleshooting =~ "Rindle.Error.message/1"
    assert troubleshooting =~ "test/rindle/error_test.exs"
    assert troubleshooting =~ "`:ffmpeg_not_found`"
    assert troubleshooting =~ "`:range_unparseable`"
  end

  defp introductory_section(doc) do
    case Regex.split(~r/^##\s+/m, doc, parts: 2) do
      [intro] -> intro
      [intro, _rest] -> intro
    end
  end
end
