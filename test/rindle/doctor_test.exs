defmodule Rindle.DoctorTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "run/1" do
    test "prints success message when ffmpeg is valid" do
      output = capture_io(fn ->
        Mix.Tasks.Rindle.Doctor.run([])
      end)

      assert output =~ "Rindle: Environment checks passed"
      assert output =~ "FFmpeg: OK"
    end

    test "prints profile-aware success output for explicit fixture modules" do
      output =
        capture_io(fn ->
          Mix.Tasks.Rindle.Doctor.run([
            "Rindle.Adopter.CanonicalApp.Profile",
            "Rindle.Adopter.CanonicalApp.VideoProfile"
          ])
        end)

      assert output =~ "Profile Rindle.Adopter.CanonicalApp.Profile: OK"
      assert output =~ "Profile Rindle.Adopter.CanonicalApp.VideoProfile: OK"
      assert output =~ "variants checked: 2"
      assert output =~ "Rindle: Environment checks passed"
    end
  end

  describe "run_checks/2" do
    test "raises with actionable output when a requested profile is unknown" do
      assert_raise Mix.Error, ~r/Rindle\.Doctor failed: unknown profile module/, fn ->
        capture_io(:stderr, fn ->
          Mix.Tasks.Rindle.Doctor.run_checks(["Does.Not.Exist"],
            probe: fn -> :ok end
          )
        end)
      end
    end
  end
end
