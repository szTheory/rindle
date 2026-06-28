defmodule Rindle.AV.Subprocess do
  @moduledoc """
  MuonTrap execution wrapper + 4-cap enforcement.
  """

  require Logger

  @cgroup_base "rindle_av"

  @doc """
  Runs a command wrapped in MuonTrap with configured cgroups and 4-cap limits.
  """
  def run(cmd, args, opts \\ []) do
    opts = Keyword.put_new(opts, :use_cgroups, default_use_cgroups?())
    muon_opts = build_opts(opts)
    modified_args = build_args(cmd, args, opts)
    run_isolated(cmd, modified_args, muon_opts, 1, &MuonTrap.cmd/3)
  end

  # NOTE (EPIPE-07, MuonTrap #98): https://github.com/fhunleth/muontrap/issues/98 (OPEN as of
  # 2026-06; reproduces in 1.7.0 / 1.8.0 / 2.0.0-rc.0). MuonTrap ACKs consumed stdout bytes by
  # writing to its wrapper's stdin (port.ex report_bytes_handled/2 -> Port.command/2). When the
  # child closes after the last chunk, that ACK write hits a dead reader and the port delivers an
  # async {:EXIT, port, :epipe} to its OWNER. MuonTrap's `rescue ArgumentError` catches only the
  # synchronous failure; this async exit kills the inline caller. We own the port in a throwaway
  # trap_exit'd worker so the signal dies with the worker, and surface the real {output, status}.
  # Removal condition: #98 fixed AND the :muontrap pin bumped to the fixed version. The live signal
  # is test/rindle/av/subprocess_epipe_canary_test.exs — do NOT delete that canary without deleting
  # this shim.
  #
  # `run_fun` is a test seam (default &MuonTrap.cmd/3); it lets the deterministic regression test
  # drive the absorption path with no OS race. run/3 never passes it, so the public contract is
  # byte-identical.
  @doc false
  def run_isolated(cmd, args, muon_opts, retries_left, run_fun) do
    parent = self()
    ref = make_ref()

    {pid, mon} =
      spawn_monitor(fn ->
        Process.flag(:trap_exit, true)
        result = run_fun.(cmd, args, muon_opts)
        send(parent, {ref, result})
        # Drain a possible late {:EXIT, port, :epipe} so it can't escape the worker.
        receive do
          {:EXIT, port, _reason} when is_port(port) -> :ok
        after
          0 -> :ok
        end
      end)

    receive do
      {^ref, result} ->
        Process.demonitor(mon, [:flush])
        result

      {:DOWN, ^mon, :process, ^pid, :epipe} when retries_left > 0 ->
        Logger.debug(
          "Rindle.AV.Subprocess: absorbed a pre-reply MuonTrap #98 :epipe exit; retrying the AV call once " <>
            "(see https://github.com/fhunleth/muontrap/issues/98)"
        )

        run_isolated(cmd, args, muon_opts, retries_left - 1, run_fun)

      {:DOWN, ^mon, :process, ^pid, reason} ->
        exit(reason)
    end
  end

  defp default_use_cgroups? do
    env = System.get_env("RINDLE_AV_USE_CGROUPS")

    cond do
      env in ["0", "false", "FALSE"] -> false
      env in ["1", "true", "TRUE"] -> true
      true -> Application.get_env(:rindle, __MODULE__, [])[:use_cgroups] != false
    end
  end

  @doc false
  def build_opts(opts) do
    opts = Keyword.put_new(opts, :use_cgroups, default_use_cgroups?())
    timeout = Keyword.get(opts, :timeout, Keyword.get(opts, :max_wall_ms, 600_000))
    base = [into: "", stderr_to_stdout: true, timeout: timeout]

    if :os.type() == {:unix, :linux} and Keyword.get(opts, :use_cgroups, true) do
      cgroup_sets = [
        {"memory", "memory.limit_in_bytes", "536870912"},
        {"cpu", "cpu.cfs_period_us", "100000"},
        {"cpu", "cpu.cfs_quota_us", "50000"}
      ]

      base ++
        [
          cgroup_controllers: ["memory", "cpu"],
          cgroup_base: @cgroup_base,
          cgroup_sets: cgroup_sets
        ]
    else
      base
    end
  end

  @doc false
  def build_args("ffmpeg", args, opts) do
    max_cpu_seconds = Keyword.get(opts, :max_cpu_seconds, 300)
    max_duration_seconds = Keyword.get(opts, :max_duration_seconds, 7200)
    max_output_bytes = Keyword.get(opts, :max_output_bytes, 500_000_000)

    common = [
      "-protocol_whitelist",
      "file,crypto,data",
      "-timelimit",
      Integer.to_string(max_cpu_seconds),
      "-t",
      Integer.to_string(max_duration_seconds)
    ]

    case List.pop_at(args, -1) do
      {destination, input_and_output_args} when is_binary(destination) ->
        common ++
          input_and_output_args ++ ["-fs", Integer.to_string(max_output_bytes), destination]

      _ ->
        common ++ args
    end
  end

  def build_args(_cmd, args, _opts), do: args
end
