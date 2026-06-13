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
  @operations_path Path.expand("../../guides/operations.md", __DIR__)
  @admin_console_path Path.expand("../../guides/admin_console.md", __DIR__)
  @mix_exs_path Path.expand("../../mix.exs", __DIR__)

  @expected_tus_extensions "creation,expiration,termination,checksum,creation-defer-length,concatenation"

  @nine_mix_tasks [
    "mix rindle.abort_incomplete_uploads",
    "mix rindle.backfill_metadata",
    "mix rindle.batch_owner_erasure",
    "mix rindle.cleanup_orphans",
    "mix rindle.doctor",
    "mix rindle.regenerate_variants",
    "mix rindle.runtime_status",
    "mix rindle.sweep_orphaned_temp_files",
    "mix rindle.verify_storage"
  ]

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

    assert readme =~ "getting_started.html"
    assert readme =~ "canonical deep adopter guide"
    assert guide =~ "[README](readme.html)"
  end

  test "README and getting-started describe CI-validated install smoke posture", %{
    readme: readme,
    guide: guide
  } do
    assert readme =~ "generated Phoenix app"
    assert readme =~ "Hex publish"

    for snippet <- [
          "install smoke",
          "generated Phoenix app",
          "image-only",
          "AV-enabled",
          "signed delivery"
        ] do
      assert guide =~ snippet
    end
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

  test "docs distinguish public install guidance from maintainer-only release runbooks", %{
    readme: readme,
    guide: guide
  } do
    assert readme =~ "upgrade runbook"
    assert guide =~ "Maintainer-only release"
    assert guide =~ "orchestration lives in"
    assert guide =~ "[Release Publish](release_publish.html)"

    refute readme =~ "GSD Hygiene"

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
    assert readme =~ "upgrading.html"
    assert guide =~ "[Upgrading](upgrading.html)"
    assert release =~ "[Upgrading](upgrading.html)"
    assert upgrade =~ "[Getting Started](getting_started.html)"
    assert upgrade =~ "pre-0.1.4"
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

  test "running guide publishes the durable libvips install matrix", %{running: running} do
    for snippet <- [
          "libvips",
          "libvips-dev",
          "brew install vips",
          "Image runtime (libvips)"
        ] do
      assert running =~ snippet
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

  test "running guide publishes the maintainer CI lane severity matrix", %{running: running} do
    for snippet <- [
          "Maintainer: CI lane severity",
          "Adopters can skip this section",
          "merge-blocking",
          "advisory",
          "secret-gated soak",
          "package-consumer",
          "adopter",
          "`proof`",
          "repo_hygiene_check.sh",
          "docs_parity_test.exs",
          "batch_owner_erasure_task_test.exs",
          ".github/workflows/ci.yml"
        ] do
      assert running =~ snippet
    end
  end

  test "running guide documents proof job as merge-blocking", %{running: running} do
    assert running =~ "`proof`"
    assert running =~ "merge-blocking"
    refute running =~ "Canonical lifecycle + doc parity"
  end

  test "troubleshooting guide is part of the public AV docs surface", %{
    troubleshooting: troubleshooting
  } do
    assert troubleshooting =~ "mix rindle.doctor"
    assert troubleshooting =~ "mix rindle.runtime_status"
    assert troubleshooting =~ "Rindle.Error.message/1"
    refute troubleshooting =~ "test/rindle/error_test.exs"
    assert troubleshooting =~ "`:ffmpeg_not_found`"
    assert troubleshooting =~ "`:range_unparseable`"
  end

  test "operations guide lists all nine shipped mix tasks" do
    operations = File.read!(@operations_path)

    assert operations =~ "nine Mix tasks"
    refute operations =~ "six Mix tasks"

    for task <- @nine_mix_tasks do
      assert operations =~ task, "expected #{task} in operations.md"
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
    refute Regex.match?(~r/PATCH\s*\|\s*—/, moduledoc)
    refute Regex.match?(~r/DELETE\s*\|\s*—/, moduledoc)
  end

  test "operations and troubleshooting guides teach the doctor vs runtime_status split" do
    operations = File.read!(Path.expand("../../guides/operations.md", __DIR__))
    troubleshooting = File.read!(@troubleshooting_path)

    assert operations =~ "mix rindle.doctor"
    assert operations =~ "mix rindle.runtime_status"
    assert operations =~ "doctor validates setup and drift"
    assert operations =~ "runtime status reports degraded or stuck work"
    assert operations =~ "repair verbs perform change"

    # TRUTH-07: the facade now ships a mountable admin console, so operations.md
    # must affirm the console (not deny a dashboard) while retaining the honest
    # "no auto-remediation" contract. The old dashboard-denial assertion was
    # reworked — re-asserting the bare denial phrase would relock the
    # scope-reversed claim Plan 01 removed (Pitfall 5 / T-93-05).
    assert operations =~ "no auto-remediation"

    assert operations =~ ~r/admin[_ ]console/i,
           "operations.md must mention the mountable admin console (TRUTH-07)"

    refute operations =~ "intentionally has no dashboard",
           "operations.md must not deny a dashboard now that the console ships"

    assert troubleshooting =~ "mix rindle.doctor"
    assert troubleshooting =~ "mix rindle.runtime_status"
    assert troubleshooting =~ "doctor validates setup and drift"
    assert troubleshooting =~ "runtime status reports degraded or stuck work"

    assert troubleshooting =~ "no auto-remediation"

    refute troubleshooting =~ "intentionally has no dashboard",
           "troubleshooting.md must not deny a dashboard now that the console ships"
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
          # TRUTH-07: user_flows now affirms the mountable admin console instead
          # of denying "an admin UI". The old required `"admin ui"` snippet was
          # replaced with the truthful "admin console" token (asserted below);
          # leaving it here would relock the scope-reversed denial (T-93-05).
          "admin console",
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

    # TRUTH-07: the JTBD admin-UI exclusion is reversed. user_flows must not
    # carry the old denial phrasings now that the mountable console ships.
    refute Regex.match?(~r/\ban admin UI\b/i, user_flows),
           "user_flows.md must not deny an admin UI (scope reversed in v1.18)"

    refute user_flows =~ "Admin UI, force-delete",
           "user_flows.md must not list the admin UI among deferred work"
  end

  test "admin console truth is locked across facade, guide, extras, and README", %{
    readme: readme
  } do
    # (1) Facade moduledoc: affirm the mountable console, deny no admin UI.
    facade_moduledoc =
      Rindle
      |> moduledoc!()
      |> normalize_whitespace()

    assert facade_moduledoc =~ "rindle_admin",
           "Rindle facade moduledoc must reference the rindle_admin router macro (TRUTH-07)"

    assert facade_moduledoc =~ "admin console",
           "Rindle facade moduledoc must affirm the mountable admin console (TRUTH-07)"

    refute Regex.match?(~r/no admin ui/i, facade_moduledoc),
           "Rindle facade moduledoc must not deny an admin UI (scope reversed in v1.18)"

    # Retain the deferred owner-erasure truths the facade still promises.
    assert facade_moduledoc =~ "force-delete"
    assert facade_moduledoc =~ "scheduler/cron erasure"

    # (2) admin_console guide exists, is in extras, and names the router macro.
    assert File.exists?(@admin_console_path),
           "guides/admin_console.md must exist (created by Plan 03)"

    admin_guide = File.read!(@admin_console_path)
    assert admin_guide =~ "rindle_admin",
           "admin_console.md must document the rindle_admin router macro"

    mix_exs = File.read!(@mix_exs_path)
    assert mix_exs =~ "guides/admin_console.md",
           "mix.exs must wire admin_console.md into docs extras"

    # (3) README links the rendered guide.
    assert readme =~ "admin_console.html",
           "README must link the admin console guide (admin_console.html)"
  end

  test "user flows roadmap does not regress tus or mux to near-term", %{user_flows: user_flows} do
    normalized = String.downcase(user_flows)

    assert normalized =~ "initiate_tus_upload"
    assert normalized =~ "shipped since 0.1.8"
    assert normalized =~ "resumable uploads"

    refute Regex.match?(~r/near-term.{0,80}tus/u, normalized)
    refute Regex.match?(~r/tus.{0,80}near-term/u, normalized)
    refute Regex.match?(~r/near-term.{0,80}mux/u, normalized)
    refute Regex.match?(~r/browser.{0,40}mux.{0,80}near-term/u, normalized)
  end

  test "user flows and operations document batch erasure without duplicating mix task contract",
       %{
         user_flows: user_flows
       } do
    operations = File.read!(Path.expand("../../guides/operations.md", __DIR__))
    normalized_flows = String.downcase(user_flows)
    normalized_ops = String.downcase(operations)

    assert normalized_flows =~ "preview_batch_owner_erasure"
    assert normalized_flows =~ "batch_owner_erasure"
    assert normalized_ops =~ "batch_owner_erasure"
    assert normalized_ops =~ "user_flows.html"

    refute normalized_ops =~ "--owners-file"
    refute normalized_ops =~ "owner_type"
  end

  test "getting-started and operations stay thin while pointing to the canonical owner-erasure flow",
       %{
         guide: guide
       } do
    operations = File.read!(Path.expand("../../guides/operations.md", __DIR__))

    assert guide =~ "[User Flows](user_flows.html)"
    assert guide =~ "account deletion / owner erasure"
    assert guide =~ "Batch owner erasure"
    assert guide =~ "user_flows.html"

    assert operations =~ "[User Flows](user_flows.html)"
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

  defp fetch_docs!(module) do
    assert Code.ensure_loaded?(module),
           "#{inspect(module)} must be loadable for docs parity checks"

    case Code.fetch_docs(module) do
      {:error, reason} ->
        flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")

      docs ->
        docs
    end
  end

  defp moduledoc!(module) do
    case fetch_docs!(module) do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} when is_binary(doc) -> doc
      {:docs_v1, _, _, _, {_, doc}, _, _} when is_binary(doc) -> doc
      {:docs_v1, _, _, _, doc, _, _} when is_binary(doc) -> doc
      other -> flunk("expected moduledoc for #{inspect(module)}, got #{inspect(other)}")
    end
  end

  defp normalize_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
