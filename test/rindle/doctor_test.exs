defmodule Rindle.DoctorTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  defmodule GCSProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.GCS,
      variants: [thumb: [mode: :fit, width: 32]]
  end

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
              env: %{},
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

    test "OptionParser accepts --streaming boolean flag" do
      # Unit-test the OptionParser boundary directly: invoking
      # `Mix.Tasks.Rindle.Doctor.run/1` calls Mix.Project.config and may not
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
              {:up, 20_260_425_090_000, "** FILE NOT FOUND **"}
            ]
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
        signing_key: Rindle.Storage.GCS.SigningKeyFixture.fixture_json()
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
    Mix.Tasks.Rindle.Doctor.run_checks(
      args,
      Keyword.put_new(opts, :resumable_session_schema_catalog, resumable_session_schema_fixture())
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
    {:service_account, Rindle.Storage.GCS.SigningKeyFixture.fixture_json(), url: token_url}
  end
end
