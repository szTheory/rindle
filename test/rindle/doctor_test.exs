defmodule Rindle.DoctorTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "run_checks/2 success output" do
    test "prints success message when ffmpeg is valid" do
      output = capture_io(fn ->
        report =
          Mix.Tasks.Rindle.Doctor.run_checks([],
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
            Mix.Tasks.Rindle.Doctor.run_checks(
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
            Mix.Tasks.Rindle.Doctor.run_checks(["Does.Not.Exist"],
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

    test "raises after emitting the summary when failures are present" do
      assert_raise Mix.Error, ~r/Rindle\.Doctor failed: 1 check\(s\) failed/, fn ->
        capture_io(fn ->
          Mix.Tasks.Rindle.Doctor.run_checks([],
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
  end
end
