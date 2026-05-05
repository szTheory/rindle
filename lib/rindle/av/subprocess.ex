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
    # max_wall 600s
    timeout = Keyword.get(opts, :timeout, 600_000)
    base = [into: "", stderr_to_stdout: true, timeout: timeout]
    
    if :os.type() == {:unix, :linux} and Keyword.get(opts, :use_cgroups, true) do
      # Calculate memory limits and cpu quotas
      cgroup_sets = [
        {"memory", "memory.limit_in_bytes", "536870912"},
        {"cpu", "cpu.cfs_period_us", "100000"},
        {"cpu", "cpu.cfs_quota_us", "50000"}
      ]
      
      base ++ [
        cgroup_controllers: ["memory", "cpu"],
        cgroup_base: @cgroup_base,
        cgroup_sets: cgroup_sets
      ]
    else
      base
    end
  end

  @doc false
  def build_args("ffmpeg", args, _opts) do
    common = [
      "-protocol_whitelist", "file,crypto,data",
      "-timelimit", "300",
      "-t", "7200"
    ]

    case List.pop_at(args, -1) do
      {destination, input_and_output_args} when is_binary(destination) ->
        common ++ input_and_output_args ++ ["-fs", "500000000", destination]

      _ ->
        common ++ args
    end
  end

  def build_args(_cmd, args, _opts), do: args
end
