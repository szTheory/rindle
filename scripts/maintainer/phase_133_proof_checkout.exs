defmodule Rindle.Phase133ProofCheckout do
  @moduledoc false

  @project_apps ["rindle", "rindle_test"]

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

  def prepare_build_path!(cache_root, audit_root) do
    build_path = Path.join(audit_root, ".phase133-proof-build")
    shared_lib = Path.join(cache_root, "_build/test/lib")
    isolated_lib = Path.join(build_path, "test/lib")
    File.mkdir_p!(isolated_lib)

    if File.dir?(shared_lib) do
      for entry <- File.ls!(shared_lib), entry not in @project_apps do
        File.ln_s!(Path.join(shared_lib, entry), Path.join(isolated_lib, entry))
      end
    end

    build_path
  end
end
