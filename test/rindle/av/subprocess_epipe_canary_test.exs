defmodule Rindle.AV.SubprocessEpipeCanaryTest do
  use ExUnit.Case, async: false

  @moduletag :canary
  @moduletag :av

  @muontrap_issue "https://github.com/fhunleth/muontrap/issues/98"
  @iters 500

  # ADVISORY canary (D-11/D-12): probes the UNGUARDED MuonTrap.cmd/3 and asserts MuonTrap #98
  # STILL reproduces. When upstream fixes #98, the :epipe stops firing and this test fails LOUDLY,
  # signalling that the Rindle.AV.Subprocess run_isolated/5 shim can be removed. Probabilistic →
  # advisory only; it must NEVER gate a PR. It is the live removal signal coupled to the
  # `# NOTE (EPIPE-07, MuonTrap #98)` block above run_isolated/5 in lib/rindle/av/subprocess.ex:
  # do NOT delete this canary without deleting that shim, and vice versa.
  #
  # Gating safety: `:canary` is excluded from the default suite in test/test_helper.exs (Plan 01,
  # D-12), so a bare `mix test` never runs this file. It is opted back in ONLY by the nightly lane's
  # `--include canary` step (continue-on-error: true) — purely informational, never a merge gate.
  test "MuonTrap #98 :epipe still reproduces (remove the Subprocess shim when this fails)" do
    Process.flag(:trap_exit, true)

    reproduced? =
      Enum.reduce_while(1..@iters, false, fn _i, _acc ->
        try do
          _ =
            MuonTrap.cmd("sh", ["-c", "yes | head -n 100000"],
              into: "",
              stderr_to_stdout: true
            )

          # Also catch the async signal form if it landed in our mailbox.
          receive do
            {:EXIT, _port, :epipe} -> {:halt, true}
          after
            0 -> {:cont, false}
          end
        catch
          :exit, :epipe -> {:halt, true}
          :exit, {:epipe, _} -> {:halt, true}
        end
      end)

    assert reproduced?, """
    MuonTrap #98 NO LONGER reproduces across #{@iters} iterations.

    This is the canary firing: upstream may have FIXED the :epipe race.
      - Upstream issue: #{@muontrap_issue}
      - Installed muontrap version: #{Application.spec(:muontrap, :vsn)}

    If #98 is fixed in this version, REMOVE the absorption shim:
      - lib/rindle/av/subprocess.ex  (run_isolated/5 + the run/3 delegation)
      - this canary file: test/rindle/av/subprocess_epipe_canary_test.exs
      - the deterministic regression test: test/rindle/av/subprocess_epipe_test.exs
    and bump the :muontrap pin to the fixed version. See the NOTE block above run_isolated/5.
    """
  end
end
