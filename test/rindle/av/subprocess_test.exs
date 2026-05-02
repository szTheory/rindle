defmodule Rindle.AV.SubprocessTest do
  use ExUnit.Case, async: true
  alias Rindle.AV.Subprocess

  describe "run/3" do
    test "appends four-cap arguments and protocol whitelist for ffmpeg" do
      # Run a command that just echoes its arguments so we can inspect what was actually executed
      # We use a script or a command that ignores unknown flags, or just 'echo'
      # But wait, Subprocess.run("ffmpeg", ...) might be hardcoded to check "ffmpeg"
      # Let's pass "echo" as the command, and see if we can trick it or if we just test a builder.
      # To be robust, let's expose `build_args/2` and `build_opts/1` for testing.
      
      args = Subprocess.build_args("ffmpeg", ["-i", "input.mp4", "output.mp4"], [])
      
      assert "-protocol_whitelist" in args
      assert "file,crypto,data" in args
      assert "-timelimit" in args
      assert "-t" in args
      assert "-fs" in args
    end

    test "does not append four-cap arguments for non-ffmpeg commands" do
      args = Subprocess.build_args("echo", ["hello"], [])
      refute "-protocol_whitelist" in args
      assert args == ["hello"]
    end

    test "build_opts/1 configures timeout and cgroups" do
      opts = Subprocess.build_opts(timeout: 5000)
      assert opts[:timeout] == 5000
      
      if :os.type() == {:unix, :linux} do
        assert opts[:cgroup_base] == "rindle_av"
        assert is_list(opts[:cgroup_controllers])
      end
    end
  end
end
