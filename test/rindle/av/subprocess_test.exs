defmodule Rindle.AV.SubprocessTest do
  use ExUnit.Case, async: true

  alias Rindle.AV.Subprocess

  describe "build_args/3" do
    test "prepends protocol whitelist and three ffmpeg caps before input, with fs before destination" do
      args =
        Subprocess.build_args(
          "ffmpeg",
          ["-y", "-i", "input.mp4", "-c:v", "libx264", "output.mp4"],
          []
        )

      assert Enum.take(args, 6) == [
               "-protocol_whitelist",
               "file,crypto,data",
               "-timelimit",
               "300",
               "-t",
               "7200"
             ]

      assert Enum.slice(args, 6, 4) == ["-y", "-i", "input.mp4", "-c:v"]

      assert Enum.take(Enum.drop_while(args, &(&1 != "-fs")), 3) == [
               "-fs",
               "500000000",
               "output.mp4"
             ]
    end

    test "allows ffmpeg cap overrides through opts while keeping enforcement centralized" do
      args =
        Subprocess.build_args(
          "ffmpeg",
          ["-i", "input.mp4", "output.mp4"],
          max_cpu_seconds: 15,
          max_duration_seconds: 45,
          max_output_bytes: 12_345
        )

      assert args == [
               "-protocol_whitelist",
               "file,crypto,data",
               "-timelimit",
               "15",
               "-t",
               "45",
               "-i",
               "input.mp4",
               "-fs",
               "12345",
               "output.mp4"
             ]
    end

    test "does not append four-cap arguments for non-ffmpeg commands" do
      args = Subprocess.build_args("echo", ["hello"], [])
      refute "-protocol_whitelist" in args
      assert args == ["hello"]
    end
  end

  describe "build_opts/1" do
    test "configures timeout and cgroups" do
      opts = Subprocess.build_opts(timeout: 5000)
      assert opts[:timeout] == 5000

      if :os.type() == {:unix, :linux} do
        assert opts[:cgroup_base] == "rindle_av"
        assert is_list(opts[:cgroup_controllers])
      end
    end
  end
end
