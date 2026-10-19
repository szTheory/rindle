defmodule Rindle.AV.SubprocessStdinTest do
  use ExUnit.Case, async: true

  alias Rindle.AV.Subprocess

  @moduletag :av

  # Locks why Rindle runs AV commands through Subprocess.ack_free_cmd/3 with `-nostdin` on ffmpeg.
  # MuonTrap 1.7 forks the child without redirecting stdin, so the child inherits the pipe the
  # BEAM writes stdout flow-control ACKs to. A child that reads stdin (ffmpeg polls it for
  # keyboard commands) races MuonTrap for those ACKs; each one it wins is lost for good, so plain
  # MuonTrap.cmd/3 stops draining the child and the call stalls until its timeout. This was the
  # main-only AV poster-frame stall in the mux lane and Adoption Demo E2E (2026-10-16).
  #
  # If MuonTrap starts giving the child its own stdin, the inheritance and raw-stall assertions
  # fail; the ACK-free runner and `-nostdin` are then still harmless but redundant.

  @output_bytes 3_000_000
  @producer "head -c #{@output_bytes} /dev/zero | tr '\\0' a 2>/dev/null"
  @stdin_reader "#{@producer} & cat >/dev/null"

  test "Subprocess.run gives ffmpeg -nostdin, so it never polls the ACK pipe for keys" do
    args = ["-hide_banner", "-f", "lavfi", "-i", "testsrc=duration=0.2", "-f", "null", "-"]

    {bare_output, 0} = Subprocess.ack_free_cmd("ffmpeg", args, stderr_to_stdout: true)
    assert bare_output =~ "Press [q]"

    {output, 0} = Subprocess.run("ffmpeg", args)
    refute output =~ "Press [q]"
  end

  test "a MuonTrap child inherits the parent's pipe as stdin" do
    assert {"pipe\n", 0} =
             Subprocess.ack_free_cmd(
               "sh",
               ["-c", "if [ -p /dev/stdin ]; then echo pipe; else echo other; fi"],
               timeout: 10_000
             )
  end

  test "plain MuonTrap.cmd/3 stalls when the child reads stdin" do
    # The reader never exits, so no end-of-run #98 :epipe can intervene; only the stall can.
    {output, status} =
      Subprocess.run_isolated(
        "sh",
        ["-c", @stdin_reader],
        [into: "", timeout: 1_000],
        1,
        &MuonTrap.cmd/3
      )

    assert status == :timeout
    assert byte_size(output) < @output_bytes
  end

  test "the ACK-free runner drains everything even when the child reads stdin" do
    # Same child: nothing is written to the pipe, so there is nothing to steal. The reader keeps
    # the command alive until the timeout, by which point all output has arrived.
    {output, status} = Subprocess.ack_free_cmd("sh", ["-c", @stdin_reader], timeout: 3_000)

    assert status == :timeout
    assert byte_size(output) == @output_bytes
  end

  test "the ACK-free runner returns the exit status of short commands" do
    for _ <- 1..50 do
      assert {"ok\n", 0} = Subprocess.ack_free_cmd("sh", ["-c", "echo ok"], timeout: 10_000)
      assert {"", 3} = Subprocess.ack_free_cmd("sh", ["-c", "exit 3"], timeout: 10_000)
    end
  end
end
