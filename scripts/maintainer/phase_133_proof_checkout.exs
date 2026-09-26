defmodule Rindle.Phase133ProofCheckout do
  @moduledoc false

  def checkout_subject!(root, audit_root, subject) do
    {_, 0} =
      System.cmd("git", ["clone", "--quiet", "--shared", "--no-checkout", root, audit_root],
        stderr_to_stdout: true
      )

    {_, 0} =
      System.cmd("git", ["checkout", "--quiet", "--detach", subject],
        cd: audit_root,
        stderr_to_stdout: true
      )

    :ok
  end

  def prepare_build_path!(audit_root) do
    build_path = Path.join(audit_root, ".phase133-proof-build")
    File.mkdir_p!(Path.join(build_path, "lib"))
    canonical_path!(build_path)
  end

  def prepare_deps_path!(audit_root) do
    path = Path.join(audit_root, ".phase133-proof-deps")
    File.mkdir_p!(path)
    canonical_path!(path)
  end

  def prepare_hex_path!(audit_root) do
    path = Path.join(audit_root, ".phase133-proof-hex")
    File.mkdir_p!(path)
    canonical_path!(path)
  end

  # Mix writes app include links using physical paths. A logical macOS temp
  # path (for example /var/... or /tmp) can otherwise mix with /private/... and
  # produce invalid /private/private/... links in the isolated build.
  defp canonical_path!(path) do
    case System.cmd("pwd", ["-P"], cd: path, stderr_to_stdout: true) do
      {physical_path, 0} ->
        String.trim(physical_path)

      {output, status} ->
        raise "could not resolve isolated proof path #{path} (#{status}): #{String.trim(output)}"
    end
  end

  def materialize_locked_dependencies!(audit_root, env) do
    with {:ok, _output} <-
           run_mix(audit_root, env, "mix deps.get --only test --check-locked"),
         {_, 0} <-
           System.cmd("git", ["diff", "--quiet", "--", "mix.exs", "mix.lock"],
             cd: audit_root,
             stderr_to_stdout: true
           ) do
      :ok
    else
      {:error, message} ->
        {:error, message}

      {output, _status} ->
        {:error,
         "locked dependency materialization modified mix.exs or mix.lock: #{String.trim(output)}"}
    end
  end

  defp run_mix(audit_root, env, command) do
    case System.cmd("bash", ["-lc", command],
           cd: audit_root,
           env: env,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        {:ok, output}

      {output, status} ->
        {:error,
         "locked dependency command failed (#{status}), exact-subject proofs fail closed: #{String.trim(output)}"}
    end
  end
end
