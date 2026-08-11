Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.DocsParityTest do
  alias Rindle.InstallSmoke.GeneratedAppHelper
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../README.md", __DIR__)
  @contributing_path Path.expand("../../CONTRIBUTING.md", __DIR__)
  @guide_path Path.expand("../../guides/getting_started.md", __DIR__)
  @upgrade_path Path.expand("../../guides/upgrading.md", __DIR__)
  @troubleshooting_path Path.expand("../../guides/troubleshooting.md", __DIR__)
  @release_path Path.expand("../../guides/release_publish.md", __DIR__)
  @running_path Path.expand("../../RUNNING.md", __DIR__)
  @user_flows_path Path.expand("../../guides/user_flows.md", __DIR__)
  @operations_path Path.expand("../../guides/operations.md", __DIR__)
  @admin_console_path Path.expand("../../guides/admin_console.md", __DIR__)
  @mix_exs_path Path.expand("../../mix.exs", __DIR__)
  @migration_module_path Path.expand("../../lib/rindle/migration.ex", __DIR__)

  @expected_tus_extensions "creation,expiration,termination,checksum,creation-defer-length,concatenation"

  @stability_sentence "Rindle follows Semantic Versioning. While Rindle is 0.x, public APIs may change between minor versions; review CHANGELOG.md and guides/upgrading.md before upgrading. Rindle 1.0 will mean the public API is stable enough that breaking public API changes move to major versions."

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
       contributing: File.read!(@contributing_path),
       guide: File.read!(@guide_path),
       upgrade: File.read!(@upgrade_path),
       troubleshooting: File.read!(@troubleshooting_path),
       release: File.read!(@release_path),
       running: File.read!(@running_path),
       user_flows: File.read!(@user_flows_path),
       migration_module: File.read!(@migration_module_path)
     }}
  end

  test "README and CONTRIBUTING state the shared pre-1.0 stability contract", %{
    readme: readme,
    contributing: contributing
  } do
    for {doc, name} <- [{readme, "README"}, {contributing, "CONTRIBUTING"}] do
      assert doc =~ "## Versioning and stability"
      assert doc =~ @stability_sentence

      assert doc |> String.split(@stability_sentence) |> length() == 2,
             "#{name} should contain the shared stability sentence exactly once"
    end

    assert_in_order!(readme, ["## Versioning and stability", "## Install"])

    assert_in_order!(contributing, [
      "## Versioning and stability",
      "## Reproduce the PR gate locally: `mix ci`"
    ])
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

  test "migration docs teach pinned Rindle.Migration and host-owned Oban setup", %{
    readme: readme,
    guide: guide,
    upgrade: upgrade
  } do
    migration_sections = [
      {"README migrations", section_between!(readme, "## Migrations", "## First Attachment")},
      {"getting-started step 3", section_between!(guide, "## 3.", "## 4.")},
      {"Unreleased upgrade note", section_between!(upgrade, "## Unreleased / Next", "## 0.1.3")}
    ]

    for {name, section} <- migration_sections do
      assert section =~ "Rindle.Migration.up(version: 1)",
             "#{name} must include Rindle.Migration.up(version: 1)"

      assert section =~ "Rindle.Migration.down(version: 1)",
             "#{name} must include Rindle.Migration.down(version: 1)"

      assert section =~ "Oban.Migration",
             "#{name} must name Oban.Migration as the host-owned Oban migration path"

      assert section =~ "oban_jobs",
             "#{name} must say Rindle does not own or create oban_jobs"

      assert section =~ "mix ecto.migrate",
             "#{name} must keep the normal host-app migration workflow"

      assert section =~ "mix rindle.doctor",
             "#{name} must keep doctor as the post-migration verification command"

      assert section =~ "rindle",
             "#{name} must state the rindle default"

      assert section =~ "prefix: \"public\"",
             "#{name} must keep the explicit public compatibility pairing"

      assert section =~ "public schema",
             "#{name} must pair public compatibility with a public-compiled release"

      assert Regex.match?(~r/back\s*up|backup/i, section),
             "#{name} must pair rollback copy with backup guidance"

      assert Regex.match?(~r/destructive/i, section),
             "#{name} must label Rindle.Migration.down/1 as destructive"

      assert section =~ "Rindle-owned tables",
             "#{name} must scope rollback to Rindle-owned tables"

      assert section =~ "schema_migrations",
             "#{name} must preserve the host migration ledger"

      refute section =~ "tenant_media",
             "#{name} must not teach arbitrary schema prefixes"

      refute section =~ "Application.app_dir(:rindle, \"priv/repo/migrations\")",
             "#{name} must not teach the legacy package migration directory as the greenfield path"

      refute section =~ "Ecto.Migrator.run",
             "#{name} must not teach raw package-path Ecto.Migrator.run for greenfield setup"
    end
  end

  test "fresh-install docs match generated host migration fixtures", %{
    readme: readme,
    guide: guide
  } do
    default_fixture = GeneratedAppHelper.default_install_contract()
    public_fixture = GeneratedAppHelper.public_compatibility_contract()

    assert default_fixture.host_oban_migration_source =~ "Oban.Migration.up()"
    assert default_fixture.rindle_migration_source =~ "Rindle.Migration.up(version: 1)"

    assert public_fixture.migration_source =~
             "Rindle.Migration.up(version: 1, prefix: \"public\")"

    assert public_fixture.migration_calls.up ==
             "def up, do: Rindle.Migration.up(version: 1, prefix: \"public\")"

    assert public_fixture.migration_calls.down ==
             "def down, do: Rindle.Migration.down(version: 1, prefix: \"public\")"

    assert public_fixture.compile_prefix == "public"

    for {name, section} <- [
          {"README migrations", section_between!(readme, "## Migrations", "## First Attachment")},
          {"getting-started step 3", section_between!(guide, "## 3.", "## 4.")}
        ] do
      assert section =~ default_fixture.host_oban_migration_source |> migration_call!(),
             "#{name} must match the generated host-owned Oban migration"

      assert section =~ default_fixture.rindle_migration_source |> migration_call!(),
             "#{name} must match the generated default Rindle migration"

      for {callback, call} <- public_fixture.migration_calls do
        assert section =~ call,
               "#{name} must teach the generated explicit-public Rindle #{callback}/0 callback"
      end

      assert section =~ "public-compiled",
             "#{name} must pair public compatibility with the public-compiled fixture"

      for host_relation <- ["public.oban_jobs", "public.schema_migrations"] do
        assert section =~ host_relation,
               "#{name} must keep #{host_relation} outside Rindle ownership"
      end

      for forbidden <- [
            "Application.app_dir(:rindle, \"priv/repo/migrations\")",
            "Ecto.Migrator.run",
            "search_path",
            "tenant_media"
          ] do
        refute section =~ forbidden,
               "#{name} must not teach #{inspect(forbidden)} for a fresh install"
      end
    end
  end

  test "Rindle.Migration moduledoc matches public fresh-install fixtures", %{
    readme: readme,
    guide: guide,
    migration_module: migration_module
  } do
    default_fixture = GeneratedAppHelper.default_install_contract()
    public_fixture = GeneratedAppHelper.public_compatibility_contract()

    default_call = migration_call!(default_fixture.rindle_migration_source)
    public_calls = public_fixture.migration_calls
    oban_call = migration_call!(default_fixture.host_oban_migration_source)

    assert public_fixture.compile_prefix == "public"

    surfaces = [
      {"README migrations", section_between!(readme, "## Migrations", "## First Attachment")},
      {"getting-started step 3", section_between!(guide, "## 3.", "## 4.")},
      {"Rindle.Migration moduledoc source", migration_module}
    ]

    for {name, surface} <- surfaces do
      assert surface =~ default_call, "#{name} must match the default generated fixture"

      for {callback, call} <- public_calls do
        assert surface =~ call,
               "#{name} must match the explicit-public generated #{callback}/0 callback"
      end

      assert surface =~ oban_call, "#{name} must retain separate host-owned Oban setup"
      assert surface =~ "public.oban_jobs", "#{name} must retain host-owned Oban in public"

      assert surface =~ "public.schema_migrations",
             "#{name} must retain the host migration ledger in public"

      for forbidden <- [
            "Application.app_dir(:rindle, \"priv/repo/migrations\")",
            "Ecto.Migrator.run",
            "search_path",
            "tenant_media"
          ] do
        refute surface =~ forbidden,
               "#{name} must not broaden the fresh-install migration contract"
      end
    end

    assert migration_module =~ "guides/upgrading.md",
           "Rindle.Migration moduledoc must direct populated installs to the upgrade guide"
  end

  test "upgrade guide documents the bounded host-owned populated move", %{upgrade: upgrade} do
    upgrade_section =
      upgrade
      |> section_between!(
        "#### Existing populated public installs",
        "#### Existing legacy installs"
      )

    migration_snippet =
      fenced_elixir_after!(upgrade_section, "defmodule MyApp.Repo.Migrations.MoveRindleToSchema")

    assert Regex.match?(
             ~r/def up do\s+execute\("SET LOCAL lock_timeout = '5s'"\)\s+Rindle\.Migration\.move_public_to_rindle\(version: 1\)/s,
             migration_snippet
           ),
           "populated migration snippet must queue the forward timeout before its direct helper call"

    assert Regex.match?(
             ~r/def down do\s+execute\("SET LOCAL lock_timeout = '5s'"\)\s+Rindle\.Migration\.move_rindle_to_public\(version: 1\)/s,
             migration_snippet
           ),
           "populated migration snippet must queue the reverse timeout before its direct helper call"

    for helper <- ["move_public_to_rindle", "move_rindle_to_public"] do
      refute Regex.match?(~r/execute\(fn\s*->.*#{helper}/s, migration_snippet),
             "populated migration snippet must call #{helper}/1 directly at migration-body scope"
    end

    upgrade_section = String.replace(upgrade_section, ~r/\s+/, " ")

    for snippet <- [
          "maintenance window",
          "SET LOCAL lock_timeout = '5s'",
          "Rindle.Migration.move_public_to_rindle(version: 1)",
          "Rindle.Migration.move_rindle_to_public(version: 1)",
          "Do not create `rindle` yourself",
          "classifies the complete public-only Rindle state",
          "inside the same host transaction",
          "fails boundedly",
          "transaction rollback leaves no partial destination",
          "six Rindle tables plus the",
          "rindle_migration_versions",
          "deploy the build compiled for `rindle`",
          "normal reads and writes",
          "exactly reversible",
          "Rindle.Migration.down/1",
          "destructive teardown"
        ] do
      assert upgrade_section =~ snippet,
             "populated upgrade guidance must include #{inspect(snippet)}"
    end

    assert upgrade_section =~ "stop or drain Rindle HTTP writers and Oban workers",
           "populated upgrade guidance must require draining Rindle writers and Oban workers"

    assert_in_order!(upgrade_section, [
      "maintenance window",
      "back up the database",
      "stop or drain Rindle HTTP writers and Oban workers",
      "mix ecto.migrate",
      "deploy the build compiled for `rindle`",
      "mix rindle.doctor",
      "mix rindle.runtime_status"
    ])

    for snippet <- [
          "database owner",
          "CREATE privilege",
          "ACCESS EXCLUSIVE",
          "Ecto's migrator lock",
          "does not quiesce application traffic",
          "guarded reverse",
          "Otherwise, restore the backup"
        ] do
      assert upgrade_section =~ snippet,
             "populated upgrade guidance must explain #{inspect(snippet)}"
    end

    for forbidden <- [
          "search_path",
          "Rindle.Migration.move(",
          "tenant_media",
          "online migration",
          "seamless migration",
          "automatic migration",
          "dual-write",
          "generic schema movement"
        ] do
      refute upgrade_section =~ forbidden,
             "populated upgrade guidance must not teach #{inspect(forbidden)}"
    end
  end

  test "troubleshooting routes schema and Oban faults through bounded ownership actions", %{
    troubleshooting: troubleshooting
  } do
    setup_section =
      troubleshooting
      |> section_between!(
        "## Schema Isolation and Host Oban Setup",
        "## Supported Recovery Verbs"
      )

    prefix_mismatch =
      section_between!(setup_section, "### Rindle prefix mismatch", "### Missing Rindle setup")

    missing_setup =
      section_between!(
        setup_section,
        "### Missing Rindle setup",
        "### Host Oban binding missing or drifted"
      )

    oban_binding =
      section_between!(setup_section, "### Host Oban binding missing or drifted", "## Supported")

    assert_in_order!(prefix_mismatch, [
      "mix rindle.doctor",
      "maintenance-window upgrade",
      "mix rindle.runtime_status"
    ])

    assert_in_order!(missing_setup, [
      "mix rindle.doctor",
      "Rindle.Migration.up(version: 1)",
      "mix rindle.runtime_status"
    ])

    assert_in_order!(oban_binding, [
      "mix rindle.doctor",
      "Oban.Migration",
      "mix ecto.migrate",
      "mix rindle.runtime_status"
    ])

    for snippet <- [
          "fixed seven-relation Rindle scope",
          "public.oban_jobs",
          "public.schema_migrations",
          "Rindle does not own or configure Oban"
        ] do
      assert setup_section =~ snippet,
             "schema troubleshooting must preserve #{inspect(snippet)} ownership truth"
    end

    for forbidden <- [
          "raw SQL",
          "automatic migration",
          "generic schema discovery",
          "Rindle.Migration.move("
        ] do
      refute setup_section =~ forbidden,
             "schema troubleshooting must not recommend #{inspect(forbidden)}"
    end
  end

  test "legacy package-directory migration copy is scoped to historical upgrade guidance", %{
    readme: readme,
    guide: guide,
    upgrade: upgrade
  } do
    readme_migrations = section_between!(readme, "## Migrations", "## First Attachment")
    guide_step_three = section_between!(guide, "## 3.", "## 4.")
    unreleased = section_between!(upgrade, "## Unreleased / Next", "## 0.1.3")
    legacy_upgrade = section_between!(upgrade, "## 0.1.3", "## Next Reads")

    for {name, section} <- [
          {"README migrations", readme_migrations},
          {"getting-started step 3", guide_step_three},
          {"Unreleased upgrade note", unreleased}
        ] do
      refute section =~ "Application.app_dir(:rindle, \"priv/repo/migrations\")",
             "#{name} must reject the raw package-directory greenfield flow"

      refute section =~ "Ecto.Migrator.run",
             "#{name} must reject direct package-path migration replay for fresh installs"
    end

    assert legacy_upgrade =~ "Application.app_dir(:rindle, \"priv/repo/migrations\")",
           "historical upgrade guidance may still name the legacy package migration directory"

    assert legacy_upgrade =~ "Ecto.Migrator.run",
           "historical upgrade guidance may still show intentionally scoped legacy replay"
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

  test "upgrade guide is a newest-first versioned upgrade home", %{upgrade: upgrade} do
    headings =
      ~r/^## .+$/m
      |> Regex.scan(upgrade)
      |> List.flatten()

    assert Enum.at(headings, 0) == "## Version index"

    assert_in_order!(upgrade, [
      "## Version index",
      "## Unreleased / Next",
      "## 0.1.3 and earlier -> current AV-aware runtime"
    ])

    for snippet <- [
          "CHANGELOG.md",
          "### Applies to",
          "### What changed",
          "### Upgrade steps",
          "### Verification",
          "Application.app_dir(:rindle, \"priv/repo/migrations\")",
          "mix rindle.doctor",
          "mix rindle.runtime_status --format json",
          "Rindle.requeue_variants(asset_id, variant_names: [\"web_720p\"])",
          "mix rindle.regenerate_variants"
        ] do
      assert upgrade =~ snippet
    end

    unreleased_index = string_index(upgrade, "## Unreleased / Next")
    av_upgrade_index = string_index(upgrade, "## 0.1.3 and earlier -> current AV-aware runtime")

    assert unreleased_index && av_upgrade_index
    assert unreleased_index < av_upgrade_index

    unreleased_section =
      binary_part(upgrade, unreleased_index, av_upgrade_index - unreleased_index)

    av_upgrade_section =
      binary_part(upgrade, av_upgrade_index, byte_size(upgrade) - av_upgrade_index)

    for section <- [unreleased_section, av_upgrade_section] do
      assert_in_order!(section, [
        "### Applies to",
        "### What changed",
        "### Upgrade steps",
        "### Verification"
      ])
    end
  end

  test "upgrade guide uses HexDocs-safe version navigation links", %{upgrade: upgrade} do
    assert upgrade =~ "[Unreleased / Next](#unreleased-next)"

    assert upgrade =~
             "[0.1.3 and earlier -> current AV-aware runtime](#0-1-3-and-earlier-current-av-aware-runtime)"

    refute upgrade =~ "](../CHANGELOG.md)"
    assert upgrade =~ "https://github.com/szTheory/rindle/blob/main/CHANGELOG.md"
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

    assert operations =~ ~r/mountable admin console/i,
           "operations.md must affirm the mountable admin console in prose (TRUTH-07) — " <>
             "a bare admin_console.html link substring must not satisfy this lock"

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

  defp section_between!(doc, start_snippet, stop_snippet) do
    start_index =
      string_index(doc, start_snippet) ||
        flunk("expected section start #{inspect(start_snippet)}")

    tail = binary_part(doc, start_index, byte_size(doc) - start_index)

    case string_index(tail, stop_snippet) do
      nil -> tail
      stop_index -> binary_part(tail, 0, stop_index)
    end
  end

  defp fenced_elixir_after!(section, snippet) do
    ~r/^```elixir\n(.*?)^```/ms
    |> Regex.scan(section, capture: :all_but_first)
    |> Enum.map(&hd/1)
    |> Enum.find(&String.contains?(&1, snippet))
    |> case do
      nil -> flunk("expected a closed Elixir fence containing #{inspect(snippet)}")
      contents -> contents
    end
  end

  defp migration_call!(source) do
    source
    |> String.split("\n")
    |> Enum.find(&String.contains?(&1, "def up, do:"))
    |> case do
      nil -> flunk("expected generated migration fixture to contain a one-line up/0 call")
      call -> String.trim(call)
    end
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
