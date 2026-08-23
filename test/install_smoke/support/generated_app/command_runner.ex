defmodule Rindle.InstallSmoke.GeneratedApp.CommandRunner do
  @moduledoc false

  @default_timeout_ms :timer.minutes(20)

  @doc false
  def run(cwd, [command | args] = argv, env, options \\ []) when is_list(env) do
    timeout_ms = Keyword.get(options, :timeout_ms, @default_timeout_ms)
    stage = Keyword.get(options, :stage, Enum.join(argv, " "))

    task =
      Task.async(fn ->
        System.cmd(command, args, cd: cwd, env: env, stderr_to_stdout: true, into: "")
      end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, exit_code}} ->
        %{
          output: "stage=#{stage}\n#{output}",
          exit_code: exit_code,
          stage: stage,
          timed_out?: false
        }

      nil ->
        %{
          output: "stage=#{stage}\ncommand timed out after #{timeout_ms}ms\ncwd=#{cwd}",
          exit_code: 124,
          stage: stage,
          timed_out?: true
        }
    end
  end

  @doc false
  def run!(cwd, argv, env, options \\ []) do
    case run(cwd, argv, env, options) do
      %{exit_code: 0} = result ->
        result

      %{exit_code: exit_code, output: output, stage: stage} ->
        raise """
        generated command failed (stage=#{stage}, exit=#{exit_code}): #{Enum.join(argv, " ")}
        cwd: #{cwd}

        #{output}
        """
    end
  end
end
