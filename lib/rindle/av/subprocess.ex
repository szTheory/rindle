defmodule Rindle.AV.Subprocess do
  @moduledoc """
  MuonTrap execution wrapper + 4-cap enforcement.
  """

  @cgroup_base "rindle_av"

  @doc """
  Runs a command wrapped in MuonTrap with configured cgroups and 4-cap limits.
  """
  def run(cmd, args, opts \\ []) do
    muon_opts = build_opts(opts)
    modified_args = build_args(cmd, args, opts)
    MuonTrap.cmd(cmd, modified_args, muon_opts)
  end

  @doc false
  def build_opts(opts) do
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
