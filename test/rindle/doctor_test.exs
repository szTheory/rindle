defmodule Rindle.DoctorTest do
  alias Mix.Tasks.Rindle.Doctor
  alias Rindle.Storage.GCS.SigningKeyFixture
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defmodule GCSProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.GCS,
      variants: [thumb: [mode: :fit, width: 32]]
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

  describe "run_checks/2 success output" do
    test "prints success message when ffmpeg is valid" do
      output =
        capture_io(fn ->
          report =
            run_doctor_checks([],
              exit_on_failure?: false,
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

          assert report.success?
        end)

      assert output =~ "Rindle: running environment checks"
      assert output =~ "doctor.ffmpeg_runtime"
      assert output =~ "doctor.oban_required_queues"
      assert output =~ "Rindle: Environment checks passed"
    end

    test "prints profile-aware success output for explicit fixture modules" do
      output =
        capture_io(fn ->
          report =
            run_doctor_checks(
              [
                "Rindle.Adopter.CanonicalApp.Profile",
                "Rindle.Adopter.CanonicalApp.VideoProfile"
              ],
              exit_on_failure?: false,
              probe: fn -> :ok end,
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
              migration_statuses: []
            )

          assert report.success?
        end)

      assert output =~ "doctor.profile_runtime_fit"
      assert output =~ "Profile/runtime fit OK for 2 profile(s)"
      assert output =~ "checked 2 AV variant(s)"
      assert output =~ "Rindle: Environment checks passed"
    end
  end

  describe "run_checks/2" do
    test "renders a safe actionable ownership diagnosis for a Rindle prefix mismatch" do
      sentinel = "SELECT secret FROM pg_catalog WHERE password = 'credential'"

      {report, output} =
        captured_doctor_report([],
          exit_on_failure?: false,
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: applied_legacy_migration_statuses(),
          ownership_snapshot: %{
            rindle: %{
              expected_prefix: "public",
              observed_prefix: "rindle",
              owner: :rindle,
              classification: :rindle_prefix_mismatch,
              next_action:
                "Schedule the host-owned maintenance-window move, then deploy the matching Rindle prefix."
            },
            oban: %{
              expected_prefix: "public",
              observed_prefix: "public",
              owner: :host,
              classification: :ready,
              next_action: "Host owns Oban.Migration for oban_jobs.",
              raw_reason: sentinel
            }
          }
        )

      rindle = Enum.find(report.checks, &(&1.id == "doctor.rindle_schema.ready"))
      oban = Enum.find(report.checks, &(&1.id == "doctor.oban_jobs.ready"))

      assert rindle.expected_prefix == "public"
      assert rindle.observed_prefix == "rindle"
      assert rindle.owner == :rindle
      assert rindle.classification == :rindle_prefix_mismatch
      assert rindle.next_action =~ "maintenance-window"
      assert oban.expected_prefix == "public"
      assert oban.observed_prefix == "public"
      assert oban.owner == :host
      assert oban.classification == :ready
      assert oban.next_action =~ "Oban.Migration"
      assert output =~ "expected public"
      assert output =~ "observed rindle"

      assert output =~
               "Rindle never creates, moves, drops, or prefixes `oban_jobs` or host `schema_migrations`."

      assert output =~ "Host owns Oban.Migration"
      refute inspect(rindle) =~ sentinel
      refute inspect(oban) =~ sentinel
      refute output =~ sentinel
    end

    test "prints all checks in stable order and emits a summary before failing" do
      output =
        capture_io(fn ->
          report =
            run_doctor_checks(["Does.Not.Exist"],
              exit_on_failure?: false,
              probe: fn -> raise RuntimeError, "ffmpeg missing" end,
              env: %{},
              oban_config: [repo: Rindle.Repo, queues: [rindle_process: 1]],
              migration_statuses: [
                {:down, 20_260_502_120_000, "extend_media_for_av.exs"}
              ]
            )

          refute report.success?
        end)

      assert output =~ "doctor.ffmpeg_runtime"
      assert output =~ "doctor.profile_runtime_fit"
      assert output =~ "doctor.oban_required_queues"
      assert output =~ "doctor.migrations.pending"
      assert output =~ "Rindle: Environment checks failed"

      assert String.contains?(output, "doctor.ffmpeg_runtime") and
               String.contains?(output, "doctor.profile_runtime_fit")
    end

    test "passes --streaming flag through to RuntimeChecks.run/2" do
      # With no streaming profiles, vacuous-OK fires regardless of flag —
      # but we still verify the smoke-ping check is present, proving the
      # opts plumbed through to RuntimeChecks.run/2.
      capture_io(fn ->
        report =
          run_doctor_checks([],
            shell: Mix.Shell.IO,
            profiles: [],
            probe: fn -> :ok end,
            exit_on_failure?: false,
            streaming: true,
            env: %{},
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
            local_playback_route: []
          )

        check = Enum.find(report.checks, &(&1.id == "doctor.streaming_smoke_ping"))
        assert check, "doctor.streaming_smoke_ping must appear in the check list"
        assert check.status == :ok
      end)
    end

    test "prints warning-only legacy file-history drift when catalog readiness is healthy" do
      {report, output} =
        captured_doctor_report([],
          exit_on_failure?: true,
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: [{:up, 20_260_425_090_000, "** FILE NOT FOUND **"}],
          rindle_schema_catalog: healthy_legacy_catalog_fixture(),
          oban_jobs_catalog: oban_jobs_ready_fixture()
        )

      assert output =~ "[WARN] doctor.migrations.unresolved"
      assert output =~ "history"
      assert output =~ "legacy"
      refute output =~ "delete"
      refute output =~ "replay"
      assert output =~ "Rindle: Environment checks passed"
      assert report.success?
      assert report.failed == 0
    end

    test "prints host-owned Oban.Migration setup copy when oban_jobs is missing" do
      {report, output} =
        captured_doctor_report([],
          exit_on_failure?: false,
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: healthy_oban_config(),
          migration_statuses: applied_legacy_migration_statuses(),
          rindle_schema_catalog: healthy_legacy_catalog_fixture(),
          oban_jobs_catalog: %{exists?: false}
        )

      assert output =~ "[ERROR] doctor.oban_jobs.ready"
      assert output =~ "oban_jobs"
      assert output =~ "Oban.Migration"
      assert output =~ "Rindle no longer manages `oban_jobs`"
      assert output =~ "Rindle: Environment checks failed"
      refute report.success?
    end

    test "OptionParser accepts --streaming boolean flag" do
      # Unit-test the OptionParser boundary directly: invoking
      # `Doctor.run/1` calls Mix.Project.config and may not
      # be safely invokable in test env, so we test the parser shape itself.
      assert {[streaming: true], [], []} =
               OptionParser.parse(["--streaming"], strict: [streaming: :boolean])

      assert {[], [], []} =
               OptionParser.parse([], strict: [streaming: :boolean])
    end

    test "raises after emitting the summary when failures are present" do
      assert_raise Mix.Error, ~r/Rindle\.Doctor failed: 1 check\(s\) failed/, fn ->
        capture_io(fn ->
          run_doctor_checks([],
            probe: fn -> raise RuntimeError, "ffmpeg missing" end,
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
        end)
      end
    end

    test "renders warning rows as [WARN] and does not raise for warning-only reports" do
      bypass = Bypass.open()
      finch_name = :"rindle_doctor_warn_finch_#{System.unique_integer([:positive])}"
      goth_name = :"rindle_doctor_warn_goth_#{System.unique_integer([:positive])}"
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
            "fields=cors" -> ~s({"cors":[]})
            _ -> ~s({"name":"my-bucket"})
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
        output =
          capture_io(fn ->
            report =
              run_doctor_checks([],
                exit_on_failure?: true,
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

            assert report.success?
            assert report.failed == 0
          end)

        assert output =~ "[WARN] doctor.gcs_resumable_cors"
        assert output =~ "Fix:"
        assert output =~ "Rindle: Environment checks passed"
      after
        if original do
          Application.put_env(:rindle, Rindle.Storage.GCS, original)
        else
          Application.delete_env(:rindle, Rindle.Storage.GCS)
        end
      end
    end
  end

  defp run_doctor_checks(args, opts) do
    Doctor.run_checks(
      args,
      opts
      |> Keyword.put_new(:rindle_schema_catalog, fresh_marker_catalog_fixture())
      |> Keyword.put_new(:oban_jobs_catalog, oban_jobs_ready_fixture())
      |> Keyword.put_new(:resumable_session_schema_catalog, resumable_session_schema_fixture())
    )
  end

  defp captured_doctor_report(args, opts) do
    ref = make_ref()

    output =
      capture_io(fn ->
        report = run_doctor_checks(args, opts)
        send(self(), {ref, report})
      end)

    assert_received {^ref, report}
    {report, output}
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

  defp oban_jobs_ready_fixture do
    %{exists?: true, owner: :host, setup: "Oban.Migration"}
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
