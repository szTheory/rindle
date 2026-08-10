defmodule Rindle.Ops.RuntimeChecksTest do
  use ExUnit.Case, async: false

  alias Rindle.Ops.RuntimeChecks
  alias Rindle.Storage.Local
  alias Rindle.Storage.GCS.SigningKeyFixture

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

  describe "GCS doctor checks (Phase 37 / D-13)" do
    defmodule LocalProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.Local,
        variants: [thumb: [mode: :fit, width: 32]]
    end

    defmodule GCSProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.GCS,
        variants: [thumb: [mode: :fit, width: 32]]
    end

    # WARNING 3 / D-13 LOCK: image-only adopters see ZERO gcs_* rows.
    # The check fn-refs are appended at the splice point ONLY when
    # gcs_profiles(profiles) != []. NOT three silent-OK rows — literal absence.
    test "S3-only adopter sees zero gcs_ rows in doctor.checks" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [LocalProfile],
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

      gcs_rows = Enum.filter(report.checks, &String.starts_with?(&1.id, "doctor.gcs_"))

      assert gcs_rows == [],
             "Expected zero gcs_* rows for S3-only adopters (D-13 lock); got: #{inspect(gcs_rows)}"
    end

    test "S3-only adopter mixed with non-storage profiles: still zero gcs_ rows" do
      # Defensive — confirms `Rindle.Capability.configured_gcs_profiles/1` filters
      # the LocalProfile out before fn-refs splice in.
      report =
        RuntimeChecks.run([],
          probe: fn -> :ok end,
          env: %{},
          profiles: [LocalProfile],
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

      refute Enum.any?(report.checks, &(&1.component == :gcs))
    end

    test "GCS profile present: three gcs_ rows are emitted (one per check)" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)
      Application.put_env(:rindle, Rindle.Storage.GCS, [])

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        ids =
          report.checks
          |> Enum.filter(&String.starts_with?(&1.id, "doctor.gcs_"))
          |> Enum.map(& &1.id)
          |> Enum.sort()

        assert ids == [
                 "doctor.gcs_bucket_reachable",
                 "doctor.gcs_goth_running",
                 "doctor.gcs_resumable_cors",
                 "doctor.gcs_signing_key"
               ]
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_goth_running: error when GCS profile exists and named Goth instance is not started" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        goth: :rindle_doctor_test_unstarted_goth,
        signing_key: %{"private_key" => "x", "client_email" => "x@y"}
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_goth_running"))
        assert check.status == :error
        assert check.component == :gcs
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_bucket_reachable: error when GCS profile exists but no bucket is configured" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)
      Application.put_env(:rindle, Rindle.Storage.GCS, [])

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_bucket_reachable"))
        assert check.status == :error
        assert check.component == :gcs
        assert check.summary =~ ~r/bucket/i
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_bucket_reachable: error_result with precondition_missing when Finch is not configured (HONEST about why no probe ran)" do
      # BLOCKER 2 / D-13 LOCK: when preconditions are missing, doctor MUST surface
      # an error_result naming the missing precondition — NOT a silent OK that masks
      # the fact that no probe actually ran. The fix message should be actionable
      # ("start `MyApp.Finch` and `MyApp.Goth` in your supervision tree").
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket"
        # Note: no :finch and no :goth keys — preconditions missing
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_bucket_reachable"))
        assert check.status == :error
        assert check.component == :gcs

        # Honest about WHY no probe ran:
        assert check.summary =~ ~r/finch|goth|supervision tree|not configured/i,
               "Expected fix-oriented summary about missing Finch/Goth precondition; got: #{inspect(check.summary)}"

        # Security parity:
        refute check.summary =~ ~r/Bearer ey/
        refute check.summary =~ ~r/-----BEGIN/
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: error when signing key is a non-PEM binary; summary does not echo secret material" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: "not-a-valid-key-or-path"
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_signing_key"))
        assert check.status == :error
        assert check.component == :gcs
        assert check.summary =~ "non-PEM binary"

        refute check.summary =~ ~r/-----BEGIN/
        refute check.summary =~ ~r/private_key/
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: ok when signing key is a valid decoded JSON map" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: SigningKeyFixture.fixture_json()
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_signing_key"))
        assert check.status == :ok
        assert check.component == :gcs
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: ok when signing key is a raw PEM string and client_email is configured" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: SigningKeyFixture.fixture_pem(),
        client_email: SigningKeyFixture.fixture_client_email()
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_signing_key"))
        assert check.status == :ok
        assert check.component == :gcs
        assert check.summary =~ "raw PEM string"
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: error when signing key is a raw PEM string without client_email" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: SigningKeyFixture.fixture_pem()
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_signing_key"))
        assert check.status == :error
        assert check.component == :gcs
        assert check.summary =~ "client_email"
        refute check.summary =~ ~r/-----BEGIN/
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_signing_key: error when signing key looks like a file path because file-path loading is unsupported" do
      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        signing_key: "/path/to/service-account.json"
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_signing_key"))
        assert check.status == :error
        assert check.component == :gcs
        assert check.summary =~ "file-path loading is not supported"
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "check_gcs_resumable_cors: absent when no resumable GCS profile exists" do
      report =
        run_runtime_checks(
          probe: fn -> :ok end,
          env: %{},
          profiles: [LocalProfile],
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

      refute Enum.any?(report.checks, &(&1.id == "doctor.gcs_resumable_cors"))
    end

    test "check_gcs_resumable_cors: warns when bucket CORS shape is missing required resumable rules" do
      bypass = Bypass.open()
      finch_name = :"rindle_cors_warn_finch_#{System.unique_integer([:positive])}"
      goth_name = :"rindle_cors_warn_goth_#{System.unique_integer([:positive])}"
      {:ok, _} = Finch.start_link(name: finch_name)

      {:ok, _} =
        Goth.start_link(
          name: goth_name,
          source: gcs_fixture_goth_source("http://localhost:#{bypass.port}/token")
        )

      Bypass.stub(bypass, "POST", "/token", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          ~s({"access_token":"test-token","token_type":"Bearer","expires_in":3600})
        )
      end)

      Bypass.stub(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        body =
          case conn.query_string do
            "fields=cors" ->
              ~s({"cors":[{"origin":["https://app.example.test"],"method":["GET"],"responseHeader":["Content-Type"]}]})

            _ ->
              ~s({"name":"my-bucket"})
          end

        Plug.Conn.resp(conn, 200, body)
      end)

      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        finch: finch_name,
        goth: goth_name,
        base_url: "http://localhost:#{bypass.port}",
        signing_key: SigningKeyFixture.fixture_json()
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProfile],
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

        check = fetch_check(report, "doctor.gcs_resumable_cors")
        assert check.status == :warn
        assert check.summary =~ "missing `PUT`/`PATCH`"
        assert check.summary =~ "missing `Content-Range`/`x-goog-resumable`"
        assert check.fix =~ "app origins"
        assert check.fix =~ "PUT"
        assert check.fix =~ "PATCH"
        assert check.fix =~ "Content-Range"
        assert check.fix =~ "x-goog-resumable"
        assert check.fix =~ "session_uri"
        assert check.fix =~ "one week"
        assert check.fix =~ "region pinning"
        assert report.failed == 0
        assert report.success?
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end

    test "warnings do not increment failure count, but errors still do" do
      report =
        run_runtime_checks(
          probe: fn -> raise RuntimeError, "ffmpeg missing" end,
          env: %{},
          profiles: [GCSProfile],
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
          gcs_bucket_cors: [
            %{
              "origin" => ["https://app.example.test"],
              "method" => ["PUT"],
              "responseHeader" => ["x-goog-resumable"]
            }
          ]
        )

      assert fetch_check(report, "doctor.gcs_resumable_cors").status == :warn
      assert report.failed == Enum.count(report.checks, &(&1.status == :error))
      assert report.failed > 0
      refute report.success?
    end
  end

  # BLOCKER 2 — Bypass-mocked unit tests for `do_probe/4` covering all 5 return
  # shapes. These tests exercise the probe directly without going through run/2,
  # mocking the GCS JSON API endpoint with Bypass and substituting the
  # Goth.fetch/1 source via a per-test Goth instance using a fresh fixture.
  describe "probe_gcs_bucket/4 + do_probe/4 (Bypass-mocked HTTP probe — BLOCKER 2 D-13 lock)" do
    alias Rindle.Storage.GCS.SigningKeyFixture
    alias SigningKeyFixture

    defmodule GCSProbeProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.GCS,
        variants: [thumb: [mode: :fit, width: 32]]
    end

    setup do
      bypass = Bypass.open()
      finch_name = :"rindle_probe_test_finch_#{System.unique_integer([:positive])}"
      {:ok, _} = Finch.start_link(name: finch_name)

      # `:token` opt is the test-only seam — Bypass-mocked unit tests cannot
      # round-trip through Google's real OAuth endpoint to exchange a fake
      # service-account JWT for a token, so we inject a fixed bearer instead.
      # `goth_name` is still passed through for the precondition-presence check
      # in probe_gcs_bucket/4 (nil goth_name → {:precondition_missing, ...}).
      goth_name = :rindle_probe_test_fake_goth_name

      base_url = "http://localhost:#{bypass.port}"
      fake_token = "test-bearer-token-#{System.unique_integer([:positive])}"

      _ = SigningKeyFixture

      {:ok,
       bypass: bypass,
       finch_name: finch_name,
       goth_name: goth_name,
       base_url: base_url,
       token: fake_token}
    end

    test "200 → :ok", %{bypass: bypass, finch_name: f, goth_name: g, base_url: u, token: t} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"name":"my-bucket"}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t) == :ok
    end

    test "403 → :ok (bucket exists; ACL-restricted; name resolution healthy per RESEARCH §7)",
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u, token: t} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 403, ~s({"error":{"code":403,"message":"Forbidden"}}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t) == :ok
    end

    test "404 → {:bucket_missing, 404}", %{
      bypass: bypass,
      finch_name: f,
      goth_name: g,
      base_url: u,
      token: t
    } do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error":{"code":404,"message":"Not Found"}}))
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t) ==
               {:bucket_missing, 404}
    end

    test "500 → {:unexpected_status, 500}",
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u, token: t} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      assert RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t) ==
               {:unexpected_status, 500}
    end

    test "Bypass.down → {:probe_error, _}", %{
      bypass: bypass,
      finch_name: f,
      goth_name: g,
      base_url: u,
      token: t
    } do
      Bypass.down(bypass)

      assert {:probe_error, _reason} =
               RuntimeChecks.do_probe("my-bucket", f, g, base_url: u, token: t)
    end

    test "precondition: nil finch_name → {:precondition_missing, :finch_not_configured}",
         %{goth_name: g} do
      assert RuntimeChecks.probe_gcs_bucket("my-bucket", nil, g) ==
               {:precondition_missing, :finch_not_configured}
    end

    test "precondition: nil goth_name → {:precondition_missing, :goth_not_configured}",
         %{finch_name: f} do
      assert RuntimeChecks.probe_gcs_bucket("my-bucket", f, nil) ==
               {:precondition_missing, :goth_not_configured}
    end

    # Security invariants — apply across all error-path return shapes that surface
    # through error_result/4. Verified at the doctor-row level (NOT do_probe/4
    # directly) because do_probe/4 returns raw tuples; error_result/4 stringifies
    # them via inspect/1.
    test "doctor row: probe error_result NEVER echoes bearer token (security invariant)",
         %{bypass: bypass, finch_name: f, goth_name: g, base_url: u, token: t} do
      Bypass.expect_once(bypass, "GET", "/storage/v1/b/my-bucket", fn conn ->
        # Server replies with body that includes a bogus bearer-shaped string —
        # the probe MUST NOT include the body in the error tuple, only the status.
        Plug.Conn.resp(conn, 500, ~s({"error":"Bearer eyJleavAk-this-must-not-leak"}))
      end)

      original = Application.get_env(:rindle, Rindle.Storage.GCS)

      Application.put_env(:rindle, Rindle.Storage.GCS,
        bucket: "my-bucket",
        finch: f,
        goth: g,
        base_url: u,
        token: t
      )

      try do
        report =
          run_runtime_checks(
            probe: fn -> :ok end,
            env: %{},
            profiles: [GCSProbeProfile],
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

        check = Enum.find(report.checks, &(&1.id == "doctor.gcs_bucket_reachable"))
        assert check.status == :error

        refute check.summary =~ ~r/Bearer ey/,
               "Bearer token leaked into doctor summary: #{inspect(check.summary)}"

        refute check.summary =~ ~r/-----BEGIN/
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
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

  defp gcs_fixture_goth_source(token_url) do
    {:service_account, SigningKeyFixture.fixture_json(), url: token_url}
  end
end
