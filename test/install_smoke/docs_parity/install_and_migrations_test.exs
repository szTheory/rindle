Code.require_file("../support/generated_app_helper.ex", __DIR__)
Code.require_file("support.ex", __DIR__)

defmodule Rindle.InstallSmoke.DocsParity.InstallAndMigrationsTest do
  alias Rindle.InstallSmoke.GeneratedAppHelper
  import Rindle.InstallSmoke.DocsParity.Support
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../../README.md", __DIR__)
  @guide_path Path.expand("../../../guides/getting_started.md", __DIR__)
  @upgrade_path Path.expand("../../../guides/upgrading.md", __DIR__)
  @troubleshooting_path Path.expand("../../../guides/troubleshooting.md", __DIR__)
  @release_path Path.expand("../../../guides/release_publish.md", __DIR__)
  @migration_module_path Path.expand("../../../lib/rindle/migration.ex", __DIR__)

  setup_all do
    {:ok,
     load_docs!(%{
       readme: @readme_path,
       guide: @guide_path,
       upgrade: @upgrade_path,
       troubleshooting: @troubleshooting_path,
       release: @release_path,
       migration_module: @migration_module_path
     })}
  end

  test "migration docs teach pinned Rindle.Migration and host-owned Oban setup", %{
    readme: readme,
    guide: guide,
    upgrade: upgrade
  } do
    migration_sections = [
      {"README migrations", section_between!(readme, "## Migrations", "## First Attachment")},
      {"getting-started step 3", section_between!(guide, "## 3.", "## 4.")},
      {"0.4.0 upgrade note", section_between!(upgrade, "## 0.4.0 schema isolation", "## 0.1.3")}
    ]

    for {name, section} <- migration_sections do
      assert section =~ "Rindle.Migration.up(version: 1)",
             "#{name} must include Rindle.Migration.up(version: 1)"

      assert section =~ "Rindle.Migration.down(version: 1)",
             "#{name} must include Rindle.Migration.down(version: 1)"

      assert section =~ "Oban.Migration",
             "#{name} must name Oban.Migration as the host-owned Oban migration path"

      assert section =~ "oban_jobs", "#{name} must say Rindle does not own or create oban_jobs"

      assert section =~ "mix ecto.migrate",
             "#{name} must keep the normal host-app migration workflow"

      assert section =~ "mix rindle.doctor",
             "#{name} must keep doctor as the post-migration verification command"

      assert section =~ "rindle", "#{name} must state the rindle default"

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

      assert section =~ "schema_migrations", "#{name} must preserve the host migration ledger"
      refute section =~ "tenant_media", "#{name} must not teach arbitrary schema prefixes"

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
    current_release = section_between!(upgrade, "## 0.4.0 schema isolation", "## 0.1.3")
    legacy_upgrade = section_between!(upgrade, "## 0.1.3", "## Next Reads")

    for {name, section} <- [
          {"README migrations", readme_migrations},
          {"getting-started step 3", guide_step_three},
          {"0.4.0 upgrade note", current_release}
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
    headings = ~r/^## .+$/m |> Regex.scan(upgrade) |> List.flatten()
    assert Enum.at(headings, 0) == "## Version index"

    assert_in_order!(upgrade, [
      "## Version index",
      "## 0.4.0 schema isolation",
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

    current_release_index = string_index(upgrade, "## 0.4.0 schema isolation")
    av_upgrade_index = string_index(upgrade, "## 0.1.3 and earlier -> current AV-aware runtime")
    assert current_release_index && av_upgrade_index
    assert current_release_index < av_upgrade_index

    current_release_section =
      binary_part(upgrade, current_release_index, av_upgrade_index - current_release_index)

    av_upgrade_section =
      binary_part(upgrade, av_upgrade_index, byte_size(upgrade) - av_upgrade_index)

    for section <- [current_release_section, av_upgrade_section] do
      assert_in_order!(section, [
        "### Applies to",
        "### What changed",
        "### Upgrade steps",
        "### Verification"
      ])
    end
  end

  test "upgrade guide uses HexDocs-safe version navigation links", %{upgrade: upgrade} do
    assert upgrade =~ "[0.4.0 schema isolation](#040-schema-isolation)"

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
end
