defmodule Rindle.AV.SubprocessStdinTest do
  use ExUnit.Case, async: true

  alias Rindle.AV.Subprocess

  @moduletag :av

  # Locks the reason Rindle.AV.Subprocess.build_args/3 prepends `-nostdin` to every ffmpeg call.
  # MuonTrap 1.7 forks the child without redirecting stdin, so the child inherits the pipe the
  # BEAM writes stdout flow-control ACKs to. A child that reads stdin (ffmpeg polls it for
  # keyboard commands) eats those ACKs; once the window is spent MuonTrap stops draining the
  # child's output and the call stalls until its timeout. This is the main-only AV poster-frame
  # stall seen in the mux lane and Adoption Demo E2E (2026-10-16).
  #
  # Deterministic: the reader below consumes every ACK. If MuonTrap starts giving the child its
  # own stdin, these assertions fail; `-nostdin` is then still harmless but no longer load-bearing.

  @output_bytes 3_000_000
  @producer "head -c #{@output_bytes} /dev/zero | tr '\\0' a 2>/dev/null"

  test "Subprocess.run gives ffmpeg -nostdin, so it never polls the ACK pipe for keys" do
    args = ["-hide_banner", "-f", "lavfi", "-i", "testsrc=duration=0.2", "-f", "null", "-"]

    {bare_output, 0} = MuonTrap.cmd("ffmpeg", args, stderr_to_stdout: true)
    assert bare_output =~ "Press [q]"

    {output, 0} = Subprocess.run("ffmpeg", args)
    refute output =~ "Press [q]"
  end

  test "a MuonTrap child inherits the ACK pipe as stdin" do
    assert {"pipe\n", 0} =
             MuonTrap.cmd("sh", [
               "-c",
               "if [ -p /dev/stdin ]; then echo pipe; else echo other; fi"
             ])
  end

  test "a child that reads stdin starves MuonTrap output until the timeout" do
    {output, status} =
      MuonTrap.cmd("sh", ["-c", "#{@producer} & cat >/dev/null"],
        into: "",
        timeout: 1_000
      )

    assert status == :timeout
    assert byte_size(output) < @output_bytes
  end

  test "the same output drains in full when the child leaves stdin alone" do
    {output, status} =
      MuonTrap.cmd("sh", ["-c", "#{@producer}; exec </dev/null"],
        into: "",
        timeout: 10_000
      )

    assert status == 0
    assert byte_size(output) == @output_bytes
  end
end
