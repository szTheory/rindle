defmodule Rindle.Ops.RuntimeChecksTest do
  use ExUnit.Case, async: false

  alias Rindle.Ops.RuntimeChecks
  alias Rindle.Storage.Local

  defmodule ImageProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.S3,
      variants: [thumb: [mode: :fit, width: 64, height: 64]]
  end

  defmodule VideoProfile do
    use Rindle.Profile.Presets.Web,
      storage: Rindle.Storage.S3,
      allow_mime: ["video/mp4"],
      max_bytes: 10_000_000
  end

  defmodule PrivateLocalImageProfile do
    use Rindle.Profile,
      storage: Local,
      variants: [thumb: [mode: :fit, width: 64, height: 64]]
  end

  defmodule PublicLocalVideoProfile do
    use Rindle.Profile,
      storage: Local,
      delivery: [public: true],
      variants: [web: [kind: :video, preset: :web_720p]]
  end

  defmodule NoTusStorage do
    def capabilities, do: [:local, :head]
  end

  defmodule TusUnsupportedVideoProfile do
    use Rindle.Profile.Presets.Web,
      storage: NoTusStorage,
      allow_mime: ["video/mp4"],
      max_bytes: 10_000_000
  end

  @rindle_tables ~w(
    media_assets
    media_attachments
    media_variants
    media_upload_sessions
    media_processing_runs
    media_provider_assets
  )
  @legacy_migration_versions [
    20_260_424_155_129,
    20_260_424_205_942,
    20_260_425_090_000,
    20_260_425_090_100,
    20_260_425_090_150,
    20_260_425_090_200,
    20_260_425_090_300,
    20_260_428_110_000,
    20_260_502_120_000,
    20_260_506_120_000,
    20_260_507_160_000,
    20_260_522_120_000,
    20_260_524_120_000,
    20_260_527_065_924,
    20_260_527_120_000
  ]

  describe "run/2" do
    test "keeps runtime check orchestration callable only through the facade" do
      assert function_exported?(RuntimeChecks, :run, 2)
      assert function_exported?(RuntimeChecks, :probe_gcs_bucket, 4)
      assert function_exported?(RuntimeChecks, :do_probe, 4)

      refute function_exported?(Rindle.Ops.RuntimeChecks.CoreChecks, :run, 2)
      refute function_exported?(Rindle.Ops.RuntimeChecks.OwnershipChecks, :run, 2)
    end

    test "returns deterministic stable check ids" do
      previous = Application.get_env(:rindle, :tus_profiles)
      Application.put_env(:rindle, :tus_profiles, [ImageProfile])

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            profiles: [ImageProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1,
                rindle_media: 1
              ]
            ],
            migration_statuses: [],
            local_playback_route: [
              base_url: "http://example.test/rindle/local",
              secret_key_base: "secret"
            ]
          )

        assert Enum.map(report.checks, & &1.id) == [
                 "doctor.delivery_support",
                 "doctor.ffmpeg_runtime",
                 "doctor.local_playback",
                 "doctor.migrations.pending",
                 "doctor.migrations.unresolved",
                 "doctor.oban_default_instance",
                 "doctor.oban_jobs.ready",
                 "doctor.oban_required_queues",
                 "doctor.profile_runtime_fit",
                 "doctor.resumable_session_schema",
                 "doctor.rindle_schema.ready",
                 "doctor.streaming_credentials",
                 "doctor.streaming_signing_key",
                 "doctor.streaming_smoke_ping",
                 "doctor.streaming_webhook_secrets",
                 "doctor.tus_capability"
               ]

        assert report.success?
        assert report.failed == 0
      after
        if previous do
          Application.put_env(:rindle, :tus_profiles, previous)
        else
          Application.delete_env(:rindle, :tus_profiles)
        end
      end
    end

    test "keeps ownership check IDs and telemetry bounded for binding refusal" do
      handler_id = "ownership-checks-#{System.unique_integer([:positive])}"
      parent = self()

      :telemetry.attach(
        handler_id,
        [:rindle, :runtime, :check, :stop],
        fn _event, _measurements, metadata, _ ->
          send(parent, {:telemetry, metadata})
        end,
        nil
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [],
            oban_config: healthy_oban_config(),
            migration_statuses: [],
            ownership_snapshot: %{
              rindle: %{
                expected_prefix: "public",
                observed_prefix: nil,
                owner: :rindle,
                classification: :inspection_failed,
                next_action: "Run mix rindle.doctor."
              },
              oban: %{
                expected_prefix: "host_oban",
                observed_prefix: "public",
                owner: :host,
                classification: :oban_binding_drift,
                next_action: "Host owns Oban.Migration."
              }
            }
          )

        for id <- ["doctor.rindle_schema.ready", "doctor.oban_jobs.ready"] do
          check = fetch_check(report, id)
          assert check.status == :error
          assert check.classification in [:inspection_failed, :oban_binding_drift]
          refute inspect(check) =~ "credential"
        end

        assert_receive {:telemetry,
                        %{check: "doctor.oban_jobs.ready", status: :error, component: :oban}}
      after
        :telemetry.detach(handler_id)
      end
    end

    @tag :phase_119_redaction
    test "redacts migration inspection failure names while preserving ownership checks" do
      sentinel = "Postgrex.Error SELECT password FROM credentials"

      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: [{:down, -1, "migration inspection failed: #{sentinel}"}]
        )

      migration = fetch_check(report, "doctor.migrations.pending")
      assert migration.status == :error
      assert migration.summary =~ "migration inspection failed"
      refute inspect(report) =~ sentinel

      for id <- ["doctor.rindle_schema.ready", "doctor.oban_jobs.ready"] do
        assert fetch_check(report, id).owner in [:rindle, :host]
      end
    end

    test "does not require rindle_media for image-only profiles" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [ImageProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      assert report.success?

      queues_check = fetch_check(report, "doctor.oban_required_queues")
      assert queues_check.status == :ok
      refute queues_check.summary =~ "rindle_media"
    end

    test "requires rindle_media when AV-capable profiles are present" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [VideoProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      refute report.success?

      queues_check = fetch_check(report, "doctor.oban_required_queues")
      assert queues_check.status == :error
      assert queues_check.summary =~ "rindle_media"
      assert queues_check.fix =~ "config"
    end

    test "flags private delivery on adapters without signed_url support" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [PrivateLocalImageProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      check = fetch_check(report, "doctor.delivery_support")
      assert check.status == :error
      assert check.summary =~ "PrivateLocalImageProfile"
      assert check.fix =~ "signed_url"
    end

    test "flags local playback route drift only for local AV profiles" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [PublicLocalVideoProfile],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1,
              rindle_media: 1
            ]
          ],
          migration_statuses: [],
          local_playback_route: nil
        )

      check = fetch_check(report, "doctor.local_playback")
      assert check.status == :error
      assert check.summary =~ "PublicLocalVideoProfile"
      assert check.fix =~ "local_playback_route"
      assert check.fix =~ "Rindle.Delivery.LocalPlug"
    end

    test "distinguishes pending and unresolved migration drift" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: [
            {:down, 20_260_502_120_000, "extend_media_for_av.exs"},
            {:up, 20_260_425_090_000, "** FILE NOT FOUND **"}
          ]
        )

      pending = fetch_check(report, "doctor.migrations.pending")
      unresolved = fetch_check(report, "doctor.migrations.unresolved")

      assert pending.status == :error
      assert pending.summary =~ "20260502120000"
      assert pending.fix =~ "mix ecto.migrate"

      assert unresolved.status == :error
      assert unresolved.summary =~ "20260425090000"
      assert unresolved.fix =~ "missing from local code"
    end

    test "accepts a fresh Rindle.Migration marker/catalog install without legacy file history" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: pending_legacy_migration_statuses(),
          rindle_schema_catalog: fresh_marker_catalog_fixture(),
          oban_jobs_catalog: oban_jobs_ready_fixture()
        )

      assert report.success?

      schema = fetch_check(report, "doctor.rindle_schema.ready")
      assert schema.status == :ok
      assert schema.summary =~ "Rindle.Migration"
      assert schema.summary =~ "version 1"

      pending = fetch_check(report, "doctor.migrations.pending")
      assert pending.status in [:ok, :warn]
      refute pending.status == :error
    end

    test "accepts a healthy legacy packaged migration install when the catalog is current" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: applied_legacy_migration_statuses(),
          rindle_schema_catalog: healthy_legacy_catalog_fixture(),
          oban_jobs_catalog: oban_jobs_ready_fixture()
        )

      assert report.success?

      schema = fetch_check(report, "doctor.rindle_schema.ready")
      assert schema.status == :ok
      assert schema.summary =~ "legacy"
      assert schema.summary =~ "catalog"
    end

    test "errors when Rindle-owned schema catalog checks are incomplete" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: applied_legacy_migration_statuses(),
          rindle_schema_catalog: incomplete_rindle_catalog_fixture(["media_variants"]),
          oban_jobs_catalog: oban_jobs_ready_fixture()
        )

      refute report.success?

      schema = fetch_check(report, "doctor.rindle_schema.ready")
      assert schema.status == :error
      assert schema.summary =~ "media_variants"
      assert schema.fix =~ "Rindle.Migration.up(version: 1)"
    end

    test "downgrades healthy legacy unresolved file-history drift to warning-only copy" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: [
            {:up, 20_260_425_090_000, "** FILE NOT FOUND **"}
          ],
          rindle_schema_catalog: healthy_legacy_catalog_fixture(),
          oban_jobs_catalog: oban_jobs_ready_fixture()
        )

      assert report.success?
      assert report.failed == 0

      unresolved = fetch_check(report, "doctor.migrations.unresolved")
      assert unresolved.status == :warn
      assert unresolved.summary =~ "history"
      assert unresolved.fix =~ "legacy"
      refute unresolved.fix =~ "delete"
      refute unresolved.fix =~ "replay"
    end

    test "errors when the host-owned oban_jobs table is not installed" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: applied_legacy_migration_statuses(),
          rindle_schema_catalog: healthy_legacy_catalog_fixture(),
          oban_jobs_catalog: %{exists?: false}
        )

      refute report.success?

      oban_jobs = fetch_check(report, "doctor.oban_jobs.ready")
      assert oban_jobs.status == :error
      assert oban_jobs.summary =~ "oban_jobs"
      assert oban_jobs.fix =~ "Oban.Migration"
      assert oban_jobs.fix =~ "Rindle no longer manages `oban_jobs`"
    end

    test "reports resumable session schema success when columns and filtered index are present" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: []
        )

      check = fetch_check(report, "doctor.resumable_session_schema")
      assert check.status == :ok
      assert check.summary =~ "All resumable session columns and the expiry index are present"
      assert check.fix =~ "Keep the packaged resumable migration applied"
    end

    test "reports resumable session schema drift when required column or index is missing" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: [
            repo: Rindle.Repo,
            queues: [
              rindle_promote: 1,
              rindle_process: 1,
              rindle_purge: 1,
              rindle_maintenance: 1
            ]
          ],
          migration_statuses: [],
          resumable_session_schema_catalog: %{
            columns: %{
              "session_uri" => %{is_nullable: "YES", column_default: nil},
              "session_uri_expires_at" => %{is_nullable: "YES", column_default: nil},
              "last_known_offset" => %{is_nullable: "YES", column_default: nil}
            },
            indexes: [
              "CREATE INDEX media_upload_sessions_expires_at_index ON public.media_upload_sessions USING btree (expires_at)"
            ]
          }
        )

      check = fetch_check(report, "doctor.resumable_session_schema")
      assert check.status == :error
      assert check.summary =~ "missing columns: region_hint"
      assert check.summary =~ "last_known_offset must be NOT NULL DEFAULT 0"
      assert check.summary =~ "missing resumable expiry index"
      assert check.fix =~ "Re-run the packaged resumable migration"
    end

    test "flags tus profile capability drift when configured tus profile lacks :tus_upload" do
      previous = Application.get_env(:rindle, :tus_profiles)
      Application.put_env(:rindle, :tus_profiles, [TusUnsupportedVideoProfile])

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [TusUnsupportedVideoProfile],
            oban_config: [
              repo: Rindle.Repo,
              queues: [
                rindle_promote: 1,
                rindle_process: 1,
                rindle_purge: 1,
                rindle_maintenance: 1,
                rindle_media: 1
              ]
            ],
            migration_statuses: [],
            local_playback_route: [
              base_url: "http://example.test/rindle/local",
              secret_key_base: "secret"
            ]
          )

        check = fetch_check(report, "doctor.tus_capability")
        assert check.status == :error
        assert check.summary =~ "TusUnsupportedVideoProfile"
        assert check.fix =~ ":tus_profiles"
      after
        if previous do
          Application.put_env(:rindle, :tus_profiles, previous)
        else
          Application.delete_env(:rindle, :tus_profiles)
        end
      end
    end
  end

  defp fetch_check(report, id) do
    Enum.find(report.checks, &(&1.id == id)) ||
      flunk("expected check #{inspect(id)} to be present")
  end

  defp healthy_oban_config do
    [
      repo: Rindle.Repo,
      queues: [
        rindle_promote: 1,
        rindle_process: 1,
        rindle_purge: 1,
        rindle_maintenance: 1
      ]
    ]
  end

  defp pending_legacy_migration_statuses do
    Enum.map(@legacy_migration_versions, &{:down, &1, "#{&1}_legacy_rindle_migration.exs"})
  end

  defp applied_legacy_migration_statuses do
    Enum.map(@legacy_migration_versions, &{:up, &1, "#{&1}_legacy_rindle_migration.exs"})
  end

  defp fresh_marker_catalog_fixture do
    %{
      marker_versions: [1],
      tables: @rindle_tables,
      legacy_packaged_install?: false,
      prefix: "public"
    }
  end

  defp healthy_legacy_catalog_fixture do
    %{
      marker_versions: [],
      tables: @rindle_tables,
      legacy_packaged_install?: true,
      prefix: "public"
    }
  end

  defp incomplete_rindle_catalog_fixture(missing_tables) do
    %{
      marker_versions: [1],
      tables: @rindle_tables -- missing_tables,
      missing_tables: missing_tables,
      legacy_packaged_install?: false,
      prefix: "public"
    }
  end

  defp oban_jobs_ready_fixture do
    %{exists?: true, owner: :host, setup: "Oban.Migration"}
  end

  defp run_runtime_checks(opts) do
    RuntimeChecks.run(
      [],
      opts
      |> Keyword.put_new(:rindle_schema_catalog, fresh_marker_catalog_fixture())
      |> Keyword.put_new(:oban_jobs_catalog, oban_jobs_ready_fixture())
      |> Keyword.put_new(:resumable_session_schema_catalog, resumable_session_schema_fixture())
    )
  end

  defp resumable_session_schema_fixture do
    %{
      columns: %{
        "session_uri" => %{is_nullable: "YES", column_default: nil},
        "session_uri_expires_at" => %{is_nullable: "YES", column_default: nil},
        "last_known_offset" => %{is_nullable: "NO", column_default: "0"},
        "region_hint" => %{is_nullable: "YES", column_default: nil}
      },
      indexes: [
        "CREATE INDEX media_upload_sessions_resumable_expiry_idx ON public.media_upload_sessions USING btree (session_uri_expires_at) WHERE ((upload_strategy = 'resumable'::text))"
      ]
    }
  end
end
