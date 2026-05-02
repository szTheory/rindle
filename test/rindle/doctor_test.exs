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
  end
end
