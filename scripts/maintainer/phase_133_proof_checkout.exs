defmodule Rindle.Phase133ProofCheckout do
  @moduledoc false

  def checkout_subject!(root, audit_root, subject) do
    root = canonical_directory!(root)
    audit_root = safe_clone_destination!(audit_root)

    {_, 0} =
      System.cmd("git", ["clone", "--quiet", "--shared", "--no-checkout", root, audit_root],
        stderr_to_stdout: true
      )

    canonical_directory!(audit_root)

    {_, 0} =
      System.cmd("git", ["checkout", "--quiet", "--detach", subject],
        cd: audit_root,
        stderr_to_stdout: true
      )

    canonical_directory!(audit_root)
    :ok
  end

  def prepare_build_path!(audit_root) do
    safe_private_directory!(audit_root, ".phase133-proof-build", ["lib"])
  end

  def prepare_deps_path!(audit_root) do
    safe_private_directory!(audit_root, ".phase133-proof-deps", [])
  end

  def prepare_hex_path!(audit_root) do
    safe_private_directory!(audit_root, ".phase133-proof-hex", [])
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

  defp canonical_directory!(path) do
    case File.lstat(path) do
      {:ok, %{type: :directory}} ->
        canonical_path!(path)

      {:ok, %{type: :symlink}} ->
        raise "refusing symlinked private proof directory: #{path}"

      {:ok, _other} ->
        raise "private proof path is not a directory: #{path}"

      {:error, reason} ->
        raise "could not inspect private proof directory #{path}: #{inspect(reason)}"
    end
  end

  defp safe_clone_destination!(audit_root) do
    expanded = Path.expand(audit_root)
    parent = expanded |> Path.dirname() |> canonical_directory!()
    destination = Path.join(parent, Path.basename(expanded))

    case File.lstat(destination) do
      {:error, :enoent} -> destination
      {:ok, %{type: :symlink}} -> raise "refusing symlinked private clone path: #{destination}"
      {:ok, _other} -> raise "private clone destination already exists: #{destination}"
      {:error, reason} -> raise "could not inspect private clone path: #{inspect(reason)}"
    end
  end

  defp safe_private_directory!(audit_root, relative_path, children) do
    root = canonical_directory!(audit_root)
    path = Path.join(root, relative_path)
    ensure_directory!(path)
    ensure_no_symlinks!(path)

    Enum.each(children, fn child ->
      child_path = Path.join(path, child)
      ensure_directory!(child_path)
      ensure_no_symlinks!(child_path)
    end)

    canonical = canonical_directory!(path)
    ensure_descendant!(root, canonical)
    canonical
  end

  defp ensure_directory!(path) do
    case File.lstat(path) do
      {:ok, %{type: :directory}} -> :ok
      {:ok, %{type: :symlink}} -> raise "refusing symlinked private proof path: #{path}"
      {:ok, _other} -> raise "private proof path is not a directory: #{path}"
      {:error, :enoent} -> File.mkdir!(path)
      {:error, reason} -> raise "could not inspect private proof path #{path}: #{inspect(reason)}"
    end
  end

  defp ensure_no_symlinks!(path) do
    case File.lstat(path) do
      {:ok, %{type: :symlink}} ->
        raise "refusing symlink inside private proof path: #{path}"

      {:ok, %{type: :directory}} ->
        path
        |> File.ls!()
        |> Enum.each(&ensure_no_symlinks!(Path.join(path, &1)))

      {:ok, _file} ->
        :ok

      {:error, reason} ->
        raise "could not inspect private proof path #{path}: #{inspect(reason)}"
    end
  end

  defp ensure_descendant!(root, path) do
    if String.starts_with?(path, root <> "/") do
      :ok
    else
      raise "private proof path escapes detached checkout: #{path}"
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
