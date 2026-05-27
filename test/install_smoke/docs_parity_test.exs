Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.DocsParityTest do
  alias Rindle.InstallSmoke.GeneratedAppHelper
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../README.md", __DIR__)
  @guide_path Path.expand("../../guides/getting_started.md", __DIR__)
  @upgrade_path Path.expand("../../guides/upgrading.md", __DIR__)
  @troubleshooting_path Path.expand("../../guides/troubleshooting.md", __DIR__)
  @release_path Path.expand("../../guides/release_publish.md", __DIR__)
  @running_path Path.expand("../../RUNNING.md", __DIR__)
  @user_flows_path Path.expand("../../guides/user_flows.md", __DIR__)

  setup_all do
    {:ok,
     %{
       readme: File.read!(@readme_path),
       guide: File.read!(@guide_path),
       upgrade: File.read!(@upgrade_path),
       troubleshooting: File.read!(@troubleshooting_path),
       release: File.read!(@release_path),
       running: File.read!(@running_path),
       user_flows: File.read!(@user_flows_path)
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

  test "README and getting-started guide lock docs to the package-consumer proof matrix", %{
    readme: readme,
    guide: guide
  } do
    assert readme =~ "generated package-consumer Phoenix app"
    assert readme =~ "image-only"
    assert readme =~ "AV-enabled"
    assert readme =~ "installed artifact"

    for snippet <- [
          "package-consumer proof matrix",
          "generated app",
          "built-artifact proof",
          "published-artifact proof",
          "image-only",
          "AV-enabled",
          "signed delivery"
        ] do
      assert guide =~ snippet
    end
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

  test "README and getting-started expose GCS only as an optional advanced pointer", %{
    readme: readme,
    guide: guide
  } do
    for doc <- [readme, guide] do
      assert doc =~ "Storage with GCS (optional)"
      assert doc =~ "mix rindle.doctor"
      assert doc =~ "storage_gcs.md"
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
      assert doc =~ "Rindle.Profile.Presets.Web"
      assert doc =~ "kind: :video"
      assert doc =~ "preset: :web_720p"
      assert doc =~ "preset: :video_poster_scene"
      assert doc =~ "FFmpeg >= 6.0"
      assert doc =~ "RUNNING.md"
    end
  end

  test "docs distinguish public install guidance from maintainer-only release runbooks", %{
    readme: readme,
    guide: guide
  } do
    assert readme =~ "release runbook"
    assert guide =~ "maintainer-only release orchestration stays in"
    assert guide =~ "[`release_publish.md`](release_publish.md)"

    for doc <- [readme, guide] do
      refute doc =~ "mix hex.user whoami"
      refute doc =~ "HEX_API_KEY"
    end
  end

  test "upgrade guidance is discoverable without polluting the greenfield path", %{
    readme: readme,
    guide: guide,
    upgrade: upgrade,
    release: release
  } do
    assert readme =~ "guides/upgrading.md"
    assert guide =~ "[`upgrading.md`](upgrading.md)"
    assert release =~ "[`upgrading.md`](upgrading.md)"
    assert upgrade =~ "[`getting_started.md`](getting_started.md)"
    assert upgrade =~ "pre-v1.4"
    assert String.downcase(upgrade) =~ "existing adopters"
  end

  test "upgrade guide mirrors the canonical generated-app proof sequence", %{upgrade: upgrade} do
    steps = GeneratedAppHelper.canonical_upgrade_step_sequence()

    for step <- steps do
      assert String.downcase(upgrade) =~ String.downcase(step.checkpoint)
      assert upgrade =~ step.proof
    end

    assert_in_order!(upgrade, Enum.map(steps, & &1.checkpoint))
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
    assert troubleshooting =~ "mix rindle.runtime_status"
    assert troubleshooting =~ "Rindle.Error.message/1"
    assert troubleshooting =~ "test/rindle/error_test.exs"
    assert troubleshooting =~ "`:ffmpeg_not_found`"
    assert troubleshooting =~ "`:range_unparseable`"
  end

  test "operations and troubleshooting guides teach the phase 31 diagnostics split" do
    operations = File.read!(Path.expand("../../guides/operations.md", __DIR__))
    troubleshooting = File.read!(@troubleshooting_path)

    assert operations =~ "mix rindle.doctor"
    assert operations =~ "mix rindle.runtime_status"
    assert operations =~ "doctor validates setup and drift"
    assert operations =~ "runtime status reports degraded or stuck work"
    assert operations =~ "repair verbs perform change"
    assert operations =~ "no dashboard"
    assert operations =~ "no auto-remediation"

    assert troubleshooting =~ "mix rindle.doctor"
    assert troubleshooting =~ "mix rindle.runtime_status"
    assert troubleshooting =~ "doctor validates setup and drift"
    assert troubleshooting =~ "runtime status reports degraded or stuck work"
  end

  test "user flows guide freezes the canonical owner-erasure support truth", %{
    user_flows: user_flows
  } do
    normalized =
      user_flows
      |> String.replace(~r/\n>\s*/, " ")
      |> String.downcase()

    for snippet <- [
          "preview_owner_erasure/2",
          "erase_owner/2",
          "attachments_to_detach",
          "assets_to_purge",
          "retained shared assets",
          "rindle-managed",
          "detach now, purge later",
          "cleanup_orphans",
          "maintenance-only",
          "admin ui",
          "preview_batch_owner_erasure",
          "erase_batch_owner_erasure",
          "batch owner erasure",
          "batch_owner_erasure",
          "batch_owner_failed",
          "partial_report",
          "force-delete"
        ] do
      assert normalized =~ snippet
    end

    refute normalized =~ "bulk orchestration"

    refute user_flows =~
             "Today you detach each of an owner's slots, then let `mix rindle.cleanup_orphans` purge the now-unattached assets."

    refute Regex.match?(
             ~r/Today you detach each of an owner's slots, then let `mix rindle\.cleanup_orphans` purge/is,
             user_flows
           )

    refute user_flows =~ "being standardized for `v1.10`"
    refute user_flows =~ "The full executable facade lands in later `v1.10` phase work"
  end

  test "user flows and operations document batch erasure without duplicating mix task contract", %{
    user_flows: user_flows
  } do
    operations = File.read!(Path.expand("../../guides/operations.md", __DIR__))
    normalized_flows = String.downcase(user_flows)
    normalized_ops = String.downcase(operations)

    assert normalized_flows =~ "preview_batch_owner_erasure"
    assert normalized_flows =~ "batch_owner_erasure"
    assert normalized_ops =~ "batch_owner_erasure"
    assert normalized_ops =~ "user_flows.md"

    refute normalized_ops =~ "--owners-file"
    refute normalized_ops =~ "owner_type"
  end

  test "getting-started and operations stay thin while pointing to the canonical owner-erasure flow",
       %{
         guide: guide
       } do
    operations = File.read!(Path.expand("../../guides/operations.md", __DIR__))

    assert guide =~ "[`user_flows.md`](user_flows.md)"
    assert guide =~ "account deletion / owner erasure"
    assert guide =~ "Batch owner erasure"
    assert guide =~ "user_flows.md"

    assert operations =~ "[`user_flows.md`](user_flows.md)"
    assert operations =~ "supported account-deletion surface"
    assert operations =~ "cleanup_orphans"
    assert operations =~ "maintenance-only"

    refute guide =~ "detach each of an owner"
    refute operations =~ "detach each of an owner"
  end

  defp introductory_section(doc) do
    case Regex.split(~r/^##\s+/m, doc, parts: 2) do
      [intro] -> intro
      [intro, _rest] -> intro
    end
  end

  defp assert_in_order!(doc, snippets) do
    normalized_doc = String.downcase(doc)

    {_last_index, _last_snippet} =
      Enum.reduce(snippets, {-1, nil}, fn snippet, {last_index, _last_snippet} ->
        index = string_index(normalized_doc, String.downcase(snippet))

        assert index,
               "expected snippet #{inspect(snippet)} to appear in order after index #{last_index}"

        assert index > last_index,
               "expected snippet #{inspect(snippet)} to appear after #{last_index}, got #{index}"

        {index, snippet}
      end)
  end

  defp string_index(doc, snippet) do
    case :binary.match(doc, snippet) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end
end
